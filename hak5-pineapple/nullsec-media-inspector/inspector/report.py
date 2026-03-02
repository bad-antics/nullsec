"""
Report Generator — nullsec-media-inspector
============================================
Produces structured JSON and Markdown reports from
subliminal and VFL analysis results.
"""

import json
import os
from datetime import datetime, timezone
from typing import Optional
from dataclasses import asdict

from .analyzer import AnalysisResult, BANDS, SUBLIMINAL_BANDS
from .subliminal import SubliminalReport, SubliminalEvent
from .vfl_detector import VFLReport, VFLEvent


class ReportGenerator:
    """Generate inspection reports in JSON and Markdown formats."""

    def __init__(self, output_dir: str = "output"):
        self.output_dir = output_dir

    # ── JSON report ─────────────────────────────────────────────────

    def generate_json(
        self,
        filepath: str,
        analysis: AnalysisResult,
        subliminal: Optional[SubliminalReport] = None,
        vfl: Optional[VFLReport] = None,
        filename: str = "report.json",
    ) -> str:
        os.makedirs(self.output_dir, exist_ok=True)
        out_path = os.path.join(self.output_dir, filename)

        report = {
            "meta": {
                "tool": "nullsec-media-inspector",
                "version": "1.0.0",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "source_file": filepath,
            },
            "audio": {
                "sample_rate": analysis.sample_rate,
                "duration_sec": round(analysis.duration_sec, 3),
                "n_channels": analysis.n_channels,
                "noise_floor_db": round(analysis.noise_floor_db, 2),
                "dynamic_range_db": round(analysis.dynamic_range_db, 2),
                "peak_frequencies": [
                    {"hz": round(f, 2), "db": round(d, 2)}
                    for f, d in analysis.peak_frequencies[:20]
                ],
            },
        }

        if subliminal:
            report["subliminal"] = {
                "risk_score": round(subliminal.risk_score, 1),
                "infrasonic_energy_ratio": subliminal.infrasonic_energy_ratio,
                "ultrasonic_energy_ratio": subliminal.ultrasonic_energy_ratio,
                "total_subliminal_duration_sec": round(
                    subliminal.total_subliminal_duration_sec, 3
                ),
                "beacon_candidates": subliminal.beacon_candidates,
                "events": [self._event_to_dict(e) for e in subliminal.events],
                "summary": subliminal.summary,
            }

        if vfl:
            report["vfl"] = {
                "risk_score": round(vfl.risk_score, 1),
                "layers_detected": vfl.layers_detected,
                "dominant_layer_type": vfl.dominant_layer_type,
                "spectral_entropy_mean": round(vfl.spectral_entropy_mean, 4),
                "events": [self._vfl_event_to_dict(e) for e in vfl.events],
                "summary": vfl.summary,
            }

        # combined risk
        sub_risk = subliminal.risk_score if subliminal else 0
        vfl_risk = vfl.risk_score if vfl else 0
        report["combined_risk_score"] = round(
            min(100, sub_risk * 0.6 + vfl_risk * 0.4), 1
        )

        with open(out_path, "w") as f:
            json.dump(report, f, indent=2, default=str)

        return out_path

    # ── Markdown report ─────────────────────────────────────────────

    def generate_markdown(
        self,
        filepath: str,
        analysis: AnalysisResult,
        subliminal: Optional[SubliminalReport] = None,
        vfl: Optional[VFLReport] = None,
        spectrogram_path: Optional[str] = None,
        filename: str = "report.md",
    ) -> str:
        os.makedirs(self.output_dir, exist_ok=True)
        out_path = os.path.join(self.output_dir, filename)

        sub_risk = subliminal.risk_score if subliminal else 0
        vfl_risk = vfl.risk_score if vfl else 0
        combined = min(100, sub_risk * 0.6 + vfl_risk * 0.4)

        lines = []
        lines.append("# 🔍 NullSec Media Inspector Report")
        lines.append(f"> Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}")
        lines.append("")
        lines.append("---")
        lines.append("")

        # overview
        lines.append("## 📊 Overview")
        lines.append("")
        lines.append(f"| Metric | Value |")
        lines.append(f"|--------|-------|")
        lines.append(f"| Source File | `{os.path.basename(filepath)}` |")
        lines.append(f"| Sample Rate | {analysis.sample_rate} Hz |")
        lines.append(f"| Duration | {analysis.duration_sec:.2f}s |")
        lines.append(f"| Channels | {analysis.n_channels} |")
        lines.append(f"| Noise Floor | {analysis.noise_floor_db:.1f} dB |")
        lines.append(f"| Dynamic Range | {analysis.dynamic_range_db:.1f} dB |")
        lines.append(f"| **Combined Risk** | **{combined:.0f}/100** {self._risk_emoji(combined)} |")
        lines.append("")

        # risk meter
        lines.append(self._risk_bar(combined))
        lines.append("")

        # spectrogram
        if spectrogram_path:
            rel = os.path.relpath(spectrogram_path, self.output_dir)
            lines.append(f"![Spectrogram]({rel})")
            lines.append("")

        # subliminal findings
        if subliminal:
            lines.append("---")
            lines.append("")
            lines.append("## 🔴 Subliminal Analysis")
            lines.append("")
            lines.append(f"**Risk Score:** {subliminal.risk_score:.0f}/100 {self._risk_emoji(subliminal.risk_score)}")
            lines.append("")
            lines.append(f"| Band | Energy Ratio |")
            lines.append(f"|------|-------------|")
            lines.append(f"| Infrasonic (<20 Hz) | {subliminal.infrasonic_energy_ratio * 100:.4f}% |")
            lines.append(f"| Ultrasonic (>18 kHz) | {subliminal.ultrasonic_energy_ratio * 100:.4f}% |")
            lines.append(f"| Total Subliminal Duration | {subliminal.total_subliminal_duration_sec:.3f}s |")
            lines.append("")

            if subliminal.beacon_candidates:
                lines.append(f"### ⚠️ Ultrasonic Beacons Detected: {len(subliminal.beacon_candidates)}")
                lines.append("")
                for i, b in enumerate(subliminal.beacon_candidates, 1):
                    lines.append(f"- **Beacon {i}:** {b['freq_hz']:.1f} Hz, "
                                 f"{b['duration_sec']:.2f}s, {b['peak_db']:.1f} dB")
                lines.append("")

            if subliminal.events:
                lines.append("### Events")
                lines.append("")
                lines.append("| # | Type | Severity | Time | Freq | Peak dB | SNR | Confidence |")
                lines.append("|---|------|----------|------|------|---------|-----|------------|")
                for i, ev in enumerate(subliminal.events, 1):
                    sev_icon = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢"}.get(ev.severity, "⚪")
                    lines.append(
                        f"| {i} | {ev.event_type} | {sev_icon} {ev.severity} | "
                        f"{ev.start_sec:.2f}–{ev.end_sec:.2f}s | "
                        f"{ev.peak_freq_hz:.0f} Hz | {ev.peak_db:.1f} | "
                        f"{ev.snr_db:.1f} | {ev.confidence:.2f} |"
                    )
                lines.append("")

        # VFL findings
        if vfl:
            lines.append("---")
            lines.append("")
            lines.append("## 🟡 Variable Frequency Layer Analysis")
            lines.append("")
            lines.append(f"**Risk Score:** {vfl.risk_score:.0f}/100 {self._risk_emoji(vfl.risk_score)}")
            lines.append(f"**Layers Detected:** {vfl.layers_detected}")
            lines.append(f"**Spectral Entropy:** {vfl.spectral_entropy_mean:.4f}")
            if vfl.dominant_layer_type:
                lines.append(f"**Dominant Type:** {vfl.dominant_layer_type}")
            lines.append("")

            if vfl.events:
                lines.append("### Events")
                lines.append("")
                lines.append("| # | Type | Severity | Time | Freq Range | Confidence | Description |")
                lines.append("|---|------|----------|------|-----------|------------|-------------|")
                for i, ev in enumerate(vfl.events, 1):
                    sev_icon = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢"}.get(ev.severity, "⚪")
                    lines.append(
                        f"| {i} | {ev.layer_type} | {sev_icon} {ev.severity} | "
                        f"{ev.start_sec:.2f}–{ev.end_sec:.2f}s | "
                        f"{ev.freq_lo_hz:.0f}–{ev.freq_hi_hz:.0f} Hz | "
                        f"{ev.confidence:.2f} | {ev.description[:60]} |"
                    )
                lines.append("")

        # band energy breakdown
        lines.append("---")
        lines.append("")
        lines.append("## 📈 Band Energy Breakdown")
        lines.append("")
        lines.append("| Band | Range | Subliminal? | Status |")
        lines.append("|------|-------|:-----------:|--------|")
        import numpy as np
        for bname, (lo, hi) in BANDS.items():
            is_sub = "⚠️" if bname in SUBLIMINAL_BANDS else ""
            timeline = analysis.band_energy_timeline.get(bname, np.array([0]))
            mean_e = float(np.mean(timeline)) if len(timeline) > 0 else 0
            status = "🔴 Active" if mean_e > 1e-6 else "⚫ Silent"
            lines.append(f"| {bname} | {lo}–{hi} Hz | {is_sub} | {status} |")
        lines.append("")

        lines.append("---")
        lines.append(f"*Report generated by nullsec-media-inspector v1.0.0*")

        with open(out_path, "w") as f:
            f.write("\n".join(lines))

        return out_path

    # ── helpers ─────────────────────────────────────────────────────

    @staticmethod
    def _event_to_dict(ev: SubliminalEvent) -> dict:
        return {
            "event_type": ev.event_type,
            "severity": ev.severity,
            "start_sec": round(ev.start_sec, 4),
            "end_sec": round(ev.end_sec, 4),
            "freq_lo_hz": round(ev.freq_lo_hz, 2),
            "freq_hi_hz": round(ev.freq_hi_hz, 2),
            "peak_freq_hz": round(ev.peak_freq_hz, 2),
            "peak_db": round(ev.peak_db, 2),
            "snr_db": round(ev.snr_db, 2),
            "confidence": round(ev.confidence, 3),
            "description": ev.description,
            "metadata": ev.metadata,
        }

    @staticmethod
    def _vfl_event_to_dict(ev: VFLEvent) -> dict:
        return {
            "layer_type": ev.layer_type,
            "severity": ev.severity,
            "start_sec": round(ev.start_sec, 4),
            "end_sec": round(ev.end_sec, 4),
            "freq_lo_hz": round(ev.freq_lo_hz, 2),
            "freq_hi_hz": round(ev.freq_hi_hz, 2),
            "characteristics": ev.characteristics,
            "confidence": round(ev.confidence, 3),
            "description": ev.description,
        }

    @staticmethod
    def _risk_emoji(score: float) -> str:
        if score >= 70:
            return "🔴"
        if score >= 40:
            return "🟠"
        if score >= 15:
            return "🟡"
        return "🟢"

    @staticmethod
    def _risk_bar(score: float) -> str:
        filled = int(score / 5)
        empty = 20 - filled
        if score >= 70:
            color = "🔴"
        elif score >= 40:
            color = "🟠"
        elif score >= 15:
            color = "🟡"
        else:
            color = "🟢"
        return f"```\nRisk: [{('█' * filled)}{('░' * empty)}] {score:.0f}/100 {color}\n```"
