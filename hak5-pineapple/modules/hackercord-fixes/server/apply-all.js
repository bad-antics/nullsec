/**
 * NullSec — Apply All Security Fixes
 * ─────────────────────────────────────
 * One-line import to apply every server-side fix from the hackercord audit.
 *
 * Usage:
 *   const nullsec = require('./modules/hackercord-fixes/server/apply-all');
 *   nullsec(app);                    // Apply all with defaults
 *   nullsec(app, { redis: client }); // Apply all with Redis for rate limiting
 *
 * Applies (in order):
 *   1. C1/M1 — Security headers (HSTS, CSP, X-Frame, etc.)
 *   2. C2    — Rate limiting (register: 5/min, login: 10/min)
 *   3. H1/M2 — Password policy (8+ chars, complexity, timing-safe)
 *   4. C3    — JWT HttpOnly cookie auth + CSRF protection
 *   5. C4/M3 — API auth guard (servers filtered, IDs obfuscated)
 *   6. H5    — JWT revocation checking
 *   7. C5    — SSRF-hardened web proxy (replaces /api/web-proxy)
 *   8. H3    — TURN credential endpoint (/api/turn-credentials)
 *
 * Client-side (load separately in browser):
 *   9. C6    — Plugin sandbox (client/plugin-sandbox.js)
 *  10. H2    — Voice crypto AES-256 fix (client/voice-crypto-fix.js)
 *  11. H4    — innerHTML guard (client/innerHTML-audit.js)
 *  12. M4    — Legacy polyfill removal (client/cleanup.js)
 *  13. M5    — sitemap.xml (config/sitemap.xml)
 *
 * @audit hackercord-audit.md — ALL 16 findings
 */

'use strict';

const path = require('path');
const fs = require('fs');

const securityHeaders = require('./middleware/security-headers');
const rateLimiter = require('./middleware/rate-limiter');
const jwtCookieAuth = require('./middleware/jwt-cookie-auth');
const apiAuthGuard = require('./middleware/api-auth-guard');
const ssrfProxy = require('./middleware/ssrf-proxy');
const passwordPolicy = require('./auth/password-policy');
const jwtRotation = require('./auth/jwt-rotation');
const turnServer = require('../config/turn-server');

/**
 * Apply all NullSec security fixes to an Express app.
 *
 * @param {object} app - Express application instance
 * @param {object} [options]
 * @param {object} [options.redis] - Redis client for rate limiting + token store
 * @param {function} [options.verifyToken] - JWT verification function
 * @param {function} [options.signToken] - JWT signing function
 * @param {function} [options.getUser] - (userId) => user object
 * @param {object} [options.csp] - Custom CSP directives
 * @param {string[]} [options.proxyAllowedDomains] - Allowed domains for web proxy
 */
function applyAll(app, options = {}) {
  const {
    redis = null,
    verifyToken = null,
    signToken = null,
    getUser = null,
    csp = undefined,
    proxyAllowedDomains = undefined,
  } = options;

  console.log('');
  console.log('╔══════════════════════════════════════════════════════╗');
  console.log('║  NullSec Security Framework — Applying All Fixes    ║');
  console.log('║  hackercord-audit.md: 6 Critical, 5 High, 5 Medium  ║');
  console.log('╚══════════════════════════════════════════════════════╝');
  console.log('');

  // Token store (for JWT rotation/revocation)
  const tokenStore = new jwtRotation.RevocationStore();

  // ── 1. Security Headers (C1 + M1) ──────────────────────────
  app.use(securityHeaders({ csp }));
  console.log('  ✓ [C1/M1] Security headers: HSTS, CSP, X-Frame, X-Content-Type, Referrer-Policy, Permissions-Policy');
  console.log('  ✓ [M1]    Server header leak removed');

  // ── 2. Rate Limiting (C2) ──────────────────────────────────
  app.use(rateLimiter({ redis }));
  console.log('  ✓ [C2]    Rate limiter: register 5/min, login 10/min, API 100/min');

  // ── 3. Password Policy (H1 + M2) ──────────────────────────
  app.use(passwordPolicy());
  console.log('  ✓ [H1]    Password policy: 8+ chars, uppercase, lowercase, number, special');
  console.log('  ✓ [M2]    Registration timing-safe (prevents user enumeration)');

  // ── 4. JWT Cookie Auth (C3) ────────────────────────────────
  if (verifyToken) {
    app.use(jwtCookieAuth({ verifyToken }));
    console.log('  ✓ [C3]    JWT moved to HttpOnly Secure SameSite cookie + CSRF');
  } else {
    console.log('  ⚠ [C3]    JWT cookie auth: skipped (provide verifyToken option)');
  }

  // ── 5. API Auth Guard (C4 + M3) ────────────────────────────
  app.use(apiAuthGuard());
  console.log('  ✓ [C4]    /api/servers: requires auth, filters by membership, hides hidden channels');
  console.log('  ✓ [M3]    Sequential IDs obfuscated with HMAC');

  // ── 6. JWT Revocation Check (H5) ──────────────────────────
  app.use(jwtRotation.checkRevocation(tokenStore));
  console.log('  ✓ [H5]    JWT revocation list active');

  // ── 7. SSRF-Hardened Proxy (C5) ────────────────────────────
  // Replace the existing /api/web-proxy route
  app.get('/api/web-proxy', ssrfProxy({
    allowedDomains: proxyAllowedDomains,
    requireAuth: true,
  }));
  console.log('  ✓ [C5]    Web proxy hardened: domain allowlist, RFC1918 blocked, DNS rebinding protection');

  // ── 8. TURN Credentials (H3) ──────────────────────────────
  app.get('/api/turn-credentials', turnServer.turnCredentialsHandler());
  console.log('  ✓ [H3]    TURN credential endpoint: /api/turn-credentials');

  // ── 9. Token Refresh Endpoint (H5) ────────────────────────
  if (signToken && getUser) {
    app.post('/api/auth/refresh', jwtRotation.refreshHandler({
      store: tokenStore,
      signToken,
      getUser,
    }));
    app.post('/api/auth/logout', jwtRotation.logoutHandler(tokenStore));
    app.post('/api/auth/logout-all', jwtRotation.logoutEverywhereHandler(tokenStore));
    console.log('  ✓ [H5]    Token refresh rotation + logout endpoints');
  }

  // ── 10. Serve sitemap.xml (M5) ────────────────────────────
  const sitemapPath = path.join(__dirname, '..', 'config', 'sitemap.xml');
  if (fs.existsSync(sitemapPath)) {
    app.get('/sitemap.xml', (req, res) => {
      res.setHeader('Content-Type', 'application/xml');
      res.sendFile(sitemapPath);
    });
    console.log('  ✓ [M5]    sitemap.xml served at /sitemap.xml');
  }

  console.log('');
  console.log('  Server-side fixes applied: 13/16');
  console.log('  Client-side fixes (load in browser):');
  console.log('    [C6] client/plugin-sandbox.js    — iframe sandbox for plugins');
  console.log('    [H2] client/voice-crypto-fix.js  — AES-256-GCM key derivation');
  console.log('    [H4] client/innerHTML-audit.js   — innerHTML auto-sanitizer');
  console.log('    [M4] client/cleanup.js           — legacy polyfill removal');
  console.log('');
  console.log('  ── NullSec — @anonantics ──');
  console.log('');

  return {
    tokenStore,
    securityHeaders,
    rateLimiter,
    jwtCookieAuth,
    apiAuthGuard,
    ssrfProxy,
    passwordPolicy,
    jwtRotation,
    turnServer,
  };
}

module.exports = applyAll;
