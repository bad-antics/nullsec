/**
 * NullSec TURN/STUN Server Configuration
 * ─────────────────────────────────────────
 * Fixes: H3 (No TURN Server — only Google STUN, ~15% users can't call)
 *
 * Before: Only stun:stun.l.google.com:19302 → fails for ~15% of users
 *         behind symmetric NAT or restrictive firewalls
 *
 * After:  STUN + TURN (relay) servers → ~99% connectivity
 *
 * @audit hackercord-audit.md — Finding H3
 * @priority P1 (2 hours)
 */

'use strict';

// ─── ICE Server Configuration ───────────────────────────────────────────────

/**
 * Generate ICE server configuration with TURN credentials.
 *
 * Options for TURN servers:
 * 1. Self-hosted coturn (recommended for privacy)
 * 2. Metered.ca (free tier: 500GB/month)
 * 3. Twilio TURN (paid, very reliable)
 * 4. Xirsys (free tier available)
 */

function getICEServers(options = {}) {
  const {
    turnUrl = process.env.TURN_URL || 'turn:turn.hackercord.com:3478',
    turnTlsUrl = process.env.TURN_TLS_URL || 'turns:turn.hackercord.com:5349',
    turnUsername = process.env.TURN_USERNAME || '',
    turnCredential = process.env.TURN_CREDENTIAL || '',
    useTempCredentials = true,
  } = options;

  const servers = [
    // STUN servers (free, for NAT traversal)
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    { urls: 'stun:stun.cloudflare.com:3478' },

    // TURN servers (relay for users behind symmetric NAT)
    {
      urls: turnUrl,
      username: turnUsername,
      credential: turnCredential,
    },
    // TURN over TLS (port 443, works through most firewalls)
    {
      urls: turnTlsUrl,
      username: turnUsername,
      credential: turnCredential,
    },
  ];

  // Filter out TURN servers if no credentials configured
  return servers.filter(s => {
    if (s.urls?.startsWith('turn') && !s.username) return false;
    return true;
  });
}

// ─── Temporary TURN Credentials (RFC 8489 / coturn compatible) ──────────────

const crypto = require('crypto');

/**
 * Generate time-limited TURN credentials.
 * Use with coturn's `use-auth-secret` mode.
 *
 * @param {string} userId - User identifier
 * @param {string} secret - Shared secret (TURN_AUTH_SECRET env var)
 * @param {number} [ttl=86400] - Credential lifetime in seconds (default: 24h)
 * @returns {{ username: string, credential: string, ttl: number }}
 */
function generateTURNCredentials(userId, secret, ttl = 86400) {
  if (!secret) {
    throw new Error('[NullSec] TURN_AUTH_SECRET not configured');
  }

  const timestamp = Math.floor(Date.now() / 1000) + ttl;
  const username = `${timestamp}:${userId}`;
  const credential = crypto
    .createHmac('sha1', secret)
    .update(username)
    .digest('base64');

  return { username, credential, ttl };
}

// ─── API Endpoint for TURN Credentials ──────────────────────────────────────

/**
 * Express handler: GET /api/turn-credentials
 * Returns temporary TURN credentials for the authenticated user.
 */
function turnCredentialsHandler(options = {}) {
  const {
    secret = process.env.TURN_AUTH_SECRET,
    turnUrl = process.env.TURN_URL || 'turn:turn.hackercord.com:3478',
    turnTlsUrl = process.env.TURN_TLS_URL || 'turns:turn.hackercord.com:5349',
    ttl = 86400,
  } = options;

  return function(req, res) {
    if (!req.user) {
      return res.status(401).json({ error: 'unauthorized' });
    }

    if (!secret) {
      // Fallback: return STUN-only config
      return res.json({
        iceServers: [
          { urls: 'stun:stun.l.google.com:19302' },
          { urls: 'stun:stun.cloudflare.com:3478' },
        ],
        warning: 'TURN not configured — some users may not be able to connect',
      });
    }

    const creds = generateTURNCredentials(req.user.id || req.user.username, secret, ttl);

    return res.json({
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun.cloudflare.com:3478' },
        {
          urls: turnUrl,
          username: creds.username,
          credential: creds.credential,
        },
        {
          urls: turnTlsUrl,
          username: creds.username,
          credential: creds.credential,
        },
      ],
      ttl: creds.ttl,
    });
  };
}

// ─── Coturn Configuration Template ──────────────────────────────────────────

const COTURN_CONFIG = `# /etc/turnserver.conf — NullSec coturn configuration
# Install: apt install coturn

# Network
listening-port=3478
tls-listening-port=5349
alt-listening-port=3479
alt-tls-listening-port=5350

# Use fingerprint for STUN messages
fingerprint

# Long-term credential mechanism
lt-cred-mech

# Use auth secret (time-limited credentials via HMAC)
use-auth-secret
static-auth-secret=REPLACE_WITH_SECURE_SECRET

# Realm
realm=hackercord.com

# TLS certificates (Let's Encrypt)
cert=/etc/letsencrypt/live/turn.hackercord.com/fullchain.pem
pkey=/etc/letsencrypt/live/turn.hackercord.com/privkey.pem

# Security
no-multicast-peers
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255

# Logging
log-file=/var/log/turnserver.log
simple-log

# Limits
total-quota=100
stale-nonce=600
max-bps=0

# Run as daemon
pidfile=/var/run/turnserver.pid
proc-user=turnserver
proc-group=turnserver
`;

module.exports = {
  getICEServers,
  generateTURNCredentials,
  turnCredentialsHandler,
  COTURN_CONFIG,
};
