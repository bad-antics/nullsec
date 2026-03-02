"""CLI for nullsec-seance"""
import click
from .necromancy import (resurrect_connections, dns_graveyard, arp_spirits,
                         commune_with_port, network_autopsy)

@click.group()
def main():
    """🕯️ nullsec-seance — Network Necromancy"""
    pass

@main.command(name="resurrect")
def resurrect():
    """Resurrect dead/dying network connections."""
    click.echo("\n🕯️ Summoning the dead connections...\n")
    ghosts = resurrect_connections()
    for g in ghosts:
        click.echo(f"   {g['emoji']} {g['local']} ↔ {g['remote']} [{g['state']}]")
    click.echo(f"\n   ⚰️ {len(ghosts)} spirits found in limbo.\n")

@main.command(name="graveyard")
def graveyard():
    """Explore the DNS graveyard — hosts file and resolver config."""
    click.echo("\n⚰️ Walking through the DNS graveyard...\n")
    graves = dns_graveyard()
    for g in graves:
        click.echo(f"   {g['emoji']} [{g['type']}] {g['ip']} → {', '.join(g['names'])}")
    click.echo(f"\n   🪦 {len(graves)} tombstones found.\n")

@main.command(name="spirits")
def spirits():
    """Read the ARP table — nearby network spirits."""
    click.echo("\n👤 Sensing nearby spirits...\n")
    s = arp_spirits()
    for spirit in s:
        anom = f" ⚠️ {', '.join(spirit['anomalies'])}" if spirit['anomalies'] else ""
        click.echo(f"   {spirit['emoji']} {spirit['ip']} ({spirit['mac']}) via {spirit['device']}{anom}")
    click.echo(f"\n   🔮 {len(s)} spirits detected in the ether.\n")

@main.command(name="commune")
@click.argument("host")
@click.argument("port", type=int)
def commune(host, port):
    """Commune with a specific port — what spirit answers?"""
    click.echo(f"\n🕯️ Communing with {host}:{port}...\n")
    r = commune_with_port(host, port)
    click.echo(f"   👻 Spirit type: {r['spirit_type']}")
    click.echo(f"   💀 Alive: {r['alive']}")
    if r['banner']:
        click.echo(f"   🗣️ Banner: {r['banner']}")
    if r['response']:
        click.echo(f"   📜 Response: {r['response'][:100]}")

@main.command(name="autopsy")
def autopsy():
    """Full network autopsy — routing, interfaces, listeners."""
    click.echo("\n🔪 Performing network autopsy...\n")
    a = network_autopsy()
    click.echo("   📡 Routing table:")
    for r in a["routing_table"]:
        click.echo(f"      {r['iface']}: {r['destination']} via {r['gateway']}")
    click.echo(f"\n   👂 Listening spirits ({len(a['listening_spirits'])}):")
    for l in a["listening_spirits"][:15]:
        click.echo(f"      {l['emoji']} {l['address']}")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
