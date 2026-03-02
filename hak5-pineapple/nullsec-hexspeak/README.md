# 🧙 nullsec-hexspeak

**Hexadecimal Word Encoder — Speak in Machine Code**

[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://python.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![bad-antics](https://img.shields.io/badge/by-bad--antics-red.svg)](https://github.com/bad-antics)

> 0xDEADBEEF walks into a 0xCAFE...

nullsec-hexspeak encodes messages using only valid hexadecimal characters (0-9, A-F), creating strings that are simultaneously readable English words AND valid hex values. It ships with a curated dictionary of 2,000+ hex-speakable words and can encode arbitrary text into the closest hex approximation.

## 🎯 Use Cases

- **Code Easter Eggs** — Hide readable messages in hex constants
- **CTF Challenge Design** — Create puzzles with dual-meaning hex strings
- **Debug Signatures** — Use meaningful magic numbers in protocols
- **Obfuscation** — Messages that look like memory addresses
- **Developer Humor** — Generate hex-word poetry and insults
- **Memory Forensics** — Recognize known hex-speak patterns in memory dumps

## ⚡ Quick Start

```bash
# Install
pip install nullsec-hexspeak

# Encode a message
hexspeak encode "dead beef cafe"

# Decode hex to words
hexspeak decode 0xDEADBEEF

# Generate random hex-word art
hexspeak random --count 10

# Search the dictionary
hexspeak search "food"

# Generate a hex poem
hexspeak poem

# Validate if a string is valid hexspeak
hexspeak check "DEADBEEF"

# Find all hex words in a binary/memory dump
hexspeak scan firmware.bin
```

## 📖 Hex Alphabet

Hexspeak uses substitutions to expand the hex character set:

| Hex | Reads As | Example |
|-----|----------|---------|
| 0 | O | `F00D` → FOOD |
| 1 | I/L | `F1LE` → FILE |
| 5 | S | `50DA` → SODA |
| 6 | G | `6ABE` → GABE |
| 7 | T | `7EA` → TEA |
| 8 | B/ATE | `B8` → BATE |
| 9 | g/q | (rare) |
| A-F | A-F | Direct hex |

## 🏆 Famous Hex Words

| Hex | Meaning | Used In |
|-----|---------|---------|
| `0xDEADBEEF` | Dead Beef | Unix malloc, debug markers |
| `0xCAFEBABE` | Cafe Babe | Java class file magic number |
| `0xFEEDFACE` | Feed Face | Mach-O binary magic |
| `0xDEADC0DE` | Dead Code | Debug fill patterns |
| `0xBAADF00D` | Bad Food | Windows LocalAlloc |
| `0xDEFEC8ED` | Defecated | OpenSolaris mutex |
| `0x8BADF00D` | Ate Bad Food | iOS watchdog kill |
| `0xFACEFEED` | Face Feed | Alpha AXP firmware |
| `0xFEE1DEAD` | Feel Dead | Linux reboot syscall |
| `0xBEEFCAFE` | Beef Cafe | — |

## 📄 License

MIT — built by [bad-antics](https://github.com/bad-antics) for the nullsec project.
