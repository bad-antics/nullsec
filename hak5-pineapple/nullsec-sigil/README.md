# 🔮 nullsec-sigil

**Visual Hash Fingerprinting — Turn Any Hash Into Unique Geometric Art**

[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://python.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![bad-antics](https://img.shields.io/badge/by-bad--antics-red.svg)](https://github.com/bad-antics)

> Every hash tells a story. Sigil makes it visible.

nullsec-sigil generates deterministic, beautiful SVG sigils from any input — files, strings, hashes, SSH keys, certificates, or network packets. Two inputs that differ by a single bit produce completely different sigils, making visual verification instant.

## 🎯 Use Cases

- **SSH Key Verification** — Visually confirm host keys at a glance
- **File Integrity** — Generate sigils for release artifacts; spot tampering instantly
- **Certificate Pinning** — Create visual fingerprints of TLS certificates
- **Forensic Tagging** — Unique visual identifiers for evidence files
- **Git Commit Signing** — Visual commit identity badges
- **CTF Challenges** — Hide clues in generative art

## ⚡ Quick Start

```bash
# Install
pip install nullsec-sigil

# Generate a sigil from a string
sigil "hello world"

# Generate from a file
sigil --file /etc/passwd

# Generate from stdin
echo "secret" | sigil --stdin

# Generate from an SSH public key
sigil --ssh ~/.ssh/id_rsa.pub

# Output as PNG (requires cairosvg)
sigil "hello world" --format png --output hello.png

# Batch mode — sigil every file in a directory
sigil --batch ./releases/ --output ./sigils/
```

## 🎨 Sigil Anatomy

Each sigil is a 512×512 SVG composed of layered geometric elements derived from the SHA-256 hash of the input:

| Hash Bytes | Element | Controls |
|-----------|---------|----------|
| 0–3 | **Outer Ring** | Shape, rotation, stroke width |
| 4–7 | **Inner Mandala** | Petal count, symmetry, radius |
| 8–11 | **Core Glyph** | Polygon type, fill pattern |
| 12–15 | **Color Palette** | Hue, saturation, lightness |
| 16–19 | **Particle Field** | Dot count, spread, opacity |
| 20–23 | **Connecting Lines** | Arc count, curvature |
| 24–27 | **Background** | Gradient angle, darkness |
| 28–31 | **Border Runes** | Tick marks, encoding hash prefix |

## 🔧 CLI Reference

```
Usage: sigil [INPUT] [OPTIONS]

Arguments:
  INPUT                    String to generate sigil from

Options:
  --file PATH              Generate from file contents
  --ssh PATH               Generate from SSH public key
  --stdin                  Read from stdin
  --format [svg|png|ascii] Output format (default: svg)
  --output PATH            Output file path (default: stdout)
  --size INT               Canvas size in pixels (default: 512)
  --theme [dark|light|neon|mono|fire|ice|matrix]
  --batch PATH             Generate sigils for all files in directory
  --compare A B            Compare two inputs side-by-side
  --no-label               Omit hash label from sigil
  --json                   Output sigil metadata as JSON
  -v, --verbose            Verbose output
```

## 🖼️ Themes

| Theme | Description |
|-------|-------------|
| `dark` | Deep black background, neon accents |
| `light` | White background, muted tones |
| `neon` | Cyberpunk palette, glow effects |
| `mono` | Grayscale only |
| `fire` | Red/orange/yellow palette |
| `ice` | Blue/cyan/white palette |
| `matrix` | Green-on-black terminal aesthetic |

## 📦 As a Library

```python
from nullsec_sigil import Sigil

# Generate from string
s = Sigil("hello world")
print(s.svg)           # Raw SVG string
s.save("hello.svg")    # Save to file
print(s.hash)          # SHA-256 hash used
print(s.palette)       # Color palette extracted

# Compare two sigils
from nullsec_sigil import compare
diff = compare("file_a.bin", "file_b.bin")
print(diff.identical)   # True/False
print(diff.distance)    # Hamming distance
```

## 🏗️ Architecture

```
nullsec-sigil/
├── sigil/
│   ├── __init__.py
│   ├── cli.py          # Click CLI interface
│   ├── core.py         # Hash → geometry engine
│   ├── palette.py      # Color extraction from hash bytes
│   ├── shapes.py       # SVG shape primitives
│   ├── themes.py       # Theme definitions
│   └── renderer.py     # SVG/PNG/ASCII renderer
├── setup.py
└── README.md
```

## 📄 License

MIT — built by [bad-antics](https://github.com/bad-antics) for the nullsec project.
