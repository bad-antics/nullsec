"""
Mothman CLI — Network Interface Promiscuity & ARP Anomaly Detector.

Three sightings, three commands:
  mothman sighting  — Full network anomaly scan
  mothman wings     — Check for promiscuous interfaces
  mothman bridge    — Audit ARP cache for anomalies
"""

import json
import click
from .engine import (
    detect_promiscuous,
    audit_arp_cache,
    check_interfaces,
    full_mothman_scan,
)


@click.group()
def cli():
    """🦇 nullsec-mothman — Network Interface Promiscuity & ARP Anomaly Detector"""
    pass


@cli.command()
@click.option("--json-out", is_flag=True, help="JSON output")
def sighting(json_out):
    """Full network anomaly scan — the mothman sees all."""
    data = full_mothman_scan()

    if json_out:
        click.echo(json.dumps(data, indent=2, default=str))
        return

    click.echo("\n🦇 MOTHMAN — Network Anomaly Detection\n")
    click.echo("=" * 55)

    # Promiscuous interfaces
    promisc = data["promiscuous"]
    if promisc:
        click.echo(f"\n👁️ Promiscuous Interfaces: {len(promisc)}")
        click.echo("-" * 45)
        for p in promisc:
            click.echo(f"  {p['emoji']} [{p['severity']}] {p['detail']}")
    else:
        click.echo("\n✅ No promiscuous interfaces detected")

    # ARP anomalies
    arp = data["arp_audit"]
    total_anomalies = len(arp["anomalies"]) + len(arp["duplicate_macs"])
    click.echo(f"\n📡 ARP Cache: {len(arp['entries'])} entries, {total_anomalies} anomalies")
    if arp["duplicate_macs"]:
        click.echo("-" * 45)
        for dm in arp["duplicate_macs"]:
            click.echo(f"  {dm['emoji']} {dm['detail']}")
    if arp["anomalies"]:
        for a in arp["anomalies"]:
            click.echo(f"  {a['emoji']} [{a['type']}] {a['detail']}")

    # Interface inventory
    ifaces = data["interfaces"]
    click.echo(f"\n🔌 Network Interfaces: {len(ifaces)}")
    click.echo("-" * 45)
    for iface in ifaces:
        state = "UP" if iface.get("up") else "DOWN"
        desc = iface.get("type_desc", "unknown")
        mac = iface.get("address", "N/A")
        click.echo(f"  {'🟢' if state == 'UP' else '⚪'} {iface['name']:12s} {desc:16s} {mac} [{state}]")
        for w in iface.get("warnings", []):
            click.echo(f"    ⚠️  {w}")

    click.echo()


@cli.command()
@click.option("--json-out", is_flag=True, help="JSON output")
def wings(json_out):
    """Check for promiscuous interfaces — moths drawn to the light."""
    promisc = detect_promiscuous()

    if json_out:
        click.echo(json.dumps(promisc, indent=2, default=str))
        return

    click.echo("\n🦇 MOTHMAN — Promiscuous Interface Detection\n")
    if promisc:
        for p in promisc:
            click.echo(f"  {p['emoji']} [{p['severity']}] {p['detail']}")
    else:
        click.echo("  ✅ No promiscuous interfaces detected")
    click.echo()


@cli.command()
@click.option("--json-out", is_flag=True, help="JSON output")
def bridge(json_out):
    """Audit ARP cache for anomalies — who's crossing the bridge?"""
    arp = audit_arp_cache()

    if json_out:
        click.echo(json.dumps(arp, indent=2, default=str))
        return

    click.echo("\n🦇 MOTHMAN — ARP Cache Audit\n")
    click.echo(f"  Entries: {len(arp['entries'])}")

    if arp["duplicate_macs"]:
        click.echo(f"\n  🔴 Duplicate MACs ({len(arp['duplicate_macs'])}):")
        for dm in arp["duplicate_macs"]:
            click.echo(f"    {dm['detail']}")

    if arp["duplicate_ips"]:
        click.echo(f"\n  🔴 Duplicate IPs ({len(arp['duplicate_ips'])}):")
        for di in arp["duplicate_ips"]:
            click.echo(f"    {di['detail']}")

    if arp["anomalies"]:
        click.echo(f"\n  ⚠️ Other Anomalies ({len(arp['anomalies'])}):")
        for a in arp["anomalies"]:
            click.echo(f"    {a['emoji']} {a['detail']}")

    if not arp["duplicate_macs"] and not arp["duplicate_ips"] and not arp["anomalies"]:
        click.echo("  ✅ ARP cache looks clean")

    click.echo()


def main():
    cli()


if __name__ == "__main__":
    main()
