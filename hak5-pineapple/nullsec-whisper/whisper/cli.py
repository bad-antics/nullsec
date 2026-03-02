"""CLI for nullsec-whisper"""
import sys, os, click
from .spectral import generate_whisper, render_spectrogram, detect_whisper

@click.group()
def main():
    """👁️ nullsec-whisper — Voices From The Static"""
    pass

@main.command(name="generate")
@click.option("--message", "-m", required=True, help="Message to hide")
@click.option("--output", "-o", required=True, help="Output WAV path")
@click.option("--duration", "-d", type=float, default=5.0)
def generate(message, output, duration):
    """Generate a haunted WAV file with hidden spectrogram message."""
    result = generate_whisper(message, output, duration=duration)
    click.echo(f"👁️  The whisper has been recorded...")
    click.echo(f"   🎵 {result['output']}")
    click.echo(f"   ⏱️  {result['duration']}s | {result['freq_range']}")
    click.echo(f"   👻 Message: \"{result['message']}\"")
    click.echo(f"   📊 View spectrogram to reveal the hidden text")

@main.command(name="listen")
@click.argument("filepath")
@click.option("--width", type=int, default=80)
def listen(filepath, width):
    """Render spectrogram — see the voices in the static."""
    click.echo(f"\n👁️  Listening to the static in {filepath}...\n")
    spec = render_spectrogram(filepath, width=width)
    click.echo(spec)
    click.echo(f"\n   ...can you see them?")

@main.command(name="detect")
@click.argument("filepath")
def detect(filepath):
    """Detect hidden voices in audio files."""
    result = detect_whisper(filepath)
    click.echo(f"\n👁️  Scanning the frequencies...")
    click.echo(f"   {result['verdict']}")
    click.echo(f"   📊 Likelihood: {result['likelihood']:.0%}")
    click.echo(f"   🔊 Hot bands: {result['hot_bands']}/{result['total_bands']}")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
