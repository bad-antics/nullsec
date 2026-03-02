"""
CLI interface for nullsec-miasma.
"""

import sys
import os
import json
import click
from .analyzer import analyze_file, entropy_map, classify_file


@click.group()
def main():
    """🎲 nullsec-miasma — File Entropy Analyzer

    Detect hidden data, weak crypto, and packed malware.
    """
    pass


@main.command(name="scan")
@click.argument("path")
@click.option("--recursive", "-r", is_flag=True, help="Scan directory recursively")
@click.option("--chunk-size", "-c", type=int, default=0,
              help="Analyze in chunks of N bytes")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.option("--threshold", "-t", type=float, default=0.0,
              help="Only show files above this entropy")
def scan(path, recursive, chunk_size, as_json, threshold):
    """Analyze entropy of files."""
    files = []

    if os.path.isfile(path):
        files = [path]
    elif os.path.isdir(path):
        if recursive:
            for root, dirs, fnames in os.walk(path):
                for f in fnames:
                    files.append(os.path.join(root, f))
        else:
            files = [os.path.join(path, f) for f in os.listdir(path)
                     if os.path.isfile(os.path.join(path, f))]
    else:
        click.echo(f"❌ Not found: {path}", err=True)
        sys.exit(1)

    results = []
    for fp in sorted(files):
        try:
            result = analyze_file(fp, chunk_size=chunk_size)
            if result.entropy < threshold:
                continue

            if as_json:
                results.append({
                    "file": fp,
                    "size": result.size,
                    "entropy": round(result.entropy, 4),
                    "classification": result.classification,
                    "threat_level": result.threat_level,
                    "unique_bytes": result.unique_bytes,
                    "chi_square": round(result.chi_square, 2),
                    "anomalies": result.anomalies,
                })
            else:
                icon = _threat_icon(result.threat_level)
                bar = _entropy_bar(result.entropy)
                click.echo(f"{icon} {result.entropy:.4f} {bar} {fp}")
                if result.anomalies:
                    for a in result.anomalies:
                        click.echo(f"   ⚠️  {a}")
                if result.sections:
                    for s in result.sections:
                        if s.flag:
                            click.echo(
                                f"   📍 0x{s.offset:08X}: {s.entropy:.2f} — {s.flag}")
        except (PermissionError, OSError) as e:
            if not as_json:
                click.echo(f"⚪ {fp}: {e}")

    if as_json:
        click.echo(json.dumps(results, indent=2))
    elif not results and as_json:
        click.echo("[]")

    if not as_json:
        click.echo(f"\n🎲 Scanned {len(files)} file(s)")


@main.command(name="map")
@click.argument("filepath")
@click.option("--chunk-size", "-c", type=int, default=4096,
              help="Chunk size in bytes")
def map_cmd(filepath, chunk_size):
    """Show entropy heatmap of a file."""
    if not os.path.isfile(filepath):
        click.echo(f"❌ Not found: {filepath}", err=True)
        sys.exit(1)

    sections = entropy_map(filepath, chunk_size=chunk_size)
    file_size = os.path.getsize(filepath)

    click.echo(f"\n🎲 Entropy Map: {filepath} ({file_size:,} bytes)\n")
    click.echo(f" {'Offset':<12} {'Entropy':<10} {'Map':<42} {'Type'}")
    click.echo(f" {'─' * 12} {'─' * 10} {'─' * 42} {'─' * 16}")

    for s in sections:
        bar = _entropy_bar(s.entropy)
        flag = f"  {s.flag}" if s.flag else ""
        click.echo(f" 0x{s.offset:08X}   {s.entropy:<8.4f}  {bar}  "
                    f"{s.classification}{flag}")

    # Summary
    entropies = [s.entropy for s in sections]
    avg = sum(entropies) / len(entropies) if entropies else 0
    high_sections = sum(1 for s in sections if s.flag.startswith("⚠"))

    click.echo(f"\n 📊 Average: {avg:.4f} | "
               f"Range: {min(entropies):.2f}–{max(entropies):.2f} | "
               f"Flagged: {high_sections}")


@main.command(name="classify")
@click.argument("filepath")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
def classify(filepath, as_json):
    """Classify a file by its entropy signature."""
    if not os.path.isfile(filepath):
        click.echo(f"❌ Not found: {filepath}", err=True)
        sys.exit(1)

    result = classify_file(filepath)

    if as_json:
        click.echo(json.dumps(result, indent=2))
    else:
        icon = _threat_icon(result["threat_level"])
        click.echo(f"{icon} {filepath}")
        click.echo(f"   📊 Entropy: {result['entropy']:.4f}")
        click.echo(f"   🏷️  Type: {result['classification']}")
        click.echo(f"   📏 Size: {result['size']:,} bytes")
        click.echo(f"   🔢 Unique bytes: {result['unique_bytes']}/256")
        if result["extension_mismatch"]:
            click.echo(f"   ⚠️  Extension mismatch! "
                        f"'{result['extension']}' doesn't match entropy profile")
        if result["anomalies"]:
            for a in result["anomalies"]:
                click.echo(f"   ⚠️  {a}")


@main.command(name="compare")
@click.argument("file_a")
@click.argument("file_b")
def compare(file_a, file_b):
    """Compare entropy profiles of two files."""
    r_a = analyze_file(file_a)
    r_b = analyze_file(file_b)

    click.echo(f"\n🎲 Entropy Comparison\n")
    click.echo(f" {'Metric':<25} {'File A':<20} {'File B':<20}")
    click.echo(f" {'─' * 25} {'─' * 20} {'─' * 20}")
    click.echo(f" {'Entropy':<25} {r_a.entropy:<20.4f} {r_b.entropy:<20.4f}")
    click.echo(f" {'Classification':<25} {r_a.classification:<20} {r_b.classification:<20}")
    click.echo(f" {'Size':<25} {r_a.size:<20,} {r_b.size:<20,}")
    click.echo(f" {'Unique bytes':<25} {r_a.unique_bytes:<20} {r_b.unique_bytes:<20}")
    click.echo(f" {'Chi-square':<25} {r_a.chi_square:<20.2f} {r_b.chi_square:<20.2f}")

    diff = abs(r_a.entropy - r_b.entropy)
    if diff < 0.1:
        click.echo(f"\n ✅ Files have very similar entropy profiles (Δ={diff:.4f})")
    elif diff < 1.0:
        click.echo(f"\n 🟡 Moderate entropy difference (Δ={diff:.4f})")
    else:
        click.echo(f"\n 🔴 Significant entropy difference (Δ={diff:.4f})")


def _threat_icon(level: str) -> str:
    return {"clean": "🟢", "suspicious": "🟡", "anomalous": "🔴"}.get(level, "⚪")


def _entropy_bar(entropy: float, width: int = 40) -> str:
    """Generate a visual entropy bar."""
    filled = int((entropy / 8.0) * width)
    empty = width - filled

    # Color code by entropy level
    if entropy > 7.5:
        char = "█"
    elif entropy > 6.5:
        char = "▓"
    elif entropy > 5.0:
        char = "▒"
    else:
        char = "░"

    return char * filled + "░" * empty


def entry_point():
    main()


if __name__ == "__main__":
    entry_point()
