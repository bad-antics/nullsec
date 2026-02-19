# NullSec NightShift 🌙

Automated overnight cluster compute scheduler. Puts your idle machines to work while you sleep — running bug bounty recon, security audits, system hardening, and maintenance tasks across every node in your mesh.

## Job Categories

| Category | Icon | Jobs | Purpose |
|----------|------|------|---------|
| **Revenue** | 💰 | hashcat-benchmark, subfinder-recon, nuclei-scan | Bug bounty recon, cracking benchmarks |
| **Research** | 🔬 | shodan-monitor, wifi-survey | Network intelligence, passive collection |
| **Hardening** | 🛡️ | lynis-audit, rkhunter-check, clamav-scan, firewall-audit | Security posture checks |
| **Maintenance** | 🧹 | disk-cleanup, update-check, backup-nullsec-config, health-report | Cluster upkeep |

## Quick Start

### CLI Mode
```bash
cd nullsec-nightshift
pip install -r requirements.txt

# List all jobs
python nightshift.py jobs

# Check cluster status
python nightshift.py status

# Run shift now (respects time window)
python nightshift.py run

# Force run regardless of time
python nightshift.py run --force

# Run only revenue jobs
python nightshift.py run --cat=revenue

# Print crontab entry
python nightshift.py cron
```

### Web Dashboard (port 9006)
```bash
python run.py
# → http://localhost:9006
```

### Automatic Nightly Run (cron)
```bash
# Add to crontab:
0 22 * * * cd /path/to/nullsec-nightshift && python nightshift.py run --force >> ~/.nullsec/nightshift/logs/cron.log 2>&1
```

## Architecture

```
nightshift.py         CLI + scheduler engine
├── Job definitions   13 built-in jobs across 4 categories
├── Cluster loader    Reads ~/.nullsec/cluster/nodes.conf
├── Node matcher      Assigns jobs to compatible nodes (OS, GPU, cores, RAM)
├── SSH executor      Runs commands on remote nodes via paramiko
└── Report generator  JSON reports saved to ~/.nullsec/nightshift/results/

app/__init__.py       FastAPI web dashboard
├── GET  /            Dashboard UI
├── GET  /api/status  Cluster + time window status
├── GET  /api/jobs    List all scheduled jobs
├── POST /api/shift/run   Trigger a shift
├── GET  /api/history     Past shift reports
├── GET  /api/report/{id} Single report detail
└── WS   /ws              Live updates during shift execution
```

## Job Matching

Each job declares requirements — the scheduler matches them to available nodes:

| Requirement | Example | Matching Logic |
|------------|---------|----------------|
| `target_os` | `linux` | Node OS must match |
| `requires_gpu` | `true` | Node must have GPU field set |
| `min_cores` | `4` | Node cores ≥ job requirement |
| `min_ram_mb` | `2048` | Node RAM ≥ job requirement |
| `run_on` | `controller` | Only runs on controller node |

## Adding Custom Jobs

Create a JSON file in `~/.nullsec/nightshift/jobs/`:
```json
{
    "name": "my-custom-scan",
    "category": "revenue",
    "description": "Custom recon job",
    "command": "nmap -sV -top-ports 100 target.com",
    "target_os": "linux",
    "requires_gpu": false,
    "priority": 5,
    "timeout_sec": 1800,
    "enabled": true
}
```

## Bug Bounty Targets

Create `~/.nullsec/nightshift/targets.txt` with one domain per line:
```
example.com
target.org
scope.io
```

The `subfinder-recon` and `nuclei-scan` jobs will automatically use this list.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `NULLSEC_BIND` | `0.0.0.0` | Web dashboard bind address |
| `NULLSEC_NIGHTSHIFT_PORT` | `9006` | Web dashboard port |
| `NULLSEC_DEBUG` | `0` | Enable debug/reload mode |
| `SHODAN_API_KEY` | — | For Shodan research job |

## File Locations

```
~/.nullsec/nightshift/
├── jobs/             Custom job definitions
├── results/          Shift reports (shift_YYYYMMDD_HHMMSS.json)
├── logs/             Cron logs
└── targets.txt       Bug bounty target domains
```

## Port: 9006

Part of the NullSec App Network:
- WebTools :9000 | Monitor :9001 | Scanner :9002 | Bench :9003
- Prompt Armor :9004 | Race Audit :9005 | **NightShift :9006**
