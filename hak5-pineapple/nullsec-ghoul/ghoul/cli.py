"""CLI for nullsec-ghoul"""
import click
from .engine import scan_loaded_libraries, detect_preload_injection, audit_library_paths, full_ghoul_scan

@click.group()
def main():
    """👹 nullsec-ghoul — Shared Library Injection Detector"""
    pass

@main.command(name="feed")
def feed():
    """Full ghoul feeding — scan everything for library injection."""
    click.echo(f"\n👹 The ghoul feeds on your libraries...\n")
    r = full_ghoul_scan()
    if r["preload_injection"]:
        click.echo(f"   💉 LD_PRELOAD Injections ({len(r['preload_injection'])}):")
        for f in r["preload_injection"]:
            click.echo(f"      {f['emoji']} PID {f['pid']} ({f['process']}): {f['detail']}")
    if r["loaded_libraries"]:
        click.echo(f"\n   📚 Suspicious Libraries ({len(r['loaded_libraries'])}):")
        for f in r["loaded_libraries"][:20]:
            click.echo(f"      {f['emoji']} [{f['severity']}] PID {f['pid']} ({f['process']})")
            click.echo(f"         {f['library']}")
            for reason in f["reasons"]:
                click.echo(f"         ⚠️ {reason}")
    if r["library_paths"]:
        click.echo(f"\n   📁 Library Path Issues ({len(r['library_paths'])}):")
        for f in r["library_paths"]:
            click.echo(f"      {f['emoji']} [{f['severity']}] {f['detail']}")
    total = len(r["preload_injection"]) + len(r["loaded_libraries"]) + len(r["library_paths"])
    click.echo(f"\n   👹 {total} findings total.\n")

@main.command(name="preload")
def preload():
    """Detect LD_PRELOAD injection across all processes."""
    click.echo(f"\n👹 Scanning for preload injections...\n")
    results = detect_preload_injection()
    if not results:
        click.echo("   ✅ No LD_PRELOAD injections detected.\n")
        return
    for r in results:
        click.echo(f"   {r['emoji']} PID {r['pid']} ({r['process']}): {r['detail']}")
    click.echo(f"\n   💉 {len(results)} injections found.\n")

@main.command(name="stalk")
@click.argument("pid", type=int)
def stalk(pid):
    """Stalk a specific process for suspicious libraries."""
    click.echo(f"\n👹 Stalking PID {pid}...\n")
    results = scan_loaded_libraries(pid)
    if not results:
        click.echo("   ✅ No suspicious libraries found.\n")
        return
    for r in results:
        click.echo(f"   {r['emoji']} [{r['severity']}] {r['library']}")
        for reason in r["reasons"]:
            click.echo(f"      ⚠️ {reason}")
    click.echo()

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
