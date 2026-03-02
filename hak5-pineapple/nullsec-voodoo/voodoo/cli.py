"""CLI for nullsec-voodoo"""
import click
from .engine import read_memory_map, stick_pin, curse_scan, create_voodoo_doll

@click.group()
def main():
    """🪡 nullsec-voodoo — Stick Pins In Process Memory"""
    pass

@main.command(name="map")
@click.argument("pid", type=int)
def map_cmd(pid):
    """View the memory map of a process."""
    click.echo(f"\n🪡 Reading memory map of PID {pid}...\n")
    regions = read_memory_map(pid)
    for r in regions:
        curse_marker = " 🔥" if r['cursed'] else ""
        click.echo(f"   {r['emoji']} {r['address']} {r['permissions']} {r['size_human']:>10} "
                   f"[{r['type']}]{curse_marker}")
        for c in r['cursed']:
            click.echo(f"      ⚠️ {c}")
    click.echo(f"\n   📊 {len(regions)} regions mapped.\n")

@main.command(name="pin")
@click.argument("pid", type=int)
@click.argument("address")
@click.option("--length", "-l", type=int, default=256)
def pin(pid, address, length):
    """Stick a pin into a specific memory address (hex)."""
    addr = int(address, 16) if address.startswith("0x") else int(address)
    click.echo(f"\n🪡 Sticking pin at 0x{addr:016x} in PID {pid}...\n")
    r = stick_pin(pid, addr, length)
    if r['success']:
        click.echo(r['hex_dump'])
        if r['strings']:
            click.echo(f"\n   🔤 Strings: {', '.join(r['strings'][:10])}")
        if r['patterns']:
            for p in r['patterns']:
                click.echo(f"   {p}")
        click.echo(f"\n   📊 Entropy: {r['entropy']}")
    else:
        click.echo(f"   ❌ {r.get('error', 'Access denied')}")

@main.command(name="curse")
@click.argument("pid", type=int)
def curse(pid):
    """Scan process memory for corruption curses (heap spray, NOP sleds, etc)."""
    click.echo(f"\n🪡 Scanning PID {pid} for memory curses...\n")
    curses = curse_scan(pid)
    if not curses:
        click.echo("   ✅ No corruption curses detected — this one is clean.\n")
        return
    for c in curses:
        click.echo(f"   {c['type']} [{c['severity']}]")
        click.echo(f"      📍 {c['address']} in {c['region']} ({c['region_addr']})")
        click.echo(f"      💀 {c['detail']}")
    crit = sum(1 for c in curses if c['severity'] == 'CRITICAL')
    high = sum(1 for c in curses if c['severity'] == 'HIGH')
    click.echo(f"\n   🩸 {len(curses)} curses found ({crit} critical, {high} high).\n")

@main.command(name="doll")
@click.argument("pid", type=int)
def doll(pid):
    """Create a voodoo doll — complete process profile."""
    click.echo(f"\n🪡 Creating voodoo doll for PID {pid}...\n")
    d = create_voodoo_doll(pid)
    if not d['exists']:
        click.echo(f"   {d['verdict']}")
        return
    click.echo(f"   🏷️ Name: {d.get('name', '???')}")
    click.echo(f"   💾 RSS: {d.get('memory_rss', '???')}")
    click.echo(f"   🧵 Threads: {d.get('threads', '???')}")
    click.echo(f"   🗺️ Regions: {d['total_regions']} ({d['total_memory_human']})")
    click.echo(f"   🔥 Cursed regions: {d['cursed_regions']}")
    for curse in d.get('curses', []):
        click.echo(f"      ⚠️ {curse}")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
