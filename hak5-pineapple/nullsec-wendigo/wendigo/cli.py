"""CLI for nullsec-wendigo"""
import click
from .engine import (hunt_cpu_devourers, hunt_memory_devourers,
                     hunt_fd_devourers, system_vitals)

@click.group()
def main():
    """🦌 nullsec-wendigo — Resource Devourer Detector"""
    pass

@main.command(name="cpu")
@click.option("--threshold", type=float, default=5.0, help="CPU% threshold")
def cpu(threshold):
    """Hunt CPU-devouring wendigos."""
    click.echo(f"\n🦌 Hunting CPU devourers (>{threshold}%)...\n")
    devourers = hunt_cpu_devourers(threshold)
    for d in devourers:
        click.echo(f"   {d['emoji']} PID {d['pid']} ({d['name']}): {d['cpu_percent']}% CPU [{d['hunger']}]")
    click.echo(f"\n   🍖 {len(devourers)} wendigos found feasting on CPU.\n")

@main.command(name="memory")
@click.option("--threshold", type=float, default=50.0, help="Memory MB threshold")
def memory(threshold):
    """Hunt memory-devouring wendigos."""
    click.echo(f"\n🦌 Hunting memory devourers (>{threshold}MB)...\n")
    devourers = hunt_memory_devourers(threshold)
    for d in devourers:
        click.echo(f"   {d['emoji']} PID {d['pid']} ({d['name']}): {d['rss_mb']}MB RSS, "
                   f"{d['vms_mb']}MB VMS, {d['threads']} threads [{d['hunger']}]")
    click.echo(f"\n   🍖 {len(devourers)} wendigos found gorging on memory.\n")

@main.command(name="fds")
@click.option("--threshold", type=int, default=100, help="FD count threshold")
def fds(threshold):
    """Hunt file-descriptor-hoarding wendigos."""
    click.echo(f"\n🦌 Hunting FD hoarders (>{threshold} FDs)...\n")
    devourers = hunt_fd_devourers(threshold)
    for d in devourers:
        click.echo(f"   {d['emoji']} PID {d['pid']} ({d['name']}): {d['total_fds']} FDs "
                   f"(sockets:{d['sockets']} pipes:{d['pipes']} files:{d['files']})")
    click.echo(f"\n   🦷 {len(devourers)} hoarders found.\n")

@main.command(name="vitals")
def vitals():
    """Check system vital signs."""
    click.echo(f"\n🦌 Checking system vitals...\n")
    v = system_vitals()
    click.echo(f"   📊 Load: {v.get('load_1m', '?')} / {v.get('load_5m', '?')} / {v.get('load_15m', '?')}")
    click.echo(f"   💾 Memory: {v.get('mem_used_percent', '?')}% used "
               f"({v.get('mem_available_mb', '?'):.0f}MB free)")
    click.echo(f"   💽 Disk: {v.get('disk_used_percent', '?')}% used "
               f"({v.get('disk_used_gb', '?')}GB / {v.get('disk_total_gb', '?')}GB)")
    click.echo(f"   🔢 Processes: {v.get('total_processes', '?')}")
    click.echo(f"\n   {v['verdict']}\n")

def entry_point():
    main()
if __name__ == "__main__":
    entry_point()
