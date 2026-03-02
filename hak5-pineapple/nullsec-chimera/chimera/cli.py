"""CLI for nullsec-chimera"""
import click
from .engine import detect_chimera, analyze_construction, scan_directory_chimeras

@click.group()
def main():
    """🐉 nullsec-chimera — Binary Polyglot Structure Validator"""
    pass

@main.command(name="scan")
@click.argument("filepath")
def scan(filepath):
    """Scan a file for chimera traits (structural polyglot)."""
    click.echo(f"\n🐉 Analyzing {filepath} for chimera traits...\n")
    r = detect_chimera(filepath)
    if r.get("error"):
        click.echo(f"   ❌ {r['error']}")
        return
    click.echo(f"   📏 Size: {r['size']} bytes")
    for face in r["faces"]:
        tech = face.get("technique", "?")
        click.echo(f"   🎭 {face['format']} — offset 0x{face.get('offset', 0):04x} [{tech}]")
    if r["is_chimera"]:
        click.echo(f"\n   🐉 CHIMERA DETECTED! {len(r['faces'])} faces")
        click.echo(f"   🔧 Construction: {r['construction']} — {r.get('detail', '')}")
        click.echo(f"   ⚠️  Danger: {r['danger_level']}")
    else:
        click.echo(f"\n   ✅ Single-form entity ({len(r['faces'])} face{'s' if len(r['faces']) != 1 else ''})")

@main.command(name="dissect")
@click.argument("filepath")
def dissect(filepath):
    """Deep dissection — how was this chimera built?"""
    click.echo(f"\n🐉 Dissecting {filepath}...\n")
    r = analyze_construction(filepath)
    if not r.get("is_chimera"):
        click.echo("   ✅ Not a chimera — nothing to dissect.")
        return
    click.echo(f"   🔧 Construction: {r['construction']}")
    click.echo(f"   📝 {r.get('detail', '')}")
    for b in r.get("boundaries", []):
        click.echo(f"   🔀 {b['format']} boundary at {b['starts_at']}: {b['hex_at_boundary']}")
    click.echo(f"\n   📊 Entropy map:")
    for region in r.get("entropy_map", [])[:10]:
        bar = "█" * int(region["entropy"]) + "░" * (8 - int(region["entropy"]))
        click.echo(f"      {region['offset']} [{bar}] {region['entropy']} ({region['pattern']})")

@main.command(name="hunt")
@click.argument("directory", default=".")
@click.option("--max", "max_files", type=int, default=500)
def hunt(directory, max_files):
    """Hunt for chimera files in a directory tree."""
    click.echo(f"\n🐉 Hunting chimeras in {directory}...\n")
    chimeras = scan_directory_chimeras(directory, max_files)
    if not chimeras:
        click.echo("   ✅ No chimeras found — this territory is clean.")
        return
    for c in chimeras:
        faces = ', '.join(f['format'] for f in c['faces'])
        click.echo(f"   🐉 {c['filepath']}")
        click.echo(f"      Faces: {faces} | Danger: {c['danger_level']}")
    click.echo(f"\n   🔥 {len(chimeras)} chimeras found.\n")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
