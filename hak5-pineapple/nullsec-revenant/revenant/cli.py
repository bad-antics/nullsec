"""CLI for nullsec-revenant"""
import click
from .engine import hunt_zombies, hunt_orphans, hunt_sleepers, graveyard_report

@click.group()
def main():
    """🧟 nullsec-revenant — Zombie Process Hunter"""
    pass

@main.command(name="zombies")
def zombies():
    """Hunt zombie processes — the undead."""
    click.echo(f"\n🧟 Hunting zombies...\n")
    z = hunt_zombies()
    for zombie in z:
        click.echo(f"   {zombie['emoji']} PID {zombie['pid']} ({zombie['name']})")
        click.echo(f"      {zombie['verdict']}")
    if not z:
        click.echo("   🌙 No zombies found. The dead rest peacefully.")
    click.echo()

@main.command(name="orphans")
def orphans():
    """Hunt orphan processes — abandoned children."""
    click.echo(f"\n👶 Hunting orphans...\n")
    o = hunt_orphans()
    for orphan in o[:20]:
        click.echo(f"   {orphan['emoji']} PID {orphan['pid']} ({orphan['name']}) — age: {orphan['age_human']}")
    click.echo(f"\n   Found {len(o)} orphans adopted by init.\n")

@main.command(name="sleepers")
@click.option("--min-age", type=float, default=3600, help="Minimum sleep age in seconds")
def sleepers(min_age):
    """Hunt deep-sleeping processes — the comatose."""
    click.echo(f"\n😴 Hunting deep sleepers (>{min_age}s)...\n")
    s = hunt_sleepers(min_age)
    for sleeper in s[:20]:
        click.echo(f"   {sleeper['emoji']} PID {sleeper['pid']} ({sleeper['name']}) — "
                   f"age: {sleeper['age']}, CPU: {sleeper['cpu_time_seconds']}s")
    click.echo(f"\n   Found {len(s)} deep sleepers.\n")

@main.command(name="graveyard")
def graveyard():
    """Full graveyard report — zombies, orphans, and sleepers."""
    click.echo(f"\n⚰️ The Process Graveyard Report\n")
    r = graveyard_report()
    click.echo(f"   📊 Total processes: {r['total_processes']}")
    click.echo(f"   🧟 Zombies: {r['zombies']}")
    click.echo(f"   👶 Orphans: {r['orphans']}")
    click.echo(f"   😴 Deep sleepers: {r['deep_sleepers']}")
    click.echo(f"\n   {r['verdict']}\n")
    if r['zombie_list']:
        click.echo("   === Zombies ===")
        for z in r['zombie_list']:
            click.echo(f"   PID {z['pid']} ({z['name']}) — parent: {z['parent_name']} (PID {z['ppid']})")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
