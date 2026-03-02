"""
Variable Frequency Layer (VFL) Detector — nullsec-media-inspector
==================================================================
Identifies non-stationary frequency patterns that indicate
intentionally embedded, shifting signal layers within media.

Detection modes
---------------
1. **Frequency Hopping** — discrete jumps between carrier frequencies
   across frames, characteristic of FHSS-style data encoding or
   covert communication channels.

2. **Chirp / Sweep** — linear or logarithmic frequency sweeps
   (ascending or descending) that may encode data in the slope
   and duration.

3. **Spread Spectrum** — energy spread across a wide band in a
   pseudo-random pattern, detectable via auto-correlation and
   entropy analysis.

4. **Modulated Carriers** — AM / FM / PSK modulation on a carrier
   above 15 kHz, used for embedded data links.

5. **Temporal Pulsing** — on/off keying of subliminal tones with
   rhythmic or encoded timing patterns.

6. **Spectral Anomalies** — sudden narrowband energy spikes that
   do not correlate with the dominant audio content.

Each detector produces VFLEvent objects that are merged into a
VFLReport with layer classification and confidence scoring.
"""

import numpy as np
from dataclasses import dataclass, field
from typing import Optional

from .analyzer import AnalysisResult


# ── configuration ───────────────────────────────────────────────────
VFL_DEFAULTS = {
    # frequency hopping
    "hop_min_jump_hz":       100,     # minimum hop distance
    "hop_max_dwell_frames":  20,      # max frames on one freq before it's "stationary"
    "hop_min_events":        3,       # minimum hops to declare a pattern
    "hop_freq_floor_hz":     500,     # ignore hops below this
    # chirp detection
    "chirp_min_sweep_hz":    200,     # minimum sweep bandwidth
    "chirp_min_duration_sec": 0.05,
    "chirp_max_duration_sec": 5.0,
    "chirp_linearity_r2":    0.85,   # min R² for linear fit
    # spread spectrum
    "spread_min_bandwidth_hz":  2000,
    "spread_entropy_threshold": 0.75,  # normalized spectral entropy
    "spread_min_duration_sec":  0.2,
    # modulated carrier
    "carrier_min_freq_hz":     15000,
    "carrier_am_depth_min":    0.1,
    "carrier_fm_deviation_min": 50,
    # temporal pulsing
    "pulse_min_events":        4,
    "pulse_regularity_threshold": 0.3,  # CoV of inter-pulse intervals
    # general
    "noise_floor_margin_db":   6.0,
    "anomaly_zscore":          3.5,
}


@dataclass
class VFLEvent:
    """Single variable-frequency-layer event."""
    layer_type: str      # hop | chirp | spread | carrier_am | carrier_fm | carrier_psk | pulse | anomaly
    severity: str
    start_sec: float
    end_sec: float
    freq_lo_hz: float
    freq_hi_hz: float
    characteristics: dict   # type-specific metrics
    confidence: float       # 0.0 – 1.0
    description: str
    metadata: dict = field(default_factory=dict)


@dataclass
class VFLReport:
    """Aggregated VFL findings."""
    channel: int
    events: list           # list[VFLEvent]
    layers_detected: int
    dominant_layer_type: Optional[str]
    spectral_entropy_mean: float
    risk_score: float
    summary: str


class VFLDetector:
    """
    Multi-pass Variable Frequency Layer detector.

    Usage
    -----
    >>> from inspector.analyzer import SpectralAnalyzer
    >>> analyzer = SpectralAnalyzer(fft_size=8192)
    >>> result  = analyzer.analyze(samples, sr)
    >>> vfl = VFLDetector()
    >>> report = vfl.detect(result)
    """

    def __init__(self, config: Optional[dict] = None):
        self.cfg = {**VFL_DEFAULTS, **(config or {})}

    # ── main entry ──────────────────────────────────────────────────

    def detect(self, analysis: AnalysisResult) -> VFLReport:
        events: list[VFLEvent] = []
        noise_floor = analysis.noise_floor_db
        margin = self.cfg["noise_floor_margin_db"]

        # extract per-frame dominant-frequency tracks
        tracks = self._extract_frequency_tracks(analysis, noise_floor + margin)

        # pass 1 — frequency hopping
        events.extend(self._detect_frequency_hopping(tracks, analysis))

        # pass 2 — chirp / sweep
        events.extend(self._detect_chirps(tracks, analysis))

        # pass 3 — spread spectrum
        events.extend(self._detect_spread_spectrum(analysis, noise_floor))

        # pass 4 — modulated carriers
        events.extend(self._detect_modulated_carriers(analysis, noise_floor))

        # pass 5 — temporal pulsing
        events.extend(self._detect_temporal_pulsing(analysis, noise_floor))

        # pass 6 — spectral anomalies
        events.extend(self._detect_spectral_anomalies(analysis, noise_floor))

        # global spectral entropy
        entropy = self._mean_spectral_entropy(analysis)

        # classify layers
        layer_types = set(e.layer_type for e in events)
        dominant = None
        if layer_types:
            type_counts = {}
            for e in events:
                type_counts[e.layer_type] = type_counts.get(e.layer_type, 0) + 1
            dominant = max(type_counts, key=type_counts.get)

        risk = self._compute_risk(events, entropy)

        return VFLReport(
            channel=analysis.metadata.get("channel", 0),
            events=events,
            layers_detected=len(layer_types),
            dominant_layer_type=dominant,
            spectral_entropy_mean=entropy,
            risk_score=risk,
            summary=self._make_summary(events, layer_types, entropy, risk),
        )

    # ── frequency track extraction ──────────────────────────────────

    def _extract_frequency_tracks(
        self,
        analysis: AnalysisResult,
        min_db: float,
        n_tracks: int = 5,
    ) -> list[list[dict]]:
        """
        For each STFT frame, extract the top-N frequency peaks
        above min_db.  Returns a list of N tracks, each being a
        list of {time, freq, db} dicts (or None for silent frames).
        """
        tracks = [[] for _ in range(n_tracks)]

        for frame in analysis.frames:
            mag_db = 20 * np.log10(frame.magnitudes + 1e-12)
            # find local maxima
            peak_indices = []
            for i in range(1, len(mag_db) - 1):
                if mag_db[i] > mag_db[i - 1] and mag_db[i] > mag_db[i + 1]:
                    if mag_db[i] > min_db:
                        peak_indices.append(i)

            peak_indices.sort(key=lambda i: mag_db[i], reverse=True)
            peak_indices = peak_indices[:n_tracks]

            for t in range(n_tracks):
                if t < len(peak_indices):
                    idx = peak_indices[t]
                    tracks[t].append({
                        "time": frame.time_sec,
                        "freq": float(frame.freqs[idx]),
                        "db": float(mag_db[idx]),
                    })
                else:
                    tracks[t].append(None)

        return tracks

    # ── pass 1: frequency hopping ───────────────────────────────────

    def _detect_frequency_hopping(
        self,
        tracks: list[list[dict]],
        analysis: AnalysisResult,
    ) -> list[VFLEvent]:
        """
        Look for tracks that jump between discrete frequencies —
        signature of FHSS or covert data encoding.
        """
        events = []
        min_jump = self.cfg["hop_min_jump_hz"]
        max_dwell = self.cfg["hop_max_dwell_frames"]
        min_events = self.cfg["hop_min_events"]
        freq_floor = self.cfg["hop_freq_floor_hz"]

        for track in tracks:
            valid = [p for p in track if p is not None and p["freq"] >= freq_floor]
            if len(valid) < min_events * 2:
                continue

            # detect jumps
            hops = []
            dwell_count = 0
            prev_freq = valid[0]["freq"]

            for i in range(1, len(valid)):
                delta = abs(valid[i]["freq"] - prev_freq)
                if delta >= min_jump:
                    hops.append({
                        "from_freq": prev_freq,
                        "to_freq": valid[i]["freq"],
                        "time": valid[i]["time"],
                        "dwell_frames": dwell_count,
                        "jump_hz": delta,
                    })
                    dwell_count = 0
                    prev_freq = valid[i]["freq"]
                else:
                    dwell_count += 1
                    if dwell_count > max_dwell:
                        prev_freq = valid[i]["freq"]
                        dwell_count = 0

            if len(hops) >= min_events:
                all_freqs = [h["from_freq"] for h in hops] + [hops[-1]["to_freq"]]
                jump_sizes = [h["jump_hz"] for h in hops]
                hop_rate = len(hops) / max(valid[-1]["time"] - valid[0]["time"], 0.001)

                # regularity check — is the hop rate consistent?
                if len(jump_sizes) > 2:
                    cov = float(np.std(jump_sizes) / (np.mean(jump_sizes) + 1e-12))
                else:
                    cov = 1.0

                confidence = min(1.0, len(hops) / 20.0) * (1.0 - min(0.8, cov))

                events.append(VFLEvent(
                    layer_type="hop",
                    severity="critical" if confidence > 0.7 else "high",
                    start_sec=hops[0]["time"],
                    end_sec=hops[-1]["time"],
                    freq_lo_hz=min(all_freqs),
                    freq_hi_hz=max(all_freqs),
                    characteristics={
                        "n_hops": len(hops),
                        "hop_rate_per_sec": hop_rate,
                        "mean_jump_hz": float(np.mean(jump_sizes)),
                        "jump_regularity_cov": cov,
                        "unique_frequencies": len(set(int(f) for f in all_freqs)),
                        "frequencies": sorted(set(round(f, 1) for f in all_freqs)),
                    },
                    confidence=confidence,
                    description=(
                        f"Frequency hopping: {len(hops)} hops across "
                        f"{min(all_freqs):.0f}–{max(all_freqs):.0f} Hz "
                        f"at {hop_rate:.1f} hops/sec"
                    ),
                ))

        return events

    # ── pass 2: chirp / sweep detection ─────────────────────────────

    def _detect_chirps(
        self,
        tracks: list[list[dict]],
        analysis: AnalysisResult,
    ) -> list[VFLEvent]:
        """
        Detect linear/log frequency sweeps by fitting a linear
        regression to frequency-vs-time in sliding windows.
        """
        events = []
        min_sweep = self.cfg["chirp_min_sweep_hz"]
        min_dur = self.cfg["chirp_min_duration_sec"]
        max_dur = self.cfg["chirp_max_duration_sec"]
        min_r2 = self.cfg["chirp_linearity_r2"]

        for track in tracks:
            valid = [(i, p) for i, p in enumerate(track) if p is not None]
            if len(valid) < 4:
                continue

            times = np.array([p["time"] for _, p in valid])
            freqs = np.array([p["freq"] for _, p in valid])

            # sliding window chirp detection
            win_sizes = [8, 16, 32, 64]
            for ws in win_sizes:
                if len(valid) < ws:
                    continue
                for start in range(0, len(valid) - ws + 1, ws // 2):
                    end = start + ws
                    t_win = times[start:end]
                    f_win = freqs[start:end]
                    dur = t_win[-1] - t_win[0]

                    if dur < min_dur or dur > max_dur:
                        continue

                    sweep = f_win[-1] - f_win[0]
                    if abs(sweep) < min_sweep:
                        continue

                    # linear regression
                    r2 = self._linear_r2(t_win, f_win)
                    if r2 < min_r2:
                        continue

                    direction = "ascending" if sweep > 0 else "descending"
                    rate = sweep / dur

                    events.append(VFLEvent(
                        layer_type="chirp",
                        severity="high",
                        start_sec=float(t_win[0]),
                        end_sec=float(t_win[-1]),
                        freq_lo_hz=float(min(f_win)),
                        freq_hi_hz=float(max(f_win)),
                        characteristics={
                            "direction": direction,
                            "sweep_hz": float(abs(sweep)),
                            "rate_hz_per_sec": float(rate),
                            "r_squared": float(r2),
                            "duration_sec": float(dur),
                        },
                        confidence=float(r2),
                        description=(
                            f"{direction.title()} chirp: {abs(sweep):.0f} Hz sweep "
                            f"over {dur:.2f}s (R²={r2:.3f}, rate={abs(rate):.0f} Hz/s)"
                        ),
                    ))

        # deduplicate overlapping chirps — keep highest R²
        return self._deduplicate_events(events)

    # ── pass 3: spread spectrum detection ───────────────────────────

    def _detect_spread_spectrum(
        self,
        analysis: AnalysisResult,
        noise_floor: float,
    ) -> list[VFLEvent]:
        """
        Detect DSSS-like patterns: energy spread across a wide
        bandwidth with high spectral entropy and low peak-to-average
        ratio (flat but elevated).
        """
        events = []
        min_bw = self.cfg["spread_min_bandwidth_hz"]
        ent_thresh = self.cfg["spread_entropy_threshold"]
        min_dur = self.cfg["spread_min_duration_sec"]
        margin = self.cfg["noise_floor_margin_db"]

        in_spread = False
        spread_start = 0.0
        spread_bws = []
        spread_ents = []

        for frame in analysis.frames:
            mag_db = 20 * np.log10(frame.magnitudes + 1e-12)
            above_noise = mag_db > (noise_floor + margin)

            if not above_noise.any():
                if in_spread:
                    events.extend(self._close_spread(
                        spread_start, frame.time_sec, spread_bws, spread_ents,
                        min_dur, min_bw, ent_thresh,
                    ))
                    in_spread = False
                continue

            # spectral entropy of above-noise region
            active_mags = frame.magnitudes[above_noise]
            active_freqs = frame.freqs[above_noise]
            entropy = self._spectral_entropy(active_mags)

            # bandwidth of active region
            bw = float(active_freqs[-1] - active_freqs[0]) if len(active_freqs) > 1 else 0

            # peak-to-average ratio
            par = float(np.max(active_mags) / (np.mean(active_mags) + 1e-12))

            if entropy > ent_thresh and bw > min_bw and par < 10:
                if not in_spread:
                    in_spread = True
                    spread_start = frame.time_sec
                    spread_bws = []
                    spread_ents = []
                spread_bws.append(bw)
                spread_ents.append(entropy)
            else:
                if in_spread:
                    events.extend(self._close_spread(
                        spread_start, frame.time_sec, spread_bws, spread_ents,
                        min_dur, min_bw, ent_thresh,
                    ))
                    in_spread = False

        if in_spread and analysis.frames:
            events.extend(self._close_spread(
                spread_start, analysis.duration_sec, spread_bws, spread_ents,
                min_dur, min_bw, ent_thresh,
            ))

        return events

    def _close_spread(
        self, start, end, bws, ents, min_dur, min_bw, ent_thresh,
    ) -> list[VFLEvent]:
        dur = end - start
        if dur < min_dur or not bws:
            return []
        mean_bw = float(np.mean(bws))
        mean_ent = float(np.mean(ents))
        if mean_bw < min_bw or mean_ent < ent_thresh:
            return []

        confidence = min(1.0, (mean_ent - ent_thresh) / 0.25 * dur / 2.0)
        return [VFLEvent(
            layer_type="spread",
            severity="critical" if confidence > 0.6 else "high",
            start_sec=start,
            end_sec=end,
            freq_lo_hz=0,
            freq_hi_hz=mean_bw,
            characteristics={
                "mean_bandwidth_hz": mean_bw,
                "mean_entropy": mean_ent,
                "duration_sec": dur,
            },
            confidence=confidence,
            description=(
                f"Spread-spectrum pattern: {mean_bw:.0f} Hz bandwidth, "
                f"entropy={mean_ent:.3f} over {dur:.2f}s"
            ),
        )]

    # ── pass 4: modulated carrier detection ─────────────────────────

    def _detect_modulated_carriers(
        self,
        analysis: AnalysisResult,
        noise_floor: float,
    ) -> list[VFLEvent]:
        """
        Look for AM/FM modulation on high-frequency carriers (>15 kHz).
        AM → amplitude envelope variation on a stable carrier.
        FM → frequency deviation around a center carrier.
        """
        events = []
        min_freq = self.cfg["carrier_min_freq_hz"]
        margin = self.cfg["noise_floor_margin_db"]

        # extract carrier amplitude + frequency per frame
        carrier_log = []
        for frame in analysis.frames:
            mask = frame.freqs >= min_freq
            if not mask.any():
                carrier_log.append(None)
                continue
            mag_db = 20 * np.log10(frame.magnitudes[mask] + 1e-12)
            max_idx = int(np.argmax(mag_db))
            if mag_db[max_idx] < noise_floor + margin:
                carrier_log.append(None)
                continue
            carrier_log.append({
                "time": frame.time_sec,
                "freq": float(frame.freqs[mask][max_idx]),
                "amp": float(frame.magnitudes[mask][max_idx]),
                "db": float(mag_db[max_idx]),
            })

        valid = [c for c in carrier_log if c is not None]
        if len(valid) < 8:
            return events

        amps = np.array([c["amp"] for c in valid])
        freqs_c = np.array([c["freq"] for c in valid])
        times_c = np.array([c["time"] for c in valid])

        # AM detection: amplitude modulation depth
        if np.mean(amps) > 0:
            am_depth = float((np.max(amps) - np.min(amps)) / (np.max(amps) + np.min(amps) + 1e-12))
            if am_depth > self.cfg["carrier_am_depth_min"]:
                # estimate modulation frequency via autocorrelation
                norm_amp = amps - np.mean(amps)
                if np.std(norm_amp) > 0:
                    acf = np.correlate(norm_amp, norm_amp, mode="full")
                    acf = acf[len(acf) // 2:]
                    acf /= acf[0] + 1e-12

                    # find first peak after zero crossing
                    mod_freq = self._estimate_mod_freq(acf, times_c)

                    events.append(VFLEvent(
                        layer_type="carrier_am",
                        severity="critical",
                        start_sec=float(times_c[0]),
                        end_sec=float(times_c[-1]),
                        freq_lo_hz=float(np.min(freqs_c)),
                        freq_hi_hz=float(np.max(freqs_c)),
                        characteristics={
                            "carrier_freq_hz": float(np.median(freqs_c)),
                            "am_depth": am_depth,
                            "modulation_freq_hz": mod_freq,
                        },
                        confidence=min(1.0, am_depth * 2),
                        description=(
                            f"AM-modulated carrier at {np.median(freqs_c):.0f} Hz, "
                            f"depth={am_depth:.2f}, mod_freq≈{mod_freq:.1f} Hz"
                        ),
                    ))

        # FM detection: frequency deviation
        freq_dev = float(np.std(freqs_c))
        if freq_dev > self.cfg["carrier_fm_deviation_min"]:
            events.append(VFLEvent(
                layer_type="carrier_fm",
                severity="critical",
                start_sec=float(times_c[0]),
                end_sec=float(times_c[-1]),
                freq_lo_hz=float(np.min(freqs_c)),
                freq_hi_hz=float(np.max(freqs_c)),
                characteristics={
                    "center_freq_hz": float(np.mean(freqs_c)),
                    "deviation_hz": freq_dev,
                    "max_deviation_hz": float(np.max(freqs_c) - np.min(freqs_c)),
                },
                confidence=min(1.0, freq_dev / 500),
                description=(
                    f"FM-modulated carrier at {np.mean(freqs_c):.0f} Hz, "
                    f"deviation={freq_dev:.0f} Hz"
                ),
            ))

        return events

    # ── pass 5: temporal pulsing ────────────────────────────────────

    def _detect_temporal_pulsing(
        self,
        analysis: AnalysisResult,
        noise_floor: float,
    ) -> list[VFLEvent]:
        """
        Detect on/off keying of frequency bands — energy that
        appears and disappears rhythmically, potentially encoding
        binary data.
        """
        events = []
        margin = self.cfg["noise_floor_margin_db"]
        min_pulses = self.cfg["pulse_min_events"]
        regularity_thresh = self.cfg["pulse_regularity_threshold"]

        # check subliminal bands for pulsing
        target_bands = {
            "infrasonic": (0.1, 20),
            "near_ultrasonic": (16000, 18000),
            "ultrasonic": (18000, 48000),
        }

        for band_name, (lo, hi) in target_bands.items():
            energy_per_frame = []
            for frame in analysis.frames:
                mask = (frame.freqs >= lo) & (frame.freqs < hi)
                if not mask.any():
                    energy_per_frame.append(0.0)
                    continue
                mag_db = 20 * np.log10(frame.magnitudes[mask] + 1e-12)
                energy_per_frame.append(float(np.max(mag_db)))

            energy = np.array(energy_per_frame)
            threshold = noise_floor + margin

            # find on/off transitions
            is_on = energy > threshold
            transitions = np.diff(is_on.astype(int))
            on_indices = np.where(transitions == 1)[0]
            off_indices = np.where(transitions == -1)[0]

            if len(on_indices) < min_pulses:
                continue

            # measure inter-pulse intervals
            if len(on_indices) > 1:
                hop_sec = analysis.duration_sec / max(len(analysis.frames), 1)
                intervals = np.diff(on_indices) * hop_sec

                if len(intervals) > 1 and np.mean(intervals) > 0:
                    cov = float(np.std(intervals) / np.mean(intervals))
                    mean_interval = float(np.mean(intervals))

                    if cov < regularity_thresh:
                        # highly regular pulsing — likely encoded
                        pulse_freq = 1.0 / mean_interval if mean_interval > 0 else 0

                        events.append(VFLEvent(
                            layer_type="pulse",
                            severity="critical",
                            start_sec=float(on_indices[0] * hop_sec),
                            end_sec=float(on_indices[-1] * hop_sec),
                            freq_lo_hz=lo,
                            freq_hi_hz=hi,
                            characteristics={
                                "band": band_name,
                                "n_pulses": len(on_indices),
                                "mean_interval_sec": mean_interval,
                                "pulse_rate_hz": pulse_freq,
                                "interval_cov": cov,
                                "regularity": "high" if cov < 0.1 else "medium",
                            },
                            confidence=min(1.0, (1 - cov) * len(on_indices) / 10),
                            description=(
                                f"Pulsed {band_name} layer: {len(on_indices)} pulses at "
                                f"{pulse_freq:.2f} Hz (regularity CoV={cov:.3f})"
                            ),
                        ))
                    elif len(on_indices) >= min_pulses * 2:
                        # irregular but frequent — possible data encoding
                        events.append(VFLEvent(
                            layer_type="pulse",
                            severity="high",
                            start_sec=float(on_indices[0] * hop_sec),
                            end_sec=float(on_indices[-1] * hop_sec),
                            freq_lo_hz=lo,
                            freq_hi_hz=hi,
                            characteristics={
                                "band": band_name,
                                "n_pulses": len(on_indices),
                                "mean_interval_sec": mean_interval,
                                "interval_cov": cov,
                                "regularity": "irregular",
                            },
                            confidence=min(0.6, len(on_indices) / 30),
                            description=(
                                f"Irregular {band_name} pulsing: {len(on_indices)} pulses, "
                                f"CoV={cov:.3f} — possible data encoding"
                            ),
                        ))

        return events

    # ── pass 6: spectral anomalies ──────────────────────────────────

    def _detect_spectral_anomalies(
        self,
        analysis: AnalysisResult,
        noise_floor: float,
    ) -> list[VFLEvent]:
        """
        Flag narrowband energy spikes that deviate significantly
        from the local spectral mean — sudden tonal injections
        that don't match the surrounding audio character.
        """
        events = []
        z_thresh = self.cfg["anomaly_zscore"]

        if len(analysis.frames) < 10:
            return events

        # compute per-frame spectral centroid and bandwidth
        centroids = []
        bandwidths = []
        for frame in analysis.frames:
            mag = frame.magnitudes
            total = np.sum(mag) + 1e-12
            centroid = np.sum(frame.freqs * mag) / total
            bw = np.sqrt(np.sum(((frame.freqs - centroid) ** 2) * mag) / total)
            centroids.append(centroid)
            bandwidths.append(bw)

        centroids = np.array(centroids)
        bandwidths = np.array(bandwidths)

        # z-score based anomaly detection on centroid
        mu_c, sigma_c = np.mean(centroids), np.std(centroids) + 1e-12
        mu_b, sigma_b = np.mean(bandwidths), np.std(bandwidths) + 1e-12

        for i, frame in enumerate(analysis.frames):
            z_centroid = abs(centroids[i] - mu_c) / sigma_c
            z_bandwidth = abs(bandwidths[i] - mu_b) / sigma_b

            if z_centroid > z_thresh or z_bandwidth > z_thresh:
                events.append(VFLEvent(
                    layer_type="anomaly",
                    severity="medium" if max(z_centroid, z_bandwidth) < 5 else "high",
                    start_sec=frame.time_sec,
                    end_sec=frame.time_sec + (analysis.duration_sec / max(len(analysis.frames), 1)),
                    freq_lo_hz=float(centroids[i] - bandwidths[i]),
                    freq_hi_hz=float(centroids[i] + bandwidths[i]),
                    characteristics={
                        "centroid_hz": float(centroids[i]),
                        "bandwidth_hz": float(bandwidths[i]),
                        "z_centroid": float(z_centroid),
                        "z_bandwidth": float(z_bandwidth),
                    },
                    confidence=min(1.0, max(z_centroid, z_bandwidth) / 10),
                    description=(
                        f"Spectral anomaly at {frame.time_sec:.3f}s: centroid "
                        f"z={z_centroid:.1f}, bandwidth z={z_bandwidth:.1f}"
                    ),
                ))

        return events

    # ── utility methods ─────────────────────────────────────────────

    @staticmethod
    def _spectral_entropy(magnitudes: np.ndarray) -> float:
        """Normalized Shannon entropy of magnitude spectrum."""
        p = magnitudes / (np.sum(magnitudes) + 1e-12)
        p = p[p > 0]
        entropy = -np.sum(p * np.log2(p))
        max_entropy = np.log2(len(magnitudes)) if len(magnitudes) > 0 else 1
        return float(entropy / (max_entropy + 1e-12))

    @staticmethod
    def _linear_r2(x: np.ndarray, y: np.ndarray) -> float:
        """R² of a linear fit."""
        if len(x) < 2:
            return 0.0
        coeffs = np.polyfit(x, y, 1)
        y_pred = np.polyval(coeffs, x)
        ss_res = np.sum((y - y_pred) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        if ss_tot == 0:
            return 0.0
        return float(1 - ss_res / ss_tot)

    @staticmethod
    def _estimate_mod_freq(acf: np.ndarray, times: np.ndarray) -> float:
        """Estimate modulation frequency from autocorrelation."""
        if len(acf) < 3 or len(times) < 2:
            return 0.0
        dt = np.mean(np.diff(times))
        # find first peak after initial decay
        for i in range(1, len(acf) - 1):
            if acf[i] > acf[i - 1] and acf[i] > acf[i + 1] and acf[i] > 0.1:
                return float(1.0 / (i * dt + 1e-12))
        return 0.0

    @staticmethod
    def _mean_spectral_entropy(analysis: AnalysisResult) -> float:
        if not analysis.frames:
            return 0.0
        entropies = []
        for frame in analysis.frames:
            p = frame.magnitudes / (np.sum(frame.magnitudes) + 1e-12)
            p = p[p > 0]
            ent = -np.sum(p * np.log2(p))
            max_ent = np.log2(len(frame.magnitudes)) if len(frame.magnitudes) > 0 else 1
            entropies.append(ent / (max_ent + 1e-12))
        return float(np.mean(entropies))

    def _deduplicate_events(self, events: list[VFLEvent]) -> list[VFLEvent]:
        """Remove overlapping events of the same type, keeping highest confidence."""
        if not events:
            return events
        events.sort(key=lambda e: (-e.confidence, e.start_sec))
        kept = []
        for ev in events:
            overlap = False
            for k in kept:
                if (k.layer_type == ev.layer_type and
                    k.start_sec < ev.end_sec and
                    ev.start_sec < k.end_sec):
                    overlap = True
                    break
            if not overlap:
                kept.append(ev)
        return kept

    def _compute_risk(self, events: list[VFLEvent], entropy: float) -> float:
        score = 0.0
        weights = {"critical": 25, "high": 15, "medium": 8, "low": 3}
        for e in events:
            score += weights.get(e.severity, 1) * e.confidence
        # high entropy bonus (possible spread spectrum even if no events)
        if entropy > 0.9:
            score += 15
        elif entropy > 0.8:
            score += 8
        return min(100.0, score)

    @staticmethod
    def _make_summary(events, layer_types, entropy, risk) -> str:
        lines = [f"VFL Risk Score: {risk:.0f}/100"]
        lines.append(f"Spectral entropy: {entropy:.3f}")
        if layer_types:
            lines.append(f"Layer types: {', '.join(sorted(layer_types))}")
        sev_counts = {}
        for e in events:
            sev_counts[e.severity] = sev_counts.get(e.severity, 0) + 1
        if sev_counts:
            parts = [f"{v} {k}" for k, v in sorted(sev_counts.items())]
            lines.append(f"Events: {', '.join(parts)} ({len(events)} total)")
        else:
            lines.append("No variable frequency layers detected")
        return "\n".join(lines)
