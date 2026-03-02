/**
 * NullSec JWT Rotation & Revocation
 * ────────────────────────────────────
 * Fixes: H5 (No JWT Revocation — 30 days, no rotation, no blacklist)
 *
 * Implements:
 * - Access token: 15 minutes (short-lived, EdDSA signed)
 * - Refresh token: 30 days (stored server-side, rotated on use)
 * - Server-side revocation list (Redis-backed or in-memory)
 * - Automatic token refresh via middleware
 * - "Logout everywhere" support
 *
 * @audit hackercord-audit.md — Finding H5
 * @priority P1 (1 day)
 */

'use strict';

const crypto = require('crypto');

// ─── Token Configuration ────────────────────────────────────────────────────

const ACCESS_TOKEN_TTL = 15 * 60;        // 15 minutes (seconds)
const REFRESH_TOKEN_TTL = 30 * 24 * 3600; // 30 days (seconds)

// ─── In-Memory Revocation Store (production: use Redis) ─────────────────────

class RevocationStore {
  constructor() {
    this.revokedTokens = new Map();   // jti → expiry timestamp
    this.refreshTokens = new Map();   // refreshToken → { userId, family, expiresAt }
    this.userFamilies = new Map();    // userId → Set<family>

    // Cleanup expired entries every 10 minutes
    this._interval = setInterval(() => this._cleanup(), 600000);
  }

  // Revoke an access token by its JTI (JWT ID)
  revokeAccess(jti, expiresAt) {
    this.revokedTokens.set(jti, expiresAt);
  }

  isAccessRevoked(jti) {
    return this.revokedTokens.has(jti);
  }

  // Store a refresh token
  storeRefresh(token, userId, family) {
    const expiresAt = Date.now() + REFRESH_TOKEN_TTL * 1000;
    this.refreshTokens.set(token, { userId, family, expiresAt, used: false });

    if (!this.userFamilies.has(userId)) {
      this.userFamilies.set(userId, new Set());
    }
    this.userFamilies.get(userId).add(family);
  }

  // Validate and consume a refresh token (one-time use)
  consumeRefresh(token) {
    const record = this.refreshTokens.get(token);
    if (!record) return null;
    if (record.expiresAt < Date.now()) {
      this.refreshTokens.delete(token);
      return null;
    }
    if (record.used) {
      // Refresh token reuse detected! Revoke entire family.
      this._revokeFamily(record.userId, record.family);
      return null;
    }
    record.used = true;
    return { userId: record.userId, family: record.family };
  }

  // Revoke all tokens for a user ("logout everywhere")
  revokeAllForUser(userId) {
    const families = this.userFamilies.get(userId);
    if (families) {
      for (const family of families) {
        this._revokeFamily(userId, family);
      }
      this.userFamilies.delete(userId);
    }
  }

  // Revoke an entire token family (detected reuse = compromised)
  _revokeFamily(userId, family) {
    for (const [token, record] of this.refreshTokens) {
      if (record.userId === userId && record.family === family) {
        this.refreshTokens.delete(token);
      }
    }
  }

  _cleanup() {
    const now = Date.now();
    for (const [jti, exp] of this.revokedTokens) {
      if (exp < now) this.revokedTokens.delete(jti);
    }
    for (const [token, record] of this.refreshTokens) {
      if (record.expiresAt < now) this.refreshTokens.delete(token);
    }
  }

  close() {
    clearInterval(this._interval);
  }
}

// ─── Token Pair Generator ───────────────────────────────────────────────────

/**
 * Generate an access + refresh token pair.
 *
 * @param {object} params
 * @param {object} params.user - User object with id, username
 * @param {function} params.signToken - (payload, options) => JWT string
 * @param {RevocationStore} params.store - Token store
 * @param {string} [params.family] - Token family ID (for rotation tracking)
 * @returns {{ accessToken, refreshToken, expiresIn, family }}
 */
function generateTokenPair({ user, signToken, store, family = null }) {
  const jti = crypto.randomUUID();
  const tokenFamily = family || crypto.randomUUID();

  // Short-lived access token
  const accessToken = signToken({
    sub: user.id,
    username: user.username,
    jti,
    type: 'access',
  }, { expiresIn: ACCESS_TOKEN_TTL });

  // Long-lived refresh token (opaque, stored server-side)
  const refreshToken = crypto.randomBytes(48).toString('base64url');

  // Store refresh token server-side
  store.storeRefresh(refreshToken, user.id, tokenFamily);

  return {
    accessToken,
    refreshToken,
    expiresIn: ACCESS_TOKEN_TTL,
    family: tokenFamily,
  };
}

// ─── Refresh Middleware ─────────────────────────────────────────────────────

/**
 * POST /api/auth/refresh — exchange refresh token for new pair
 *
 * @param {object} options
 * @param {RevocationStore} options.store
 * @param {function} options.signToken - Sign a new JWT
 * @param {function} options.getUser - (userId) => user object
 */
function refreshHandler({ store, signToken, getUser }) {
  return async function nullsecRefreshToken(req, res) {
    const { refreshToken } = req.body || {};

    if (!refreshToken) {
      return res.status(400).json({ error: 'missing_token', message: 'Refresh token required' });
    }

    // Consume refresh token (one-time use with reuse detection)
    const result = store.consumeRefresh(refreshToken);

    if (!result) {
      return res.status(401).json({
        error: 'invalid_refresh_token',
        message: 'Token expired, already used, or revoked. Please log in again.',
      });
    }

    // Get fresh user data
    const user = await getUser(result.userId);
    if (!user) {
      return res.status(401).json({ error: 'user_not_found', message: 'Account not found' });
    }

    // Generate rotated token pair (same family for reuse detection)
    const pair = generateTokenPair({
      user,
      signToken,
      store,
      family: result.family,
    });

    return res.json({
      ok: true,
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      expiresIn: pair.expiresIn,
    });
  };
}

// ─── Access Token Verification Middleware ────────────────────────────────────

/**
 * Checks access tokens against revocation list.
 */
function checkRevocation(store) {
  return function nullsecCheckRevocation(req, res, next) {
    if (req.user?.jti && store.isAccessRevoked(req.user.jti)) {
      return res.status(401).json({ error: 'token_revoked', message: 'Token has been revoked' });
    }
    next();
  };
}

// ─── Logout Handlers ────────────────────────────────────────────────────────

function logoutHandler(store) {
  return function nullsecLogout(req, res) {
    if (req.user?.jti) {
      // Revoke current access token
      store.revokeAccess(req.user.jti, Date.now() + ACCESS_TOKEN_TTL * 1000);
    }
    return res.json({ ok: true, message: 'Logged out' });
  };
}

function logoutEverywhereHandler(store) {
  return function nullsecLogoutEverywhere(req, res) {
    if (req.user?.sub) {
      store.revokeAllForUser(req.user.sub);
    }
    return res.json({ ok: true, message: 'Logged out from all devices' });
  };
}

module.exports = {
  RevocationStore,
  generateTokenPair,
  refreshHandler,
  checkRevocation,
  logoutHandler,
  logoutEverywhereHandler,
  ACCESS_TOKEN_TTL,
  REFRESH_TOKEN_TTL,
};
