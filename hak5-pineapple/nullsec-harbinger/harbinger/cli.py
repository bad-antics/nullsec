"""CLI for nullsec-harbinger"""
import click
from .engine import listen_to_file, listen_to_directory, wail_analysis, listen_to_journald

@click.group()
def main():
    """🔔 nullsec-harbinger — Log Scream Detector"""
    pass

@main.command(name="listen")
@click.argument("filepath")
@click.option("--max-lines", type=int, default=10000)
def listen(filepath, max_lines):
    """Listen to a single log file for screams."""
    click.echo(f"\n� The harbinger listens to {filepath}...\n")
    screams = listen_to_file(filepath, max_lines)
    for s in screams:
        click.echo(f"   {s['emoji']} [{s['severity']}] {s['type']}: {s['content'][:100]}")
    analysis = wail_analysis(screams)
    click.echo(f"\n   {analysis['verdict']}\n")

@main.command(name="haunt")
@click.argument("directory")
def haunt(directory):
    """Listen to all log files in a directory."""
    click.echo(f"\n� The harbinger haunts {directory}...\n")
    screams = listen_to_directory(directory)
    analysis = wail_analysis(screams)
    click.echo(f"   📊 Total screams: {analysis['total']}")
    if analysis.get('by_type'):
        click.echo(f"   📋 By type:")
        for t, c in analysis['by_type'].items():
            click.echo(f"      {t}: {c}")
    if analysis.get('loudest_file'):
        click.echo(f"   📢 Loudest: {analysis['loudest_file'][0]} ({analysis['loudest_file'][1]} screams)")
    click.echo(f"\n   {analysis['verdict']}\n")

@main.command(name="journal")
@click.option("--lines", "-n", type=int, default=500)
@click.option("--unit", "-u", default=None, help="Filter by systemd unit")
def journal(lines, unit):
    """Listen to systemd journal for screams."""
    click.echo(f"\n� The harbinger reads the journal...\n")
    screams = listen_to_journald(lines, unit)
    for s in screams[:20]:
        click.echo(f"   {s['emoji']} [{s['severity']}] {s['type']}: {s['content'][:80]}")
    analysis = wail_analysis(screams)
    click.echo(f"\n   {analysis['verdict']}\n")

@main.command(name="scream")
@click.argument("filepath")
@click.argument("pattern")
def scream(filepath, pattern):
    """Search for a custom scream pattern in a log file."""
    click.echo(f"\n� Listening for '{pattern}' in {filepath}...\n")
    try:
        with open(filepath, 'r', errors='replace') as f:
            for num, line in enumerate(f, 1):
                if pattern.lower() in line.lower():
                    click.echo(f"   💀 L{num}: {line.strip()[:120]}")
    except (PermissionError, FileNotFoundError) as e:
        click.echo(f"   ❌ {e}")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
