"""
CLI interface for nullsec-sigil.
"""

import sys
import os
import click
from .core import Sigil, compare
from .themes import THEMES


@click.command()
@click.argument("input_text", required=False)
@click.option("--file", "filepath", help="Generate from file contents")
@click.option("--ssh", "ssh_path", help="Generate from SSH public key")
@click.option("--stdin", "use_stdin", is_flag=True, help="Read from stdin")
@click.option("--format", "fmt", type=click.Choice(["svg", "png", "ascii"]),
              default="svg", help="Output format")
@click.option("--output", "-o", help="Output file path")
@click.option("--size", type=int, default=512, help="Canvas size in pixels")
@click.option("--theme", type=click.Choice(list(THEMES.keys())),
              default="dark", help="Color theme")
@click.option("--batch", help="Generate sigils for all files in directory")
@click.option("--compare", "compare_inputs", nargs=2, help="Compare two inputs")
@click.option("--no-label", is_flag=True, help="Omit hash label")
@click.option("--json", "as_json", is_flag=True, help="Output metadata as JSON")
@click.option("-v", "--verbose", is_flag=True, help="Verbose output")
def main(input_text, filepath, ssh_path, use_stdin, fmt, output, size,
         theme, batch, compare_inputs, no_label, as_json, verbose):
    """🔮 nullsec-sigil — Visual Hash Fingerprinting

    Generate unique geometric art from any input.
    """

    # Compare mode
    if compare_inputs:
        result = compare(compare_inputs[0], compare_inputs[1])
        if as_json:
            import json
            click.echo(json.dumps(result, indent=2))
        else:
            icon = "✅" if result["identical"] else "❌"
            click.echo(f"{icon} Identical: {result['identical']}")
            click.echo(f"📏 Distance: {result['distance']}/{result['max_distance']}")
            click.echo(f"📊 Similarity: {result['similarity']:.1%}")
            click.echo(f"🔑 Hash A: {result['hash_a'][:32]}…")
            click.echo(f"🔑 Hash B: {result['hash_b'][:32]}…")
        return

    # Batch mode
    if batch:
        if not os.path.isdir(batch):
            click.echo(f"❌ Not a directory: {batch}", err=True)
            sys.exit(1)

        out_dir = output or "."
        os.makedirs(out_dir, exist_ok=True)
        count = 0

        for entry in sorted(os.listdir(batch)):
            fpath = os.path.join(batch, entry)
            if not os.path.isfile(fpath):
                continue
            try:
                s = Sigil.from_file(fpath, size=size, theme=theme)
                ext = "svg" if fmt == "svg" else fmt
                out_path = os.path.join(out_dir, f"{entry}.sigil.{ext}")
                s.save(out_path)
                if verbose:
                    click.echo(f"🔮 {entry} → {out_path} ({s.hash[:16]}…)")
                count += 1
            except Exception as e:
                if verbose:
                    click.echo(f"⚠️  {entry}: {e}", err=True)

        click.echo(f"\n🔮 Generated {count} sigils in {out_dir}/")
        return

    # Single input mode
    sigil = None

    if filepath:
        sigil = Sigil.from_file(filepath, size=size, theme=theme)
    elif ssh_path:
        with open(ssh_path, "r") as f:
            key_data = f.read().strip()
        sigil = Sigil(key_data, size=size, theme=theme)
    elif use_stdin:
        data = sys.stdin.read()
        sigil = Sigil(data, size=size, theme=theme)
    elif input_text:
        sigil = Sigil(input_text, size=size, theme=theme)
    else:
        click.echo("❌ Provide input text, --file, --ssh, or --stdin", err=True)
        sys.exit(1)

    # JSON metadata mode
    if as_json:
        import json
        meta = {
            "hash": sigil.hash,
            "theme": theme,
            "size": size,
            "palette": {
                "primary": sigil.palette.primary,
                "secondary": sigil.palette.secondary,
                "tertiary": sigil.palette.tertiary,
                "hue": round(sigil.palette.hue, 1),
                "saturation": round(sigil.palette.saturation, 3),
            },
            "params": {
                "ring_sides": sigil.params.ring_sides,
                "mandala_petals": sigil.params.mandala_petals,
                "glyph_sides": sigil.params.glyph_sides,
                "particle_count": sigil.params.particle_count,
            }
        }
        click.echo(json.dumps(meta, indent=2))
        return

    # Render output
    if fmt == "ascii":
        result = sigil.ascii
    else:
        result = sigil.svg

    if output:
        sigil.save(output)
        if verbose:
            click.echo(f"🔮 Saved to {output}")
            click.echo(f"🔑 SHA-256: {sigil.hash}")
    else:
        click.echo(result)


def entry_point():
    main()


if __name__ == "__main__":
    entry_point()
