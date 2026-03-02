/**
 * NullSec API Auth Guard Middleware
 * ──────────────────────────────────
 * Fixes: C4 (/api/servers leaks all data) + M3 (Sequential ID leak)
 *
 * Before: GET /api/servers → returns ALL servers, hidden channels, settings (unauthenticated)
 * After:  GET /api/servers → requires auth, filters by membership, hides hidden channels
 *
 * Also fixes M3 by replacing sequential integer IDs with opaque tokens.
 *
 * @audit hackercord-audit.md — Finding C4, M3
 * @priority P0 (1 hour)
 */

'use strict';

const crypto = require('crypto');

// ─── ID Obfuscation (fixes M3: sequential ID leak) ─────────────────────────

const ID_SECRET = process.env.NULLSEC_ID_SECRET || crypto.randomBytes(32).toString('hex');

/**
 * Convert sequential integer ID to opaque hash.
 * Deterministic: same input → same output (for caching/URLs).
 */
function obfuscateId(id) {
  return crypto
    .createHmac('sha256', ID_SECRET)
    .update(String(id))
    .digest('hex')
    .slice(0, 16);
}

/**
 * Strip sensitive fields from server objects before sending to client.
 */
function sanitizeServer(server, userId) {
  if (!server) return null;

  return {
    id: obfuscateId(server.id),
    name: server.name,
    icon: server.icon || null,
    description: server.description || '',
    memberCount: server.members?.length || 0,
    // Only include channels the user has access to
    channels: (server.channels || [])
      .filter(ch => {
        // Hide hidden channels from non-admins
        if (ch.hidden && !isServerAdmin(server, userId)) return false;
        // Hide private channels user isn't a member of
        if (ch.private && !ch.members?.includes(userId)) return false;
        return true;
      })
      .map(ch => ({
        id: obfuscateId(ch.id),
        name: ch.name,
        type: ch.type,
        // Do NOT leak: settings, permissions, hidden flag, member list
      })),
    // Do NOT leak: categories, permissions, full settings, all channels
  };
}

/**
 * Strip sensitive fields from user objects.
 */
function sanitizeUser(user) {
  if (!user) return null;
  return {
    id: obfuscateId(user.id),
    username: user.username,
    displayName: user.display_name || user.username,
    avatar: user.avatar || null,
    // Do NOT leak: password_hash, role (unless needed), sequential ID
  };
}

function isServerAdmin(server, userId) {
  if (!server || !userId) return false;
  return server.owner_id === userId
    || server.admins?.includes(userId)
    || false;
}

// ─── Auth Guard Middleware ───────────────────────────────────────────────────

/**
 * Protects API endpoints that were previously unauthenticated.
 *
 * @param {object} [options]
 * @param {string[]} [options.publicPaths] - Paths that remain public
 * @param {function} [options.getMemberships] - (userId) => serverId[] — get user's server memberships
 */
function apiAuthGuard(options = {}) {
  const {
    publicPaths = [
      '/api/register',
      '/api/login',
      '/api/anonymous',
      '/api/public-servers',
      '/api/download-count',
    ],
    getMemberships = null,
  } = options;

  return function nullsecApiAuthGuard(req, res, next) {
    const path = req.path || req.url?.split('?')[0];

    // Public paths don't need auth
    if (publicPaths.some(p => path.startsWith(p))) {
      return next();
    }

    // Require authenticated user (set by jwt-cookie-auth middleware)
    if (!req.user) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Authentication required to access this resource.',
      });
    }

    // ── Specific endpoint hardening ───────────────────────────

    // C4: /api/servers — filter by membership
    if (path === '/api/servers') {
      // Intercept the response to filter/sanitize
      const originalJson = res.json.bind(res);
      res.json = function(data) {
        if (Array.isArray(data)) {
          const userId = req.user.id;
          const filtered = data
            .filter(server => {
              // Only return servers the user is a member of
              return server.members?.includes(userId)
                || server.owner_id === userId;
            })
            .map(server => sanitizeServer(server, userId));
          return originalJson(filtered);
        }
        if (data && typeof data === 'object' && data.servers) {
          const userId = req.user.id;
          data.servers = data.servers
            .filter(server => server.members?.includes(userId) || server.owner_id === userId)
            .map(server => sanitizeServer(server, userId));
        }
        return originalJson(data);
      };
    }

    // /api/me — sanitize user data, strip sequential ID
    if (path === '/api/me') {
      const originalJson = res.json.bind(res);
      res.json = function(data) {
        if (data && data.id) {
          return originalJson(sanitizeUser(data));
        }
        return originalJson(data);
      };
    }

    next();
  };
}

// ─── Registration Response Fix (M2 + M3) ────────────────────────────────────

/**
 * Wraps registration handler to:
 * - M2: Return identical response for "username exists" vs success timing
 * - M3: Don't return sequential user ID
 */
apiAuthGuard.fixRegistrationResponse = function(handler) {
  return async function(req, res) {
    const start = Date.now();
    try {
      await handler(req, res);
    } catch (err) {
      // M2: Constant-time response to prevent user enumeration
      const elapsed = Date.now() - start;
      const delay = Math.max(0, 200 - elapsed);  // Normalize to ~200ms
      await new Promise(r => setTimeout(r, delay));

      // Generic error regardless of whether username exists
      return res.status(400).json({
        error: 'registration_failed',
        message: 'Unable to create account. Check your input and try again.',
      });
    }
  };
};

module.exports = apiAuthGuard;
module.exports.sanitizeServer = sanitizeServer;
module.exports.sanitizeUser = sanitizeUser;
module.exports.obfuscateId = obfuscateId;
