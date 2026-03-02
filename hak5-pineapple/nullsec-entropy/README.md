# 🎲 nullsec-entropy

**File Entropy Analyzer — Detect Hidden Data, Weak Crypto & Packed Malware**

[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://python.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![bad-antics](https://img.shields.io/badge/by-bad--antics-red.svg)](https://github.com/bad-antics)

> Randomness tells secrets. Entropy reveals them.

nullsec-entropy measures the Shannon entropy and byte distribution of files to detect anomalies: encrypted payloads hiding in plain text, packed malware masquerading as images, weak crypto with predictable patterns, and steganographic content embedded in media.

## 🎯 Use Cases

- **Malware Analysis** — Detect packed/encrypted executables (high entropy sections)
- **Stego Detection** — Spot hidden data in images/audio by entropy spikes
- **Crypto Auditing** — Identify weak encryption (non-uniform byte distribution)
- **Forensics** — Find encrypted containers, hidden partitions, data blobs
- **CTF Challenges** — Identify file type mismatches and embedded payloads
- **Data Classification** — Classify files as text, binary, compressed, encrypted

## ⚡ Quick Start

```bash
# Install
pip install nullsec-entropy

# Analyze a single file
entropy scan /path/to/file

# Scan a directory recursively
entropy scan /path/to/dir --recursive

# Visual entropy map (terminal heatmap)
entropy map suspicious.bin

# Compare entropy profiles
entropy compare clean.exe suspicious.exe

# Classify file type by entropy signature
entropy classify mystery_file

# JSON output for automation
entropy scan /path/to/file --json
```

## 📊 Entropy Scale

| Range | Classification | Examples |
|-------|---------------|----------|
| 0.0 – 1.0 | **Null/Repetitive** | Zero-filled files, simple patterns |
| 1.0 – 3.5 | **Structured Text** | Source code, config files, logs |
| 3.5 – 5.0 | **Natural Language** | English text, documents |
| 5.0 – 6.5 | **Mixed/Binary** | Executables, object files |
| 6.5 – 7.5 | **Compressed** | ZIP, GZIP, JPEG, PNG |
| 7.5 – 7.99 | **Encrypted/Packed** | AES output, packed malware |
| 7.99 – 8.0 | **True Random** | /dev/urandom, hardware RNG |

## 🎨 Entropy Map

```
$ entropy map suspicious.exe

 Offset    Entropy  ████████████████████████████████████████
 0x0000    4.2      ████████████████████░░░░░░░░░░░░░░░░░░░░  PE Header
 0x1000    6.8      ██████████████████████████████████░░░░░░  .text
 0x5000    7.1      ███████████████████████████████████░░░░░  .rdata
 0x8000    7.95     ████████████████████████████████████████  ⚠ PACKED
 0xC000    3.1      ████████████████░░░░░░░░░░░░░░░░░░░░░░░░  .rsrc
 0xF000    0.2      █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  padding

 ⚠ Section at 0x8000 has suspiciously high entropy (7.95)
   Likely: encrypted payload, packed code, or embedded archive
```

## 📄 License

MIT — built by [bad-antics](https://github.com/bad-antics) for the nullsec project.
