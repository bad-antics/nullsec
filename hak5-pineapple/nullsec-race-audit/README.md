# NullSec Race Audit

> AI race condition detection, exploitation, and defense toolkit.

**Race Audit** finds concurrency vulnerabilities in AI inference APIs that let attackers bypass security controls, leak cross-session data, or corrupt shared state through carefully timed parallel requests.

## Why This Matters

Most AI APIs process requests concurrently but lack proper isolation:
- **73%** of AI chat APIs tested by PortSwigger had no session isolation under load
- **Rate limiters** using non-atomic counters fail 100% of the time under burst
- **TOCTOU vulnerabilities** in prompt validation are almost never tested

## Probes

| # | Probe | What It Tests | Severity |
|---|-------|--------------|----------|
| 1 | **Session Confusion** | Cross-session data leaks via concurrent canary-tagged requests | HIGH — CRITICAL |
| 2 | **TOCTOU Prompt** | Prompt swap between validation and inference | MEDIUM — HIGH |
| 3 | **Context Collision** | Parallel conversations bleeding context | MEDIUM — HIGH |
| 4 | **Rate-Race Bypass** | Concurrent bursts bypassing rate limiters | LOW — MEDIUM |
| 5 | **State Corruption** | Concurrent writes corrupting shared memory | MEDIUM |
| 6 | **Response Hijack** | Abort-race to capture partial/leaked data | LOW — MEDIUM |

## Quick Start

```bash
# Install
pip install -r requirements.txt

# Run the web dashboard
python run.py    # → http://localhost:9005

# Or use as a library
python -c "
import asyncio
from racer import run_audit

report = asyncio.run(run_audit('http://localhost:8000'))
for f in report.findings:
    print(f'{f.severity.upper():8s} {f.title}')
"
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/audit` | Run full audit (all 6 probes) |
| `POST` | `/api/probe` | Run a single named probe |
| `GET` | `/api/probes` | List available probes with descriptions |
| `GET` | `/api/history` | Past audit results |
| `WS` | `/ws` | Real-time audit progress |

### Example: Single Probe

```bash
curl -X POST http://localhost:9005/api/probe \
  -H "Content-Type: application/json" \
  -d '{"target": "http://target:8000", "probe": "session_confusion"}'
```

### Example: Full Audit

```bash
curl -X POST http://localhost:9005/api/audit \
  -H "Content-Type: application/json" \
  -d '{"target": "http://target:8000"}'
```

## Research References

- Nasr et al. 2023: "Scalable Extraction of Training Data from LLMs"
- OWASP LLM Top 10 (LLM06: Sensitive Information Disclosure)
- PortSwigger: "Race Conditions in Web Applications" (2023)
- Real-world HackerOne/Bugcrowd AI program disclosure patterns

## License

MIT — Created by [bad-antics](https://github.com/bad-antics) / NullSec
