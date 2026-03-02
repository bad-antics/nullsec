"""
Spectrogram Generator — nullsec-media-inspector
=================================================
Produces annotated spectrograms with subliminal and VFL
regions highlighted, plus standalone band-energy heatmaps.

Output formats: PNG, SVG, interactive HTML (via plotly).
"""

import numpy as np
import os
from typing import Optional

from .analyzer import AnalysisResult, BANDS, SUBLIMINAL_BANDS
from .subliminal import SubliminalReport, SubliminalEvent
from .vfl_detector import VFLReport, VFLEvent

# color constants
COLOR_CRITICAL = "#ff2d2d"
COLOR_HIGH     = "#ff9800"
COLOR_MEDIUM   = "#ffd600"
COLOR_LOW      = "#4caf50"
COLOR_INFO     = "#2196f3"

SEVERITY_COLORS = {
    "critical": COLOR_CRITICAL,
    "high":     COLOR_HIGH,
    "medium":   COLOR_MEDIUM,
    "low":      COLOR_LOW,
    "info":     COLOR_INFO,
}


class SpectrogramGenerator:
    """
    Generate annotated spectrograms from analysis results.

    Uses matplotlib for static output and optional plotly
    for interactive HTML views.
    """

    def __init__(
        self,
        dpi: int = 150,
        figsize: tuple = (16, 10),
        colormap: str = "inferno",
        freq_scale: str = "log",      # 'log' or 'linear'
        db_range: float = 80.0,       # dB range to display
        output_dir: str = "output",
    ):
        self.dpi = dpi
        self.figsize = figsize
        self.colormap = colormap
        self.freq_scale = freq_scale
        self.db_range = db_range
        self.output_dir = output_dir

    # ── main spectrogram ────────────────────────────────────────────

    def generate(
        self,
        analysis: AnalysisResult,
        subliminal: Optional[SubliminalReport] = None,
        vfl: Optional[VFLReport] = None,
        title: str = "NullSec Media Inspector",
        filename: str = "spectrogram.png",
    ) -> str:
        """
        Generate annotated spectrogram and save to file.
        Returns the output path.
        """
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from matplotlib.patches import Rectangle
        from matplotlib.colors import LinearSegmentedColormap

        os.makedirs(self.output_dir, exist_ok=True)
        out_path = os.path.join(self.output_dir, filename)

        # build STFT matrix
        if not analysis.frames:
            fig, ax = plt.subplots(1, 1, figsize=self.figsize)
            ax.text(0.5, 0.5, "No audio data", ha="center", va="center",
                    fontsize=20, color="white", transform=ax.transAxes)
            ax.set_facecolor("black")
            fig.savefig(out_path, dpi=self.dpi, bbox_inches="tight",
                        facecolor="black")
            plt.close(fig)
            return out_path

        n_freqs = len(analysis.frames[0].magnitudes)
        n_frames = len(analysis.frames)
        spec_matrix = np.zeros((n_freqs, n_frames))

        for i, frame in enumerate(analysis.frames):
            spec_matrix[:, i] = 20 * np.log10(frame.magnitudes + 1e-12)

        times = np.array([f.time_sec for f in analysis.frames])
        freqs = analysis.frames[0].freqs

        # clamp dB range
        vmax = np.max(spec_matrix)
        vmin = vmax - self.db_range

        # create figure with subplots
        n_panels = 1
        if subliminal:
            n_panels += 1
        if vfl:
            n_panels += 1

        fig, axes = plt.subplots(
            n_panels, 1,
            figsize=(self.figsize[0], self.figsize[1] * n_panels / 2),
            gridspec_kw={"height_ratios": [3] + [1] * (n_panels - 1)},
        )
        if n_panels == 1:
            axes = [axes]

        fig.patch.set_facecolor("#0a0a0a")

        # ── panel 1: spectrogram ──
        ax = axes[0]
        if self.freq_scale == "log":
            # log-frequency spectrogram
            extent = [times[0], times[-1], 1, analysis.sample_rate / 2]
            ax.imshow(
                spec_matrix,
                aspect="auto",
                origin="lower",
                extent=extent,
                cmap=self.colormap,
                vmin=vmin,
                vmax=vmax,
                interpolation="bilinear",
            )
            ax.set_yscale("symlog", linthresh=100)
        else:
            extent = [times[0], times[-1], freqs[0], freqs[-1]]
            ax.imshow(
                spec_matrix,
                aspect="auto",
                origin="lower",
                extent=extent,
                cmap=self.colormap,
                vmin=vmin,
                vmax=vmax,
                interpolation="bilinear",
            )

        ax.set_xlabel("Time (s)", color="white", fontsize=11)
        ax.set_ylabel("Frequency (Hz)", color="white", fontsize=11)
        ax.set_title(title, color="white", fontsize=14, fontweight="bold", pad=12)
        ax.tick_params(colors="white")

        # overlay subliminal regions
        if subliminal:
            for ev in subliminal.events:
                color = SEVERITY_COLORS.get(ev.severity, COLOR_INFO)
                rect = Rectangle(
                    (ev.start_sec, ev.freq_lo_hz),
                    ev.end_sec - ev.start_sec,
                    ev.freq_hi_hz - ev.freq_lo_hz,
                    linewidth=1.5,
                    edgecolor=color,
                    facecolor=color,
                    alpha=0.25,
                )
                ax.add_patch(rect)

        # overlay VFL regions
        if vfl:
            for ev in vfl.events:
                color = SEVERITY_COLORS.get(ev.severity, COLOR_INFO)
                rect = Rectangle(
                    (ev.start_sec, ev.freq_lo_hz),
                    ev.end_sec - ev.start_sec,
                    max(ev.freq_hi_hz - ev.freq_lo_hz, 100),
                    linewidth=2,
                    edgecolor=color,
                    facecolor="none",
                    linestyle="--",
                )
                ax.add_patch(rect)

        # subliminal band markers
        for band in SUBLIMINAL_BANDS:
            lo, hi = BANDS[band]
            if hi <= analysis.sample_rate / 2:
                ax.axhspan(lo, hi, alpha=0.08, color="red")

        # ── panel 2: subliminal timeline ──
        if subliminal and len(axes) > 1:
            ax2 = axes[1]
            ax2.set_facecolor("#0a0a0a")
            ax2.set_title("Subliminal Events", color="white", fontsize=11,
                          fontweight="bold")
            for ev in subliminal.events:
                color = SEVERITY_COLORS.get(ev.severity, COLOR_INFO)
                ax2.barh(
                    ev.event_type,
                    ev.end_sec - ev.start_sec,
                    left=ev.start_sec,
                    color=color,
                    alpha=0.7,
                    height=0.6,
                )
            ax2.set_xlabel("Time (s)", color="white", fontsize=10)
            ax2.tick_params(colors="white")
            ax2.set_xlim(times[0], times[-1])

        # ── panel 3: VFL timeline ──
        if vfl:
            ax3 = axes[-1] if len(axes) > 2 else (axes[1] if not subliminal and len(axes) > 1 else None)
            if ax3 is not None:
                ax3.set_facecolor("#0a0a0a")
                ax3.set_title("VFL Events", color="white", fontsize=11,
                              fontweight="bold")
                for ev in vfl.events:
                    color = SEVERITY_COLORS.get(ev.severity, COLOR_INFO)
                    ax3.barh(
                        ev.layer_type,
                        ev.end_sec - ev.start_sec,
                        left=ev.start_sec,
                        color=color,
                        alpha=0.7,
                        height=0.6,
                    )
                ax3.set_xlabel("Time (s)", color="white", fontsize=10)
                ax3.tick_params(colors="white")
                ax3.set_xlim(times[0], times[-1])

        plt.tight_layout()
        fig.savefig(out_path, dpi=self.dpi, bbox_inches="tight",
                    facecolor="#0a0a0a")
        plt.close(fig)
        return out_path

    # ── band energy heatmap ─────────────────────────────────────────

    def generate_band_heatmap(
        self,
        analysis: AnalysisResult,
        filename: str = "band_heatmap.png",
    ) -> str:
        """
        Generate a band-vs-time energy heatmap highlighting
        subliminal bands in red.
        """
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        os.makedirs(self.output_dir, exist_ok=True)
        out_path = os.path.join(self.output_dir, filename)

        band_names = list(BANDS.keys())
        n_bands = len(band_names)
        n_frames = max(
            len(analysis.band_energy_timeline.get(b, []))
            for b in band_names
        )

        if n_frames == 0:
            return out_path

        matrix = np.zeros((n_bands, n_frames))
        for i, bname in enumerate(band_names):
            arr = analysis.band_energy_timeline.get(bname, np.zeros(n_frames))
            matrix[i, :len(arr)] = 10 * np.log10(arr + 1e-12)

        fig, ax = plt.subplots(1, 1, figsize=(self.figsize[0], 6))
        fig.patch.set_facecolor("#0a0a0a")

        hop_sec = analysis.duration_sec / max(n_frames, 1)
        extent = [0, analysis.duration_sec, 0, n_bands]
        ax.imshow(matrix, aspect="auto", origin="lower", extent=extent,
                  cmap="magma", interpolation="bilinear")

        ax.set_yticks(np.arange(n_bands) + 0.5)
        ax.set_yticklabels(band_names, fontsize=9)
        ax.set_xlabel("Time (s)", color="white", fontsize=11)
        ax.set_title("Band Energy Heatmap", color="white", fontsize=14,
                     fontweight="bold")
        ax.tick_params(colors="white")

        # highlight subliminal bands
        for i, bname in enumerate(band_names):
            if bname in SUBLIMINAL_BANDS:
                ax.axhspan(i, i + 1, alpha=0.15, color="red")
                ax.text(-0.5, i + 0.5, "⚠", fontsize=12, color="red",
                        ha="right", va="center")

        plt.tight_layout()
        fig.savefig(out_path, dpi=self.dpi, bbox_inches="tight",
                    facecolor="#0a0a0a")
        plt.close(fig)
        return out_path

    # ── interactive HTML spectrogram ────────────────────────────────

    def generate_interactive(
        self,
        analysis: AnalysisResult,
        subliminal: Optional[SubliminalReport] = None,
        vfl: Optional[VFLReport] = None,
        title: str = "NullSec Media Inspector",
        filename: str = "spectrogram.html",
    ) -> str:
        """
        Generate an interactive HTML spectrogram using plotly.
        Returns the output path.
        """
        try:
            import plotly.graph_objects as go
            from plotly.subplots import make_subplots
        except ImportError:
            # fall back to static
            return self.generate(
                analysis, subliminal, vfl, title,
                filename.replace(".html", ".png"),
            )

        os.makedirs(self.output_dir, exist_ok=True)
        out_path = os.path.join(self.output_dir, filename)

        if not analysis.frames:
            return out_path

        n_freqs = len(analysis.frames[0].magnitudes)
        n_frames = len(analysis.frames)
        spec_matrix = np.zeros((n_freqs, n_frames))
        for i, frame in enumerate(analysis.frames):
            spec_matrix[:, i] = 20 * np.log10(frame.magnitudes + 1e-12)

        times = [f.time_sec for f in analysis.frames]
        freqs = analysis.frames[0].freqs.tolist()

        vmax = float(np.max(spec_matrix))
        vmin = vmax - self.db_range

        fig = make_subplots(rows=1, cols=1)
        fig.add_trace(go.Heatmap(
            z=spec_matrix.tolist(),
            x=times,
            y=freqs,
            colorscale="Inferno",
            zmin=vmin,
            zmax=vmax,
            colorbar=dict(title="dB"),
        ))

        # add event annotations
        all_events = []
        if subliminal:
            all_events.extend(subliminal.events)
        if vfl:
            all_events.extend(vfl.events)

        for ev in all_events:
            color = SEVERITY_COLORS.get(getattr(ev, "severity", "info"), COLOR_INFO)
            fig.add_shape(
                type="rect",
                x0=ev.start_sec, x1=ev.end_sec,
                y0=ev.freq_lo_hz, y1=ev.freq_hi_hz,
                line=dict(color=color, width=2),
                fillcolor=color,
                opacity=0.2,
            )

        fig.update_layout(
            title=dict(text=title, font=dict(color="white", size=16)),
            xaxis_title="Time (s)",
            yaxis_title="Frequency (Hz)",
            yaxis_type="log" if self.freq_scale == "log" else "linear",
            template="plotly_dark",
            paper_bgcolor="#0a0a0a",
            plot_bgcolor="#0a0a0a",
        )

        fig.write_html(out_path)
        return out_path
