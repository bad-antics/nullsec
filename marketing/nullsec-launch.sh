#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# NullSec Marketing Launch — Account Setup & Post Deployment
# ═══════════════════════════════════════════════════════════════
# This script walks you through creating accounts and posting.
# Email: badxantics@gmail.com
# ═══════════════════════════════════════════════════════════════

set -e

MARKETING_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo -e "${RED}"
    echo "  ╔═══════════════════════════════════════════════════╗"
    echo "  ║     NullSec Marketing Launch Script v1.0          ║"
    echo "  ║     badxantics@gmail.com | github.com/bad-antics  ║"
    echo "  ╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

section() { echo -e "\n${YELLOW}━━━ $1 ━━━${NC}\n"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
info()    { echo -e "  ${CYAN}ℹ${NC} $1"; }
warn()    { echo -e "  ${YELLOW}!${NC} $1"; }
err()     { echo -e "  ${RED}✗${NC} $1"; }
prompt()  { echo -ne "  ${BOLD}▸${NC} $1 "; }

banner

echo -e "This script helps you:"
echo -e "  1. Create Reddit & Hacker News accounts"
echo -e "  2. Configure API credentials"
echo -e "  3. Post to all platforms automatically"
echo -e "  4. Track posting status"
echo ""

# ═══ CREDENTIALS FILE ═══
CREDS_FILE="$MARKETING_DIR/.marketing-creds"

load_creds() {
    if [[ -f "$CREDS_FILE" ]]; then
        source "$CREDS_FILE"
        return 0
    fi
    return 1
}

save_creds() {
    cat > "$CREDS_FILE" << EOF
# NullSec Marketing Credentials
# DO NOT COMMIT THIS FILE
export REDDIT_CLIENT_ID="${REDDIT_CLIENT_ID}"
export REDDIT_CLIENT_SECRET="${REDDIT_CLIENT_SECRET}"
export REDDIT_USERNAME="${REDDIT_USERNAME}"
export REDDIT_PASSWORD="${REDDIT_PASSWORD}"
export HN_USERNAME="${HN_USERNAME}"
export HN_PASSWORD="${HN_PASSWORD}"
EOF
    chmod 600 "$CREDS_FILE"
    ok "Credentials saved to $CREDS_FILE (mode 600)"
}

# ═══ MENU ═══
while true; do
    section "MAIN MENU"
    echo "  1) Reddit Setup & Post"
    echo "  2) Hacker News Setup & Post"
    echo "  3) View Posting Status"
    echo "  4) Dry Run (preview all posts)"
    echo "  5) Launch Everything"
    echo "  6) Open Twitter Drafts"
    echo "  q) Quit"
    echo ""
    prompt "Choice:"
    read -r choice

    case "$choice" in
    1)
        section "REDDIT SETUP"

        load_creds 2>/dev/null || true

        if [[ -z "$REDDIT_USERNAME" ]]; then
            echo -e "  ${BOLD}Step 1: Create Reddit Account${NC}"
            echo "  Open: https://www.reddit.com/register"
            echo "  Email: badxantics@gmail.com"
            echo "  Pick a username (suggestion: NullSec-Antics or BadAntics)"
            echo ""
            prompt "Press Enter after creating the account..."
            read -r

            prompt "Reddit username:"
            read -r REDDIT_USERNAME
            prompt "Reddit password:"
            read -rs REDDIT_PASSWORD
            echo ""
        else
            ok "Reddit username: $REDDIT_USERNAME"
        fi

        if [[ -z "$REDDIT_CLIENT_ID" ]]; then
            echo ""
            echo -e "  ${BOLD}Step 2: Create Reddit App (for API access)${NC}"
            echo "  Open: https://www.reddit.com/prefs/apps/"
            echo "  Click 'create another app...'"
            echo "  Settings:"
            echo "    Name: NullSec"
            echo "    Type: script"
            echo "    Redirect URI: http://localhost:8080"
            echo ""
            prompt "Press Enter after creating the app..."
            read -r

            prompt "Client ID (text under app name):"
            read -r REDDIT_CLIENT_ID
            prompt "Client Secret:"
            read -r REDDIT_CLIENT_SECRET
        else
            ok "Reddit API configured"
        fi

        save_creds
        source "$CREDS_FILE"

        echo ""
        info "Testing Reddit connection..."
        export REDDIT_CLIENT_ID REDDIT_CLIENT_SECRET REDDIT_USERNAME REDDIT_PASSWORD

        python3 "$MARKETING_DIR/nullsec-reddit-poster.py" --dry-run

        echo ""
        prompt "Post to all 6 subreddits now? (y/n):"
        read -r post_now
        if [[ "$post_now" == "y" ]]; then
            python3 "$MARKETING_DIR/nullsec-reddit-poster.py" --delay 600
        else
            info "Run manually: python3 $MARKETING_DIR/nullsec-reddit-poster.py"
        fi
        ;;

    2)
        section "HACKER NEWS SETUP"

        load_creds 2>/dev/null || true

        if [[ -z "$HN_USERNAME" ]]; then
            echo -e "  ${BOLD}Step 1: Create HN Account${NC}"
            echo "  Open: https://news.ycombinator.com/login"
            echo "  Click 'create account'"
            echo "  Username suggestion: bad-antics or nullsec"
            echo ""
            prompt "Press Enter after creating the account..."
            read -r

            prompt "HN username:"
            read -r HN_USERNAME
            prompt "HN password:"
            read -rs HN_PASSWORD
            echo ""
        else
            ok "HN username: $HN_USERNAME"
        fi

        save_creds
        source "$CREDS_FILE"

        echo ""
        echo "  Available posts:"
        echo "    1) Show HN: NullSec — 290+ tools overview"
        echo "    2) Show HN: Prompt Armor — 8-layer LLM defense"
        echo ""
        prompt "Which post? (1/2/both):"
        read -r hn_choice

        export HN_USERNAME HN_PASSWORD

        case "$hn_choice" in
            1)    python3 "$MARKETING_DIR/nullsec-hn-poster.py" --post 1 ;;
            2)    python3 "$MARKETING_DIR/nullsec-hn-poster.py" --post 2 ;;
            both)
                python3 "$MARKETING_DIR/nullsec-hn-poster.py" --post 1
                echo "  Waiting 30 minutes before second post..."
                sleep 1800
                python3 "$MARKETING_DIR/nullsec-hn-poster.py" --post 2
                ;;
            *)    python3 "$MARKETING_DIR/nullsec-hn-poster.py" --dry-run --post 1 ;;
        esac
        ;;

    3)
        section "POSTING STATUS"
        echo -e "  ${BOLD}Reddit:${NC}"
        if [[ -f "$MARKETING_DIR/reddit-post-log.json" ]]; then
            python3 "$MARKETING_DIR/nullsec-reddit-poster.py" --status 2>/dev/null || cat "$MARKETING_DIR/reddit-post-log.json"
        else
            warn "No Reddit posts yet"
        fi

        echo ""
        echo -e "  ${BOLD}Hacker News:${NC}"
        if [[ -f "$MARKETING_DIR/hn-post-log.json" ]]; then
            python3 "$MARKETING_DIR/nullsec-hn-poster.py" --status 2>/dev/null || cat "$MARKETING_DIR/hn-post-log.json"
        else
            warn "No HN posts yet"
        fi

        echo ""
        echo -e "  ${BOLD}Twitter/X:${NC}"
        info "Drafts parked at: $MARKETING_DIR/twitter-drafts-PARKED.md"

        echo ""
        echo -e "  ${BOLD}Product Hunt:${NC}"
        info "Launch copy ready in: $MARKETING_DIR/platform-posts.md"
        info "Product Hunt requires browser submission at producthunt.com/posts/new"
        ;;

    4)
        section "DRY RUN — PREVIEW ALL"
        load_creds 2>/dev/null && source "$CREDS_FILE" 2>/dev/null
        export REDDIT_CLIENT_ID="${REDDIT_CLIENT_ID:-dummy}" REDDIT_CLIENT_SECRET="${REDDIT_CLIENT_SECRET:-dummy}" REDDIT_USERNAME="${REDDIT_USERNAME:-dummy}" REDDIT_PASSWORD="${REDDIT_PASSWORD:-dummy}"
        python3 "$MARKETING_DIR/nullsec-reddit-poster.py" --list
        echo ""
        python3 "$MARKETING_DIR/nullsec-hn-poster.py" --list
        ;;

    5)
        section "LAUNCH EVERYTHING"
        load_creds 2>/dev/null || true

        if [[ -z "$REDDIT_USERNAME" || -z "$REDDIT_CLIENT_ID" ]]; then
            err "Reddit not configured. Run option 1 first."
            continue
        fi

        source "$CREDS_FILE"
        export REDDIT_CLIENT_ID REDDIT_CLIENT_SECRET REDDIT_USERNAME REDDIT_PASSWORD HN_USERNAME HN_PASSWORD

        echo "  This will post to:"
        echo "    • 6 subreddits (5-minute delay between each)"
        if [[ -n "$HN_USERNAME" ]]; then
            echo "    • Hacker News (Show HN #1)"
        fi
        echo ""
        prompt "Launch? (yes/no):"
        read -r launch

        if [[ "$launch" == "yes" ]]; then
            info "Posting to Reddit..."
            python3 "$MARKETING_DIR/nullsec-reddit-poster.py" --delay 300

            if [[ -n "$HN_USERNAME" ]]; then
                info "Posting to Hacker News..."
                python3 "$MARKETING_DIR/nullsec-hn-poster.py" --post 1
            fi

            echo ""
            ok "All posts deployed!"
            echo ""
            info "Remaining manual tasks:"
            info "  • Product Hunt: Submit at https://www.producthunt.com/posts/new"
            info "  • Twitter/X: Post threads from $MARKETING_DIR/twitter-drafts-PARKED.md"
        fi
        ;;

    6)
        section "TWITTER DRAFTS"
        info "File: $MARKETING_DIR/twitter-drafts-PARKED.md"
        echo ""
        echo "  3 threads ready:"
        echo "    Thread 1: NullSec Overview (8 tweets)"
        echo "    Thread 2: Prompt Injection Deep Dive (7 tweets)"
        echo "    Thread 3: Flipper Zero Tips (6 tweets)"
        echo ""
        prompt "Open in editor? (y/n):"
        read -r open_file
        if [[ "$open_file" == "y" ]]; then
            ${EDITOR:-nano} "$MARKETING_DIR/twitter-drafts-PARKED.md"
        fi
        ;;

    q|Q|quit|exit)
        echo ""
        ok "Done. Files in: $MARKETING_DIR/"
        echo ""
        exit 0
        ;;

    *)
        err "Invalid choice"
        ;;
    esac
done
