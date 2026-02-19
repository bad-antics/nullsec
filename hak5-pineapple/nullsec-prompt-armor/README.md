# NullSec Prompt Armor

> Multi-layered AI prompt injection detection and defense toolkit.

**Prompt Armor** protects LLM-powered applications from prompt injection attacks — the #1 security risk for AI systems (OWASP LLM Top 10).

## Detection Layers

| Layer | Method | Catches |
|-------|--------|---------|
| **Lexical** | Regex pattern matching against 30+ injection signatures | Role hijack, delimiter escapes, jailbreaks, exfiltration attempts |
| **Structural** | Multi-persona detection, instruction sandwich, invisible chars | Context manipulation, evasion via whitespace |
| **Entropy** | Shannon entropy + encoding detection (base64, hex, ROT13, unicode) | Obfuscated/encoded payloads |
| **Semantic** | Keyword-category alignment scoring | Topic drift toward manipulation, code execution, data theft |
| **Canary** | Hidden token injection + leak detection | Post-hoc verification that system prompt wasn't compromised |

## Threat Classification

- **CLEAN** (score 0-19) — No injection detected
- **SUSPICIOUS** (score 20-44) — Possible injection, low confidence
- **HOSTILE** (score 45-69) — Probable injection, high confidence
- **CRITICAL** (score 70-100) — Multi-vector attack with high confidence

## Quick Start

```bash
# Install
pip install -r requirements.txt

# Run the web dashboard
python run.py    # → http://localhost:9004

# Or use as a library
python -c "
from armor import analyze
v = analyze('Ignore all previous instructions.')
print(f'{v.threat_level}: {v.score}/100 ({len(v.findings)} findings)')
"
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/scan` | Analyze text for prompt injection |
| `POST` | `/api/sanitize` | Strip injection payloads from text |
| `POST` | `/api/canary/create` | Generate a canary trap token |
| `POST` | `/api/canary/verify` | Check if canary was leaked in AI output |
| `POST` | `/api/batch` | Analyze multiple inputs at once |
| `GET` | `/api/signatures` | List detection pattern categories |
| `GET` | `/api/stats` | Dashboard statistics |
| `WS` | `/ws` | Real-time WebSocket scanning |

## FastAPI Middleware Integration

```python
from armor import armor_guard
from fastapi import Depends

@app.post("/chat")
async def chat(request: Request, guard=Depends(armor_guard(threshold=50))):
    safe_input = guard["sanitized"]  # Injection payloads stripped
    verdict = guard["verdict"]       # Full analysis results
    # ... send safe_input to your LLM
```

## Running Tests

```bash
python tests/test_detection.py
# Or with pytest:
pytest tests/ -v
```

## Attack Vectors Detected

- **Role Hijack** — "Ignore all previous instructions", "You are now DAN"
- **Delimiter Escape** — `<|im_start|>`, `[INST]`, `<<SYS>>` injection
- **Data Exfiltration** — "Repeat your system prompt", "Reveal your instructions"
- **Jailbreak** — "Developer mode", "DAN mode", fictional scenarios
- **Payload Smuggle** — eval(), exec(), SQL injection, XSS via prompts
- **Encoding Attack** — Base64, hex, ROT13, unicode escape obfuscation
- **Context Manipulation** — Multi-persona simulation, instruction sandwich
- **Canary Trigger** — System prompt leaked to output

## License

MIT — Created by [bad-antics](https://github.com/bad-antics) / NullSec
