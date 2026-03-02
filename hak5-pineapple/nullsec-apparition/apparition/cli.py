"""CLI for nullsec-apparition"""
import click
from .engine import scan_env_secrets, audit_path_hijack, check_dangerous_vars, full_apparition_scan

@click.group()
def main():
    """👤 nullsec-apparition — Environment Variable Security Audit"""
    pass

@main.command(name="manifest")
def manifest():
    """Full apparition scan — all environment security checks."""
    click.echo(f"\n👤 Apparitions manifesting from your environment...\n")
    r = full_apparition_scan()
    click.echo(f"   📊 {r['total_env_vars']} environment variables scanned\n")
    if r["secrets"]:
        click.echo(f"   🔑 Secret Leaks ({len(r['secrets'])}):")
        for s in r["secrets"]:
            click.echo(f"      {s['emoji']} [{s['severity']}] {s['variable']} — {s['secret_type']}")
    if r["path_hijack"]:
        click.echo(f"\n   🛤️  PATH Issues ({len(r['path_hijack'])}):")
        for p in r["path_hijack"]:
            click.echo(f"      {p['emoji']} [{p['severity']}] {p['detail']}")
    if r["dangerous_vars"]:
        click.echo(f"\n   ☠️  Dangerous Variables ({len(r['dangerous_vars'])}):")
        for d in r["dangerous_vars"]:
            click.echo(f"      {d['emoji']} [{d['severity']}] {d['variable']} — {d['description']}")
            if d.get("extra"):
                click.echo(f"         ⚡ {d['extra']}")
    total = len(r["secrets"]) + len(r["path_hijack"]) + len(r["dangerous_vars"])
    click.echo(f"\n   👤 {total} apparitions found.\n")

@main.command(name="secrets")
def secrets():
    """Scan for leaked secrets in environment variables."""
    click.echo(f"\n👤 Scanning for secret apparitions...\n")
    results = scan_env_secrets()
    for s in results:
        click.echo(f"   {s['emoji']} [{s['severity']}] ${s['variable']} — {s['secret_type']} ({s['value_preview']})")
    click.echo(f"\n   🔑 {len(results)} secrets found.\n" if results else "\n   ✅ No secrets detected.\n")

@main.command(name="path")
def path():
    """Audit PATH for hijack vulnerabilities."""
    click.echo(f"\n👤 Auditing PATH for hijack vectors...\n")
    results = audit_path_hijack()
    for p in results:
        click.echo(f"   {p['emoji']} [{p['severity']}] {p['detail']}")
    click.echo(f"\n   🛤️ {len(results)} PATH issues found.\n" if results else "\n   ✅ PATH looks clean.\n")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
