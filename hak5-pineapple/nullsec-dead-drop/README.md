# 💀 nullsec-dead-drop

**Steganographic Message Hiding — Spy-Craft for the Terminal**

[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://python.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![bad-antics](https://img.shields.io/badge/by-bad--antics-red.svg)](https://github.com/bad-antics)

> Hide messages in plain sight. Extract them with a key.

nullsec-dead-drop embeds encrypted messages into PNG images using Least Significant Bit (LSB) steganography. The image looks identical to the human eye, but carries a hidden payload. Messages are AES-256 encrypted before embedding — even if someone knows the image contains data, they can't read it without the key.

## 🎯 Use Cases

- **Covert Communication** — Exchange messages hidden in memes
- **CTF Challenges** — Build stego challenges with one command
- **Whistleblowing** — Embed encrypted evidence in innocuous images
- **Data Exfil Training** — Red team exercises for steganography detection
- **Digital Watermarking** — Embed ownership proofs in images
- **Educational** — Learn how LSB steganography works

## ⚡ Quick Start

```bash
# Install
pip install nullsec-dead-drop

# Hide a message in an image
dead-drop hide --image photo.png --message "meet at the usual place" --key "s3cr3t" --output stego.png

# Extract a hidden message
dead-drop extract --image stego.png --key "s3cr3t"

# Hide a file inside an image
dead-drop hide --image photo.png --payload secret.pdf --key "s3cr3t" --output stego.png

# Extract a hidden file
dead-drop extract --image stego.png --key "s3cr3t" --output recovered.pdf

# Check if an image contains hidden data (without key)
dead-drop detect --image suspicious.png

# Generate a clean carrier image
dead-drop generate --size 1024x768 --output carrier.png

# Estimate capacity
dead-drop capacity --image photo.png
```

## 🔐 How It Works

```
┌────────────┐     ┌──────────┐     ┌──────────┐     ┌───────────┐
│  Message/   │ ──► │ AES-256  │ ──► │ LSB      │ ──► │ Stego     │
│  File       │     │ Encrypt  │     │ Embed    │     │ Image     │
└────────────┘     └──────────┘     └──────────┘     └───────────┘
     + Key              │                │
                   Ciphertext      Bit-by-bit into
                   + HMAC          pixel channels
```

1. **Compress** — Input is zlib compressed
2. **Encrypt** — AES-256-GCM with PBKDF2-derived key (100k iterations)
3. **Header** — 32-byte header: magic bytes, payload length, checksum
4. **Embed** — Each bit replaces the least significant bit of a pixel color channel
5. **Verify** — HMAC ensures integrity on extraction

## 📊 Capacity

| Image Size | Max Hidden Data | Equivalent Text |
|-----------|----------------|-----------------|
| 256×256 | ~24 KB | ~24,000 characters |
| 512×512 | ~96 KB | ~96,000 characters |
| 1024×1024 | ~384 KB | A short novel |
| 1920×1080 | ~760 KB | Multiple documents |
| 4096×4096 | ~6 MB | Large files |

## 🛡️ Security

- **AES-256-GCM** encryption with authenticated tags
- **PBKDF2** key derivation (100,000 iterations, random salt)
- **HMAC-SHA256** integrity verification
- **No metadata leakage** — no EXIF modifications
- **Constant-time extraction** — resistant to timing attacks
- **Decoy mode** — embed random noise to mask real payloads

## 📦 As a Library

```python
from dead_drop import hide, extract, detect, capacity

# Hide a message
hide("carrier.png", "output.png", message="secret", key="passphrase")

# Extract
msg = extract("output.png", key="passphrase")
print(msg)

# Detection scan
result = detect("suspicious.png")
print(result.likelihood)   # 0.0 to 1.0
print(result.indicators)   # List of stego indicators

# Check capacity
cap = capacity("carrier.png")
print(f"Can hide {cap.bytes} bytes ({cap.human})")
```

## 📄 License

MIT — built by [bad-antics](https://github.com/bad-antics) for the nullsec project.
