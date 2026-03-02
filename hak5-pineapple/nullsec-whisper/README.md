# 👁️ nullsec-whisper

**Spectral Audio Steganography — Voices From The Static**

[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://python.org)
[![bad-antics](https://img.shields.io/badge/by-bad--antics-red.svg)](https://github.com/bad-antics)

> The static is talking. Can you hear it?

Hides messages in audio frequency spectrograms. When you view the spectrogram, the hidden text appears as ghostly letters floating in the noise floor. Also detects hidden spectrogram messages in existing audio files.

## ⚡ Quick Start

```bash
pip install nullsec-whisper
whisper embed --audio white-noise.wav --message "HELP ME" --output haunted.wav
whisper listen --audio haunted.wav  # Renders spectrogram to terminal
whisper generate --message "I SEE YOU" --output ghost.wav  # Generate from scratch
```

## 📄 License
MIT — [bad-antics](https://github.com/bad-antics)
