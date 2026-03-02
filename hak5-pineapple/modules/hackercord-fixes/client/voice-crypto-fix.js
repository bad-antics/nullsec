/**
 * NullSec Voice Crypto Fix
 * ──────────────────────────
 * Fixes: H2 (E2EE Mismatch — claims AES-256-GCM, actually AES-128-GCM)
 *
 * The voiceCrypto.js module uses ECDH P-256 to derive a shared secret,
 * then passes it to AES-GCM. The bug: deriveKey() defaults to 128-bit
 * when {length: 256} is not specified.
 *
 * This module patches the key derivation to actually use AES-256-GCM.
 *
 * @audit hackercord-audit.md — Finding H2
 * @priority P1 (30 min)
 */

'use strict';

// ─── Corrected Key Derivation ───────────────────────────────────────────────

/**
 * Fixed ECDH → AES-256-GCM key derivation.
 *
 * BEFORE (broken):
 *   crypto.subtle.deriveKey(
 *     { name: 'ECDH', public: remotePubKey },
 *     localPrivKey,
 *     { name: 'AES-GCM', length: 128 },  // ← BUG: 128-bit, not 256
 *     false,
 *     ['encrypt', 'decrypt']
 *   );
 *
 * AFTER (fixed):
 *   Uses HKDF intermediate step for proper 256-bit key derivation
 */

async function deriveVoiceKey(localPrivateKey, remotePublicKey) {
  // Step 1: ECDH shared secret
  const sharedSecret = await crypto.subtle.deriveBits(
    {
      name: 'ECDH',
      public: remotePublicKey,
    },
    localPrivateKey,
    256  // P-256 gives 256 bits of shared secret
  );

  // Step 2: Import shared secret as HKDF key material
  const hkdfKey = await crypto.subtle.importKey(
    'raw',
    sharedSecret,
    { name: 'HKDF' },
    false,
    ['deriveKey']
  );

  // Step 3: Derive AES-256-GCM key via HKDF (proper key stretching)
  const aesKey = await crypto.subtle.deriveKey(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: new TextEncoder().encode('hackercord-voice-e2ee-v2'),
      info: new TextEncoder().encode('voice-encryption-key'),
    },
    hkdfKey,
    {
      name: 'AES-GCM',
      length: 256,  // ← FIX: 256-bit key (was 128)
    },
    false,
    ['encrypt', 'decrypt']
  );

  return aesKey;
}

// ─── Corrected Encrypt/Decrypt ──────────────────────────────────────────────

/**
 * Encrypt an audio frame with AES-256-GCM.
 * @param {CryptoKey} key - AES-256-GCM key from deriveVoiceKey()
 * @param {ArrayBuffer} frame - Raw audio frame data
 * @returns {ArrayBuffer} - IV (12 bytes) + ciphertext + tag
 */
async function encryptFrame(key, frame) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv, tagLength: 128 },
    key,
    frame
  );
  // Prepend IV to ciphertext
  const result = new Uint8Array(iv.byteLength + ciphertext.byteLength);
  result.set(iv, 0);
  result.set(new Uint8Array(ciphertext), iv.byteLength);
  return result.buffer;
}

/**
 * Decrypt an audio frame with AES-256-GCM.
 * @param {CryptoKey} key - AES-256-GCM key
 * @param {ArrayBuffer} encryptedFrame - IV + ciphertext + tag
 * @returns {ArrayBuffer} - Decrypted audio frame
 */
async function decryptFrame(key, encryptedFrame) {
  const data = new Uint8Array(encryptedFrame);
  const iv = data.slice(0, 12);
  const ciphertext = data.slice(12);
  return crypto.subtle.decrypt(
    { name: 'AES-GCM', iv, tagLength: 128 },
    key,
    ciphertext
  );
}

// ─── Key Generation ─────────────────────────────────────────────────────────

async function generateKeyPair() {
  return crypto.subtle.generateKey(
    {
      name: 'ECDH',
      namedCurve: 'P-256',
    },
    false,
    ['deriveBits']  // Note: deriveBits, not deriveKey (we use HKDF intermediate)
  );
}

async function exportPublicKey(keyPair) {
  const raw = await crypto.subtle.exportKey('raw', keyPair.publicKey);
  return btoa(String.fromCharCode(...new Uint8Array(raw)));
}

async function importPublicKey(base64Key) {
  const raw = Uint8Array.from(atob(base64Key), c => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'raw',
    raw,
    { name: 'ECDH', namedCurve: 'P-256' },
    false,
    []
  );
}

// ─── Monkey-patch for existing voiceCrypto.js ───────────────────────────────

/**
 * Call this to patch the existing voiceCrypto module in-place.
 * Usage: patchVoiceCrypto(window.voiceCrypto || window.VoiceCrypto);
 */
function patchVoiceCrypto(module) {
  if (!module) {
    console.warn('[NullSec] voiceCrypto module not found, loading standalone');
    return;
  }

  // Override the key derivation function
  if (module.deriveKey) module.deriveKey = deriveVoiceKey;
  if (module.deriveVoiceKey) module.deriveVoiceKey = deriveVoiceKey;

  // Override encrypt/decrypt if they exist
  if (module.encryptFrame) module.encryptFrame = encryptFrame;
  if (module.decryptFrame) module.decryptFrame = decryptFrame;

  console.log('[NullSec] voiceCrypto patched: AES-128-GCM → AES-256-GCM ✓');
}

// ─── Export ─────────────────────────────────────────────────────────────────

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    deriveVoiceKey,
    encryptFrame,
    decryptFrame,
    generateKeyPair,
    exportPublicKey,
    importPublicKey,
    patchVoiceCrypto,
  };
} else {
  window.NullSecVoiceCrypto = {
    deriveVoiceKey,
    encryptFrame,
    decryptFrame,
    generateKeyPair,
    exportPublicKey,
    importPublicKey,
    patchVoiceCrypto,
  };
}
