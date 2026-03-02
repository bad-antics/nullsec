"""
Media Extractor — nullsec-media-inspector
==========================================
Handles loading audio from various file formats and extracting
audio streams from video containers.

Supported formats:
  Audio: WAV, FLAC, MP3, OGG, AAC, M4A, WMA, AIFF, OPUS
  Video: MP4, MKV, AVI, MOV, WEBM, FLV, WMV, MPEG, TS

Uses soundfile for lossless, pydub+ffmpeg for lossy/video,
and falls back to scipy.io.wavfile for raw WAV.
"""

import os
import tempfile
import subprocess
import numpy as np
from dataclasses import dataclass
from typing import Optional

AUDIO_EXTENSIONS = {
    ".wav", ".flac", ".mp3", ".ogg", ".aac", ".m4a",
    ".wma", ".aiff", ".aif", ".opus", ".oga",
}
VIDEO_EXTENSIONS = {
    ".mp4", ".mkv", ".avi", ".mov", ".webm", ".flv",
    ".wmv", ".mpeg", ".mpg", ".ts", ".m4v", ".3gp",
}


@dataclass
class AudioData:
    """Extracted audio ready for analysis."""
    channels: list          # list[np.ndarray]  — each channel as float64 in [-1, 1]
    sample_rate: int
    n_channels: int
    duration_sec: float
    bit_depth: Optional[int]
    source_format: str
    source_path: str
    metadata: dict          # ffprobe / mediainfo metadata


class MediaExtractor:
    """
    Extract and normalize audio from any media file.

    Priority chain:
      1. soundfile (for WAV/FLAC/AIFF — fast, no ffmpeg needed)
      2. pydub + ffmpeg (for everything else)
      3. scipy.io.wavfile (fallback for raw WAV)
    """

    def __init__(
        self,
        target_sr: Optional[int] = None,   # resample to this SR; None = keep native
        mono: bool = False,                  # downmix to mono
        normalize: bool = True,              # peak-normalize to [-1, 1]
        ffmpeg_path: str = "ffmpeg",
        ffprobe_path: str = "ffprobe",
    ):
        self.target_sr = target_sr
        self.mono = mono
        self.normalize = normalize
        self.ffmpeg = ffmpeg_path
        self.ffprobe = ffprobe_path

    # ── public API ──────────────────────────────────────────────────

    def extract(self, filepath: str) -> AudioData:
        """
        Load and extract audio from a media file.
        Returns an AudioData object with float64 channels.
        """
        filepath = os.path.abspath(filepath)
        if not os.path.isfile(filepath):
            raise FileNotFoundError(f"File not found: {filepath}")

        ext = os.path.splitext(filepath)[1].lower()
        metadata = self._probe(filepath)
        source_format = ext.lstrip(".")

        if ext in VIDEO_EXTENSIONS:
            channels, sr, bd = self._extract_from_video(filepath)
        elif ext in AUDIO_EXTENSIONS:
            channels, sr, bd = self._load_audio(filepath)
        else:
            # try ffmpeg anyway
            channels, sr, bd = self._extract_via_ffmpeg(filepath)

        # resample if requested
        if self.target_sr and sr != self.target_sr:
            channels = [self._resample(ch, sr, self.target_sr) for ch in channels]
            sr = self.target_sr

        # downmix
        if self.mono and len(channels) > 1:
            mixed = np.mean(np.stack(channels), axis=0)
            channels = [mixed]

        # normalize
        if self.normalize:
            channels = [self._peak_normalize(ch) for ch in channels]

        n_ch = len(channels)
        dur = len(channels[0]) / sr if channels else 0.0

        return AudioData(
            channels=channels,
            sample_rate=sr,
            n_channels=n_ch,
            duration_sec=dur,
            bit_depth=bd,
            source_format=source_format,
            source_path=filepath,
            metadata=metadata,
        )

    # ── loaders ─────────────────────────────────────────────────────

    def _load_audio(self, filepath: str):
        """Try soundfile → pydub → scipy chain."""
        # attempt 1: soundfile
        try:
            import soundfile as sf
            data, sr = sf.read(filepath, dtype="float64", always_2d=True)
            channels = [data[:, i] for i in range(data.shape[1])]
            info = sf.info(filepath)
            bd = info.subtype_info.split()[0] if hasattr(info, "subtype_info") else None
            try:
                bd = int(bd)
            except (TypeError, ValueError):
                bd = None
            return channels, sr, bd
        except Exception:
            pass

        # attempt 2: pydub + ffmpeg
        try:
            return self._extract_via_pydub(filepath)
        except Exception:
            pass

        # attempt 3: scipy (WAV only)
        try:
            from scipy.io import wavfile
            sr, data = wavfile.read(filepath)
            if data.dtype == np.int16:
                data = data.astype(np.float64) / 32768.0
                bd = 16
            elif data.dtype == np.int32:
                data = data.astype(np.float64) / 2147483648.0
                bd = 32
            elif data.dtype == np.float32:
                data = data.astype(np.float64)
                bd = 32
            else:
                data = data.astype(np.float64)
                bd = None

            if data.ndim == 1:
                channels = [data]
            else:
                channels = [data[:, i] for i in range(data.shape[1])]
            return channels, sr, bd
        except Exception as e:
            raise RuntimeError(f"Cannot load audio from {filepath}: {e}")

    def _extract_from_video(self, filepath: str):
        """Extract audio track from video via ffmpeg."""
        return self._extract_via_ffmpeg(filepath)

    def _extract_via_ffmpeg(self, filepath: str):
        """
        Use ffmpeg to decode any media file to raw PCM WAV,
        then load with soundfile/scipy.
        """
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            cmd = [
                self.ffmpeg, "-y", "-i", filepath,
                "-vn",                    # no video
                "-acodec", "pcm_f32le",   # 32-bit float PCM
                "-ar", str(self.target_sr or 48000),
                tmp_path,
            ]
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120,
            )
            if result.returncode != 0:
                raise RuntimeError(f"ffmpeg error: {result.stderr[:500]}")

            return self._load_audio(tmp_path)
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    def _extract_via_pydub(self, filepath: str):
        """Use pydub as intermediate."""
        from pydub import AudioSegment

        audio = AudioSegment.from_file(filepath)
        sr = audio.frame_rate
        bd = audio.sample_width * 8
        samples = np.array(audio.get_array_of_samples(), dtype=np.float64)

        max_val = float(2 ** (bd - 1))
        samples /= max_val

        n_ch = audio.channels
        if n_ch > 1:
            channels = [samples[i::n_ch] for i in range(n_ch)]
        else:
            channels = [samples]

        return channels, sr, bd

    # ── metadata via ffprobe ────────────────────────────────────────

    def _probe(self, filepath: str) -> dict:
        """Extract metadata with ffprobe."""
        try:
            cmd = [
                self.ffprobe,
                "-v", "quiet",
                "-print_format", "json",
                "-show_format",
                "-show_streams",
                filepath,
            ]
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=30,
            )
            if result.returncode == 0:
                import json
                return json.loads(result.stdout)
        except Exception:
            pass
        return {}

    # ── DSP helpers ─────────────────────────────────────────────────

    @staticmethod
    def _peak_normalize(signal: np.ndarray) -> np.ndarray:
        peak = np.max(np.abs(signal))
        if peak > 0:
            return signal / peak
        return signal

    @staticmethod
    def _resample(signal: np.ndarray, src_sr: int, dst_sr: int) -> np.ndarray:
        """Simple linear resampling. For production, use scipy.signal.resample."""
        try:
            from scipy.signal import resample
            n_out = int(len(signal) * dst_sr / src_sr)
            return resample(signal, n_out)
        except ImportError:
            # naive resampling
            ratio = dst_sr / src_sr
            n_out = int(len(signal) * ratio)
            x_old = np.linspace(0, 1, len(signal))
            x_new = np.linspace(0, 1, n_out)
            return np.interp(x_new, x_old, signal)
