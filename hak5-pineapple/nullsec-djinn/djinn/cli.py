"""
Djinn CLI — Container Escape Surface Analyzer.

Three wishes, three commands:
  djinn lamp     — Full container escape surface assessment
  djinn wish     — Check capabilities (what powers do we have?)
  djinn smoke    — Check namespace isolation
"""

import json
import click
from .engine import (
    detect_container,
    audit_escape_surface,
    check_capabilities,
    check_namespaces,
    full_djinn_scan,
)


@click.group()
def cli():
    """🧞 nullsec-djinn — Container Escape Surface Analyzer"""
    pass


@cli.command()
@click.option("--json-out", is_flag=True, help="JSON output")
def lamp(json_out):
    """Full container escape surface assessment."""
    data = full_djinn_scan()

    if json_out:
        click.echo(json.dumps(data, indent=2, default=str))
        return

    click.echo("\n🧞 DJINN — Container Escape Surface Analysis\n")
    click.echo("=" * 55)

    # Container detection
    ct = data["container"]
    if ct["in_container"]:
        click.echo(f"\n🫙 Container Detected: {ct['container_type']}")
        if ct["container_id"]:
            click.echo(f"   ID: {ct['container_id']}")
        for ind in ct["indicators"]:
            click.echo(f"   • {ind}")
    else:
        click.echo("\n🚫 Not running inside a detected container")
        click.echo("   (Results still show host surface)")

    # Escape surface
    escape = data["escape_surface"]
    if escape:
        click.echo(f"\n⚡ Escape Vectors: {len(escape)}")
        click.echo("-" * 45)
        for finding in escape:
            emoji = finding.get("emoji", "⚠️")
            sev = finding.get("severity", "INFO")
            click.echo(f"  {emoji} [{sev}] {finding['vector']}")
            click.echo(f"     {finding['detail']}")
    else:
        click.echo("\n✅ No escape vectors detected")

    # Capabilities summary
    caps = data["capabilities"]
    if caps["dangerous"]:
        click.echo(f"\n🔥 Dangerous Capabilities: {len(caps['dangerous'])}")
        for dc in caps["dangerous"]:
            click.echo(f"  🔴 {dc['cap']} ({dc['severity']})")
    else:
        click.echo("\n✅ No dangerous capabilities in effective set")

    click.echo()


@cli.command()
@click.option("--json-out", is_flag=True, help="JSON output")
def wish(json_out):
    """Check Linux capabilities — the djinn's powers."""
    caps = check_capabilities()

    if json_out:
        click.echo(json.dumps(caps, indent=2, default=str))
        return

    click.echo("\n🧞 DJINN — Capability Assessment\n")

    for cap_type in ("effective", "permitted", "bounding"):
        cap_list = caps.get(cap_type, [])
        click.echo(f"  {cap_type.upper()} ({len(cap_list)}):")
        if cap_list:
            for c in cap_list:
                marker = "🔴" if c in {d['cap'] for d in caps['dangerous']} else "  "
                click.echo(f"    {marker} {c}")
        else:
            click.echo("    (none)")
        click.echo()

    if caps["dangerous"]:
        click.echo(f"⚠️  {len(caps['dangerous'])} DANGEROUS capabilities active!")
    click.echo()


@cli.command()
@click.option("--json-out", is_flag=True, help="JSON output")
def smoke(json_out):
    """Check namespace isolation — where the smoke leaks."""
    ns_data = check_namespaces()

    if json_out:
        click.echo(json.dumps(ns_data, indent=2, default=str))
        return

    click.echo("\n🧞 DJINN — Namespace Isolation Check\n")

    if ns_data["namespaces"]:
        for ns in ns_data["namespaces"]:
            shared = "⚠️ SHARED" if ns.get("shared_with_init") else "✅ isolated"
            click.echo(f"  {ns['type']:>6}  {ns['id']}  {shared}")
    else:
        click.echo("  (no namespace info available)")
    click.echo()


def main():
    cli()


if __name__ == "__main__":
    main()
