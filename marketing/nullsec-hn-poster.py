#!/usr/bin/env python3
"""
NullSec Hacker News Poster — Submit Show HN posts via HN API
Usage:
  1. Create HN account at https://news.ycombinator.com/login (use badxantics@gmail.com)
  2. Set environment variables:
     export HN_USERNAME="your_username"
     export HN_PASSWORD="your_password"
  3. Run: python3 nullsec-hn-poster.py [--dry-run] [--post 1|2]
"""

import os
import sys
import json
import time
import argparse
import requests
from datetime import datetime

# ═══════════════════════════════════════════════════════════════
# SHOW HN POSTS
# ═══════════════════════════════════════════════════════════════

POSTS = {
    "1": {
        "title": "Show HN: NullSec – 290+ open-source security tools, pentest framework, and security distro",
        "url": "https://bad-antics.github.io",
        "text": """Hi HN,

I've been building NullSec for the past few years — it started as a personal toolkit and grew into a full security framework with 290+ tools across 690+ GitHub repos.

Some highlights:

• NullSec Linux — Modular security distro. Install only what you need instead of getting 600+ tools where half are broken. Hardened kernel, custom package repo.

• Prompt Armor v2.0 — 8-layer defense against LLM prompt injection. Pattern matching → context isolation → token analysis → behavioral monitoring. Tested against 50+ injection vectors.

• 183+ Hak5 WiFi Pineapple payloads — Automated recon, evil twin, 5GHz hunting, AI-powered network classification.

• Marshall Browser — Hardened Chromium fork with built-in ad blocking, tracker prevention, and privacy features.

• Distributed scanning — 9-node cluster for parallel security assessments.

Everything has a free tier. Pro/Enterprise tiers for teams that need managed dashboards, compliance reporting, and dedicated support.

Tech stack: Bash/Python/C for tools, custom Linux kernel, mesh networking between nodes.

GitHub: https://github.com/bad-antics

Would love feedback on the architecture. Happy to discuss the prompt injection defense system — that's been the most technically interesting part to build."""
    },
    "2": {
        "title": "Show HN: Prompt Armor – 8-layer defense system against LLM prompt injection attacks",
        "url": "https://bad-antics.github.io/nullsec-prompt-armor/",
        "text": """Built an 8-layer defense system for LLM prompt injection:

1. Input Sanitization — Strip known injection patterns
2. Context Isolation — Separate system/user/assistant contexts
3. Token Analysis — Detect suspicious token sequences
4. Semantic Boundary — Enforce instruction hierarchy
5. Output Filtering — Prevent data leakage in responses
6. Behavioral Monitoring — Track deviation from expected behavior
7. Rate Limiting — Prevent brute-force injection attempts
8. Audit Logging — Full request/response chain logging

Tested against 50+ known injection vectors including DAN, jailbreaks, indirect injection via tool calls, and multi-turn manipulation.

The interesting technical challenge was layer 4 (Semantic Boundary) — enforcing instruction hierarchy without making the model useless. We ended up using a combination of prompt templating and runtime context tagging.

Free for individual use. Team plans start at $29/mo.

GitHub: https://github.com/bad-antics"""
    }
}

LOG_FILE = os.path.expanduser("~/nullsec/marketing/hn-post-log.json")

def load_log():
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE) as f:
            return json.load(f)
    return {"posts": {}}

def save_log(data):
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, "w") as f:
        json.dump(data, f, indent=2)

def login_hn(username, password):
    """Login to Hacker News and get session cookie."""
    session = requests.Session()
    resp = session.post("https://news.ycombinator.com/login", data={
        "acct": username,
        "pw": password,
        "goto": "news"
    }, allow_redirects=False)

    if resp.status_code in (301, 302) or "user?id=" in resp.text:
        print(f"✅ Logged in as {username}")
        return session
    else:
        print(f"❌ Login failed (status {resp.status_code})")
        return None

def submit_hn(session, title, url=None, text=None):
    """Submit a story to Hacker News."""
    # First get the fnid (form nonce)
    resp = session.get("https://news.ycombinator.com/submit")
    if resp.status_code != 200:
        print(f"❌ Could not load submit page (status {resp.status_code})")
        return None

    # Extract fnid from form
    import re
    fnid_match = re.search(r'name="fnid" value="([^"]+)"', resp.text)
    if not fnid_match:
        print("❌ Could not find form nonce (fnid)")
        return None

    fnid = fnid_match.group(1)

    data = {
        "fnid": fnid,
        "fnop": "submit-page",
        "title": title,
    }

    if url:
        data["url"] = url
    if text:
        data["text"] = text

    resp = session.post("https://news.ycombinator.com/r", data=data, allow_redirects=True)

    if resp.status_code == 200 and ("item?id=" in resp.url or "newest" in resp.url):
        print(f"✅ Submitted: {title[:60]}...")
        # Try to find the post URL
        item_match = re.search(r'item\?id=(\d+)', resp.url)
        if item_match:
            return f"https://news.ycombinator.com/item?id={item_match.group(1)}"
        return resp.url
    else:
        print(f"❌ Submit may have failed (status {resp.status_code}, url: {resp.url})")
        return None

def main():
    parser = argparse.ArgumentParser(description="NullSec HN Poster")
    parser.add_argument("--dry-run", action="store_true", help="Preview without posting")
    parser.add_argument("--post", choices=["1", "2"], help="Which post to submit (1=NullSec overview, 2=Prompt Armor)")
    parser.add_argument("--list", action="store_true", help="List available posts")
    parser.add_argument("--status", action="store_true", help="Show posting status")
    args = parser.parse_args()

    if args.list:
        print("\n📋 Available HN posts:\n")
        for key, data in POSTS.items():
            print(f"  [{key}] {data['title'][:70]}...")
            print(f"      URL: {data['url']}")
        return

    if args.status:
        log = load_log()
        print("\n📊 HN Posting Status:\n")
        for key in POSTS:
            if key in log.get("posts", {}):
                entry = log["posts"][key]
                print(f"  ✅ Post {key}: {entry.get('url', 'posted')} — {entry['posted_at'][:10]}")
            else:
                print(f"  ⬜ Post {key}: {POSTS[key]['title'][:60]}...")
        return

    username = os.environ.get("HN_USERNAME")
    password = os.environ.get("HN_PASSWORD")

    if not username or not password:
        print("\n❌ Missing HN credentials.")
        print("\nSetup:")
        print("  1. Create account at https://news.ycombinator.com/login")
        print("  2. export HN_USERNAME='your_username'")
        print("  3. export HN_PASSWORD='your_password'")
        sys.exit(1)

    post_key = args.post or "1"
    post = POSTS[post_key]

    print(f"\n🔶 NullSec HN Poster — Post #{post_key}")
    print("━" * 40)
    print(f"Title: {post['title']}")
    print(f"URL:   {post['url']}")
    print(f"Text:  {len(post['text'])} chars")

    if args.dry_run:
        print("\n[DRY RUN] Would submit above post.")
        return

    log = load_log()
    if post_key in log.get("posts", {}):
        print(f"\n⏭️  Already posted: {log['posts'][post_key].get('url', 'unknown')}")
        return

    session = login_hn(username, password)
    if not session:
        sys.exit(1)

    # For Show HN, submit with text (self-post)
    result_url = submit_hn(session, post["title"], text=post["text"])

    if result_url:
        log["posts"][post_key] = {
            "title": post["title"],
            "url": result_url,
            "posted_at": datetime.now().isoformat()
        }
        save_log(log)
        print(f"\n✅ Posted! URL: {result_url}")
    else:
        print("\n⚠️  Submission result uncertain. Check https://news.ycombinator.com/newest")

if __name__ == "__main__":
    main()
