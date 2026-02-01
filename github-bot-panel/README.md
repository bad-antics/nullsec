# NullSec GitHub Bot Control Panel

A desktop application for GitHub automation, PR review, and repository monitoring.

## Features

### 🔀 Pull Request Management
- View all open PRs across monitored repos
- One-click approve, request changes, merge, or close
- Custom review comments
- View diffs in terminal
- Open in browser

### 🐛 Issue Management  
- View all open issues
- Add comments
- Close issues with comments
- Quick access to GitHub

### 🔔 Notifications
- Real-time GitHub notifications
- Desktop notifications for new PRs
- Mark all as read

### 📊 Repository Stats
- Star count, forks, open issues
- Auto-refresh dashboard

### ⚡ Quick Actions
- Star any repository
- Follow any user
- Batch approve all pending PRs
- Create issues from the app

### ⚙️ Settings
- Configure monitored repositories
- Auto-refresh interval
- Notification preferences
- Auto-star contributors

## Requirements

- Python 3.8+
- GTK 3.0
- GitHub CLI (`gh`) authenticated
- libnotify

## Installation

```bash
# Install dependencies (Debian/Ubuntu)
sudo apt install python3-gi gir1.2-gtk-3.0 gir1.2-notify-0.7

# Make executable
chmod +x github_bot_panel.py

# Install desktop entry
cp github-bot-panel.desktop ~/.local/share/applications/
```

## Usage

```bash
# Run directly
./github_bot_panel.py

# Or from applications menu
# Look for "NullSec GitHub Bot"
```

## Configuration

Config is stored at `~/.config/nullsec-github-bot/config.json`

Default monitored repos:
- bad-antics/awesome-julia-security
- bad-antics/securevault
- bad-antics/hashforensics
- bad-antics/netprobe

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+R | Refresh all data |
| Ctrl+Q | Quit |

## Screenshots

```
┌─────────────────────────────────────────────────────────────────────┐
│ █▀█  NULLSEC GITHUB BOT  █▀█                    ● ONLINE   🔔 3    │
├─────────────────────────────────────────────────────────────────────┤
│ [🔀 Pull Requests] [🐛 Issues] [🔔 Notifications] [📊 Stats]       │
├─────────────────────────────────────────────────────────────────────┤
│ 📋 PENDING REVIEWS          │  #42 Add new security tool            │
│                              │                                       │
│ ● #42 Add new security tool  │  Repository: bad-antics/awesome-...  │
│   awesome-julia-security     │  Author: contributor123               │
│   by contributor123          │  State: OPEN                          │
│                              │  Review: PENDING                      │
│ ✓ #41 Fix typo in README     │                                       │
│   awesome-julia-security     │  Review Comment:                      │
│   by helper456               │  ┌─────────────────────────────────┐  │
│                              │  │ LGTM! Thanks for contributing 🚀│  │
│                              │  └─────────────────────────────────┘  │
│                              │                                       │
│                              │  [✓ Approve] [⚠ Changes] [🔀 Merge]  │
│                              │                                       │
│                              │  Activity Log:                        │
│                              │  [14:23:01] Selected PR #42           │
│                              │  [14:23:05] Approved PR #42           │
└─────────────────────────────────────────────────────────────────────┘
```

## License

MIT
