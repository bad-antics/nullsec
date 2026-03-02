"""CLI for nullsec-skinwalker"""
import click
from .hunter import scan_skinwalkers, hunt_doppelganger, autopsy

@click.group()
def main():
    """🐺 nullsec-skinwalker — It Wears Your Process's Face"""
    pass

@main.command(name="scan")
@click.option("--verbose", "-v", is_flag=True, help="Show all processes, not just skinwalkers")
def scan(verbose):
    """Scan all processes for shapeshifting behavior."""
    click.echo("\n🐺 The skinwalker hunt begins...\n")
    findings = scan_skinwalkers(verbose=verbose)
    walkers = [f for f in findings if f["is_skinwalker"]]
    click.echo(f"   Scanned {len(findings)} processes, found {len(walkers)} skinwalkers\n")
    for f in walkers:
        click.echo(f"   ═══ PID {f['pid']} ({f['comm']}) ═══")
        for a in f["anomalies"]:
            click.echo(f"   {a['emoji']} [{a['severity']}] {a['type']}: {a['detail']}")
        click.echo()
    if not walkers:
        click.echo("   🌙 The night is quiet... no skinwalkers found.")
        click.echo("   But that doesn't mean they aren't watching.\n")

@main.command(name="hunt")
@click.argument("name")
def hunt(name):
    """Hunt all processes claiming to be NAME."""
    click.echo(f"\n🐺 Hunting everything that calls itself '{name}'...\n")
    results = hunt_doppelganger(name)
    for r in results:
        click.echo(f"   PID {r['pid']}: {r['comm']}")
        click.echo(f"      📍 {r['exe']}")
        click.echo(f"      🔑 Hash: {r['exe_hash'] or '???'}")
        click.echo()
    if not results:
        click.echo(f"   Nothing calls itself '{name}'. Or... it's hiding better than we thought.\n")

@main.command(name="autopsy")
@click.argument("pid", type=int)
def autopsy_cmd(pid):
    """Deep inspection of a process — peel back its skin."""
    click.echo(f"\n🔪 Performing autopsy on PID {pid}...\n")
    r = autopsy(pid)
    if not r["exists"]:
        click.echo(f"   {r['verdict']}")
        return
    for k, v in r.items():
        if k not in ("exists", "status"):
            click.echo(f"   {k}: {v}")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
