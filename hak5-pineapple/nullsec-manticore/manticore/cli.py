"""CLI for nullsec-manticore"""
import click
from .engine import inspect_cert, audit_ciphers, multi_inspect

@click.group()
def main():
    """🦂 nullsec-manticore — TLS/SSL Certificate Chain Analyzer"""
    pass

@main.command(name="sting")
@click.argument("host")
@click.option("--port", type=int, default=443)
def sting(host, port):
    """Sting a host — inspect its TLS certificate."""
    click.echo(f"\n🦂 Manticore stinging {host}:{port}...\n")
    r = inspect_cert(host, port)
    cert = r.get("certificate")
    if cert:
        click.echo(f"   📜 Subject: {cert['subject_cn']} ({cert['subject_org']})")
        click.echo(f"   🏛️  Issuer: {cert['issuer_cn']} ({cert['issuer_org']})")
        click.echo(f"   📅 Valid: {cert['not_before']} → {cert['not_after']}")
        if cert.get("days_remaining") is not None:
            click.echo(f"   ⏰ Days remaining: {cert['days_remaining']}")
        click.echo(f"   🔐 TLS: {cert.get('tls_version', '?')} | Cipher: {cert.get('negotiated_cipher', '?')} ({cert.get('cipher_bits', 0)}-bit)")
        click.echo(f"   🌐 SANs: {cert['san_count']}")
        for san in cert.get("sans", [])[:5]:
            click.echo(f"      {san}")
        click.echo(f"   🔏 SHA256: {cert.get('sha256', 'N/A')[:32]}...")
        if cert.get("is_wildcard"):
            click.echo(f"   🌟 Wildcard certificate")
        if cert.get("is_self_signed"):
            click.echo(f"   ⚠️  SELF-SIGNED")
    click.echo(f"\n   📋 Findings:")
    for f in r["findings"]:
        click.echo(f"      {f['emoji']} [{f['severity']}] {f['detail']}")
    click.echo()

@main.command(name="ciphers")
@click.argument("host")
@click.option("--port", type=int, default=443)
def ciphers(host, port):
    """Audit cipher suites supported by a host."""
    click.echo(f"\n🦂 Auditing ciphers for {host}:{port}...\n")
    results = audit_ciphers(host, port)
    for r in results:
        if r.get("cipher"):
            strength = "💪" if r.get("strong") else "⚠️"
            click.echo(f"   {strength} [{r['config']}] {r['cipher']} ({r['bits']}-bit) {r['version']}")
        else:
            click.echo(f"   ❌ [{r['config']}] {r.get('error', 'Failed')}")
    click.echo()

@main.command(name="sweep")
@click.argument("hosts", nargs=-1)
@click.option("--port", type=int, default=443)
def sweep(hosts, port):
    """Sweep multiple hosts for certificate issues."""
    if not hosts:
        click.echo("   ❌ Provide one or more hostnames")
        return
    click.echo(f"\n🦂 Sweeping {len(hosts)} hosts...\n")
    results = multi_inspect(list(hosts), port)
    for r in results:
        cert = r.get("certificate", {})
        days = cert.get("days_remaining", "?") if cert else "N/A"
        cn = cert.get("subject_cn", "N/A") if cert else "N/A"
        issues = sum(1 for f in r["findings"] if f["severity"] in ("CRITICAL", "HIGH"))
        emoji = "🔴" if issues > 0 else "✅"
        click.echo(f"   {emoji} {r['host']} — CN={cn}, expires in {days}d, {issues} issues")
    click.echo()

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
