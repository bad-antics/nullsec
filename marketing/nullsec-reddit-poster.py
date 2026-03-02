#!/usr/bin/env python3
"""
NullSec Reddit Poster — Automated posting via PRAW
Usage:
  1. Create Reddit account at https://www.reddit.com/register (use badxantics@gmail.com)
  2. Create a Reddit app at https://www.reddit.com/prefs/apps/
     - Click "create another app"
     - Select "script"
     - Name: NullSec
     - Redirect URI: http://localhost:8080
     - Copy the client_id (under app name) and client_secret
  3. Set environment variables:
     export REDDIT_CLIENT_ID="your_client_id"
     export REDDIT_CLIENT_SECRET="your_client_secret"
     export REDDIT_USERNAME="your_username"
     export REDDIT_PASSWORD="your_password"
  4. Run: python3 nullsec-reddit-poster.py [--dry-run] [--subreddit r/netsec]
"""

import os
import sys
import time
import json
import argparse
from datetime import datetime

try:
    import praw
except ImportError:
    print("ERROR: praw not installed. Run: pip3 install --user --break-system-packages praw")
    sys.exit(1)

# ═══════════════════════════════════════════════════════════════
# POST DEFINITIONS — All 6 Reddit posts ready to go
# ═══════════════════════════════════════════════════════════════

POSTS = {
    "netsec": {
        "subreddit": "netsec",
        "title": "[Tool] NullSec: 290+ Open-Source Security Tools & Pentest Framework",
        "selftext": """Hey r/netsec,

I've been building NullSec — an open-source security toolkit with 290+ tools across 690+ GitHub repos. Wanted to share some of the highlights:

**What's in the toolkit:**

- **NullSec Linux** — Security-focused distro with pre-configured tools, hardened kernel, and custom package repo. Free community tier, Pro ($49/yr) and Enterprise ($199/yr) with managed SOC dashboards.
- **Prompt Armor v2.0** — 8-layer defense against LLM prompt injection attacks. Tested against 50+ known injection vectors. Pattern matching, context isolation, token analysis, behavioral monitoring.
- **183+ Hak5 WiFi Pineapple payloads** — Everything from automated recon to evil twin, 5GHz hunting, BLE reconnaissance, drone detection, and AI-powered network classification.
- **Simulacra Detection Engine** — Social engineering defense that identifies manipulated media and deepfakes.

**Technical highlights:**

- Full pentest workflow automation (recon → scan → exploit → report)
- 9-node cluster running distributed scanning and payload deployment
- Custom firmware builder for Hak5 hardware
- Enterprise breach simulation suite
- All tools are open source under MIT

**Links:**

- GitHub: https://github.com/bad-antics
- Portfolio: https://bad-antics.github.io
- NullSec Linux: https://bad-antics.github.io/nullsec-linux/
- Prompt Armor: https://bad-antics.github.io/nullsec-prompt-armor/
- WiFi Pineapple Payloads: https://github.com/bad-antics/hak5-pineapple

Happy to answer questions about the architecture or specific tools. PRs welcome."""
    },

    "hacking": {
        "subreddit": "hacking",
        "title": "NullSec Linux: A Security Distro Built for Real Engagements (290+ tools, free tier available)",
        "selftext": """Built a security-focused Linux distro called NullSec Linux. Unlike Kali/Parrot which ship everything, NullSec is modular — install only the toolsets you need.

**What makes it different:**

- 290+ curated security tools (not just apt packages — custom-built tools tested in real engagements)
- Hardened kernel with security patches
- Pre-configured tool chains that actually work together
- Custom package repository for NullSec-specific tools
- 9-node cluster support for distributed scanning
- Built-in C2 relay and mesh networking

**Tiers:**

- 🆓 Community — Core tools, community support
- 💼 Pro ($49/yr) — Full toolset, priority updates, private repo access
- 🏢 Enterprise ($199/yr) — Managed SOC dashboard, dedicated support, compliance reporting

Built this because I was tired of spending the first day of every engagement fixing broken tool dependencies. Everything in NullSec just works.

**Links:**

- https://bad-antics.github.io/nullsec-linux/
- GitHub: https://github.com/bad-antics (690+ repos)

Contact: badxantics@gmail.com"""
    },

    "FlipperZero": {
        "subreddit": "FlipperZero",
        "title": "[Release] NullSec Flipper Suite — 430+ files covering SubGHz, RFID, NFC, IR, BadUSB, and WiFi",
        "selftext": """Hey Flipper community,

Releasing my Flipper Zero payload suite — 430+ files organized by category:

**What's included:**

📡 **SubGHz** — Garage door testing, car fob analysis, frequency scanning, replay tools
🔒 **RFID** — Badge cloning, access control testing, Wiegand capture
💳 **NFC** — Card emulation, tag manipulation, payment testing
📺 **IR** — Universal remote databases, custom device profiles
⌨️ **BadUSB** — Keystroke injection payloads, credential harvesters, reverse shells
📶 **WiFi** — Deauth, evil twin, captive portal (with Marauder/Pineapple integration)

**Tiers:**

- 🆓 Community — Core payloads, basic categories
- 💼 Pro ($19/mo) — Full suite, priority updates, custom payload requests
- 👥 Team ($99/mo) — Multi-device management, shared payload libraries

Everything is organized with documentation explaining what each payload does, how to use it, and what it's testing for. No script kiddie nonsense — these are professional pentesting payloads.

**Links:**

- https://bad-antics.github.io/nullsec-flipper-suite/
- GitHub: https://github.com/bad-antics
- Contact: badxantics@gmail.com"""
    },

    "CarHacking": {
        "subreddit": "CarHacking",
        "title": "BlackFlag ECU — CAN bus analysis, ECU diagnostics, and automotive security testing toolkit",
        "selftext": """Been working on BlackFlag ECU — an automotive security toolkit for CAN bus analysis, ECU diagnostics, and vehicle security testing.

**Features:**

- CAN bus sniffing and injection
- OBD-II diagnostic scanning
- ECU firmware extraction and analysis
- UDS (Unified Diagnostic Services) fuzzing
- J1939 heavy vehicle protocol support
- Replay attack testing
- Custom DBC file support

**Tiers:**

- 🆓 Hobbyist — Basic CAN tools, OBD-II scanning
- 💼 Pro ($29/mo) — Full ECU analysis, firmware tools, UDS fuzzing
- 🏪 Shop ($149/mo) — Multi-vehicle fleet support, compliance reporting, priority support

Built this after finding most automotive security tools were either $10k+ enterprise software or abandoned GitHub repos from 2018. BlackFlag bridges that gap.

**Links:**

- https://bad-antics.github.io/blackflag-ecu/
- GitHub: https://github.com/bad-antics
- Contact: badxantics@gmail.com"""
    },

    "linux": {
        "subreddit": "linux",
        "title": "NullSec Linux — Security-focused distro with modular tool installation and 9-node cluster support",
        "selftext": """Built a security-focused Linux distribution that takes a different approach from Kali/Parrot:

**Philosophy:**

Instead of shipping 600+ tools where half are broken or outdated, NullSec Linux is **modular**. Install only what you need:

```
nullsec-install --toolset recon        # Recon tools only
nullsec-install --toolset web          # Web app testing
nullsec-install --toolset wireless     # WiFi/BLE/SDR
nullsec-install --toolset forensics    # DFIR toolkit
nullsec-install --full                 # Everything
```

**Technical details:**

- Hardened kernel with custom security patches
- Custom package repository (290+ tools)
- SystemD hardening profiles for all services
- Built-in mesh networking for distributed operations
- 9-node cluster support for parallel scanning
- AppArmor profiles for all pentest tools
- Reproducible builds

**Free tier** includes core tools and community support. Pro/Enterprise tiers add managed dashboards and priority updates.

- https://bad-antics.github.io/nullsec-linux/
- https://github.com/bad-antics (690+ repos)
- badxantics@gmail.com"""
    },

    "cybersecurity": {
        "subreddit": "cybersecurity",
        "title": "Security Consulting & Tools: Pentesting, AI/LLM Security, Wireless, Automotive — 690+ open-source tools",
        "selftext": """I run NullSec — a security consultancy backed by 690+ open-source repositories and 290+ custom security tools. Offering services in:

**Specialties:**

🔒 **Penetration Testing** — Network, web app, wireless, and physical security assessments

🤖 **AI/LLM Security** — Prompt injection defense (Prompt Armor v2.0), model security auditing, adversarial testing for AI systems

📡 **Wireless Security** — WiFi, Bluetooth, RFID, NFC assessments. 183+ Hak5 Pineapple payloads.

🚗 **Automotive Security** — CAN bus analysis, ECU testing, vehicle security assessments

🐧 **Security Infrastructure** — Custom security distro (NullSec Linux), 9-node distributed scanning cluster

**Products (all have free tiers):**

| Product | What It Does | Free? |
|---------|-------------|-------|
| NullSec Linux | Security distro | ✅ |
| Prompt Armor | AI injection defense | ✅ |
| Marshall Browser | Hardened browser | ✅ |
| Flipper Suite | 430+ Flipper payloads | ✅ |
| BlackFlag ECU | Auto security | ✅ |
| RCE Shield | Anti-cheat/exploit | ✅ |

**Contact:** badxantics@gmail.com
**Portfolio:** https://bad-antics.github.io
**GitHub:** https://github.com/bad-antics

Happy to do a free initial assessment for interesting projects."""
    }
}

# ═══════════════════════════════════════════════════════════════
# POSTING ENGINE
# ═══════════════════════════════════════════════════════════════

LOG_FILE = os.path.expanduser("~/nullsec/marketing/reddit-post-log.json")

def get_reddit():
    """Initialize PRAW Reddit instance."""
    client_id = os.environ.get("REDDIT_CLIENT_ID")
    client_secret = os.environ.get("REDDIT_CLIENT_SECRET")
    username = os.environ.get("REDDIT_USERNAME")
    password = os.environ.get("REDDIT_PASSWORD")

    missing = []
    if not client_id: missing.append("REDDIT_CLIENT_ID")
    if not client_secret: missing.append("REDDIT_CLIENT_SECRET")
    if not username: missing.append("REDDIT_USERNAME")
    if not password: missing.append("REDDIT_PASSWORD")

    if missing:
        print(f"\n❌ Missing environment variables: {', '.join(missing)}")
        print("\nSetup steps:")
        print("  1. Create Reddit account at https://www.reddit.com/register")
        print("     (use badxantics@gmail.com)")
        print("  2. Go to https://www.reddit.com/prefs/apps/")
        print("  3. Click 'create another app...'")
        print("  4. Select 'script', name it 'NullSec', redirect URI: http://localhost:8080")
        print("  5. Export the credentials:")
        print(f'     export REDDIT_CLIENT_ID="<id under app name>"')
        print(f'     export REDDIT_CLIENT_SECRET="<secret>"')
        print(f'     export REDDIT_USERNAME="{username or "your_username"}"')
        print(f'     export REDDIT_PASSWORD="your_password"')
        sys.exit(1)

    return praw.Reddit(
        client_id=client_id,
        client_secret=client_secret,
        username=username,
        password=password,
        user_agent="NullSec Marketing Bot v1.0 by /u/" + username
    )

def load_log():
    """Load posting log."""
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE) as f:
            return json.load(f)
    return {"posts": {}}

def save_log(log_data):
    """Save posting log."""
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, "w") as f:
        json.dump(log_data, f, indent=2)

def post_to_subreddit(reddit, sub_key, dry_run=False):
    """Post a single entry to its subreddit."""
    post_data = POSTS[sub_key]
    subreddit_name = post_data["subreddit"]
    title = post_data["title"]
    body = post_data["selftext"]

    log = load_log()

    if sub_key in log["posts"]:
        print(f"  ⏭️  r/{subreddit_name} — Already posted ({log['posts'][sub_key]['url']})")
        return

    if dry_run:
        print(f"  🔍 [DRY RUN] r/{subreddit_name}")
        print(f"     Title: {title[:80]}...")
        print(f"     Body: {len(body)} chars")
        return

    try:
        subreddit = reddit.subreddit(subreddit_name)
        submission = subreddit.submit(title=title, selftext=body)
        url = f"https://www.reddit.com{submission.permalink}"
        print(f"  ✅ r/{subreddit_name} — Posted! {url}")

        log["posts"][sub_key] = {
            "subreddit": subreddit_name,
            "url": url,
            "title": title,
            "posted_at": datetime.now().isoformat(),
            "id": submission.id
        }
        save_log(log)

    except praw.exceptions.RedditAPIException as e:
        print(f"  ❌ r/{subreddit_name} — API Error: {e}")
        # Check for rate limiting
        for item in e.items:
            if item.error_type == "RATELIMIT":
                wait = int(''.join(filter(str.isdigit, item.message)) or "60")
                print(f"     Rate limited. Waiting {wait} seconds...")
                time.sleep(wait)
    except Exception as e:
        print(f"  ❌ r/{subreddit_name} — Error: {e}")

def main():
    parser = argparse.ArgumentParser(description="NullSec Reddit Poster")
    parser.add_argument("--dry-run", action="store_true", help="Preview posts without submitting")
    parser.add_argument("--subreddit", "-s", help="Post to specific subreddit only (e.g., netsec)")
    parser.add_argument("--list", action="store_true", help="List all available posts")
    parser.add_argument("--status", action="store_true", help="Show posting status")
    parser.add_argument("--delay", type=int, default=300, help="Seconds between posts (default: 300)")
    args = parser.parse_args()

    if args.list:
        print("\n📋 Available Reddit posts:\n")
        for key, data in POSTS.items():
            print(f"  r/{data['subreddit']:15s} — {data['title'][:60]}...")
        print(f"\n  Total: {len(POSTS)} posts")
        return

    if args.status:
        log = load_log()
        print("\n📊 Posting Status:\n")
        for key in POSTS:
            if key in log.get("posts", {}):
                entry = log["posts"][key]
                print(f"  ✅ r/{POSTS[key]['subreddit']:15s} — {entry['posted_at'][:10]} — {entry['url']}")
            else:
                print(f"  ⬜ r/{POSTS[key]['subreddit']:15s} — Not posted")
        return

    print("\n🔒 NullSec Reddit Poster")
    print("━" * 40)

    reddit = get_reddit()

    # Verify authentication
    try:
        user = reddit.user.me()
        print(f"✅ Authenticated as u/{user.name}")
        print(f"   Karma: {user.link_karma} link / {user.comment_karma} comment")
    except Exception as e:
        print(f"❌ Authentication failed: {e}")
        sys.exit(1)

    targets = {args.subreddit: POSTS[args.subreddit]} if args.subreddit else POSTS
    total = len(targets)

    print(f"\n📮 Posting to {total} subreddit(s)...\n")

    for i, (key, _) in enumerate(targets.items()):
        post_to_subreddit(reddit, key, dry_run=args.dry_run)

        # Delay between posts to avoid rate limiting (except last one)
        if i < total - 1 and not args.dry_run:
            delay = args.delay
            print(f"\n  ⏳ Waiting {delay}s before next post (rate limit protection)...\n")
            time.sleep(delay)

    print("\n✅ Done! Run with --status to check post URLs.")
    print("   Contact: badxantics@gmail.com\n")

if __name__ == "__main__":
    main()
