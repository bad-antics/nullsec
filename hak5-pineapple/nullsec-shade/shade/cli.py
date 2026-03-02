"""CLI for nullsec-shade"""
import click
from .engine import (scan_world_writable, find_orphaned_files, audit_capabilities,
                     check_config_perms, find_sgid_binaries, full_shade_scan)

@click.group()
def main():
    """🌑 nullsec-shade — File Permission Anomaly Hunter"""
    pass

@main.command(name="lurk")
def lurk():
    """Full shade scan — hunt all permission anomalies."""
    click.echo(f"\n🌑 The shade lurks through your filesystem...\n")
    r = full_shade_scan()
    sections = [
        ("🔓 World-Writable", r["world_writable"]),
        ("👻 Orphaned Files", r["orphaned"]),
        ("⚡ Capabilities", r["capabilities"]),
        ("📋 Config Permissions", r["config_perms"]),
        ("🔑 SGID Binaries", r["sgid_binaries"]),
    ]
    for title, items in sections:
        if items:
            click.echo(f"   {title} ({len(items)}):")
            for item in items[:10]:
                click.echo(f"      {item['emoji']} [{item['severity']}] {item['detail']}")
            if len(items) > 10:
                click.echo(f"      ... and {len(items) - 10} more")
    total = sum(len(items) for _, items in sections)
    click.echo(f"\n   🌑 {total} permission anomalies found.\n")

@main.command(name="writable")
@click.argument("directory", default="/etc")
def writable(directory):
    """Find world-writable files in a directory."""
    click.echo(f"\n🌑 Scanning {directory} for world-writable files...\n")
    results = scan_world_writable([directory])
    for r in results[:20]:
        click.echo(f"   {r['emoji']} {r['path']} ({r['mode']}) owned by {r['owner']}")
    click.echo(f"\n   🔓 {len(results)} world-writable files found.\n")

@main.command(name="orphans")
def orphans():
    """Find orphaned files (no valid owner/group)."""
    click.echo(f"\n🌑 Hunting orphaned files...\n")
    results = find_orphaned_files()
    for r in results[:20]:
        click.echo(f"   {r['emoji']} {r['path']} — {', '.join(r['reasons'])}")
    click.echo(f"\n   👻 {len(results)} orphaned files found.\n")

@main.command(name="caps")
def caps():
    """Audit file capabilities (privilege escalation surface)."""
    click.echo(f"\n🌑 Scanning for file capabilities...\n")
    results = audit_capabilities()
    for r in results:
        click.echo(f"   {r['emoji']} [{r['severity']}] {r['detail']}")
    click.echo(f"\n   ⚡ {len(results)} files with capabilities.\n")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
