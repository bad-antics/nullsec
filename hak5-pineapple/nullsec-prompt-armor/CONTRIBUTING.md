# Contributing to NullSec Prompt Armor

## Reporting New Bypass Techniques

If you discover a prompt injection payload that evades detection:

1. **Open an issue** with the tag `bypass`
2. Include:
   - The payload text (or a sanitized/redacted version)
   - Which detection layer you expected to flag it
   - The `ArmorVerdict` output from `analyze()`
   - Suggested regex pattern or detection logic fix

## Adding Detection Patterns

1. Fork the repo
2. Add your pattern to the appropriate category in `prompt_armor/armor/engine.py`
3. Add a test case in `tests/test_detection.py`
4. Run `pytest tests/ -v` — all tests must pass
5. Open a PR with a clear description of the attack vector

## Code Style

- Python 3.10+
- No external dependencies for the core engine
- Use `ruff` for linting: `ruff check .`
- Type hints everywhere
- Docstrings on all public functions

## Running Tests

```bash
pip install -e ".[dev]"
pytest tests/ -v
```
