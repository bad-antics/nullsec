"""
Core Spectral Analyzer — nullsec-media-inspector
=================================================
FFT-based frequency decomposition with STFT windowing,
band-power extraction, and temporal energy tracking.

Designed to surface frequency content invisible to
casual listening / viewing — the foundation for all
subliminal and VFL detection passes.
"""

import numpy as np
from dataclasses import dataclass, field
from typing import Optional


# ── frequency band definitions ──────────────────────────────────────
BANDS = {
    "infrasonic":       (0.1,    20),
    "sub_bass":         (20,     60),
    "bass":             (60,    250),
    "low_mid":          (250,   500),
    "mid":              (500,  2000),
    "upper_mid":        (2000, 4000),
    "presence":         (4000, 6000),
    "brilliance":       (6000, 16000),
    "near_ultrasonic":  (16000, 18000),
    "ultrasonic":       (18000, 24000),
    "deep_ultrasonic":  (24000, 48000),
}

# subliminal-relevant ranges
SUBLIMINAL_BANDS = ["infrasonic", "near_ultrasonic", "ultrasonic", "deep_ultrasonic"]


@dataclass
class SpectralFrame:
    """One STFT window worth of analysis."""
    time_sec: float
    freqs: np.ndarray
    magnitudes: np.ndarray
    phase: np.ndarray
    band_powers: dict = field(default_factory=dict)


@dataclass
class AnalysisResult:
    """Full spectral analysis of an audio signal."""
    sample_rate: int
    duration_sec: float
    n_channels: int
    frames: list  # list[SpectralFrame]
    global_spectrum: np.ndarray
    global_freqs: np.ndarray
    band_energy_timeline: dict  # band_name → np.ndarray of per-frame energies
    peak_frequencies: list      # top-N frequency peaks (Hz, dB)
    noise_floor_db: float
    dynamic_range_db: float
    metadata: dict = field(default_factory=dict)


class SpectralAnalyzer:
    """
    Performs multi-resolution FFT analysis on raw PCM audio.

    Parameters
    ----------
    fft_size : int
        FFT window size in samples (default 4096).
    hop_size : int
        Hop between successive windows (default fft_size // 4).
    window : str
        Window function — 'hann', 'hamming', 'blackman', 'blackmanharris',
        'kaiser' (β=14), or 'flat'.
    zero_pad_factor : int
        Multiply fft_size by this for frequency resolution boost.
    """

    WINDOWS = {
        "hann":           np.hanning,
        "hamming":        np.hamming,
        "blackman":       np.blackman,
        "flat":           lambda n: np.ones(n),
    }

    def __init__(
        self,
        fft_size: int = 4096,
        hop_size: Optional[int] = None,
        window: str = "blackman",
        zero_pad_factor: int = 1,
        top_peaks: int = 50,
    ):
        self.fft_size = fft_size
        self.hop_size = hop_size or fft_size // 4
        self.window = window
        self.zero_pad_factor = zero_pad_factor
        self.top_peaks = top_peaks

    # ── public API ──────────────────────────────────────────────────

    def analyze(
        self,
        samples: np.ndarray,
        sample_rate: int,
        channel_index: int = 0,
    ) -> AnalysisResult:
        """
        Run full spectral analysis on a mono signal.

        Parameters
        ----------
        samples : np.ndarray
            1-D float64 PCM in [-1, 1].
        sample_rate : int
            Sample rate in Hz.
        channel_index : int
            Which channel this is (for metadata).

        Returns
        -------
        AnalysisResult
        """
        n_samples = len(samples)
        duration = n_samples / sample_rate
        win = self._make_window()
        padded_size = self.fft_size * self.zero_pad_factor

        frames: list[SpectralFrame] = []
        band_timelines = {b: [] for b in BANDS}

        pos = 0
        while pos + self.fft_size <= n_samples:
            segment = samples[pos : pos + self.fft_size] * win

            # optional zero-padding
            if self.zero_pad_factor > 1:
                padded = np.zeros(padded_size)
                padded[: self.fft_size] = segment
                segment = padded

            spectrum = np.fft.rfft(segment)
            freqs = np.fft.rfftfreq(len(segment), 1.0 / sample_rate)
            magnitudes = np.abs(spectrum)
            phase = np.angle(spectrum)

            frame = SpectralFrame(
                time_sec=pos / sample_rate,
                freqs=freqs,
                magnitudes=magnitudes,
                phase=phase,
            )

            # per-band power
            for bname, (lo, hi) in BANDS.items():
                mask = (freqs >= lo) & (freqs < hi)
                if mask.any():
                    power = np.mean(magnitudes[mask] ** 2)
                else:
                    power = 0.0
                frame.band_powers[bname] = power
                band_timelines[bname].append(power)

            frames.append(frame)
            pos += self.hop_size

        # convert timelines to arrays
        band_energy_timeline = {
            b: np.array(v, dtype=np.float64) for b, v in band_timelines.items()
        }

        # global average spectrum
        if frames:
            global_mags = np.mean(
                np.stack([f.magnitudes for f in frames]), axis=0
            )
            global_freqs = frames[0].freqs
        else:
            global_mags = np.array([])
            global_freqs = np.array([])

        # peak detection
        peaks = self._find_peaks(global_freqs, global_mags)

        # noise floor / dynamic range
        mag_db = 20 * np.log10(global_mags + 1e-12)
        noise_floor = float(np.percentile(mag_db, 5))
        dynamic_range = float(np.max(mag_db) - noise_floor)

        return AnalysisResult(
            sample_rate=sample_rate,
            duration_sec=duration,
            n_channels=1,
            frames=frames,
            global_spectrum=global_mags,
            global_freqs=global_freqs,
            band_energy_timeline=band_energy_timeline,
            peak_frequencies=peaks,
            noise_floor_db=noise_floor,
            dynamic_range_db=dynamic_range,
            metadata={"channel": channel_index},
        )

    def analyze_multichannel(
        self,
        channels: list[np.ndarray],
        sample_rate: int,
    ) -> list[AnalysisResult]:
        """Analyze each channel independently."""
        return [
            self.analyze(ch, sample_rate, channel_index=i)
            for i, ch in enumerate(channels)
        ]

    # ── band helpers ────────────────────────────────────────────────

    @staticmethod
    def subliminal_energy(result: AnalysisResult) -> dict:
        """
        Return per-subliminal-band energy as fraction of total.
        Useful for quick triage — if subliminal bands carry > 0.1%
        of total energy, something is embedded.
        """
        total = sum(
            np.sum(result.band_energy_timeline[b])
            for b in BANDS
        )
        if total == 0:
            return {b: 0.0 for b in SUBLIMINAL_BANDS}

        return {
            b: float(np.sum(result.band_energy_timeline[b]) / total)
            for b in SUBLIMINAL_BANDS
        }

    @staticmethod
    def band_energy_over_time(
        result: AnalysisResult,
        band: str,
    ) -> tuple[np.ndarray, np.ndarray]:
        """
        Return (time_axis, energy_array) for a specific band.
        """
        if band not in result.band_energy_timeline:
            raise ValueError(f"Unknown band: {band}")
        n_frames = len(result.band_energy_timeline[band])
        hop_sec = result.duration_sec / max(n_frames, 1)
        times = np.arange(n_frames) * hop_sec
        return times, result.band_energy_timeline[band]

    # ── internals ───────────────────────────────────────────────────

    def _make_window(self) -> np.ndarray:
        if self.window == "blackmanharris":
            return self._blackman_harris(self.fft_size)
        elif self.window == "kaiser":
            return np.kaiser(self.fft_size, 14)
        fn = self.WINDOWS.get(self.window)
        if fn is None:
            raise ValueError(f"Unknown window: {self.window}")
        return fn(self.fft_size)

    @staticmethod
    def _blackman_harris(n: int) -> np.ndarray:
        a0, a1, a2, a3 = 0.35875, 0.48829, 0.14128, 0.01168
        t = np.arange(n) / n
        return a0 - a1 * np.cos(2 * np.pi * t) + \
               a2 * np.cos(4 * np.pi * t) - \
               a3 * np.cos(6 * np.pi * t)

    def _find_peaks(
        self,
        freqs: np.ndarray,
        magnitudes: np.ndarray,
    ) -> list[tuple[float, float]]:
        """Return top-N (freq_hz, magnitude_db) peaks."""
        if len(magnitudes) < 3:
            return []

        mag_db = 20 * np.log10(magnitudes + 1e-12)

        # simple local-max detection
        peaks = []
        for i in range(1, len(mag_db) - 1):
            if mag_db[i] > mag_db[i - 1] and mag_db[i] > mag_db[i + 1]:
                peaks.append((float(freqs[i]), float(mag_db[i])))

        peaks.sort(key=lambda p: p[1], reverse=True)
        return peaks[: self.top_peaks]
