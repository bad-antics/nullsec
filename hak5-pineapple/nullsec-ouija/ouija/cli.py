"""CLI for nullsec-ouija"""
import click
from .board import summon_spirits, seance_scan, read_tombstone

@click.group()
def main():
    """🔮 nullsec-ouija — Summon Spirits From Deleted Files"""
    pass

@main.command(name="summon")
@click.argument("source")
@click.option("--output", "-o", default="./summoned", help="Output directory for recovered spirits")
@click.option("--max-size", type=int, default=10485760)
def summon(source, output, max_size):
    """Carve and recover deleted files from raw binary source."""
    click.echo(f"\n🔮 The board trembles... summoning spirits from {source}...\n")
    spirits = summon_spirits(source, output, max_size=max_size)
    for s in spirits:
        click.echo(f"   {s['emoji']} Spirit #{s['id']}: {s['type']} ({s['size']} bytes) @ {s['hex_offset']}")
        click.echo(f"      → {s['output']}")
    click.echo(f"\n   🕯️ {len(spirits)} spirits summoned from the void.\n")

@main.command(name="seance")
@click.argument("filepath")
def seance(filepath):
    """Scan a file for ghostly remnants of deleted data."""
    click.echo(f"\n🕯️ Conducting séance on {filepath}...\n")
    r = seance_scan(filepath)
    click.echo(f"   📊 File size: {r['size']} bytes")
    click.echo(f"   💀 Death echoes: {len(r['death_echoes'])}")
    click.echo(f"   👻 Magic remnants: {len(r['magic_remnants'])}")
    for echo in r["death_echoes"][:5]:
        click.echo(f"      🗣️ \"{echo['string']}\" @ {echo['offset']}")
    for rem in r["magic_remnants"][:5]:
        click.echo(f"      {rem['emoji']} {rem['type']} @ {rem['offset']}")
    click.echo(f"\n   {r['verdict']}\n")

@main.command(name="tombstone")
@click.argument("filepath")
@click.argument("offset", type=int)
@click.option("--length", "-l", type=int, default=256)
def tombstone(filepath, offset, length):
    """Read raw bytes from a grave (hex dump at offset)."""
    click.echo(f"\n⚰️ Reading the tombstone at 0x{offset:08x}...\n")
    r = read_tombstone(filepath, offset, length)
    click.echo(r["hex_dump"])
    click.echo()

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
