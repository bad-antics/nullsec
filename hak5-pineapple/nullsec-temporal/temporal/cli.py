"""
CLI interface for nullsec-temporal.
"""

import sys
import os
import json
import time
import re
import click
from datetime import datetime, timezone
from .scanner import scan_path, check_file, build_timeline


@click.group()
def main():
    """⏱️ nullsec-temporal — Filesystem Forensic Timestamp Analyzer

    Detect timestomping, time anomalies, and anti-forensic manipulation.
    """
    pass


@main.command(name="scan")
@click.argument("path")
@click.option("--recursive", "-r", is_flag=True, help="Scan recursively")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.option("--verbose", "-v", is_flag=True, help="Show all files, not just anomalies")
def scan(path, recursive, as_json, verbose):
    """Scan for timestamp anomalies in a directory."""
    result = scan_path(path, recursive=recursive)

    if as_json:
        output = {
            "path": result.path,
            "total_files": result.total_files,
            "anomalies": result.total_anomalies,
            "critical": result.critical,
            "suspicious": result.suspicious,
            "info": result.info,
            "files": [
                {
                    "path": f.filepath,
                    "mtime": f.mtime,
                    "ctime": f.ctime,
                    "atime": f.atime,
                    "severity": f.severity,
                    "anomalies": f.anomalies,
                }
                for f in result.files if f.anomalies or verbose
            ],
            "clusters": result.clusters,
            "timeline_gaps": result.timeline_gaps,
        }
        click.echo(json.dumps(output, indent=2))
        return

    click.echo(f"\n⏱️  Temporal Scan: {path}\n")

    for f in result.files:
        if not f.anomalies and not verbose:
            continue

        icon = _severity_icon(f.severity)
        mtime_str = datetime.fromtimestamp(f.mtime).strftime("%Y-%m-%d %H:%M:%S")
        click.echo(f"{icon} {f.filepath}")
        if verbose or f.anomalies:
            click.echo(f"   📅 mtime: {mtime_str}  size: {f.size:,} bytes")
        for a in f.anomalies:
            click.echo(f"   ⚠️  {a}")

    # Clusters
    if result.clusters:
        click.echo(f"\n📎 Timestamp Clusters (≥5 files with identical mtime):")
        for c in result.clusters:
            click.echo(f"   🕐 {c['datetime']}: {c['count']} files")
            for fp in c["files"][:5]:
                click.echo(f"      • {os.path.basename(fp)}")
            if c["count"] > 5:
                click.echo(f"      … and {c['count'] - 5} more")

    # Gaps
    if result.timeline_gaps:
        click.echo(f"\n📍 Timeline Gaps:")
        for g in result.timeline_gaps:
            click.echo(f"   🕳️  {g['gap_human']} gap between:")
            click.echo(f"      {g['before']['time']} — {os.path.basename(g['before']['file'])}")
            click.echo(f"      {g['after']['time']} — {os.path.basename(g['after']['file'])}")

    # Summary
    click.echo(f"\n📊 Summary: {result.total_files} files scanned")
    click.echo(f"   🔴 Critical: {result.critical}")
    click.echo(f"   🟡 Suspicious: {result.suspicious}")
    click.echo(f"   🔵 Info: {result.info}")
    click.echo(f"   🟢 Clean: {result.total_files - result.total_anomalies}")


@main.command(name="check")
@click.argument("filepath")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
def check(filepath, as_json):
    """Check timestamps of a single file."""
    if not os.path.exists(filepath):
        click.echo(f"❌ Not found: {filepath}", err=True)
        sys.exit(1)

    info = check_file(filepath)

    if as_json:
        click.echo(json.dumps({
            "path": info.filepath,
            "atime": info.atime,
            "mtime": info.mtime,
            "ctime": info.ctime,
            "atime_human": datetime.fromtimestamp(info.atime).isoformat(),
            "mtime_human": datetime.fromtimestamp(info.mtime).isoformat(),
            "ctime_human": datetime.fromtimestamp(info.ctime).isoformat(),
            "size": info.size,
            "severity": info.severity,
            "anomalies": info.anomalies,
        }, indent=2))
        return

    icon = _severity_icon(info.severity)
    click.echo(f"\n{icon} {filepath}\n")
    click.echo(f"   📅 Access time:  {datetime.fromtimestamp(info.atime).strftime('%Y-%m-%d %H:%M:%S.%f')}")
    click.echo(f"   📅 Modify time:  {datetime.fromtimestamp(info.mtime).strftime('%Y-%m-%d %H:%M:%S.%f')}")
    click.echo(f"   📅 Change time:  {datetime.fromtimestamp(info.ctime).strftime('%Y-%m-%d %H:%M:%S.%f')}")
    click.echo(f"   📏 Size: {info.size:,} bytes")
    click.echo(f"   🏷️  Severity: {info.severity}")

    if info.anomalies:
        click.echo(f"\n   ⚠️  Anomalies:")
        for a in info.anomalies:
            click.echo(f"      • {a}")
    else:
        click.echo(f"\n   ✅ No anomalies detected")


@main.command(name="timeline")
@click.argument("path")
@click.option("--last", "last_str", default=None,
              help="Show last N period (e.g., 7d, 24h, 30m)")
@click.option("--limit", type=int, default=50, help="Max entries to show")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
def timeline(path, last_str, limit, as_json):
    """Show chronological file activity timeline."""
    last_seconds = _parse_duration(last_str) if last_str else None

    entries = build_timeline(path, recursive=True, last_seconds=last_seconds)

    if as_json:
        click.echo(json.dumps(entries[-limit:], indent=2))
        return

    click.echo(f"\n⏱️  Timeline: {path}")
    if last_str:
        click.echo(f"   (last {last_str})")
    click.echo()

    for entry in entries[-limit:]:
        dt = datetime.fromtimestamp(entry["time"])
        icon = "📁" if entry["type"] == "dir" else "📄"
        name = os.path.relpath(entry["file"], path)
        size = f"  ({entry['size']:,}b)" if entry["type"] == "file" else ""
        click.echo(f"   {dt.strftime('%Y-%m-%d %H:%M:%S')}  {icon} {name}{size}")

    click.echo(f"\n   📊 {len(entries)} entries total, showing last {min(limit, len(entries))}")


@main.command(name="future")
@click.argument("path")
@click.option("--recursive", "-r", is_flag=True, help="Scan recursively")
def future(path, recursive):
    """Find files with timestamps in the future."""
    result = scan_path(path, recursive=recursive)
    now = time.time()

    future_files = [
        f for f in result.files
        if f.mtime > now + 300 or f.atime > now + 300 or f.ctime > now + 300
    ]

    if not future_files:
        click.echo(f"✅ No future-dated files found in {path}")
        return

    click.echo(f"\n🔮 Future-dated files in {path}:\n")
    for f in future_files:
        max_ts = max(f.mtime, f.atime, f.ctime)
        dt = datetime.fromtimestamp(max_ts)
        delta = max_ts - now
        click.echo(f"   🔴 {f.filepath}")
        click.echo(f"      📅 {dt.strftime('%Y-%m-%d %H:%M:%S')} "
                    f"({_format_delta_human(delta)} in the future)")

    click.echo(f"\n   Found {len(future_files)} future-dated file(s)")


def _severity_icon(severity: str) -> str:
    return {
        "clean": "🟢",
        "info": "🔵",
        "suspicious": "🟡",
        "critical": "🔴",
    }.get(severity, "⚪")


def _parse_duration(s: str) -> float:
    """Parse duration string like '7d', '24h', '30m' to seconds."""
    match = re.match(r"(\d+(?:\.\d+)?)\s*([smhd])", s.lower())
    if not match:
        return 86400 * 7  # default 7 days

    value = float(match.group(1))
    unit = match.group(2)
    multipliers = {"s": 1, "m": 60, "h": 3600, "d": 86400}
    return value * multipliers.get(unit, 86400)


def _format_delta_human(seconds: float) -> str:
    seconds = abs(seconds)
    if seconds < 3600:
        return f"{seconds / 60:.0f} minutes"
    elif seconds < 86400:
        return f"{seconds / 3600:.1f} hours"
    else:
        return f"{seconds / 86400:.0f} days"


def entry_point():
    main()


if __name__ == "__main__":
    entry_point()
