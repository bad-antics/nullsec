"""CLI for nullsec-gremlin"""
import json, click
from .engine import detect_anomalies, generate_honeypot, filesystem_fingerprint

@click.group()
def main():
    """👹 nullsec-gremlin — Filesystem Chaos Agent"""
    pass

@main.command(name="haunt")
@click.argument("directory")
@click.option("--recursive/--no-recursive", default=True)
def haunt(directory, recursive):
    """Detect filesystem anomalies — things that shouldn't be there."""
    click.echo(f"\n� The gremlin is searching {directory}...\n")
    anomalies = detect_anomalies(directory, recursive)
    for a in anomalies:
        click.echo(f"   📁 {a['path']} [{a['mode']}] ({a['size']} bytes)")
        for an in a['anomalies']:
            click.echo(f"      {an['emoji']} [{an['severity']}] {an['type']}: {an['detail']}")
    click.echo(f"\n   🔍 {len(anomalies)} anomalous files found.\n")

@main.command(name="honeypot")
@click.argument("directory")
@click.option("--count", type=int, default=8)
def honeypot(directory, count):
    """Generate honeypot decoy files that look juicy."""
    click.echo(f"\n🍯 Planting honeypot in {directory}...\n")
    decoys = generate_honeypot(directory, count)
    for d in decoys:
        click.echo(f"   {d['emoji']} {d['name']} ({d['size']} bytes)")
    click.echo(f"\n   🪤 {len(decoys)} traps set. Waiting for intruders...\n")

@main.command(name="fingerprint")
@click.argument("directory")
@click.option("--output", "-o", default=None)
def fingerprint(directory, output):
    """Generate filesystem fingerprint for change detection."""
    click.echo(f"\n� Fingerprinting {directory}...\n")
    fp = filesystem_fingerprint(directory)
    click.echo(f"   🔑 Signature: {fp['signature']}")
    click.echo(f"   📊 Total files: {fp['total_files']}")
    if output:
        with open(output, 'w') as f:
            json.dump(fp, f, indent=2)
        click.echo(f"   💾 Saved to {output}")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
