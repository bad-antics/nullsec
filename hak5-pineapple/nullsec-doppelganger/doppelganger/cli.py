"""CLI for nullsec-doppelganger"""
import click
from .engine import identify_true_face, scan_directory, find_twins, polyglot_check

@click.group()
def main():
    """👥 nullsec-doppelganger — File Identity Crisis Detector"""
    pass

@main.command(name="unmask")
@click.argument("filepath")
def unmask(filepath):
    """Reveal the TRUE face of a file."""
    click.echo(f"\n👥 Unmasking {filepath}...\n")
    r = identify_true_face(filepath)
    click.echo(f"   🏷️ Claims: {r['claimed_ext'] or '(no extension)'}")
    click.echo(f"   🧬 Reality: {r['true_type']}")
    click.echo(f"   🎭 Identity Crisis: {'YES' if r['has_identity_crisis'] else 'No'}")
    for a in r["anomalies"]:
        click.echo(f"   {a['emoji']} [{a['severity']}] {a['type']}: {a['detail']}")

@main.command(name="scan")
@click.argument("directory")
@click.option("--recursive/--no-recursive", default=True)
def scan(directory, recursive):
    """Scan directory for impostor files."""
    click.echo(f"\n👥 Scanning for impostors in {directory}...\n")
    results = scan_directory(directory, recursive)
    for r in results:
        click.echo(f"   🎭 {r['filepath']}")
        for a in r["anomalies"]:
            click.echo(f"      {a['emoji']} {a['detail']}")
    click.echo(f"\n   Found {len(results)} files with identity crises.\n")

@main.command(name="twins")
@click.argument("directory")
def twins(directory):
    """Find identical files with different names — true doppelgängers."""
    click.echo(f"\n👯 Searching for twins in {directory}...\n")
    twins_list = find_twins(directory)
    for t in twins_list:
        click.echo(f"   {t['emoji']} Hash {t['hash']} ({t['count']} copies):")
        for f in t["files"]:
            click.echo(f"      → {f}")
    click.echo(f"\n   Found {len(twins_list)} sets of doppelgängers.\n")

@main.command(name="polyglot")
@click.argument("filepath")
def polyglot(filepath):
    """Check if a file is a polyglot — multiple identities at once."""
    r = polyglot_check(filepath)
    click.echo(f"\n🎭 Polyglot analysis of {filepath}...\n")
    for face in r["faces"]:
        marker = "★" if face["at_start"] else "·"
        click.echo(f"   {marker} {face['type']} @ {face['offset']}")
    click.echo(f"\n   {r['verdict']}\n")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
