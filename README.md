# WebContentMonitor (WebCM)

> 🏡 **A self‑hosted VisualPing alternative** – monitor web page changes, receive Slack/Email alerts, view a live dashboard, and compare screenshots.

---

## 📋 Prerequisites
| Tool | Required | Notes |
|------|----------|-------|
| `curl` | ✔︎ | Fetches page content |
| `jq` | ✔︎ | Parses JSON config |
| `tmux` | ✔︎ | Local notifications |
| `ffmpeg` / `ImageMagick` | ✔︎ | Screenshot diffing |
| `python3` + `flask` | ✔︎ | Web dashboard |
| `wkhtmltoimage` | ❌ Optional | Full‑page capture |
| Systemd | ✔︎ | Background service |
| Slack / SMTP | ❌ Optional | For remote alerts |

---

## 🚀 Quick Install (5 min)
```bash
# 1. Clone the repo
git clone https://github.com/aicloudtop-spec/webcm.git
cd webcm

# 2. Make installer executable
chmod +x webcm-install.sh

# 3. Run installer (auto‑checks prerequisites)
./webcm-install.sh
```

The installer:
- Creates `~/.webcm/` with all configs, logs, and temp directories
- Sets up a systemd service (`webcm-monitor`)
- Starts the Flask dashboard on `http://localhost:8080`
- Leaves a default `config.json` ready for you to edit

---

## ⚙️ Post‑Install Configuration
Edit the configuration file:
```bash
nano ~/.webcm/config.json
```

Below is a summary of keys you’ll want to set:
```json
{
  "poll_interval": 3600,
  "screenshot_interval": 86400,
  "slack_enabled": true,
  "slack_hook_url": "https://hooks.slack.com/services/...",
  "email_enabled": true,
  "email_user": "alert@your-domain.com",
  "email_pass": "$YOUR_SMTP_PASS",
  "email_smtp": "smtp.your-domain.com",
  "urls": {
    "my‑blog": { "url": "https://example.com" },
    "status‑page": { "url": "https://status.example.com" }
  }
}
```

After editing, apply the changes:
```bash
sudo systemctl restart webcm-monitor
```

---

## 📊 Web Dashboard
Navigate to <http://localhost:8080> to see:
- Latest change log (top 20 entries)
- Service status and logs
- Config details with easy refresh
- Quick controls to start/stop/reload the monitor

---

## 📦 How the Installer Works
* The **installer** creates the required directories, installs the systemd unit, and launches the service.
* The **monitor script** (`monitor.sh`) pulls page content, diff‑compares it, and records changes.
* The **Flask dashboard** (`dashboard.py`) provides a human‑friendly web UI.

---

## 🛠️ Troubleshooting
| Problem | Quick Fix |
|---------|-----------|
| Service won’t start | `journalctl -u webcm-monitor -f` – check for errors |
| No alerts | Verify Slack webhook AND test with `curl` |
| No screenshots | Install `wkhtmltoimage`: `sudo apt install wkhtmltopdf` |
| Missing `config.json` | Copy the default file from the repo and run `chmod 600` |

---

## 📚 Further Reading
- `webcm-install.sh` – the installation script
- `dashboard.py` – the Flask dashboard code
- `monitor.sh` – the background monitor
- `config.json` – example configuration template

---

**Happy monitoring!**

