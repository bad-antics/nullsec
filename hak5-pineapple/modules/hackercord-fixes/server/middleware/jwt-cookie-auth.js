/**
 * NullSec JWT Cookie Auth Middleware
 * ────────────────────────────────────
 * Fixes: C3 (JWT in localStorage)
 *
 * Moves JWT from localStorage to HttpOnly Secure SameSite cookie.
 * Adds double-submit CSRF protection.
 *
 * Before: localStorage.setItem('hackercord_token', token)  ← XSS → full takeover
 * After:  HttpOnly; Secure; SameSite=Strict cookie          ← XSS can't read it
 *
 * @audit hackercord-audit.md — Finding C3
 * @priority P0 (4 hours)
 */

'use strict';

const crypto = require('crypto');

const COOKIE_NAME = 'hackercord_session';
const CSRF_COOKIE = 'hackercord_csrf';
const CSRF_HEADER = 'x-csrf-token';
const COOKIE_MAX_AGE = 30 * 24 * 60 * 60 * 1000;  // 30 days (matches existing JWT expiry)

// ─── CSRF Token Generator ───────────────────────────────────────────────────

function generateCSRF() {
  return crypto.randomBytes(32).toString('hex');
}

function isStateMutating(method) {
  return ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method.toUpperCase());
}

// ─── Cookie Helpers ─────────────────────────────────────────────────────────

function setAuthCookie(res, token, options = {}) {
  const {
    maxAge = COOKIE_MAX_AGE,
    domain = undefined,
    path = '/',
  } = options;

  // Set HttpOnly JWT cookie (JavaScript CANNOT access this)
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,      // ← KEY FIX: prevents XSS token theft
    secure: true,        // HTTPS only
    sameSite: 'Strict',  // No cross-origin sending
    maxAge,
    path,
    domain,
  });

  // Set readable CSRF token cookie (JS can read, but attacker can't forge)
  const csrf = generateCSRF();
  res.cookie(CSRF_COOKIE, csrf, {
    httpOnly: false,     // Client JS needs to read this to send as header
    secure: true,
    sameSite: 'Strict',
    maxAge,
    path,
    domain,
  });

  return csrf;
}

function clearAuthCookie(res) {
  res.clearCookie(COOKIE_NAME);
  res.clearCookie(CSRF_COOKIE);
}

// ─── Cookie Parser (minimal, no dependency) ─────────────────────────────────

function parseCookies(cookieHeader) {
  if (!cookieHeader) return {};
  return cookieHeader.split(';').reduce((cookies, pair) => {
    const [name, ...rest] = pair.trim().split('=');
    if (name) cookies[name.trim()] = decodeURIComponent(rest.join('='));
    return cookies;
  }, {});
}

// ─── Middleware ──────────────────────────────────────────────────────────────

/**
 * @param {object} [options]
 * @param {function} options.verifyToken - (token) => payload | null — your JWT verify function
 * @param {string[]} [options.excludePaths] - Paths that don't need auth
 * @param {boolean} [options.csrfProtection] - Enable CSRF double-submit (default: true)
 */
function jwtCookieAuth(options = {}) {
  const {
    verifyToken,
    excludePaths = ['/api/register', '/api/login', '/api/anonymous', '/api/public-servers'],
    csrfProtection = true,
  } = options;

  if (!verifyToken) {
    throw new Error('[NullSec] jwtCookieAuth requires a verifyToken function');
  }

  return function nullsecJwtCookieAuth(req, res, next) {
    const path = req.path || req.url?.split('?')[0];

    // Skip auth for excluded paths
    if (excludePaths.some(p => path.startsWith(p))) {
      return next();
    }

    // Parse cookies
    const cookies = req.cookies || parseCookies(req.headers.cookie);
    const token = cookies[COOKIE_NAME];

    if (!token) {
      // Also check Authorization header for backward compatibility / API clients
      const authHeader = req.headers.authorization;
      if (authHeader?.startsWith('Bearer ')) {
        const bearerToken = authHeader.slice(7);
        const payload = verifyToken(bearerToken);
        if (payload) {
          req.user = payload;
          return next();
        }
      }
      return res.status(401).json({ error: 'unauthorized', message: 'Authentication required' });
    }

    // Verify JWT from cookie
    const payload = verifyToken(token);
    if (!payload) {
      clearAuthCookie(res);
      return res.status(401).json({ error: 'token_expired', message: 'Session expired' });
    }

    // CSRF double-submit validation for state-mutating requests
    if (csrfProtection && isStateMutating(req.method)) {
      const csrfCookie = cookies[CSRF_COOKIE];
      const csrfHeader = req.headers[CSRF_HEADER];

      if (!csrfCookie || !csrfHeader || csrfCookie !== csrfHeader) {
        return res.status(403).json({
          error: 'csrf_invalid',
          message: 'CSRF token mismatch. Refresh the page and try again.',
        });
      }
    }

    req.user = payload;
    next();
  };
}

// ─── Login/Register Response Helper ─────────────────────────────────────────

/**
 * Wraps the existing login/register handlers to set cookies instead of
 * returning JWT in response body.
 *
 * Usage:
 *   app.post('/api/login', async (req, res) => {
 *     const { user, token } = await authenticate(req.body);
 *     sendAuthResponse(res, token, { id: user.id, username: user.username });
 *   });
 */
function sendAuthResponse(res, token, userData, options = {}) {
  const csrf = setAuthCookie(res, token, options);
  return res.json({
    ok: true,
    user: userData,
    csrf,
    // NOTE: token is NOT in the response body anymore (was the vulnerability)
  });
}

// ─── Client-side Migration Script ───────────────────────────────────────────

/**
 * Drop-in client JS to migrate from localStorage to cookie auth.
 * Include this in the SPA to handle the transition.
 */
jwtCookieAuth.clientMigrationScript = `
// NullSec: Migrate from localStorage JWT to HttpOnly cookie
(function() {
  'use strict';

  // Read CSRF token from cookie for API requests
  function getCSRF() {
    const match = document.cookie.match(/hackercord_csrf=([^;]+)/);
    return match ? match[1] : '';
  }

  // Patch fetch to include CSRF header automatically
  const _fetch = window.fetch;
  window.fetch = function(url, opts = {}) {
    opts.credentials = 'same-origin';  // Send cookies
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes((opts.method || 'GET').toUpperCase())) {
      opts.headers = opts.headers || {};
      if (opts.headers instanceof Headers) {
        opts.headers.set('x-csrf-token', getCSRF());
      } else {
        opts.headers['x-csrf-token'] = getCSRF();
      }
    }
    return _fetch.call(this, url, opts);
  };

  // Clean up old localStorage token (the vulnerability)
  if (localStorage.getItem('hackercord_token')) {
    console.log('[NullSec] Migrating auth from localStorage to HttpOnly cookie');
    localStorage.removeItem('hackercord_token');
  }
})();
`;

module.exports = jwtCookieAuth;
module.exports.setAuthCookie = setAuthCookie;
module.exports.clearAuthCookie = clearAuthCookie;
module.exports.sendAuthResponse = sendAuthResponse;
module.exports.COOKIE_NAME = COOKIE_NAME;
module.exports.CSRF_HEADER = CSRF_HEADER;
