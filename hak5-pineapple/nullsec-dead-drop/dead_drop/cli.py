"""
CLI interface for nullsec-dead-drop.
"""

import sys
import click
from .stego import hide, extract, detect, capacity, generate_carrier


@click.group()
def main():
    """💀 nullsec-dead-drop — Steganographic Message Hiding

    Hide encrypted messages inside PNG images.
    """
    pass


@main.command(name="hide")
@click.option("--image", "-i", required=True, help="Carrier image path")
@click.option("--message", "-m", help="Text message to hide")
@click.option("--payload", "-p", help="File to hide inside image")
@click.option("--key", "-k", required=True, help="Encryption passphrase")
@click.option("--output", "-o", required=True, help="Output stego image path")
def hide_cmd(image, message, payload, key, output):
    """Hide a message or file inside a PNG image."""
    if not message and not payload:
        click.echo("❌ Provide --message or --payload", err=True)
        sys.exit(1)

    try:
        result = hide(image, output,
                      message=message,
                      payload_path=payload,
                      key=key)
        click.echo(f"💀 Dead drop created successfully!")
        click.echo(f"   📦 Original: {result['original_size']} bytes")
        click.echo(f"   🔐 Encrypted: {result['encrypted_size']} bytes")
        click.echo(f"   🖼️  Image: {result['image_size']}")
        click.echo(f"   📊 Capacity used: {result['capacity_used']}")
        click.echo(f"   💾 Output: {result['output']}")
    except Exception as e:
        click.echo(f"❌ {e}", err=True)
        sys.exit(1)


@main.command(name="extract")
@click.option("--image", "-i", required=True, help="Stego image path")
@click.option("--key", "-k", required=True, help="Decryption passphrase")
@click.option("--output", "-o", help="Write to file instead of stdout")
def extract_cmd(image, key, output):
    """Extract a hidden message from a stego image."""
    try:
        result = extract(image, key=key, output_path=output)
        if result:
            click.echo(f"💀 Hidden message:\n")
            click.echo(result)
        else:
            click.echo(f"💀 Payload extracted to {output}")
    except ValueError as e:
        click.echo(f"❌ {e}", err=True)
        sys.exit(1)


@main.command(name="detect")
@click.option("--image", "-i", required=True, help="Image to analyze")
def detect_cmd(image):
    """Detect steganographic content in an image."""
    try:
        result = detect(image)
        icon = "🔴" if result.likelihood > 0.7 else "🟡" if result.likelihood > 0.3 else "🟢"
        click.echo(f"{icon} Steganography likelihood: {result.likelihood:.0%}")
        click.echo(f"   📊 LSB χ²: {result.lsb_chi_square:.4f}")
        click.echo(f"   🔮 Magic bytes: {'Found' if result.has_magic else 'Not found'}")
        if result.indicators:
            click.echo(f"   ⚠️  Indicators:")
            for ind in result.indicators:
                click.echo(f"      • {ind}")
        else:
            click.echo(f"   ✅ No suspicious indicators")
    except Exception as e:
        click.echo(f"❌ {e}", err=True)
        sys.exit(1)


@main.command(name="capacity")
@click.option("--image", "-i", required=True, help="Image to check")
def capacity_cmd(image):
    """Show how much data can be hidden in an image."""
    try:
        cap = capacity(image)
        click.echo(f"🖼️  Image: {cap.width}×{cap.height} ({cap.channels} channels)")
        click.echo(f"📊 Total pixels: {cap.total_pixels:,}")
        click.echo(f"💾 Capacity: {cap.human} ({cap.bytes:,} bytes)")
    except Exception as e:
        click.echo(f"❌ {e}", err=True)
        sys.exit(1)


@main.command()
@click.option("--size", "-s", default="512x512", help="Image dimensions (WxH)")
@click.option("--output", "-o", required=True, help="Output path")
def generate(size, output):
    """Generate a clean carrier image."""
    try:
        w, h = map(int, size.lower().split("x"))
        generate_carrier(w, h, output)
        click.echo(f"🖼️  Generated {w}×{h} carrier image: {output}")
    except Exception as e:
        click.echo(f"❌ {e}", err=True)
        sys.exit(1)


def entry_point():
    main()


if __name__ == "__main__":
    entry_point()
