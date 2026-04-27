# WebContentMonitor (WebCM) – Complete Installation Guide

> **One‑stop, privacy‑first alternative to VisualPing**  
> Monitor web page changes, get Slack/Email alerts, view a dashboard, and compare screenshots – all self‑hosted.

---

## 📋 Prerequisites
| Tool | Required? | Notes |
|------|-----------|-------|
| `curl` | ✅ Yes | Fetches web content |
| `jq` | ✅ Yes | Parses JSON config |
| `tmux` | ✅ Yes | Sends local notifications |
| `ffmpeg` / `imagemagick` | ✅ Yes | Screenshot diffing |
| `python3` + `flask` | ✅ Yes | Runs the web dashboard |
| `wkhtmltoimage` | ❌ Optional | Full‑page screenshot capture |
| Systemd | ✅ Yes | Manages the background service |
| Slack workspace / SMTP server | ❌ Optional | For remote notifications |

---

## 🚀 Quick Install (5 minutes)
```bash
# 1. Clone the repo (all files in one place)
git clone https://github.com/aicloudtop-spec/nuc-auto-scripts.git
cd nuc-auto-scripts

# 2. Make the installer executable
chmod +x webcm-install.sh

# 3. Run the installer (auto‑checks prerequisites)
./webcm-install.sh
```

The installer will:
- Create `~/.webcm/` with all config/logs
- Set up a systemd service (`webcm-monitor`)
- Launch the web dashboard on `http://localhost:8080`
- Drop a default `config.json` for you to customise

---

## ⚙️ Post‑Install Configuration
Edit the main config file:
```bash
nano ~/.webcm/config.json
```

### Key settings to update:
```json
{
  "urls": {
    "my-blog": { "url": "https://your-blog.com" },
    "status-page": { "url": "https://status.example.com" }
  },
  "slack_hook_url": "https://hooks.slack.com/services/YOUR/SLACK/HOOK",
  "email_enabled": true,
  "email_user": "alerts@your-domain.com",
  "email_smtp": "smtp.your-domain.com"
}
```

Restart the service to apply changes:
```bash
sudo systemctl restart webcm-monitor
```

---

## 🖥️ Using the Web Dashboard
Open your browser and visit:
```
http://localhost:8080
```

Features:
- 📊 View last 20 change events
- 🔄 Reload/stop the monitor with one click
- 📝 See current config and poll intervals
- 🔔 Real‑time change feed (updates every 30s)

---

## 🎨 GUI / Visual Interface (Planned)
We’re working on a full React‑based GUI with:
- Drag‑and‑drop URL management
- Side‑by‑side screenshot diff viewer
- Priority‑based alert rules
- Template‑driven monitoring for dynamic pages

Watch the repo for updates!

---

## 🛠️ Common Operations
| Task | Command |
|------|---------|
| Check service status | `systemctl status webcm-monitor` |
| View live logs | `tail -f ~/.webcm/logs/monitor.out` |
| Add a new URL | Edit `~/.webcm/config.json` → restart service |
| Stop monitoring | `sudo systemctl stop webcm-monitor` |
| Uninstall completely | `sudo ./webcm-install.sh --uninstall` |

---

## ❓ Troubleshooting
1. **Service won’t start?**
   - Check logs: `journalctl -u webcm-monitor -f`
   - Verify config: `jq . ~/.webcm/config.json`
2. **No notifications?**
   - Test Slack hook: `curl -X POST -H "Content-Type: application/json" -d '{"text":"test"}' YOUR_HOOK_URL`
   - Test email: `echo "test" | sendmail -v your@email.com`
3. **Screenshots not working?**
   - Install `wkhtmltoimage`: `sudo apt install wkhtmltopdf`

---

## 📦 Files in This Repo (All‑in‑One)
```
nuc-auto-scripts/
├── webcm-install.sh   # Main installer script
└── INSTALL.md         # This guide
```

All supporting files (config, dashboard, service definitions) are created automatically in `~/.webcm/` when you run the installer.

---

## 🔗 Links
- Repo: https://github.com/aicloudtop-spec/nuc-auto-scripts
- Dashboard: http://localhost:8080 (after install)
- Issue tracker: https://github.com/aicloudtop-spec/nuc-auto-scripts/issues

---

**Happy monitoring! ☁️**
