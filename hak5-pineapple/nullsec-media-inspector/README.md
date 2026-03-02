# 🔍 nullsec-media-inspector

> **n01d Media Inspector** — Subliminal Variable Frequency Layer Analyzer  
> NullSec Toolkit v1.0

---

## What It Does

Scans audio and video files for **hidden frequency content** that a human listener wouldn't consciously perceive:

| Detection Layer | What It Finds |
|----------------|---------------|
| **Infrasonic** (<20 Hz) | Sub-audible tones that cause physiological effects (anxiety, nausea, disorientation) |
| **Ultrasonic** (>18 kHz) | Inaudible carriers used by tracking beacons (SilverPush, Xtify, Lisnr) |
| **Near-Threshold** | Content at the edge of hearing exploiting individual perception limits |
| **Psychoacoustic Masking** | Tones hidden in the masking skirt of louder sounds |
| **Ultrasonic Beacons** | Sustained high-frequency tones for cross-device tracking |
| **Frequency Hopping** | FHSS-style carrier jumps encoding covert data |
| **Chirp / Sweep** | Linear/log frequency sweeps carrying embedded signals |
| **Spread Spectrum** | DSSS-style wideband energy patterns |
| **AM/FM Carriers** | Modulated carriers above 15 kHz |
| **Temporal Pulsing** | On/off keying of subliminal tones (binary data encoding) |
| **Spectral Anomalies** | Sudden narrowband injections not matching surrounding audio |

---

## Quick Start

```bash
# install deps
pip install -r requirements.txt

# also need ffmpeg for video / lossy audio
sudo apt install ffmpeg    # Debian/Ubuntu
brew install ffmpeg         # macOS

# scan a file
python run.py scan suspicious_podcast.mp3

# scan with custom FFT resolution
python run.py scan target.wav --fft-size 16384 --window blackmanharris

# batch scan a directory
python run.py batch /media/evidence/ --ext mp3,wav,mp4

# launch web UI
python run.py web --port 8090
```

---

## CLI Usage

```
python run.py scan <file> [options]
python run.py batch <dir> [options]
python run.py web [options]

Scan Options:
  -o, --output DIR        Output directory (default: output/)
  --fft-size N            FFT window size: 2048|4096|8192|16384 (default: 8192)
  --window TYPE           Window function: hann|hamming|blackman|blackmanharris|kaiser|flat
  --zero-pad N            Zero-padding factor (default: 1)
  --sample-rate HZ        Resample to this rate (default: native)
  --mono                  Downmix to mono before analysis
  --interactive           Generate interactive HTML spectrograms (requires plotly)
  --colormap NAME         Matplotlib colormap (default: inferno)

Batch Options:
  --ext EXTS              Comma-separated extensions (e.g., mp3,wav,mp4)

Web Options:
  -p, --port PORT         Web UI port (default: 8090)
  --debug                 Flask debug mode
```

---

## Output

Each scan produces:

```
output/scan_<filename>/
├── spectrogram_ch0.png       # Annotated spectrogram with event overlays
├── heatmap_ch0.png           # Band energy heatmap (subliminal bands highlighted)
├── spectrogram_ch0.html      # Interactive spectrogram (with --interactive)
├── report.json               # Machine-readable findings
└── report.md                 # Human-readable report with risk scores
```

---

## Architecture

```
nullsec-media-inspector/
├── run.py                    # CLI entrypoint
├── requirements.txt
├── inspector/
│   ├── analyzer.py           # Core FFT/STFT spectral engine
│   ├── subliminal.py         # Subliminal frequency detector
│   ├── vfl_detector.py       # Variable Frequency Layer detector
│   ├── spectrogram.py        # Annotated spectrogram generator
│   ├── extractor.py          # Audio extraction from any media format
│   └── report.py             # JSON + Markdown report generator
├── app/
│   └── routes.py             # Flask web UI
├── templates/
│   ├── index.html            # Upload + scan interface
│   └── report.html           # Interactive report viewer
└── output/                   # Scan results
```

### Analysis Pipeline

```
Media File
    │
    ▼
┌─────────────┐    ┌──────────────────┐    ┌───────────────────┐
│  Extractor   │───▶│ Spectral Analyzer │───▶│ Subliminal Detect │
│  (ffmpeg)    │    │  (STFT / FFT)     │    │ (6 pass scanner)  │
└─────────────┘    └──────────────────┘    └───────────────────┘
                           │                         │
                           │                         ▼
                           │               ┌───────────────────┐
                           └──────────────▶│  VFL Detector      │
                                           │ (6 pass scanner)   │
                                           └───────────────────┘
                                                     │
                                    ┌────────────────┼────────────────┐
                                    ▼                ▼                ▼
                            ┌────────────┐  ┌─────────────┐  ┌────────────┐
                            │ Spectrogram │  │   Report    │  │  Web UI    │
                            │  (PNG/HTML) │  │ (JSON + MD) │  │  (Flask)   │
                            └────────────┘  └─────────────┘  └────────────┘
```

---

## Detection Details

### Subliminal Detector — 6 Passes

1. **Infrasonic scan** (0.1–20 Hz) — flags energy above noise floor + 6 dB
2. **Near-threshold low** (16–20 Hz) — borderline audible content
3. **Near-threshold high** (17–18 kHz) — near upper hearing limit
4. **Ultrasonic scan** (18 kHz – Nyquist) — inaudible high-frequency content
5. **Psychoacoustic masking** — tones hidden within critical bandwidth of a louder masker
6. **Beacon detection** — sustained ultrasonic tones (>18 kHz) stable across frames

### VFL Detector — 6 Passes

1. **Frequency hopping** — discrete carrier jumps between frames (FHSS signatures)
2. **Chirp/sweep** — linear frequency sweeps detected via R² fitting on sliding windows
3. **Spread spectrum** — wideband energy with high spectral entropy and low peak-to-average ratio
4. **Modulated carriers** — AM depth and FM deviation on carriers above 15 kHz
5. **Temporal pulsing** — on/off keying with regularity analysis (CoV of inter-pulse intervals)
6. **Spectral anomalies** — z-score outliers in spectral centroid and bandwidth

---

## Risk Scoring

Both the subliminal and VFL detectors produce a 0–100 risk score:

| Range | Level | Meaning |
|-------|-------|---------|
| 0–14 | 🟢 Low | Clean — no significant findings |
| 15–39 | 🟡 Medium | Minor anomalies — review recommended |
| 40–69 | 🟠 High | Significant hidden content detected |
| 70–100 | 🔴 Critical | Active subliminal/covert layers present |

Combined risk = `subliminal_risk × 0.6 + vfl_risk × 0.4`

---

## Use Cases

- **Podcast / media forensics** — check audio for embedded tracking beacons
- **Ad-tech analysis** — detect cross-device ultrasonic tracking (SilverPush-style)
- **Broadcast monitoring** — identify subliminal content in TV/radio
- **Security auditing** — verify media files are clean before distribution
- **Research** — study psychoacoustic manipulation techniques
- **Counter-surveillance** — detect covert audio channels in ambient recordings

---

*NullSec Toolkit — n01d Media Inspector v1.0*
