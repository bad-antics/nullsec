# NullSec Architecture

> System design overview for the NullSec offensive security platform.

```
┌─────────────────────────────────────────────────────────────────┐
│                    NullSec App Network                          │
│                                                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐           │
│  │   WebTools    │ │   Monitor    │ │   Scanner    │           │
│  │   Hub :9000   │ │   Live :9001 │ │   Recon :9002│           │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘           │
│         │                │                │                     │
│  ┌──────┴───────┐ ┌──────┴───────┐ ┌──────┴───────┐           │
│  │    Bench     │ │ Prompt Armor │ │  Race Audit  │           │
│  │  Perf :9003  │ │  Guard :9004 │ │  Fuzz :9005  │           │
│  └──────────────┘ └──────────────┘ └──────────────┘           │
│                                                                 │
│  ┌──────────────────────────────────────────────────┐          │
│  │              NullSec NightShift                   │          │
│  │     Cluster job scheduler (cron-driven)           │          │
│  └──────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NullSec Mesh Cluster                         │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ nullsec  │  │ doomsday │  │ nullkia  │  │  fairy   │      │
│  │ ctrl/12c │  │ win/gpu  │  │ arm/4c   │  │ win/gpu  │      │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │thinkcentr│  │DESKTOP-F3│  │  parrot  │  │   r420   │      │
│  │ win/work │  │ win/gpu  │  │ lin/work │  │ srv/32c  │      │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Layout

```
hak5-pineapple/                    # Workspace (source of truth)
├── nullsec-webtools/              # Hub dashboard + cluster management
│   ├── app/
│   │   ├── __init__.py            # FastAPI app, static/template setup
│   │   ├── config.py              # Paths, secrets, env vars
│   │   ├── routers/               # Route modules (dashboard, cluster, etc.)
│   │   ├── services/              # Cluster SSH, node stat collection
│   │   ├── static/css/            # nullsec.css shared theme
│   │   └── templates/             # Jinja2 HTML (base.html, dashboard.html, ...)
│   ├── run.py                     # Entrypoint
│   └── requirements.txt
│
├── nullsec-monitor/               # Real-time cluster health monitor
│   ├── app/__init__.py            # WebSocket broadcast loop, stat collection
│   ├── templates/monitor.html     # Chart.js live graphs, node cards
│   └── run.py
│
├── nullsec-scanner/               # Network reconnaissance tool
│   ├── app/__init__.py            # Port scan, subnet discovery, fingerprinting
│   ├── templates/scanner.html     # Tabbed scan UI, host cards
│   └── run.py
│
├── nullsec-bench/                 # Cluster benchmarking suite
│   ├── app/__init__.py            # CPU/mem/disk/net benchmarks, SSH remote
│   ├── templates/bench.html       # Comparison charts, result cards
│   └── run.py
│
├── nullsec-prompt-armor/          # AI prompt injection defense
│   ├── armor/                     # Detection engine, sanitizer, classifier
│   ├── tests/                     # Adversarial test corpus
│   └── run.py
│
├── nullsec-race-audit/            # AI race condition fuzzer
│   ├── racer/                     # Concurrency probes, session attacks
│   ├── reports/                   # Finding templates
│   └── run.py
│
├── nullsec-nightshift/            # Overnight cluster job scheduler
│   ├── jobs/                      # Job definitions (hashcat, recon, etc.)
│   └── nightshift.py
│
├── nullsec-suite/                 # 141+ WiFi Pineapple payloads
├── nullsec-firmware/              # Custom firmware builder
├── nullsec-appnet.sh              # Unified app launcher (start/stop/status)
└── lib/                           # Shared libraries
```

## Cluster Configuration

Nodes are defined in `~/.nullsec/cluster/nodes.conf`:

```
# hostname|ip|user|port|os|arch|cores|ram_mb|gpu|role|tags
nullsec|127.0.0.1|antics|22|linux|x86_64|12|8192||controller|
r420|192.168.40.209|root|22|linux|x86_64|32|131072||server|
doomsday|192.168.40.22|antics|22|windows|x86_64|16|32768|rtx3060|gpu-worker|
```

## Port Assignments

| Port | Service | Description |
|------|---------|-------------|
| 9000 | WebTools | Hub dashboard, cluster management, payload browser |
| 9001 | Monitor | Real-time WebSocket cluster health feed |
| 9002 | Scanner | Network port scanning, subnet discovery |
| 9003 | Bench | CPU/memory/disk/network benchmarks |
| 9004 | Prompt Armor | AI prompt injection detection API |
| 9005 | Race Audit | AI race condition testing API |
| 9006 | NightShift | Overnight cluster compute scheduler |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NULLSEC_SECRET` | random | Session signing key (auto-generated if unset) |
| `NULLSEC_DEBUG` | `0` | Enable debug mode (`1` = on) |
| `NULLSEC_BIND` | `0.0.0.0` | Network bind address |

## Security Notes

- **SSH Host Keys**: `AutoAddPolicy` is used intentionally — all cluster nodes are trusted LAN peers on a private mesh network. Do not expose SSH ports to the internet.
- **No Authentication**: The web apps have no login gate by default. They are intended for use on a private network or behind a VPN. Add a reverse proxy with auth (nginx + basic auth, Authelia, etc.) for exposed deployments.
- **Binding**: Apps bind to `0.0.0.0` for cluster accessibility. Set `NULLSEC_BIND=127.0.0.1` to restrict to localhost.
