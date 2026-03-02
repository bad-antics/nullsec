"""CLI for nullsec-wraith"""
import json, click
from .engine import (craft_phantom_packet, generate_traffic_pattern,
                     scan_open_ports, network_ghost_map)

@click.group()
def main():
    """👻 nullsec-wraith — Ghost Network Packets"""
    pass

@main.command(name="craft")
@click.option("--dst", default="127.0.0.1", help="Destination IP")
@click.option("--port", type=int, default=0, help="Destination port")
@click.option("--payload", default="", help="Payload message")
@click.option("--protocol", type=click.Choice(["tcp", "udp"]), default="tcp")
def craft(dst, port, payload, protocol):
    """Craft a wraith packet — see its anatomy without sending."""
    pkt = craft_phantom_packet(dst, port, payload, protocol)
    click.echo(f"\n👻 Wraith Packet #{pkt['phantom_id']}\n")
    click.echo(f"   L2: {pkt['layer2']['src_mac']} → {pkt['layer2']['dst_mac']}")
    click.echo(f"   L3: {pkt['layer3']['src_ip']} → {pkt['layer3']['dst_ip']} TTL={pkt['layer3']['ttl']}")
    click.echo(f"   L4: {pkt['layer4']['type']} :{pkt['layer4']['src_port']} → :{pkt['layer4']['dst_port']}")
    if pkt['layer4']['flags']:
        click.echo(f"       Flags: {pkt['layer4']['flags']}")
    click.echo(f"   📦 Payload: {pkt['payload']['size']} bytes | Entropy: {pkt['payload']['entropy']}")
    click.echo(f"   🔮 Hex: {pkt['payload']['hex'][:60]}...")

@main.command(name="traffic")
@click.option("--pattern", type=click.Choice(["heartbeat", "exfil", "scan", "ghost"]), default="ghost")
@click.option("--count", type=int, default=5)
def traffic(pattern, count):
    """Generate wraith traffic patterns for analysis."""
    click.echo(f"\n👻 Generating '{pattern}' traffic pattern ({count} packets)...\n")
    packets = generate_traffic_pattern(pattern, count)
    for i, pkt in enumerate(packets):
        delay = pkt.get("timing", {}).get("delay_ms", 0)
        click.echo(f"   #{i+1} {pkt['layer3']['src_ip']}:{pkt['layer4']['src_port']} → "
                   f"{pkt['layer3']['dst_ip']}:{pkt['layer4']['dst_port']} "
                   f"[{pkt['layer4']['type']}] +{delay}ms")

@main.command(name="haunt")
@click.option("--target", default="127.0.0.1")
def haunt(target):
    """Scan for wraith listeners (open ports) on a target."""
    click.echo(f"\n👻 Haunting {target}... looking for spirits...\n")
    results = scan_open_ports(target)
    for r in results:
        click.echo(f"   {r['emoji']} :{r['port']} ({r['service']}) — {r['status']}")
    alive = sum(1 for r in results if r["status"] == "ALIVE")
    click.echo(f"\n   🕯️ {alive} spirits found listening in the dark.\n")

@main.command(name="map")
def ghost_map():
    """Map the local network neighborhood."""
    click.echo(f"\n👻 Mapping the spectral realm...\n")
    m = network_ghost_map()
    click.echo(f"   🏠 Hostname: {m['hostname']}")
    for iface in m["interfaces"]:
        click.echo(f"   📡 {iface['addr']} ({iface['scope']})")
    click.echo(f"   🔗 Active connections: {len(m['connections'])}")
    for conn in m["connections"][:10]:
        click.echo(f"      {conn['type']} {conn['state']} {conn['local']}")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
