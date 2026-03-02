"""
CLI interface for nullsec-hexspeak.
"""

import sys
import os
import json
import click
from .engine import encode, decode, search, random_words, is_hexspeak, scan_bytes, generate_poem
from .dictionary import CATEGORIES


@click.group()
def main():
    """🧙 nullsec-hexspeak — Hexadecimal Word Encoder

    Speak in machine code. DEADBEEF walks into a CAFE.
    """
    pass


@main.command(name="encode")
@click.argument("text")
def encode_cmd(text):
    """Encode text into hexspeak."""
    result = encode(text)
    click.echo(f"📝 Input:  {text}")
    click.echo(f"🔮 Hex:    0x{result.replace(' ', '_')}")
    click.echo(f"💻 Raw:    {result}")

    # Show if it's a valid hex number
    clean = result.replace(" ", "")
    if all(c in "0123456789ABCDEF" for c in clean) and clean:
        click.echo(f"🔢 Value:  {int(clean, 16)}")


@main.command(name="decode")
@click.argument("hex_str")
def decode_cmd(hex_str):
    """Decode a hex string into readable text."""
    result = decode(hex_str)
    info = is_hexspeak(hex_str)

    click.echo(f"💻 Input:   {hex_str}")
    click.echo(f"📝 Decoded: {result}")
    if info["known_word"]:
        click.echo(f"📖 Known:   {info['meaning']}")
    if info["hex_value"] is not None:
        click.echo(f"🔢 Value:   {info['hex_value']}")


@main.command(name="search")
@click.argument("query")
@click.option("--category", "-c", type=click.Choice(list(CATEGORIES.keys())),
              help="Filter by category")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
def search_cmd(query, category, as_json):
    """Search the hexspeak dictionary."""
    results = search(query, category=category)

    if as_json:
        click.echo(json.dumps(results, indent=2))
        return

    if not results:
        click.echo(f"❌ No hexspeak words matching '{query}'")
        return

    click.echo(f"\n🔍 Results for '{query}':\n")
    for r in results:
        click.echo(f"   {r['hex']:<16} {r['meaning']:<20} [{r['category']}]")

    click.echo(f"\n   Found {len(results)} word(s)")


@main.command(name="random")
@click.option("--count", "-n", type=int, default=10, help="Number of words")
@click.option("--min-len", type=int, default=4, help="Minimum hex length")
@click.option("--max-len", type=int, default=12, help="Maximum hex length")
def random_cmd(count, min_len, max_len):
    """Generate random hexspeak words."""
    words = random_words(count=count, min_len=min_len, max_len=max_len)

    click.echo(f"\n🎲 Random Hexspeak:\n")
    for w in words:
        click.echo(f"   {w['hex']:<16} → {w['meaning']}")


@main.command(name="check")
@click.argument("hex_str")
def check_cmd(hex_str):
    """Check if a string is valid hexspeak."""
    result = is_hexspeak(hex_str)

    click.echo(f"\n🔎 Checking: {hex_str}\n")
    click.echo(f"   Valid hex:    {'✅' if result['valid_hex'] else '❌'}")
    click.echo(f"   Known word:   {'✅ ' + result['meaning'] if result['known_word'] else '❌'}")
    click.echo(f"   Decoded:      {result['decoded'] or 'N/A'}")
    click.echo(f"   Readable:     {'✅' if result['readable'] else '❌'}")
    if result["hex_value"] is not None:
        click.echo(f"   Decimal:      {result['hex_value']}")


@main.command(name="poem")
@click.option("--lines", "-n", type=int, default=4, help="Number of lines")
def poem_cmd(lines):
    """Generate a hexspeak poem."""
    poem = generate_poem(lines=lines)

    click.echo(f"\n🧙 Hexspeak Poem:\n")
    for line in poem:
        click.echo(f"   {line['text']}")
    click.echo()
    click.echo(f"   --- in hex ---")
    for line in poem:
        click.echo(f"   {line['hex']}")


@main.command(name="scan")
@click.argument("filepath")
@click.option("--min-len", type=int, default=4, help="Minimum word length")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
def scan_cmd(filepath, min_len, as_json):
    """Scan a binary file for hexspeak patterns."""
    if not os.path.isfile(filepath):
        click.echo(f"❌ Not found: {filepath}", err=True)
        sys.exit(1)

    with open(filepath, "rb") as f:
        data = f.read()

    findings = scan_bytes(data, min_word_len=min_len)

    if as_json:
        click.echo(json.dumps(findings, indent=2))
        return

    if not findings:
        click.echo(f"🔍 No hexspeak patterns found in {filepath}")
        return

    click.echo(f"\n🔍 Hexspeak patterns in {filepath}:\n")
    for f in findings:
        click.echo(f"   {f['hex_offset']}  {f['hex']:<16} → {f['meaning']}")

    click.echo(f"\n   Found {len(findings)} pattern(s)")


@main.command(name="categories")
def categories_cmd():
    """List all hexspeak categories."""
    click.echo(f"\n📂 Hexspeak Categories:\n")
    for cat, words in sorted(CATEGORIES.items()):
        click.echo(f"   {cat:<15} ({len(words)} words)")


def entry_point():
    main()


if __name__ == "__main__":
    entry_point()
