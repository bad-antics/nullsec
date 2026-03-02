# 🔍 NullSec Recon — OpenClaw Skill

Network reconnaissance and OSINT skill for OpenClaw/Clawd. Covers passive intelligence gathering through active scanning and enumeration.

## Features

- **Passive OSINT** — Subdomain enum, WHOIS, certificate transparency, Google dorking
- **Active scanning** — nmap strategies, host discovery, port analysis
- **Web enumeration** — Directory brute-force, API discovery, tech detection
- **Result analysis** — Priority ports guide, quick-win identification
- **Automation** — Bundled recon script for full workflow

## Installation

### Via ClawHub
Search for `nullsec-recon` on [ClawHub](https://clawhub.com)

### Manual
```bash
cp -r nullsec-recon/ ~/.config/openclaw/skills/
chmod +x scripts/nullsec-recon.sh
```

## Usage

Ask Clawd:
- "Run recon on example.com"
- "Enumerate subdomains for target.org"
- "What ports should I check first on this nmap output?"
- "Help me do OSINT on this company"
- "Analyze these scan results for quick wins"

## About NullSec

Built by [@bad-antics](https://github.com/bad-antics) — 690+ repos, 290+ security tools.

📧 badxantics@gmail.com | 🌐 [bad-antics.github.io](https://bad-antics.github.io)

## License

MIT
