"""CLI for nullsec-cryptid"""
import click
from .engine import hunt_in_source, hunt_in_binary, hunt_env_secrets

@click.group()
def main():
    """🦎 nullsec-cryptid — Hidden API & Endpoint Hunter"""
    pass

@main.command(name="hunt")
@click.argument("directory")
@click.option("--recursive/--no-recursive", default=True)
def hunt(directory, recursive):
    """Hunt for cryptid endpoints in source code."""
    click.echo(f"\n🦎 Hunting cryptids in {directory}...\n")
    findings = hunt_in_source(directory, recursive)
    for f in findings:
        tags = ' '.join(f'[{t}]' for t in f['tags'])
        click.echo(f"   {f['emoji']} ({f['suspicion']}/10) {f['endpoint']} {tags}")
        click.echo(f"      📁 {f['file']}:{f['line']}")
    click.echo(f"\n   🔍 {len(findings)} cryptid endpoints discovered.\n")

@main.command(name="binary")
@click.argument("filepath")
def binary(filepath):
    """Hunt for endpoints hidden in binary files."""
    click.echo(f"\n🦎 Dissecting binary {filepath}...\n")
    findings = hunt_in_binary(filepath)
    for f in findings:
        click.echo(f"   {f['emoji']} [{f['type']}] {f['value']} @ {f['offset']} (sus: {f['suspicion']})")
    click.echo(f"\n   🔍 {len(findings)} entities found.\n")

@main.command(name="secrets")
@click.argument("directory")
def secrets(directory):
    """Hunt for secrets lurking in config files."""
    click.echo(f"\n🔑 Hunting secrets in {directory}...\n")
    findings = hunt_env_secrets(directory)
    for f in findings:
        click.echo(f"   {f['emoji']} {f['file']}:{f['line']}")
        click.echo(f"      {f['preview']}")
    click.echo(f"\n   🔍 {len(findings)} secrets found lurking.\n")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
