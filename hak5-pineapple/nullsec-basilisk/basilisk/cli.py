"""CLI for nullsec-basilisk"""
import click
from .engine import audit_resolver, check_nameserver

@click.group()
def main():
    """🐍 nullsec-basilisk — DNS Resolver Security Audit"""
    pass

@main.command(name="gaze")
def gaze():
    """Turn the basilisk's gaze on your DNS configuration."""
    click.echo(f"\n🐍 The basilisk gazes upon your DNS...\n")
    r = audit_resolver()
    resolv = r["resolv_conf"]
    click.echo(f"   📄 resolv.conf: {resolv.get('raw_lines', 0)} directives")
    if resolv.get("managed_by"):
        click.echo(f"   🔗 Managed by: {resolv['managed_by']}")
    click.echo(f"   🔎 Search domains: {', '.join(resolv.get('search_domains', [])) or 'none'}")
    click.echo(f"\n   🏠 Nameservers:")
    for ns in r["nameservers"]:
        status = "✅" if ns["reachable"] else "💀"
        latency = f" ({ns['response_time_ms']}ms)" if ns.get("response_time_ms") else ""
        provider = f" [{ns.get('provider', ns['type'])}]" if ns.get("provider") else f" [{ns['type']}]"
        click.echo(f"      {status} {ns['ip']}{provider}{latency}")
    click.echo(f"\n   🔒 Security & Risk:")
    for f in r["findings"]:
        click.echo(f"      {f['emoji']} [{f['severity']}] {f['detail']}")
    click.echo()

@main.command(name="probe")
@click.argument("nameserver")
def probe(nameserver):
    """Probe a specific nameserver's health."""
    click.echo(f"\n🐍 Probing {nameserver}...\n")
    r = check_nameserver(nameserver)
    status = "ALIVE" if r["reachable"] else "DEAD"
    click.echo(f"   Status: {status}")
    click.echo(f"   Type: {r['type']}")
    if r.get("response_time_ms"):
        click.echo(f"   Latency: {r['response_time_ms']}ms")
    if r.get("provider"):
        click.echo(f"   Provider: {r['provider']}")
    for issue in r["issues"]:
        click.echo(f"   ⚠️ {issue}")
    click.echo()

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
