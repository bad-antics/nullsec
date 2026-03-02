#!/usr/bin/env python3
"""
nullsec-media-inspector — Subliminal VFL Analyzer for n01d
============================================================
CLI entrypoint for scanning media files for subliminal
frequency content and variable frequency layers.

Usage:
  python run.py scan <file>                   # full scan with reports
  python run.py scan <file> -o results/       # custom output dir
  python run.py batch <dir>                   # scan entire directory
  python run.py batch <dir> --ext mp3,wav     # filter extensions
  python run.py web                           # launch web UI
  python run.py web --port 8090               # custom port
"""

import argparse
import os
import sys
import glob
import time
import json

# ── ANSI colors ─────────────────────────────────────────────────────
class C:
    R  = "\033[91m"    # red
    G  = "\033[92m"    # green
    Y  = "\033[93m"    # yellow
    B  = "\033[94m"    # blue
    M  = "\033[95m"    # magenta
    CY = "\033[96m"    # cyan
    W  = "\033[97m"    # white
    DK = "\033[90m"    # dark/gray
    BD = "\033[1m"     # bold
    UL = "\033[4m"     # underline
    X  = "\033[0m"     # reset


BANNER = f"""
{C.R}╔══════════════════════════════════════════════════════════════╗
║{C.W}  ███╗   ██╗ ██████╗  ██╗██████╗     ███╗   ███╗██╗         {C.R}║
║{C.W}  ████╗  ██║██╔═══██╗███║██╔══██╗    ████╗ ████║██║         {C.R}║
║{C.W}  ██╔██╗ ██║██║   ██║╚██║██║  ██║    ██╔████╔██║██║         {C.R}║
║{C.W}  ██║╚██╗██║██║   ██║ ██║██║  ██║    ██║╚██╔╝██║██║         {C.R}║
║{C.W}  ██║ ╚████║╚██████╔╝ ██║██████╔╝    ██║ ╚═╝ ██║██║         {C.R}║
║{C.W}  ╚═╝  ╚═══╝ ╚═════╝  ╚═╝╚═════╝     ╚═╝     ╚═╝╚═╝         {C.R}║
║{C.DK}  ─────────────────────────────────────────────────────────  {C.R}║
║{C.CY}  MEDIA INSPECTOR{C.DK} — Subliminal Variable Frequency Layer    {C.R}║
║{C.DK}  Analyzer for n01d  ·  NullSec Toolkit v1.0                {C.R}║
╚══════════════════════════════════════════════════════════════╝{C.X}
"""


def print_banner():
    print(BANNER)


def log(level, msg):
    icons = {
        "info":    f"{C.CY}[ℹ]{C.X}",
        "ok":      f"{C.G}[✓]{C.X}",
        "warn":    f"{C.Y}[⚠]{C.X}",
        "error":   f"{C.R}[✗]{C.X}",
        "scan":    f"{C.M}[◉]{C.X}",
        "finding": f"{C.R}[!]{C.X}",
    }
    print(f"  {icons.get(level, '[·]')} {msg}")


def risk_bar(score):
    filled = int(score / 5)
    empty = 20 - filled
    if score >= 70:
        color = C.R
    elif score >= 40:
        color = C.Y
    elif score >= 15:
        color = C.Y
    else:
        color = C.G
    bar = f"{color}{'█' * filled}{C.DK}{'░' * empty}{C.X}"
    return f"  [{bar}] {color}{score:.0f}/100{C.X}"


# ── scan command ────────────────────────────────────────────────────

def cmd_scan(args):
    """Full scan of a single media file."""
    from inspector.extractor import MediaExtractor
    from inspector.analyzer import SpectralAnalyzer
    from inspector.subliminal import SubliminalDetector
    from inspector.vfl_detector import VFLDetector
    from inspector.spectrogram import SpectrogramGenerator
    from inspector.report import ReportGenerator

    filepath = args.file
    output_dir = args.output or "output"
    fft_size = args.fft_size
    interactive = args.interactive

    if not os.path.isfile(filepath):
        log("error", f"File not found: {filepath}")
        sys.exit(1)

    basename = os.path.splitext(os.path.basename(filepath))[0]
    scan_dir = os.path.join(output_dir, f"scan_{basename}")
    os.makedirs(scan_dir, exist_ok=True)

    t0 = time.time()

    # ── extract audio ──
    log("scan", f"Loading media: {C.W}{filepath}{C.X}")
    extractor = MediaExtractor(
        target_sr=args.sample_rate,
        mono=args.mono,
    )
    try:
        audio = extractor.extract(filepath)
    except Exception as e:
        log("error", f"Failed to extract audio: {e}")
        sys.exit(1)

    log("ok", f"Loaded: {audio.n_channels}ch, {audio.sample_rate} Hz, "
              f"{audio.duration_sec:.2f}s, {audio.source_format}")

    # ── spectral analysis ──
    log("scan", "Running spectral analysis...")
    analyzer = SpectralAnalyzer(
        fft_size=fft_size,
        window=args.window,
        zero_pad_factor=args.zero_pad,
    )
    results = analyzer.analyze_multichannel(audio.channels, audio.sample_rate)

    for i, res in enumerate(results):
        log("ok", f"Channel {i}: noise floor {res.noise_floor_db:.1f} dB, "
                  f"dynamic range {res.dynamic_range_db:.1f} dB, "
                  f"{len(res.frames)} frames")

    # ── subliminal detection ──
    log("scan", "Scanning for subliminal content...")
    sub_detector = SubliminalDetector()
    sub_reports = [sub_detector.detect(r) for r in results]

    for i, sr in enumerate(sub_reports):
        if sr.events:
            log("finding", f"Channel {i}: {C.R}{len(sr.events)} subliminal events{C.X} "
                           f"(risk: {sr.risk_score:.0f}/100)")
            for ev in sr.events[:5]:
                sev_color = {
                    "critical": C.R, "high": C.Y,
                    "medium": C.CY, "low": C.G,
                }.get(ev.severity, C.W)
                log("warn", f"  {sev_color}{ev.severity.upper()}{C.X}: {ev.description}")
            if len(sr.events) > 5:
                log("info", f"  ... and {len(sr.events) - 5} more events")
        else:
            log("ok", f"Channel {i}: No subliminal content detected")

        if sr.beacon_candidates:
            log("finding", f"  {C.R}⚠ {len(sr.beacon_candidates)} ultrasonic beacon(s)!{C.X}")

    # ── VFL detection ──
    log("scan", "Scanning for variable frequency layers...")
    vfl_detector = VFLDetector()
    vfl_reports = [vfl_detector.detect(r) for r in results]

    for i, vr in enumerate(vfl_reports):
        if vr.events:
            log("finding", f"Channel {i}: {C.Y}{vr.layers_detected} VFL layer type(s){C.X}, "
                           f"{len(vr.events)} events (risk: {vr.risk_score:.0f}/100)")
            for ev in vr.events[:5]:
                sev_color = {
                    "critical": C.R, "high": C.Y,
                    "medium": C.CY, "low": C.G,
                }.get(ev.severity, C.W)
                log("warn", f"  {sev_color}{ev.severity.upper()}{C.X}: {ev.description}")
            if len(vr.events) > 5:
                log("info", f"  ... and {len(vr.events) - 5} more events")
        else:
            log("ok", f"Channel {i}: No VFL patterns detected")

    # ── generate outputs ──
    log("scan", "Generating spectrograms...")
    spec_gen = SpectrogramGenerator(output_dir=scan_dir, colormap=args.colormap)
    report_gen = ReportGenerator(output_dir=scan_dir)

    spectrogram_paths = []
    for i, (res, sr, vr) in enumerate(zip(results, sub_reports, vfl_reports)):
        ch_label = f"ch{i}"

        # static spectrogram
        sp = spec_gen.generate(
            res, sr, vr,
            title=f"n01d Media Inspector — {basename} (ch{i})",
            filename=f"spectrogram_{ch_label}.png",
        )
        spectrogram_paths.append(sp)
        log("ok", f"Spectrogram: {sp}")

        # band heatmap
        hp = spec_gen.generate_band_heatmap(res, filename=f"heatmap_{ch_label}.png")
        log("ok", f"Heatmap: {hp}")

        # interactive
        if interactive:
            ip = spec_gen.generate_interactive(
                res, sr, vr,
                title=f"n01d Media Inspector — {basename} (ch{i})",
                filename=f"spectrogram_{ch_label}.html",
            )
            log("ok", f"Interactive: {ip}")

    # ── generate reports ──
    log("scan", "Generating reports...")
    # use first channel for primary report (most common case)
    primary_sub = sub_reports[0] if sub_reports else None
    primary_vfl = vfl_reports[0] if vfl_reports else None
    primary_res = results[0] if results else None

    if primary_res:
        json_path = report_gen.generate_json(
            filepath, primary_res, primary_sub, primary_vfl,
            filename="report.json",
        )
        log("ok", f"JSON report: {json_path}")

        md_path = report_gen.generate_markdown(
            filepath, primary_res, primary_sub, primary_vfl,
            spectrogram_path=spectrogram_paths[0] if spectrogram_paths else None,
            filename="report.md",
        )
        log("ok", f"Markdown report: {md_path}")

    elapsed = time.time() - t0

    # ── summary ──
    print()
    print(f"  {C.BD}{C.W}═══ SCAN COMPLETE ═══{C.X}")
    print(f"  {C.DK}File:{C.X} {filepath}")
    print(f"  {C.DK}Time:{C.X} {elapsed:.2f}s")
    print(f"  {C.DK}Output:{C.X} {scan_dir}/")
    print()

    if primary_sub:
        print(f"  {C.BD}Subliminal Risk:{C.X}")
        print(risk_bar(primary_sub.risk_score))
    if primary_vfl:
        print(f"  {C.BD}VFL Risk:{C.X}")
        print(risk_bar(primary_vfl.risk_score))
    if primary_sub and primary_vfl:
        combined = min(100, primary_sub.risk_score * 0.6 + primary_vfl.risk_score * 0.4)
        print(f"  {C.BD}Combined Risk:{C.X}")
        print(risk_bar(combined))

    print()


# ── batch command ───────────────────────────────────────────────────

def cmd_batch(args):
    """Scan all media files in a directory."""
    from inspector.extractor import AUDIO_EXTENSIONS, VIDEO_EXTENSIONS

    target_dir = args.directory
    if not os.path.isdir(target_dir):
        log("error", f"Directory not found: {target_dir}")
        sys.exit(1)

    if args.ext:
        extensions = {"." + e.strip().lower().lstrip(".") for e in args.ext.split(",")}
    else:
        extensions = AUDIO_EXTENSIONS | VIDEO_EXTENSIONS

    # find all matching files
    files = []
    for root, dirs, filenames in os.walk(target_dir):
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            if ext in extensions:
                files.append(os.path.join(root, fname))

    if not files:
        log("warn", f"No media files found in {target_dir}")
        sys.exit(0)

    log("info", f"Found {len(files)} media file(s)")
    print()

    results_summary = []
    for i, fpath in enumerate(files, 1):
        print(f"  {C.DK}{'─' * 60}{C.X}")
        log("scan", f"[{i}/{len(files)}] {os.path.basename(fpath)}")

        # build args for scan
        scan_args = argparse.Namespace(
            file=fpath,
            output=args.output,
            fft_size=args.fft_size,
            window=args.window,
            zero_pad=args.zero_pad,
            sample_rate=args.sample_rate,
            mono=args.mono,
            interactive=args.interactive,
            colormap=args.colormap,
        )

        try:
            cmd_scan(scan_args)
            results_summary.append({"file": fpath, "status": "ok"})
        except Exception as e:
            log("error", f"Failed: {e}")
            results_summary.append({"file": fpath, "status": "error", "error": str(e)})

    # batch summary
    print(f"\n  {C.BD}{C.W}═══ BATCH COMPLETE ═══{C.X}")
    ok = sum(1 for r in results_summary if r["status"] == "ok")
    err = sum(1 for r in results_summary if r["status"] == "error")
    log("info", f"Scanned: {ok} OK, {err} failed, {len(files)} total")


# ── web command ─────────────────────────────────────────────────────

def cmd_web(args):
    """Launch the Flask web UI."""
    try:
        from app.routes import create_app
        app = create_app(output_dir=args.output or "output")
        log("info", f"Starting web UI on http://0.0.0.0:{args.port}")
        app.run(host="0.0.0.0", port=args.port, debug=args.debug)
    except ImportError as e:
        log("error", f"Flask not installed. Run: pip install flask")
        sys.exit(1)


# ── argument parser ─────────────────────────────────────────────────

def build_parser():
    parser = argparse.ArgumentParser(
        prog="nullsec-media-inspector",
        description="n01d Media Inspector — Subliminal VFL Analyzer",
    )
    subparsers = parser.add_subparsers(dest="command", help="Command")

    # common scan args
    def add_scan_args(p):
        p.add_argument("-o", "--output", default="output",
                       help="Output directory (default: output)")
        p.add_argument("--fft-size", type=int, default=8192,
                       help="FFT window size (default: 8192)")
        p.add_argument("--window", default="blackman",
                       choices=["hann", "hamming", "blackman", "blackmanharris", "kaiser", "flat"],
                       help="Window function (default: blackman)")
        p.add_argument("--zero-pad", type=int, default=1,
                       help="Zero-padding factor (default: 1)")
        p.add_argument("--sample-rate", type=int, default=None,
                       help="Resample to this rate (default: native)")
        p.add_argument("--mono", action="store_true",
                       help="Downmix to mono before analysis")
        p.add_argument("--interactive", action="store_true",
                       help="Generate interactive HTML spectrograms")
        p.add_argument("--colormap", default="inferno",
                       help="Matplotlib colormap (default: inferno)")

    # scan
    scan_p = subparsers.add_parser("scan", help="Scan a single media file")
    scan_p.add_argument("file", help="Path to the media file")
    add_scan_args(scan_p)

    # batch
    batch_p = subparsers.add_parser("batch", help="Scan all media in a directory")
    batch_p.add_argument("directory", help="Directory to scan")
    batch_p.add_argument("--ext", default=None,
                         help="Comma-separated extensions to scan (e.g., mp3,wav,mp4)")
    add_scan_args(batch_p)

    # web
    web_p = subparsers.add_parser("web", help="Launch the web UI")
    web_p.add_argument("-p", "--port", type=int, default=8090,
                       help="Port (default: 8090)")
    web_p.add_argument("-o", "--output", default="output",
                       help="Output directory")
    web_p.add_argument("--debug", action="store_true",
                       help="Run Flask in debug mode")

    return parser


# ── main ────────────────────────────────────────────────────────────

def main():
    print_banner()
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "scan":
        cmd_scan(args)
    elif args.command == "batch":
        cmd_batch(args)
    elif args.command == "web":
        cmd_web(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
