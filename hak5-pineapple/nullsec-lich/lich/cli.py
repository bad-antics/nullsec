"""CLI for nullsec-lich"""
import click
from .engine import list_modules, detect_hidden_modules, check_kernel_taint, rootkit_indicators, full_lich_scan

@click.group()
def main():
    """💀 nullsec-lich — Kernel Module & Rootkit Surface Scanner"""
    pass

@main.command(name="command")
def command_undead():
    """Full lich scan — command all kernel security checks."""
    click.echo(f"\n💀 The lich commands the kernel realm...\n")
    r = full_lich_scan()
    click.echo(f"   📦 {r['module_count']} kernel modules loaded")
    taint = r["taint"]
    if taint["tainted"]:
        click.echo(f"   ⚠️  Kernel TAINTED (value: {taint['taint_value']}):")
        for flag in taint["flags"]:
            click.echo(f"      [{flag['severity']}] {flag['flag']}: {flag['description']}")
    else:
        click.echo(f"   ✅ Kernel untainted")
    if r["hidden"]:
        click.echo(f"\n   👻 Hidden Module Detection ({len(r['hidden'])}):")
        for h in r["hidden"]:
            click.echo(f"      {h['emoji']} [{h['severity']}] {h['detail']}")
    if r["rootkit_indicators"]:
        click.echo(f"\n   ☠️  Rootkit Indicators ({len(r['rootkit_indicators'])}):")
        for ri in r["rootkit_indicators"]:
            click.echo(f"      {ri['emoji']} [{ri['severity']}] {ri['detail']}")
    sus = sum(1 for m in r["modules"] if m["suspicious"])
    oot = sum(1 for m in r["modules"] if m.get("out_of_tree"))
    click.echo(f"\n   💀 {sus} suspicious, {oot} out-of-tree, {len(r['hidden'])} hidden, "
               f"{len(r['rootkit_indicators'])} rootkit indicators.\n")

@main.command(name="modules")
@click.option("--suspicious", is_flag=True, help="Show only suspicious modules")
def modules(suspicious):
    """List loaded kernel modules."""
    click.echo(f"\n💀 Listing kernel modules...\n")
    mods = list_modules()
    for m in mods:
        if suspicious and not m["suspicious"] and not m.get("out_of_tree"):
            continue
        emoji = "☠️" if m["suspicious"] else "🔍" if m.get("out_of_tree") else "📦"
        used = f" (used by: {', '.join(m['used_by'])})" if m["used_by"] else ""
        click.echo(f"   {emoji} {m['name']} {m['size_human']} [{m['state']}]{used}")
    click.echo(f"\n   💀 {len(mods)} modules total.\n")

@main.command(name="taint")
def taint():
    """Check kernel taint flags."""
    click.echo(f"\n💀 Checking kernel taint...\n")
    r = check_kernel_taint()
    if not r["tainted"]:
        click.echo("   ✅ Kernel is UNTAINTED — pure and uncorrupted.\n")
        return
    click.echo(f"   ⚠️  Taint value: {r['taint_value']}")
    for flag in r["flags"]:
        click.echo(f"   [{flag['severity']}] Bit {flag['bit']} ({flag['flag']}): {flag['description']}")
    click.echo()

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
