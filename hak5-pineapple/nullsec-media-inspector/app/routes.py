"""
Flask Web UI — nullsec-media-inspector
=======================================
Upload + scan interface with spectrogram viewer and
interactive report browsing.
"""

import os
import uuid
import time
import json
import threading
from flask import (
    Flask, render_template, request, jsonify,
    send_from_directory, redirect, url_for,
)


def create_app(output_dir="output"):
    app = Flask(
        __name__,
        template_folder=os.path.join(os.path.dirname(__file__), "..", "templates"),
        static_folder=os.path.join(os.path.dirname(__file__), "..", "static"),
    )
    app.config["MAX_CONTENT_LENGTH"] = 500 * 1024 * 1024  # 500 MB
    app.config["OUTPUT_DIR"] = os.path.abspath(output_dir)
    app.config["UPLOAD_DIR"] = os.path.join(app.config["OUTPUT_DIR"], "uploads")

    os.makedirs(app.config["UPLOAD_DIR"], exist_ok=True)
    os.makedirs(app.config["OUTPUT_DIR"], exist_ok=True)

    # in-memory scan tracker
    scans = {}

    @app.route("/")
    def index():
        return render_template("index.html", scans=scans)

    @app.route("/upload", methods=["POST"])
    def upload():
        if "file" not in request.files:
            return jsonify({"error": "No file uploaded"}), 400

        f = request.files["file"]
        if f.filename == "":
            return jsonify({"error": "Empty filename"}), 400

        scan_id = str(uuid.uuid4())[:8]
        ext = os.path.splitext(f.filename)[1]
        save_path = os.path.join(app.config["UPLOAD_DIR"], f"{scan_id}{ext}")
        f.save(save_path)

        scans[scan_id] = {
            "id": scan_id,
            "filename": f.filename,
            "path": save_path,
            "status": "queued",
            "progress": 0,
            "started": time.time(),
            "results": None,
        }

        # run scan in background thread
        fft_size = int(request.form.get("fft_size", 8192))
        window = request.form.get("window", "blackman")

        thread = threading.Thread(
            target=_run_scan,
            args=(app, scans, scan_id, save_path, fft_size, window),
            daemon=True,
        )
        thread.start()

        return jsonify({"scan_id": scan_id, "status": "queued"})

    @app.route("/scan/<scan_id>")
    def scan_status(scan_id):
        if scan_id not in scans:
            return jsonify({"error": "Scan not found"}), 404
        scan = scans[scan_id]

        # if complete, try to load the JSON report
        if scan["status"] == "complete" and scan["results"] is None:
            report_path = os.path.join(
                app.config["OUTPUT_DIR"],
                f"scan_{os.path.splitext(os.path.basename(scan['path']))[0]}",
                "report.json",
            )
            if os.path.exists(report_path):
                with open(report_path) as rf:
                    scan["results"] = json.load(rf)

        return jsonify(scan)

    @app.route("/scan/<scan_id>/view")
    def scan_view(scan_id):
        if scan_id not in scans:
            return "Scan not found", 404
        return render_template("report.html", scan=scans[scan_id], scan_id=scan_id)

    @app.route("/output/<path:subpath>")
    def serve_output(subpath):
        return send_from_directory(app.config["OUTPUT_DIR"], subpath)

    @app.route("/api/scans")
    def list_scans():
        return jsonify(list(scans.values()))

    return app


def _run_scan(app, scans, scan_id, filepath, fft_size, window):
    """Background scan worker."""
    try:
        scans[scan_id]["status"] = "running"
        scans[scan_id]["progress"] = 10

        from inspector.extractor import MediaExtractor
        from inspector.analyzer import SpectralAnalyzer
        from inspector.subliminal import SubliminalDetector
        from inspector.vfl_detector import VFLDetector
        from inspector.spectrogram import SpectrogramGenerator
        from inspector.report import ReportGenerator

        output_dir = app.config["OUTPUT_DIR"]
        basename = os.path.splitext(os.path.basename(filepath))[0]
        scan_dir = os.path.join(output_dir, f"scan_{basename}")
        os.makedirs(scan_dir, exist_ok=True)

        # extract
        extractor = MediaExtractor()
        audio = extractor.extract(filepath)
        scans[scan_id]["progress"] = 25

        # analyze
        analyzer = SpectralAnalyzer(fft_size=fft_size, window=window)
        results = analyzer.analyze_multichannel(audio.channels, audio.sample_rate)
        scans[scan_id]["progress"] = 50

        # subliminal
        sub_detector = SubliminalDetector()
        sub_reports = [sub_detector.detect(r) for r in results]
        scans[scan_id]["progress"] = 65

        # VFL
        vfl_detector = VFLDetector()
        vfl_reports = [vfl_detector.detect(r) for r in results]
        scans[scan_id]["progress"] = 80

        # spectrograms
        spec_gen = SpectrogramGenerator(output_dir=scan_dir)
        for i, (res, sr, vr) in enumerate(zip(results, sub_reports, vfl_reports)):
            spec_gen.generate(res, sr, vr,
                              title=f"n01d Inspector — {basename} (ch{i})",
                              filename=f"spectrogram_ch{i}.png")
            spec_gen.generate_band_heatmap(res, filename=f"heatmap_ch{i}.png")
            try:
                spec_gen.generate_interactive(res, sr, vr,
                                              title=f"n01d Inspector — {basename} (ch{i})",
                                              filename=f"spectrogram_ch{i}.html")
            except Exception:
                pass

        scans[scan_id]["progress"] = 90

        # reports
        report_gen = ReportGenerator(output_dir=scan_dir)
        primary = results[0] if results else None
        primary_sub = sub_reports[0] if sub_reports else None
        primary_vfl = vfl_reports[0] if vfl_reports else None

        if primary:
            report_gen.generate_json(filepath, primary, primary_sub, primary_vfl)
            report_gen.generate_markdown(filepath, primary, primary_sub, primary_vfl)

        scans[scan_id]["status"] = "complete"
        scans[scan_id]["progress"] = 100
        scans[scan_id]["scan_dir"] = f"scan_{basename}"
        scans[scan_id]["elapsed"] = time.time() - scans[scan_id]["started"]

        # load results
        report_path = os.path.join(scan_dir, "report.json")
        if os.path.exists(report_path):
            with open(report_path) as f:
                scans[scan_id]["results"] = json.load(f)

    except Exception as e:
        scans[scan_id]["status"] = "error"
        scans[scan_id]["error"] = str(e)
