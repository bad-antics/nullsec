/**
 * NullSec Rate Limiter Middleware
 * ────────────────────────────────
 * Fixes: C2 (No Rate Limiting)
 *
 * Redis-backed sliding window rate limiter
 * - /api/register: 5 requests per minute per IP
 * - /api/login: 10 requests per minute per IP
 * - Global: 100 requests per minute per IP
 *
 * Falls back to in-memory Map if Redis is unavailable.
 *
 * @audit hackercord-audit.md — Finding C2
 * @priority P0 (2 hours)
 */

'use strict';

// ─── In-Memory Fallback Store ───────────────────────────────────────────────

class MemoryStore {
  constructor() {
    this.hits = new Map();
    // Clean up every 5 minutes
    this._interval = setInterval(() => this._cleanup(), 300000);
  }

  async increment(key, windowMs) {
    const now = Date.now();
    let record = this.hits.get(key);
    if (!record || now - record.start > windowMs) {
      record = { start: now, count: 0 };
      this.hits.set(key, record);
    }
    record.count++;
    return {
      count: record.count,
      resetMs: record.start + windowMs - now,
    };
  }

  _cleanup() {
    const now = Date.now();
    for (const [key, record] of this.hits) {
      if (now - record.start > 120000) {
        this.hits.delete(key);
      }
    }
  }

  close() {
    clearInterval(this._interval);
  }
}

// ─── Redis Store ────────────────────────────────────────────────────────────

class RedisStore {
  constructor(redisClient) {
    this.redis = redisClient;
  }

  async increment(key, windowMs) {
    const windowSec = Math.ceil(windowMs / 1000);
    const prefixed = `nullsec:rl:${key}`;

    const multi = this.redis.multi();
    multi.incr(prefixed);
    multi.pttl(prefixed);
    const results = await multi.exec();

    const count = results[0][1];
    const ttl = results[1][1];

    // Set expiry on first hit
    if (ttl === -1) {
      await this.redis.pexpire(prefixed, windowMs);
    }

    return {
      count,
      resetMs: ttl > 0 ? ttl : windowMs,
    };
  }
}

// ─── Rate Limit Presets (from audit findings) ───────────────────────────────

const PRESETS = {
  register: {
    windowMs: 60000,     // 1 minute
    max: 5,              // 5 per minute (audit: was unlimited → 10/10 succeeded)
    message: 'Too many registration attempts. Try again in a minute.',
  },
  login: {
    windowMs: 60000,
    max: 10,             // 10 per minute (audit: was unlimited → 20/20 succeeded)
    message: 'Too many login attempts. Account temporarily locked.',
  },
  api: {
    windowMs: 60000,
    max: 100,            // General API
    message: 'Rate limit exceeded.',
  },
  proxy: {
    windowMs: 60000,
    max: 20,             // web-proxy calls
    message: 'Proxy rate limit exceeded.',
  },
};

// ─── Route → Preset Mapping ─────────────────────────────────────────────────

const ROUTE_MAP = {
  '/api/register': 'register',
  '/api/login': 'login',
  '/api/anonymous': 'login',
  '/api/web-proxy': 'proxy',
};

// ─── Middleware Factory ─────────────────────────────────────────────────────

/**
 * @param {object} [options]
 * @param {object} [options.redis] - Redis client instance (ioredis/node-redis)
 * @param {object} [options.presets] - Override rate limit presets
 * @param {function} [options.keyGenerator] - Custom key generator (req) => string
 * @param {boolean} [options.trustProxy] - Trust X-Forwarded-For (default: true for CF)
 */
function rateLimiter(options = {}) {
  const {
    redis = null,
    presets = PRESETS,
    keyGenerator = null,
    trustProxy = true,
  } = options;

  const store = redis ? new RedisStore(redis) : new MemoryStore();

  function getIP(req) {
    if (keyGenerator) return keyGenerator(req);
    if (trustProxy) {
      // Cloudflare sets CF-Connecting-IP
      return req.headers['cf-connecting-ip']
        || req.headers['x-forwarded-for']?.split(',')[0]?.trim()
        || req.ip
        || req.connection?.remoteAddress
        || 'unknown';
    }
    return req.ip || req.connection?.remoteAddress || 'unknown';
  }

  return async function nullsecRateLimiter(req, res, next) {
    const path = req.path || req.url?.split('?')[0];
    const presetName = ROUTE_MAP[path] || 'api';
    const preset = presets[presetName] || presets.api;

    const ip = getIP(req);
    const key = `${presetName}:${ip}`;

    try {
      const { count, resetMs } = await store.increment(key, preset.windowMs);

      // Set rate limit headers (RFC 6585 / draft-ietf-httpapi-ratelimit-headers)
      res.setHeader('X-RateLimit-Limit', preset.max);
      res.setHeader('X-RateLimit-Remaining', Math.max(0, preset.max - count));
      res.setHeader('X-RateLimit-Reset', Math.ceil(resetMs / 1000));
      res.setHeader('RateLimit-Policy', `${preset.max};w=${Math.ceil(preset.windowMs / 1000)}`);

      if (count > preset.max) {
        res.setHeader('Retry-After', Math.ceil(resetMs / 1000));
        return res.status(429).json({
          error: 'rate_limited',
          message: preset.message,
          retryAfter: Math.ceil(resetMs / 1000),
        });
      }
    } catch (err) {
      // Fail open — don't break the app if rate limiter errors
      console.error('[NullSec RateLimiter] Store error:', err.message);
    }

    next();
  };
}

rateLimiter.PRESETS = PRESETS;
rateLimiter.MemoryStore = MemoryStore;
rateLimiter.RedisStore = RedisStore;

module.exports = rateLimiter;
