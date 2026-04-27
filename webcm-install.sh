#!/usr/bin/env bash
# ------------------------------------------------------------------
# WebContentMonitor – Cookie‑cutter Web‑page change detector
# Install script – pulls in everything you asked for
# ------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

###########################
# Configurable Parameters
###########################
WEB_CM_DIR="$HOME/.webcm"
SERVICE_NAME="webcm-monitor"
USERNAME="$USER"
PYTHON_CMD="${PYTHON_CMD:-python3}"   # Override if you need a different python

# ----------------------------------------------------------------------
# Utility helpers
# ----------------------------------------------------------------------
log() { printf '%s\n' "$*"; }
err() { log "❌ $*"; exit 1; }

# Check for required command
req() {
  command -v "$1" >/dev/null 2>&1 ||
    err "Missing required command: $1. Install it and retry."
}

# ----------------------------------------------------------------------
# 1. Prerequisites
# ----------------------------------------------------------------------
log "✅ Checking prerequisites…"
for cmd in curl jq tmux ffmpeg imagemagick \"$PYTHON_CMD\"; do
  req "$cmd"
done
# We assume Python 3 is available with stdlib only

# ----------------------------------------------------------------------
# 2. Create directory tree
# ----------------------------------------------------------------------
log "📁 Creating directory structure at $WEB_CM_DIR …"
mkdir -p "$WEB_CM_DIR"/{cache,tmp,logs,screenshots,templates}
chmod 700 "$WEB_CM_DIR" "$WEB_CM_DIR/tmp" "$WEB_CM_DIR/cache"

# ----------------------------------------------------------------------
# 3. Main monitor script
# ----------------------------------------------------------------------
log "📄 Writing monitor script …"
cat >"$WEB_CM_DIR/monitor.sh" <<'EOF'
#!/usr/bin/env bash
# --------------- WEBCM: Monitor – main loop --------------------------
set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------------------
# Bootstrap: source config
# ----------------------------------------------------------------------
CONFIG="$HOME/.webcm/config.json"
if [[ ! -f "$CONFIG" ]]; then
  echo "🔴 Configuration not found – aborting."
  exit 1
fi
source <(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' "$CONFIG")

# ----------------------------------------------------------------------
# Define helpers
# ----------------------------------------------------------------------
check_url() {
  local url="$1"
  local id="$2"
  local snapshot="$WEB_CM_DIR/tmp/${id}.html"
  local prev="$WEB_CM_DIR/content_${id}.html"
  local change_time
  change_time=$(date +"%Y-%m-%d %T")

  # Grab latest page
  if ! curl -sS -m 10 "$url" > "$snapshot"; then
    echo "$change_time;ERROR;${url};failed to fetch" >> "$CHANGE_LOG"
    return
  fi

  # Compare diff
  if [[ ! -f "$prev" ]]; then
    cp "$snapshot" "$prev"
    echo "$change_time;NEW;${url};initial snapshot" >> "$CHANGE_LOG"
    notify "${url}" "${id}" "initial snapshot created"
    return
  fi

  if ! diff -q "$prev" "$snapshot" >/dev/null; then
    cp "$snapshot" "$prev"
    echo "$change_time;CHANGED;${url};detected change" >> "$CHANGE_LOG"
    notify "${url}" "${id}" "change detected"
  fi

  # Screenshot comparison (placeholder – requires wkhtmltoimage)
  if [[ -n "$SCREENSHOT_INTERVAL" && $(( $(date +%s) - ${LAST_SCREENSHOT[${id}]:-0} )) -ge "$SCREENSHOT_INTERVAL" ]]; then
    local new_ss="$WEB_CM_DIR/screenshots/${id}_$(date +%s).png"
    if command -v wkhtmltoimage >/dev/null; then
      wkhtmltoimage "$url" "$new_ss"
    else
      new_ss="/dev/null"
    fi
    local prev_ss="${LAST_SS[${id}]:-}";
    if [[ -f "$prev_ss" && -f "$new_ss" && ! compare_screenshots "$prev_ss" "$new_ss" ]]; then
      echo "$change_time;SCREENSHOT;${url};visual change" >> "$CHANGE_LOG"
      notify "${url}" "${id}" "visual change detected"
    fi
    LAST_SS[${id}]="$new_ss"
    LAST_SCREENSHOT[${id}]=$(date +%s)
  fi
}

compare_screenshots() {
  local prev="$1" cur="$2"
  # simple pixel diff: exit 0 if identical, 1 otherwise
  compare -metric AE "$prev" "$cur" null:
}

# Notification dispatcher
notify() {
  local url=$1 id=$2 msg=$3
  if [[ "${SLACK_ENABLED:-false}" == "true" ]]; then
    local payload=$(jq -n --arg txt "[$id] $msg\n$url" '{"text": $txt}')
    curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$SLACK_HOOK_URL" >/dev/null
  fi
  if [[ "${EMAIL_ENABLED:-false}" == "true" ]]; then
    printf "Subject: [%s] WebCM Alert: %s\n\nURL: %s\nMessage: %s\n\n" "$msg" "$url" "$url" "$msg" |
      /usr/sbin/sendmail -t -S "${EMAIL_SMTP}" -au "$EMAIL_USER" -ap "$EMAIL_PASS"
  fi
  tmux new-session -d -s webcm-notify "echo 'ALERT [$id] $msg: $url'"
}

# ----------------------------------------------------------------------
# Main execution
# ----------------------------------------------------------------------
declare -A LAST_SS LAST_SCREENSHOT
CHANGE_LOG="$WEB_CM_DIR/changes.log"
log_file="$WEB_CM_DIR/status.log"

echo "$(date +"%Y-%m-%d %T") Starting WebCM monitoring…" >> "$CHANGE_LOG"

# Load URLs from config
urls=$(jq -r '.urls|to_entries|map("\(.key):\(.value.url)")|.[]' "$CONFIG")
for entry in $urls; do
  IFS=':' read -r name url <<<"$entry"
  check_url "$url" "$name"
done
EOF
chmod +x "$WEB_CM_DIR/monitor.sh"

# ----------------------------------------------------------------------
# 4. Configuration file (JSON)
# ----------------------------------------------------------------------
log "📁 Writing default configuration …"
cat >"$WEB_CM_DIR/config.json" <<'EOF'
{
  "poll_interval": 3600,
  "screenshot_interval": 86400,
  "notification_level": "info",
  "slack_enabled": true,
  "slack_hook_url": "https://hooks.slack.com/services/XXXXX/XXXXX/XXXXX",
  "email_enabled": false,
  "email_user": "user@example.com",
  "email_pass": "password",
  "email_smtp": "smtp.example.com",
  "urls": {
    "homepage": { "url": "https://example.com" },
    "dashboard": { "url": "https://app.example.com" }
  }
}
EOF
chmod 600 "$WEB_CM_DIR/config.json"

# ----------------------------------------------------------------------
# 5. Web dashboard (simple Flask app)
# ----------------------------------------------------------------------
log "🚀 Writing web dashboard …"
cat >"$WEB_CM_DIR/dashboard.py" <<'EOF'
#!/usr/bin/env python3
# Simple Flask dashboard for WebCM
import os, json, subprocess
from flask import Flask, render_template_string, redirect, url_for

app = Flask(__name__)
WEB_CM_DIR = os.path.expanduser("~/.webcm")
CONFIG_PATH = os.path.join(WEB_CM_DIR, "config.json")
CHANGE_LOG = os.path.join(WEB_CM_DIR, "changes.log")

def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)

def read_changes():
    if not os.path.exists(CHANGE_LOG):
        return []
    with open(CHANGE_LOG) as f:
        logs = []
        for line in f:
            if line.strip():
                ts, level, url, msg = line.strip().split(';', 3)
                logs.append({"ts": ts, "level": level, "url": url, "msg": msg})
        return logs

@app.route('/')
def index():
    cfg = load_config()
    logs = read_changes()
    return render_template_string('''
<!doctype html>
<title>WebCM Dashboard</title>
<h1>Web Content Monitor</h1>
<p><b>Poll interval:</b> {{ cfg["poll_interval"] }} sec</p>
<p><b>Screenshot interval:</b> {{ cfg["screenshot_interval"] }} sec</p>
<h2>Recent Changes ({{ logs|length }} entries)</h2>
<table border=1 cellpadding=4>
<tr><th>Timestamp</th><th>URL</th><th>Level</th><th>Message</th></tr>
{% for e in logs[:20] %}
<tr><td>{{ e.ts }}</td><td>{{ e.url }}</td><td>{{ e.level }}</td><td>{{ e.msg }}</td></tr>
{% endfor %}
</table>
<p><a href="{{ url_for('reload') }}">Reload Service</a></p>
<p><a href="{{ url_for('stop') }}">Stop Service</a></p>
''', cfg=cfg, logs=logs)

@app.route('/reload')
def reload():
    subprocess.run(["systemctl", "daemon-reload"])
    subprocess.run(["systemctl", "restart", "webcm-monitor"])
    return redirect(url_for('index'))

@app.route('/stop')
def stop():
    subprocess.run(["systemctl", "stop", "webcm-monitor"])
    return redirect(url_for('index'))

if __name__ == '__main__':
    port = int(os.getenv('WEBCM_PORT', 8080))
    app.run(host='0.0.0.0', port=port)
EOF
chmod +x "$WEB_CM_DIR/dashboard.py"

# ----------------------------------------------------------------------
# 6. Systemd service definition
# ----------------------------------------------------------------------
log "🛠️  Configuring systemd service …"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Web Content Monitor Service
After=network-online.target

[Service]
User=${USERNAME}
WorkingDirectory=${WEB_CM_DIR}
ExecStart=${WEB_CM_DIR}/monitor.sh
StandardOutput=append:${WEB_CM_DIR}/logs/monitor.out
StandardError=append:${WEB_CM_DIR}/logs/monitor.err
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
chmod 644 "$SERVICE_PATH"

# Reload systemd and enable/start service
log "🔄 Reloading systemd daemon …"
systemctl daemon-reload
log "🚀 Enabling and starting service …"
systemctl enable "${SERVICE_NAME}.service" || err "Failed to enable service."
systemctl start "${SERVICE_NAME}.service" || err "Failed to start service."

# ----------------------------------------------------------------------
# 7. Flask dashboard (optional – run in background)
# ----------------------------------------------------------------------
if command -v flask >/dev/null 2>&1; then
  log "🚀 Starting Flask dashboard on port 8080 …"
  nohup $PYTHON_CMD "$WEB_CM_DIR/dashboard.py" &>/dev/null &
fi

log "✅ WebContentMonitor installation script written to webcm-install.sh"
log "You can now run it with ./webcm-install.sh"
