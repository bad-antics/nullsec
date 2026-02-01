#!/bin/bash
# NullSec GitHub Bot Control Panel Launcher

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check gh auth
if ! gh auth status &>/dev/null; then
    echo "GitHub CLI not authenticated. Run 'gh auth login' first."
    exit 1
fi

# Launch the panel
cd "$SCRIPT_DIR"
python3 github_bot_panel.py "$@"
