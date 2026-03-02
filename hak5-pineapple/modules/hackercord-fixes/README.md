# HackerCord NullSec Security Fixes

> Drop-in patches for every finding in the [hackercord-audit.md](../../docs/hackercord-audit.md)
>
> 6 Critical • 5 High • 5 Medium → All addressed

## Structure

```
modules/hackercord-fixes/
├── server/
│   ├── middleware/
│   │   ├── security-headers.js    ── P0: HSTS, CSP, X-Frame, etc.
│   │   ├── rate-limiter.js        ── P0: Redis rate limiting
│   │   ├── jwt-cookie-auth.js     ── P0: HttpOnly cookie + CSRF
│   │   ├── api-auth-guard.js      ── P0: /api/servers auth + filter
│   │   └── ssrf-proxy.js          ── P0: Hardened web-proxy
│   ├── auth/
│   │   ├── password-policy.js     ── P1: 8+ chars, complexity
│   │   └── jwt-rotation.js        ── P1: Refresh rotation + revocation
│   └── apply-all.js               ── One-line import to apply everything
├── client/
│   ├── plugin-sandbox.js          ── P1: iframe/Worker sandboxed plugins
│   ├── voice-crypto-fix.js        ── P1: AES-256-GCM key derivation
│   ├── innerHTML-audit.js         ── P2: Runtime innerHTML guard
│   └── cleanup.js                 ── P2: Remove polyfills, add sitemap
├── config/
│   ├── turn-server.js             ── P1: TURN/STUN config
│   ├── cloudflare-headers.json    ── P0: CF Transform Rules export
│   └── sitemap.xml                ── P2: Basic sitemap
└── README.md
```

## Quick Start

```js
// server.js — one line to apply all server-side fixes
require('./modules/hackercord-fixes/server/apply-all')(app);
```

## Finding Coverage

| ID | Finding | Severity | File | Status |
|----|---------|----------|------|--------|
| C1 | No Security Headers | 🔴 CRITICAL | security-headers.js | ✅ |
| C2 | No Rate Limiting | 🔴 CRITICAL | rate-limiter.js | ✅ |
| C3 | JWT in localStorage | 🔴 CRITICAL | jwt-cookie-auth.js | ✅ |
| C4 | /api/servers Leaks All | 🔴 CRITICAL | api-auth-guard.js | ✅ |
| C5 | Open SSRF Proxy | 🔴 CRITICAL | ssrf-proxy.js | ✅ |
| C6 | Unsafe Plugin System | 🔴 CRITICAL | plugin-sandbox.js | ✅ |
| H1 | Weak Password Policy | 🟡 HIGH | password-policy.js | ✅ |
| H2 | E2EE Mismatch | 🟡 HIGH | voice-crypto-fix.js | ✅ |
| H3 | No TURN Server | 🟡 HIGH | turn-server.js | ✅ |
| H4 | innerHTML + User Data | 🟡 HIGH | innerHTML-audit.js | ✅ |
| H5 | No JWT Revocation | 🟡 HIGH | jwt-rotation.js | ✅ |
| M1 | Server Header Leak | 🟢 MEDIUM | security-headers.js | ✅ |
| M2 | User Enum via Reg | 🟢 MEDIUM | password-policy.js | ✅ |
| M3 | ID Leaks User Count | 🟢 MEDIUM | api-auth-guard.js | ✅ |
| M4 | Ancient Polyfills | 🟢 MEDIUM | cleanup.js | ✅ |
| M5 | No sitemap.xml | 🟢 MEDIUM | sitemap.xml | ✅ |

---
*NullSec — @anonantics*
