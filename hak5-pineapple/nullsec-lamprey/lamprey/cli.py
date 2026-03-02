"""CLI for nullsec-lamprey"""
import click
from .engine import (scan_requirements, scan_package_json, generate_typosquats,
                     scan_installed_packages)

@click.group()
def main():
    """🐟 nullsec-lamprey — Dependency Infection Analyzer"""
    pass

@main.command(name="scan")
@click.argument("filepath")
def scan(filepath):
    """Scan requirements.txt or package.json for parasites."""
    click.echo(f"\n🐟 Scanning {filepath} for lamprey dependencies...\n")
    if filepath.endswith('.json'):
        findings = scan_package_json(filepath)
    else:
        findings = scan_requirements(filepath)
    for f in findings:
        click.echo(f"   🎯 {f['package']}")
        for a in f["anomalies"]:
            click.echo(f"      {a['emoji']} [{a['severity']}] {a['type']}: {a['detail']}")
    click.echo(f"\n   🔬 {len(findings)} latched dependencies found.\n")

@main.command(name="typosquat")
@click.argument("package_name")
def typosquat(package_name):
    """Generate typosquat variants for a package name."""
    click.echo(f"\n🐟 Generating lamprey clones of '{package_name}'...\n")
    variants = generate_typosquats(package_name)
    for v in variants:
        click.echo(f"   🎭 {v['variant']} [{v['technique']}] — {v['detail']}")
    click.echo(f"\n   ☣️ {len(variants)} potential typosquats generated.\n")

@main.command(name="installed")
def installed():
    """Scan installed pip packages for parasitic indicators."""
    click.echo("\n🐟 Scanning installed packages for lampreys...\n")
    findings = scan_installed_packages()
    for f in findings:
        click.echo(f"   🎯 {f['package']}=={f['version']}")
        for a in f["anomalies"]:
            click.echo(f"      {a['emoji']} {a['detail']}")
    click.echo(f"\n   {len(findings)} suspicious packages found.\n")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
