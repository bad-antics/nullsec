"""CLI for nullsec-imp"""
import click
from .engine import audit_history, detect_history_evasion, full_imp_scan, _find_history_files

@click.group()
def main():
    """😈 nullsec-imp — Shell History Auditor"""
    pass

@main.command(name="mischief")
def mischief():
    """Full imp mischief — audit all history files."""
    click.echo(f"\n😈 The imp digs through your history...\n")
    r = full_imp_scan()
    click.echo(f"   📂 Found {len(r['history_files'])} history files:")
    for hf in r["history_files"]:
        click.echo(f"      📄 {hf['path']} ({hf['user']}, {hf['size']} bytes)")
    for audit in r["audits"]:
        if audit.get("error"):
            continue
        click.echo(f"\n   📜 {audit['file']} ({audit['lines_scanned']}/{audit.get('total_lines', '?')} lines):")
        if audit["secrets"]:
            click.echo(f"      🔑 Secrets ({len(audit['secrets'])}):")
            for s in audit["secrets"][:10]:
                click.echo(f"         {s['emoji']} L{s['line_num']}: {s['type']}")
                click.echo(f"            {s['command'][:80]}")
        if audit["dangerous"]:
            click.echo(f"      💣 Dangerous ({len(audit['dangerous'])}):")
            for d in audit["dangerous"][:10]:
                click.echo(f"         {d['emoji']} [{d['severity']}] L{d['line_num']}: {d['type']}")
        if audit["evasion"]:
            click.echo(f"      🕵️ Evasion ({len(audit['evasion'])}):")
            for e in audit["evasion"]:
                click.echo(f"         {e['emoji']} L{e['line_num']}: {e['type']}")
    if r["evasion"]:
        click.echo(f"\n   🕵️ Active Evasion Detected:")
        for e in r["evasion"]:
            click.echo(f"      {e['emoji']} [{e['severity']}] {e['detail']}")
    click.echo()

@main.command(name="snoop")
@click.argument("history_file", required=False)
def snoop(history_file):
    """Snoop through a specific history file."""
    click.echo(f"\n😈 Snooping through history...\n")
    r = audit_history(history_file)
    if r.get("error"):
        click.echo(f"   ❌ {r['error']}")
        return
    total = len(r["secrets"]) + len(r["dangerous"]) + len(r["evasion"])
    click.echo(f"   📜 {r['file']}: {r['lines_scanned']} lines scanned")
    click.echo(f"   🔑 {len(r['secrets'])} secrets | 💣 {len(r['dangerous'])} dangerous | 🕵️ {len(r['evasion'])} evasion")
    for s in r["secrets"][:5]:
        click.echo(f"      {s['emoji']} {s['type']}: {s['command'][:80]}")
    for d in r["dangerous"][:5]:
        click.echo(f"      {d['emoji']} {d['type']}: {d['command'][:80]}")
    click.echo()

@main.command(name="evasion")
def evasion():
    """Check for active history evasion."""
    click.echo(f"\n😈 Checking for history evasion...\n")
    results = detect_history_evasion()
    if not results:
        click.echo("   ✅ No history evasion detected.\n")
        return
    for r in results:
        click.echo(f"   {r['emoji']} [{r['severity']}] {r['detail']}")
    click.echo()

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
