"""
🎪 Freakshow CLI — The ringmaster of all 20 tools.
"""
import shutil
import click
from . import TOOLS

BANNER = r"""
  ╔══════════════════════════════════════════════════════╗
  ║                                                      ║
  ║   🎪  T H E   F R E A K S H O W   S U I T E  🎪    ║
  ║                                                      ║
  ║     30 Weird & Creepy Security Tools                 ║
  ║     by bad-antics | nullsec@proton.me                ║
  ║                                                      ║
  ╚══════════════════════════════════════════════════════╝
"""

@click.group()
def main():
    """🎪 nullsec-freakshow — The Freakshow Suite"""
    pass


@main.command(name="roster")
def roster():
    """Show the full roster of freakshow tools."""
    click.echo(BANNER)
    click.echo("  The Full Roster:")
    click.echo("  " + "─" * 50)
    for i, tool in enumerate(TOOLS, 1):
        installed = "✅" if shutil.which(tool["name"]) else "❌"
        click.echo(f"  {installed} {i:2d}. {tool['emoji']} {tool['name']:<15} — {tool['desc']}")
    click.echo("  " + "─" * 50)
    installed_count = sum(1 for t in TOOLS if shutil.which(t["name"]))
    click.echo(f"\n  🎪 {installed_count}/{len(TOOLS)} tools installed.\n")


@main.command(name="summon")
@click.argument("tool_name")
def summon(tool_name):
    """Summon a specific tool by name (runs its --help)."""
    import subprocess
    tool = next((t for t in TOOLS if t["name"] == tool_name), None)
    if not tool:
        click.echo(f"  ❌ Unknown tool: {tool_name}")
        click.echo(f"  Run 'freakshow roster' to see all tools.")
        return
    if not shutil.which(tool_name):
        click.echo(f"  ❌ {tool_name} is not installed.")
        click.echo(f"  Run: pip install {tool['package']}")
        return
    subprocess.run([tool_name, "--help"])


@main.command(name="check")
def check():
    """Check which freakshow tools are installed."""
    click.echo(f"\n🎪 Checking freakshow installation...\n")
    installed = []
    missing = []
    for tool in TOOLS:
        if shutil.which(tool["name"]):
            installed.append(tool)
        else:
            missing.append(tool)

    click.echo(f"  ✅ Installed ({len(installed)}):")
    for t in installed:
        click.echo(f"     {t['emoji']} {t['name']}")

    if missing:
        click.echo(f"\n  ❌ Missing ({len(missing)}):")
        for t in missing:
            click.echo(f"     {t['emoji']} {t['name']} — pip install {t['package']}")

    click.echo(f"\n  🎪 {len(installed)}/{len(TOOLS)} tools ready.\n")


@main.command(name="about")
def about():
    """About the freakshow."""
    click.echo(BANNER)
    click.echo("  The Freakshow Suite is a collection of 30 weird and creepy")
    click.echo("  security tools built by bad-antics for the nullsec project.")
    click.echo()
    click.echo("  Each tool takes a horror/occult theme and applies it to a")
    click.echo("  real security concept — from steganography to process")
    click.echo("  forensics, from network necromancy to password dark arts.")
    click.echo()
    click.echo("  🔗 https://github.com/bad-antics/nullsec")
    click.echo("  📧 nullsec@proton.me")
    click.echo()
    click.echo("  The freakshow never closes. It only moves to the next town.")
    click.echo()


def entry_point():
    main()

if __name__ == "__main__":
    entry_point()
