/**
 * NullSec Security Headers Middleware
 * ────────────────────────────────────
 * Fixes: C1 (No Security Headers) + M1 (Server Header Leak)
 *
 * Adds: HSTS, CSP, X-Frame-Options, X-Content-Type-Options,
 *       Referrer-Policy, Permissions-Policy
 * Removes: 'server' header leak
 *
 * @audit hackercord-audit.md — Finding C1, M1
 * @priority P0 (1 hour)
 */

'use strict';

const DEFAULT_CSP = {
  'default-src': ["'self'"],
  'script-src': ["'self'"],
  'style-src': ["'self'", "'unsafe-inline'"],  // needed for inline styles
  'img-src': ["'self'", 'data:', 'blob:', 'https:'],
  'font-src': ["'self'"],
  'connect-src': ["'self'", 'wss:', 'https://stun.l.google.com'],
  'media-src': ["'self'", 'blob:'],
  'object-src': ["'none'"],
  'frame-src': ["'self'"],  // for sandboxed plugins
  'base-uri': ["'self'"],
  'form-action': ["'self'"],
  'frame-ancestors': ["'self'"],
  'upgrade-insecure-requests': [],
};

function buildCSP(policy) {
  return Object.entries(policy)
    .map(([directive, sources]) => {
      if (sources.length === 0) return directive;
      return `${directive} ${sources.join(' ')}`;
    })
    .join('; ');
}

/**
 * @param {object} [options]
 * @param {object} [options.csp] - Override CSP directives
 * @param {number} [options.hstsMaxAge] - HSTS max-age in seconds (default: 2 years)
 * @param {boolean} [options.hstsPreload] - Include HSTS preload directive
 * @param {string} [options.referrerPolicy] - Referrer-Policy value
 * @param {string[]} [options.permissionsDisable] - Features to disable in Permissions-Policy
 */
function securityHeaders(options = {}) {
  const {
    csp = DEFAULT_CSP,
    hstsMaxAge = 63072000,  // 2 years
    hstsPreload = true,
    referrerPolicy = 'strict-origin-when-cross-origin',
    permissionsDisable = [
      'camera', 'microphone', 'geolocation', 'payment',
      'usb', 'magnetometer', 'gyroscope', 'accelerometer',
      'autoplay', 'fullscreen', 'picture-in-picture'
    ],
  } = options;

  // Build Permissions-Policy: camera=(), microphone=(), ...
  // Exception: microphone needs (self) for voice calls
  const permPolicy = permissionsDisable
    .map(feat => {
      if (feat === 'microphone') return 'microphone=(self)';
      if (feat === 'fullscreen') return 'fullscreen=(self)';
      return `${feat}=()`;
    })
    .join(', ');

  const cspString = buildCSP(csp);
  const hstsValue = `max-age=${hstsMaxAge}; includeSubDomains${hstsPreload ? '; preload' : ''}`;

  return function nullsecSecurityHeaders(req, res, next) {
    // ── CRITICAL: Add all missing security headers ────────────
    res.setHeader('Strict-Transport-Security', hstsValue);
    res.setHeader('Content-Security-Policy', cspString);
    res.setHeader('X-Frame-Options', 'SAMEORIGIN');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', referrerPolicy);
    res.setHeader('Permissions-Policy', permPolicy);

    // ── Additional hardening ──────────────────────────────────
    res.setHeader('X-XSS-Protection', '0');  // CSP supersedes; disable to avoid quirks
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');

    // ── FIX M1: Remove server header leak ─────────────────────
    res.removeHeader('X-Powered-By');
    res.removeHeader('Server');

    next();
  };
}

/**
 * Cloudflare Transform Rules equivalent (for CF dashboard / API)
 * Export as JSON for non-origin deployments
 */
securityHeaders.cloudflareRules = {
  name: 'NullSec Security Headers',
  expression: 'true',
  action: 'set',
  headers: {
    'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload',
    'X-Frame-Options': 'SAMEORIGIN',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'camera=(), geolocation=(), payment=(), usb=(), microphone=(self)',
    'Content-Security-Policy': buildCSP(DEFAULT_CSP),
  },
};

module.exports = securityHeaders;
module.exports.DEFAULT_CSP = DEFAULT_CSP;
module.exports.buildCSP = buildCSP;
