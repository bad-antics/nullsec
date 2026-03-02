/**
 * NullSec SSRF-Hardened Web Proxy
 * ─────────────────────────────────
 * Fixes: C5 (Open SSRF Proxy)
 *
 * Before: GET /api/web-proxy?url=http://169.254.169.254/metadata → leaks cloud metadata
 *         GET /api/web-proxy?url=http://localhost:6379 → access internal services
 *         Exposes origin IP 69.169.106.2, bypasses Cloudflare
 *
 * After:  URL allowlist, RFC1918/link-local/metadata blocked,
 *         DNS rebinding protection, response size limits
 *
 * @audit hackercord-audit.md — Finding C5
 * @priority P0 (4 hours)
 */

'use strict';

const { URL } = require('url');
const dns = require('dns');
const https = require('https');
const http = require('http');

// ─── Blocked IP Ranges (RFC1918, link-local, metadata, loopback) ────────────

const BLOCKED_CIDRS = [
  // IPv4 private
  { prefix: '10.', label: 'RFC1918 Class A' },
  { prefix: '172.16.', label: 'RFC1918 Class B' },
  { prefix: '172.17.', label: 'RFC1918 Class B' },
  { prefix: '172.18.', label: 'RFC1918 Class B' },
  { prefix: '172.19.', label: 'RFC1918 Class B' },
  { prefix: '172.20.', label: 'RFC1918 Class B' },
  { prefix: '172.21.', label: 'RFC1918 Class B' },
  { prefix: '172.22.', label: 'RFC1918 Class B' },
  { prefix: '172.23.', label: 'RFC1918 Class B' },
  { prefix: '172.24.', label: 'RFC1918 Class B' },
  { prefix: '172.25.', label: 'RFC1918 Class B' },
  { prefix: '172.26.', label: 'RFC1918 Class B' },
  { prefix: '172.27.', label: 'RFC1918 Class B' },
  { prefix: '172.28.', label: 'RFC1918 Class B' },
  { prefix: '172.29.', label: 'RFC1918 Class B' },
  { prefix: '172.30.', label: 'RFC1918 Class B' },
  { prefix: '172.31.', label: 'RFC1918 Class B' },
  { prefix: '192.168.', label: 'RFC1918 Class C' },
  // Loopback
  { prefix: '127.', label: 'Loopback' },
  // Link-local
  { prefix: '169.254.', label: 'Link-local / Cloud metadata' },
  // Cloud metadata endpoints
  { prefix: '100.100.100.200', label: 'Alibaba metadata' },
  // IPv6
  { prefix: '::1', label: 'IPv6 Loopback' },
  { prefix: 'fc00:', label: 'IPv6 ULA' },
  { prefix: 'fd', label: 'IPv6 ULA' },
  { prefix: 'fe80:', label: 'IPv6 Link-local' },
];

// Blocked hostnames (metadata services, localhost aliases)
const BLOCKED_HOSTS = new Set([
  'localhost',
  'metadata.google.internal',
  'metadata.google',
  'instance-data',
  '169.254.169.254',
  '169.254.170.2',
  '[::1]',
  '0.0.0.0',
  'kubernetes.default.svc',
]);

// ─── URL Validation ─────────────────────────────────────────────────────────

function isBlockedIP(ip) {
  if (!ip) return true;
  return BLOCKED_CIDRS.some(cidr => ip.startsWith(cidr.prefix));
}

function isBlockedHost(hostname) {
  if (!hostname) return true;
  const lower = hostname.toLowerCase();
  if (BLOCKED_HOSTS.has(lower)) return true;
  // Block numeric IPs that might be encoded (decimal, hex, octal)
  if (/^0x/i.test(lower)) return true;  // hex IP
  if (/^0\d/.test(lower)) return true;  // octal IP
  if (/^\d+$/.test(lower)) return true; // decimal IP (e.g., 2130706433 = 127.0.0.1)
  return false;
}

async function resolveAndCheck(hostname) {
  return new Promise((resolve, reject) => {
    dns.resolve4(hostname, (err, addresses) => {
      if (err) {
        // Also try resolve6
        dns.resolve6(hostname, (err6, addr6) => {
          if (err6) return reject(new Error(`DNS resolution failed for ${hostname}`));
          for (const ip of addr6) {
            if (isBlockedIP(ip)) return reject(new Error(`Blocked: ${hostname} resolves to private IP ${ip}`));
          }
          resolve(addr6[0]);
        });
        return;
      }
      for (const ip of addresses) {
        if (isBlockedIP(ip)) {
          return reject(new Error(`Blocked: ${hostname} resolves to private IP ${ip}`));
        }
      }
      resolve(addresses[0]);
    });
  });
}

// ─── Domain Allowlist ───────────────────────────────────────────────────────

const DEFAULT_ALLOWED_DOMAINS = [
  // Social/media embeds
  '*.youtube.com', '*.youtu.be',
  '*.twitter.com', '*.x.com',
  '*.github.com', '*.githubusercontent.com',
  '*.imgur.com', '*.giphy.com',
  '*.tenor.com',
  '*.wikipedia.org', '*.wikimedia.org',
  // Image hosting
  '*.cloudflare.com',
  '*.cdn.discordapp.com',
];

function matchesDomain(hostname, pattern) {
  if (pattern.startsWith('*.')) {
    const suffix = pattern.slice(2);
    return hostname === suffix || hostname.endsWith('.' + suffix);
  }
  return hostname === pattern;
}

// ─── Proxy Handler ──────────────────────────────────────────────────────────

/**
 * @param {object} [options]
 * @param {string[]} [options.allowedDomains] - Glob patterns for allowed domains
 * @param {number} [options.maxResponseSize] - Max response bytes (default: 5MB)
 * @param {number} [options.timeout] - Request timeout ms (default: 10s)
 * @param {boolean} [options.requireAuth] - Require authenticated user (default: true)
 */
function ssrfProxy(options = {}) {
  const {
    allowedDomains = DEFAULT_ALLOWED_DOMAINS,
    maxResponseSize = 5 * 1024 * 1024,
    timeout = 10000,
    requireAuth = true,
  } = options;

  return async function nullsecSSRFProxy(req, res, next) {
    const targetUrl = req.query?.url || req.query?.target;

    // ── Require authentication ────────────────────────────────
    if (requireAuth && !req.user) {
      return res.status(401).json({ error: 'unauthorized', message: 'Auth required for proxy' });
    }

    // ── Validate URL exists ───────────────────────────────────
    if (!targetUrl) {
      return res.status(400).json({ error: 'missing_url', message: 'url parameter required' });
    }

    // ── Parse and validate URL ────────────────────────────────
    let parsed;
    try {
      parsed = new URL(targetUrl);
    } catch {
      return res.status(400).json({ error: 'invalid_url', message: 'Malformed URL' });
    }

    // Only allow HTTP(S)
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return res.status(400).json({ error: 'invalid_protocol', message: 'Only HTTP/HTTPS allowed' });
    }

    // ── Block dangerous hosts ─────────────────────────────────
    const hostname = parsed.hostname.toLowerCase();

    if (isBlockedHost(hostname)) {
      return res.status(403).json({ error: 'blocked_host', message: 'This host is not allowed' });
    }

    // ── Domain allowlist check ────────────────────────────────
    const allowed = allowedDomains.some(pattern => matchesDomain(hostname, pattern));
    if (!allowed) {
      return res.status(403).json({
        error: 'domain_not_allowed',
        message: `Domain ${hostname} is not in the allowlist`,
      });
    }

    // ── DNS rebinding protection ──────────────────────────────
    try {
      await resolveAndCheck(hostname);
    } catch (err) {
      return res.status(403).json({ error: 'dns_blocked', message: err.message });
    }

    // ── Make the proxied request ──────────────────────────────
    const client = parsed.protocol === 'https:' ? https : http;

    const proxyReq = client.get(parsed.href, {
      timeout,
      headers: {
        'User-Agent': 'HackerCord-Proxy/2.0 (NullSec-Hardened)',
        // Do NOT forward cookies, auth headers, or origin info
      },
    }, (proxyRes) => {
      // Enforce size limit
      let received = 0;
      const chunks = [];

      proxyRes.on('data', (chunk) => {
        received += chunk.length;
        if (received > maxResponseSize) {
          proxyReq.destroy();
          return res.status(413).json({
            error: 'response_too_large',
            message: `Response exceeds ${maxResponseSize} byte limit`,
          });
        }
        chunks.push(chunk);
      });

      proxyRes.on('end', () => {
        const contentType = proxyRes.headers['content-type'] || 'application/octet-stream';
        res.setHeader('Content-Type', contentType);
        // Security headers on proxied content
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.setHeader('Content-Security-Policy', "default-src 'none'");
        res.setHeader('Cache-Control', 'public, max-age=3600');
        res.status(proxyRes.statusCode || 200).end(Buffer.concat(chunks));
      });
    });

    proxyReq.on('error', (err) => {
      res.status(502).json({ error: 'proxy_error', message: 'Failed to fetch remote resource' });
    });

    proxyReq.on('timeout', () => {
      proxyReq.destroy();
      res.status(504).json({ error: 'proxy_timeout', message: 'Remote resource timed out' });
    });
  };
}

module.exports = ssrfProxy;
module.exports.isBlockedIP = isBlockedIP;
module.exports.isBlockedHost = isBlockedHost;
module.exports.resolveAndCheck = resolveAndCheck;
module.exports.BLOCKED_HOSTS = BLOCKED_HOSTS;
module.exports.DEFAULT_ALLOWED_DOMAINS = DEFAULT_ALLOWED_DOMAINS;
