"""CLI for nullsec-grimoire"""
import click
from .engine import (conjure_password, conjure_passphrase, analyze_password,
                     generate_credential_set)

@click.group()
def main():
    """📖 nullsec-grimoire — The Dark Book of Password Arts"""
    pass

@main.command(name="conjure")
@click.option("--length", "-l", type=int, default=24)
@click.option("--style", type=click.Choice(["chaos", "hex", "rune", "sigil", "leet"]), default="chaos")
def conjure(length, style):
    """Conjure a password from the dark arts."""
    r = conjure_password(length, style)
    click.echo(f"\n📖 The grimoire speaks...\n")
    click.echo(f"   🔑 {r['password']}")
    click.echo(f"   📊 Entropy: {r['entropy_bits']} bits")
    click.echo(f"   💪 Strength: {r['strength']}")
    click.echo(f"   🔒 SHA-256: {r['hash_sha256'][:32]}...")

@main.command(name="phrase")
@click.option("--words", "-w", type=int, default=5)
@click.option("--separator", "-s", default="-")
def phrase(words, separator):
    """Conjure a dark passphrase."""
    r = conjure_passphrase(words, separator)
    click.echo(f"\n📖 The dark incantation...\n")
    click.echo(f"   🗝️ {r['passphrase']}")
    click.echo(f"   📊 Entropy: {r['entropy_bits']} bits")
    click.echo(f"   💪 Strength: {r['strength']}")

@main.command(name="analyze")
@click.argument("password")
def analyze(password):
    """Analyze a password's dark power."""
    r = analyze_password(password)
    click.echo(f"\n📖 Analyzing the incantation...\n")
    click.echo(f"   📏 Length: {r['length']}")
    click.echo(f"   📊 Entropy: {r['entropy_bits']} bits")
    click.echo(f"   💪 Strength: {r['strength']}")
    click.echo(f"   🎰 Crack time: {r['crack_time']}")
    click.echo(f"   🔤 Classes: {r['char_classes']}/4")
    for w in r["weaknesses"]:
        click.echo(f"   ⚠️ {w}")

@main.command(name="credentials")
@click.option("--count", "-c", type=int, default=5)
def credentials(count):
    """Generate a full set of dark credentials."""
    click.echo(f"\n📖 The grimoire creates {count} identities...\n")
    creds = generate_credential_set(count)
    for c in creds:
        click.echo(f"   #{c['id']} 👤 {c['username']}")
        click.echo(f"       🔑 {c['password']}")
        click.echo(f"       💪 {c['strength']} ({c['entropy']} bits)")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
