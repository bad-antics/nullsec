"""CLI for nullsec-necronomicon"""
import json, click
from .engine import perform_dark_ritual, generate_dark_report

@click.group()
def main():
    """📕 nullsec-necronomicon — The Book That Should Not Be Read"""
    pass

@main.command(name="ritual")
@click.option("--target", "-t", default="/", help="Target directory for filesystem analysis")
@click.option("--json-output", "-j", default=None, help="Save JSON report to file")
def ritual(target, json_output):
    """Perform the Dark Ritual — full system assessment."""
    click.echo(f"\n📕 Opening the Necronomicon...\n")
    click.echo(f"   🕯️ The candles flicker. The ritual begins.\n")

    result = perform_dark_ritual(target)
    report = generate_dark_report(result)
    click.echo(report)

    if json_output:
        with open(json_output, 'w') as f:
            json.dump(result, f, indent=2, default=str)
        click.echo(f"\n   💾 Dark report saved to {json_output}")

@main.command(name="chapter")
@click.argument("chapter_name", type=click.Choice(["flesh", "blood", "bones", "spirits", "seals"]))
@click.option("--target", "-t", default="/")
def chapter(chapter_name, target):
    """Read a single chapter of the Necronomicon."""
    click.echo(f"\n📖 Opening Chapter: {chapter_name}...\n")

    result = perform_dark_ritual(target)
    ch = result["chapters"].get(chapter_name, {})

    click.echo(f"   {ch.get('title', chapter_name)}")
    for k, v in ch.items():
        if k not in ("title", "findings"):
            click.echo(f"      {k}: {v}")
    for f in ch.get("findings", []):
        click.echo(f"      {f['emoji']} [{f['severity']}] {f['detail']}")
    if not ch.get("findings"):
        click.echo("      ✅ This chapter reveals nothing... yet.")

@main.command(name="verdict")
def verdict():
    """Get the final dark verdict — threat level assessment."""
    click.echo(f"\n📕 The Necronomicon speaks...\n")
    result = perform_dark_ritual()
    v = result["verdict"]
    click.echo(f"   ⚠️ THREAT LEVEL: {v['threat_level']}")
    click.echo(f"   {v['text']}")
    click.echo(f"   📊 {v['total_findings']} findings ({v['critical']} critical, {v['high']} high)")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
