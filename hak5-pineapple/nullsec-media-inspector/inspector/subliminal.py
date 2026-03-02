"""
Subliminal Frequency Detector — nullsec-media-inspector
========================================================
Identifies audio content in frequency ranges below and above
the nominal human hearing threshold (20 Hz – 18 kHz).

Detection classes
-----------------
1. **Infrasonic** (< 20 Hz)  — low-frequency content that can cause
   physiological effects (anxiety, disorientation) without conscious
   perception.

2. **Near-threshold** (16–20 Hz and 17–18 kHz) — perceptible by some
   listeners but commonly used as a carrier because most people
   cannot hear it.

3. **Ultrasonic** (> 18 kHz) — inaudible content that may encode
   data (audio watermarks, tracking beacons like SilverPush / Xtify),
   or mask embedded signals.

4. **Psychoacoustic masking abuse** — tonal content hidden just below
   a louder neighboring tone, exploiting simultaneous masking so the
   human ear ignores it but a decoder can extract it.

Each detector returns time-stamped events with severity, frequency
span, estimated SNR, and a confidence score.
"""

import numpy as np
from dataclasses import dataclass, field
from typing import Optional

from .analyzer import (
    AnalysisResult,
    SpectralAnalyzer,
    BANDS,
    SUBLIMINAL_BANDS,
)


# ── thresholds (tunable) ───────────────────────────────────────────
DEFAULT_THRESHOLDS = {
    # minimum dB above noise floor to flag
    "infrasonic_min_db":        6.0,
    "ultrasonic_min_db":        6.0,
    "near_threshold_min_db":    3.0,
    # masking: hidden tone must be within this dB of masker
    "masking_proximity_db":     12.0,
    # minimum duration (seconds) for a subliminal event to be flagged
    "min_event_duration_sec":   0.05,
    # energy ratio: subliminal band power / total power
    "energy_ratio_alert":       0.001,   # 0.1 %
    "energy_ratio_warning":     0.0001,  # 0.01 %
    # beacon detection: if ultrasonic tone is within ±5 Hz for > 0.5 s
    "beacon_freq_tolerance_hz": 5.0,
    "beacon_min_duration_sec":  0.5,
}


@dataclass
class SubliminalEvent:
    """One detected subliminal occurrence."""
    event_type: str          # infrasonic | ultrasonic | near_threshold | masked | beacon
    severity: str            # critical | high | medium | low | info
    start_sec: float
    end_sec: float
    freq_lo_hz: float
    freq_hi_hz: float
    peak_freq_hz: float
    peak_db: float
    snr_db: float
    confidence: float        # 0.0 – 1.0
    description: str
    metadata: dict = field(default_factory=dict)


@dataclass
class SubliminalReport:
    """Aggregated subliminal findings for one audio channel."""
    channel: int
    events: list             # list[SubliminalEvent]
    infrasonic_energy_ratio: float
    ultrasonic_energy_ratio: float
    total_subliminal_duration_sec: float
    beacon_candidates: list  # list[dict]
    risk_score: float        # 0 – 100
    summary: str


class SubliminalDetector:
    """
    Multi-pass subliminal content detector.

    Usage
    -----
    >>> analyzer = SpectralAnalyzer(fft_size=8192)
    >>> result  = analyzer.analyze(samples, sr)
    >>> detector = SubliminalDetector()
    >>> report  = detector.detect(result)
    """

    def __init__(self, thresholds: Optional[dict] = None):
        self.th = {**DEFAULT_THRESHOLDS, **(thresholds or {})}

    # ── main entry ──────────────────────────────────────────────────

    def detect(self, analysis: AnalysisResult) -> SubliminalReport:
        events: list[SubliminalEvent] = []
        noise_floor = analysis.noise_floor_db

        # pass 1 — infrasonic
        events.extend(self._scan_band(
            analysis, "infrasonic", 0.1, 20,
            self.th["infrasonic_min_db"], noise_floor,
            "infrasonic",
        ))

        # pass 2 — near-threshold low
        events.extend(self._scan_band(
            analysis, "near_threshold_low", 16, 20,
            self.th["near_threshold_min_db"], noise_floor,
            "near_threshold",
        ))

        # pass 3 — near-threshold high
        events.extend(self._scan_band(
            analysis, "near_threshold_high", 17000, 18000,
            self.th["near_threshold_min_db"], noise_floor,
            "near_threshold",
        ))

        # pass 4 — ultrasonic
        events.extend(self._scan_band(
            analysis, "ultrasonic", 18000, analysis.sample_rate / 2,
            self.th["ultrasonic_min_db"], noise_floor,
            "ultrasonic",
        ))

        # pass 5 — psychoacoustic masking
        events.extend(self._detect_masked_tones(analysis, noise_floor))

        # pass 6 — ultrasonic beacons (constant-frequency carriers)
        beacons = self._detect_beacons(analysis, noise_floor)
        for b in beacons:
            events.append(SubliminalEvent(
                event_type="beacon",
                severity="critical",
                start_sec=b["start_sec"],
                end_sec=b["end_sec"],
                freq_lo_hz=b["freq_hz"] - self.th["beacon_freq_tolerance_hz"],
                freq_hi_hz=b["freq_hz"] + self.th["beacon_freq_tolerance_hz"],
                peak_freq_hz=b["freq_hz"],
                peak_db=b["peak_db"],
                snr_db=b["peak_db"] - noise_floor,
                confidence=b["confidence"],
                description=(
                    f"Ultrasonic beacon at {b['freq_hz']:.1f} Hz sustained "
                    f"for {b['end_sec'] - b['start_sec']:.2f}s — "
                    f"possible tracking / data carrier"
                ),
                metadata=b,
            ))

        # energy ratios
        sub_energy = SpectralAnalyzer.subliminal_energy(analysis)
        infra_ratio = sub_energy.get("infrasonic", 0.0)
        ultra_ratio = (
            sub_energy.get("ultrasonic", 0.0)
            + sub_energy.get("deep_ultrasonic", 0.0)
            + sub_energy.get("near_ultrasonic", 0.0)
        )

        # total subliminal time
        total_sub_time = self._merge_event_duration(events)

        # risk score
        risk = self._compute_risk(events, infra_ratio, ultra_ratio, total_sub_time)

        return SubliminalReport(
            channel=analysis.metadata.get("channel", 0),
            events=events,
            infrasonic_energy_ratio=infra_ratio,
            ultrasonic_energy_ratio=ultra_ratio,
            total_subliminal_duration_sec=total_sub_time,
            beacon_candidates=beacons,
            risk_score=risk,
            summary=self._make_summary(events, risk, infra_ratio, ultra_ratio),
        )

    # ── band scanning ───────────────────────────────────────────────

    def _scan_band(
        self,
        analysis: AnalysisResult,
        label: str,
        lo_hz: float,
        hi_hz: float,
        min_db_above_noise: float,
        noise_floor: float,
        event_type: str,
    ) -> list[SubliminalEvent]:
        """
        Walk every STFT frame, look for energy in [lo_hz, hi_hz]
        that exceeds noise_floor + min_db_above_noise.  Merge
        adjacent frames into contiguous events.
        """
        events: list[SubliminalEvent] = []
        in_event = False
        ev_start = 0.0
        ev_peak_db = -np.inf
        ev_peak_freq = 0.0
        ev_freq_lo = hi_hz
        ev_freq_hi = lo_hz

        for frame in analysis.frames:
            mask = (frame.freqs >= lo_hz) & (frame.freqs < hi_hz)
            if not mask.any():
                if in_event:
                    events.append(self._close_event(
                        event_type, ev_start, frame.time_sec,
                        ev_freq_lo, ev_freq_hi, ev_peak_freq,
                        ev_peak_db, noise_floor, label,
                    ))
                    in_event = False
                continue

            mags_db = 20 * np.log10(frame.magnitudes[mask] + 1e-12)
            max_db = float(np.max(mags_db))
            max_idx = int(np.argmax(mags_db))
            max_freq = float(frame.freqs[mask][max_idx])

            if max_db > noise_floor + min_db_above_noise:
                if not in_event:
                    in_event = True
                    ev_start = frame.time_sec
                    ev_peak_db = max_db
                    ev_peak_freq = max_freq
                    ev_freq_lo = lo_hz
                    ev_freq_hi = hi_hz
                else:
                    if max_db > ev_peak_db:
                        ev_peak_db = max_db
                        ev_peak_freq = max_freq
            else:
                if in_event:
                    events.append(self._close_event(
                        event_type, ev_start, frame.time_sec,
                        ev_freq_lo, ev_freq_hi, ev_peak_freq,
                        ev_peak_db, noise_floor, label,
                    ))
                    in_event = False

        # flush trailing event
        if in_event and analysis.frames:
            events.append(self._close_event(
                event_type, ev_start, analysis.duration_sec,
                ev_freq_lo, ev_freq_hi, ev_peak_freq,
                ev_peak_db, noise_floor, label,
            ))

        # filter by min duration
        min_dur = self.th["min_event_duration_sec"]
        return [e for e in events if (e.end_sec - e.start_sec) >= min_dur]

    def _close_event(
        self, etype, start, end, flo, fhi, peak_f, peak_db, noise, label,
    ) -> SubliminalEvent:
        snr = peak_db - noise
        conf = min(1.0, snr / 30.0)
        sev = self._severity_from_snr(snr, etype)
        return SubliminalEvent(
            event_type=etype,
            severity=sev,
            start_sec=start,
            end_sec=end,
            freq_lo_hz=flo,
            freq_hi_hz=fhi,
            peak_freq_hz=peak_f,
            peak_db=peak_db,
            snr_db=snr,
            confidence=conf,
            description=f"{label} content detected: {peak_f:.1f} Hz @ {peak_db:.1f} dB (SNR {snr:.1f} dB)",
        )

    # ── psychoacoustic masking detection ────────────────────────────

    def _detect_masked_tones(
        self,
        analysis: AnalysisResult,
        noise_floor: float,
    ) -> list[SubliminalEvent]:
        """
        Look for tones hiding in the masking skirt of a louder tone.
        Simultaneous masking: a tone at frequency f masks nearby
        tones within a critical band, up to ~masking_proximity_db below.
        If we find a secondary peak within the masking threshold of a
        dominant peak, and the secondary peak is in a subliminal-relevant
        range, flag it.
        """
        events = []
        proximity = self.th["masking_proximity_db"]

        for frame in analysis.frames:
            mag_db = 20 * np.log10(frame.magnitudes + 1e-12)

            # find all local maxima
            peaks_idx = []
            for i in range(1, len(mag_db) - 1):
                if mag_db[i] > mag_db[i - 1] and mag_db[i] > mag_db[i + 1]:
                    if mag_db[i] > noise_floor + 3:
                        peaks_idx.append(i)

            if len(peaks_idx) < 2:
                continue

            # sort by magnitude
            peaks_idx.sort(key=lambda i: mag_db[i], reverse=True)

            # for each dominant peak, check if any weaker peak within critical band
            for d in range(min(5, len(peaks_idx))):
                dom_i = peaks_idx[d]
                dom_freq = frame.freqs[dom_i]
                dom_db = mag_db[dom_i]

                # critical bandwidth approximation (ERB)
                cb = 24.7 * (4.37 * dom_freq / 1000 + 1)

                for s in range(d + 1, len(peaks_idx)):
                    sec_i = peaks_idx[s]
                    sec_freq = frame.freqs[sec_i]
                    sec_db = mag_db[sec_i]

                    if abs(sec_freq - dom_freq) > cb * 2:
                        continue  # too far away

                    # is the secondary tone masked?
                    if dom_db - sec_db < proximity:
                        continue  # not masked, it's audible

                    # is it in a subliminal-adjacent range or suspiciously precise?
                    if sec_freq < 20 or sec_freq > 17000 or (
                        abs(sec_freq - round(sec_freq)) < 0.5  # suspiciously round freq
                    ):
                        events.append(SubliminalEvent(
                            event_type="masked",
                            severity="high",
                            start_sec=frame.time_sec,
                            end_sec=frame.time_sec + (analysis.duration_sec / max(len(analysis.frames), 1)),
                            freq_lo_hz=sec_freq - 5,
                            freq_hi_hz=sec_freq + 5,
                            peak_freq_hz=sec_freq,
                            peak_db=sec_db,
                            snr_db=sec_db - noise_floor,
                            confidence=min(1.0, (dom_db - sec_db) / proximity),
                            description=(
                                f"Masked tone at {sec_freq:.1f} Hz hidden by "
                                f"{dom_freq:.1f} Hz masker (Δ{dom_db - sec_db:.1f} dB)"
                            ),
                            metadata={
                                "masker_freq": dom_freq,
                                "masker_db": dom_db,
                                "delta_db": dom_db - sec_db,
                            },
                        ))

        return events

    # ── ultrasonic beacon detection ─────────────────────────────────

    def _detect_beacons(
        self,
        analysis: AnalysisResult,
        noise_floor: float,
    ) -> list[dict]:
        """
        Detect sustained ultrasonic tones (>18 kHz) that persist
        across multiple frames at nearly the same frequency.
        These are characteristic of audio tracking beacons
        (SilverPush, Xtify, Lisnr-style).
        """
        tol = self.th["beacon_freq_tolerance_hz"]
        min_dur = self.th["beacon_min_duration_sec"]
        min_db = noise_floor + self.th["ultrasonic_min_db"]

        # extract dominant ultrasonic freq per frame
        frame_tones = []
        for frame in analysis.frames:
            mask = frame.freqs >= 18000
            if not mask.any():
                frame_tones.append(None)
                continue
            mags_db = 20 * np.log10(frame.magnitudes[mask] + 1e-12)
            max_db = float(np.max(mags_db))
            if max_db < min_db:
                frame_tones.append(None)
                continue
            max_idx = int(np.argmax(mags_db))
            frame_tones.append({
                "freq": float(frame.freqs[mask][max_idx]),
                "db": max_db,
                "time": frame.time_sec,
            })

        # merge contiguous frames with same freq (within tolerance)
        beacons = []
        run = []
        for ft in frame_tones:
            if ft is None:
                if run:
                    beacons.append(self._finalize_beacon_run(run, min_dur))
                    run = []
                continue
            if run and abs(ft["freq"] - run[-1]["freq"]) > tol:
                beacons.append(self._finalize_beacon_run(run, min_dur))
                run = []
            run.append(ft)

        if run:
            beacons.append(self._finalize_beacon_run(run, min_dur))

        return [b for b in beacons if b is not None]

    @staticmethod
    def _finalize_beacon_run(run: list[dict], min_dur: float) -> Optional[dict]:
        if not run:
            return None
        dur = run[-1]["time"] - run[0]["time"]
        if dur < min_dur:
            return None
        freqs = [r["freq"] for r in run]
        dbs = [r["db"] for r in run]
        return {
            "freq_hz": float(np.median(freqs)),
            "freq_spread_hz": float(np.max(freqs) - np.min(freqs)),
            "peak_db": float(np.max(dbs)),
            "mean_db": float(np.mean(dbs)),
            "start_sec": run[0]["time"],
            "end_sec": run[-1]["time"],
            "duration_sec": dur,
            "n_frames": len(run),
            "confidence": min(1.0, dur / 2.0),  # longer → higher confidence
        }

    # ── helpers ─────────────────────────────────────────────────────

    @staticmethod
    def _severity_from_snr(snr: float, event_type: str) -> str:
        if event_type == "beacon":
            return "critical"
        if snr > 20:
            return "critical" if event_type in ("ultrasonic", "infrasonic") else "high"
        if snr > 12:
            return "high"
        if snr > 6:
            return "medium"
        return "low"

    @staticmethod
    def _merge_event_duration(events: list[SubliminalEvent]) -> float:
        """Total unique seconds covered by all events (merging overlaps)."""
        if not events:
            return 0.0
        intervals = sorted([(e.start_sec, e.end_sec) for e in events])
        merged = [intervals[0]]
        for start, end in intervals[1:]:
            if start <= merged[-1][1]:
                merged[-1] = (merged[-1][0], max(merged[-1][1], end))
            else:
                merged.append((start, end))
        return sum(e - s for s, e in merged)

    def _compute_risk(
        self,
        events: list[SubliminalEvent],
        infra_ratio: float,
        ultra_ratio: float,
        sub_duration: float,
    ) -> float:
        """0-100 risk score."""
        score = 0.0
        severity_weights = {
            "critical": 25,
            "high": 15,
            "medium": 8,
            "low": 3,
            "info": 1,
        }
        for e in events:
            score += severity_weights.get(e.severity, 1)
        # energy ratio bonus
        if infra_ratio > self.th["energy_ratio_alert"]:
            score += 20
        elif infra_ratio > self.th["energy_ratio_warning"]:
            score += 10
        if ultra_ratio > self.th["energy_ratio_alert"]:
            score += 20
        elif ultra_ratio > self.th["energy_ratio_warning"]:
            score += 10
        # duration bonus
        score += min(20, sub_duration * 2)
        return min(100.0, score)

    @staticmethod
    def _make_summary(
        events: list[SubliminalEvent],
        risk: float,
        infra_ratio: float,
        ultra_ratio: float,
    ) -> str:
        n_crit = sum(1 for e in events if e.severity == "critical")
        n_high = sum(1 for e in events if e.severity == "high")
        n_med  = sum(1 for e in events if e.severity == "medium")
        beacons = sum(1 for e in events if e.event_type == "beacon")

        lines = [f"Risk Score: {risk:.0f}/100"]
        if beacons:
            lines.append(f"⚠️  {beacons} ultrasonic beacon(s) detected")
        lines.append(
            f"Events: {n_crit} critical, {n_high} high, {n_med} medium "
            f"({len(events)} total)"
        )
        lines.append(f"Infrasonic energy ratio: {infra_ratio * 100:.4f}%")
        lines.append(f"Ultrasonic energy ratio: {ultra_ratio * 100:.4f}%")
        return "\n".join(lines)
