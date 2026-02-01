# Contributing to NullSec Pineapple Suite

Thanks for your interest in contributing! 🍍

## How to Contribute

### Submitting Payloads

1. **Fork** the repository
2. Create a new branch: `git checkout -b payload/your-payload-name`
3. Add your payload to `payloads/` following the naming convention: `YourPayloadName_payload.sh`
4. Test your payload on a WiFi Pineapple Pager
5. Submit a Pull Request

### Payload Requirements

- Must include the NullSec header with credits
- Use Pager DuckyScript commands (PROMPT, NUMBER_PICKER, SPINNER_START, etc.)
- Include proper cleanup on exit
- Log output to `/mmc/nullsec/[payload-name]/`
- Pass `bash -n` syntax check

### Payload Template

```bash
#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# YOUR_PAYLOAD_NAME - Full Descriptive Name Here
# Developed by: your-name (contributor) | NullSec Suite by bad-antics
#═══════════════════════════════════════════════════════════════════════════════

source /mmc/nullsec/lib/nullsec-scanner.sh 2>/dev/null

LOOT_DIR="/mmc/nullsec/your-payload"
mkdir -p "$LOOT_DIR"

PROMPT "YOUR PAYLOAD BANNER
━━━━━━━━━━━━━━━━━━━━━━━━━
Description here

━━━━━━━━━━━━━━━━━━━━━━━━━
NullSec Pineapple Suite"

# Your code here...

PROMPT "COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━
Results here

━━━━━━━━━━━━━━━━━━━━━━━━━
Developed by: bad-antics"
```

### Code Style

- Use 4-space indentation
- Include comments for complex logic
- Use meaningful variable names
- Handle errors gracefully
- Clean up temp files

### Bug Reports

Open an issue with:
- Payload name
- Expected behavior
- Actual behavior
- Pager firmware version
- Steps to reproduce

### Feature Requests

Open an issue with:
- Clear description
- Use case
- Any implementation ideas

## Code of Conduct

- Be respectful
- Use for authorized testing only
- No malicious contributions
- Help others learn

## Questions?

Open a discussion or issue!

---

**NullSec Pineapple Suite** | Developed by: bad-antics
