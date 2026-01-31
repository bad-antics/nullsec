#!/usr/bin/env python3
"""
AI Entropy Mapper CLI
=====================

Offensive security-style command line interface for AI system
detection, analysis, and vulnerability scanning.

Usage:
    aiem <command> [options]

Commands:
    entropy     Analyze text entropy for AI detection
    detect      Detect AI system type from response
    scan        Scan endpoint for prompt injection vulnerabilities
    map         Map and visualize AI network
    probe       Probe endpoint for AI presence

NullSec Module 49 - For authorized security research only.
"""

import sys
import os
import json
import time
import asyncio
import argparse
from pathlib import Path
from typing import Optional, List, Dict
from datetime import datetime

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
from rich.syntax import Syntax
from rich.markdown import Markdown
from rich.live import Live
from rich.layout import Layout
from rich.text import Text
from rich import box

# Local imports
from .entropy_analyzer import EntropyAnalyzer
from .ai_detector import AIDetector
from .network_mapper import NetworkMapper
from .prompt_scanner import PromptScanner, SeverityLevel


# Initialize console
console = Console()

# ASCII Banner
BANNER = """
[bold red]
    ▄▄▄       ██▓   ▓█████  ███▄    █ ▄▄▄█████▓ ██▀███   ▒█████   ██▓███ ▓██   ██▓
   ▒████▄    ▓██▒   ▓█   ▀  ██ ▀█   █ ▓  ██▒ ▓▒▓██ ▒ ██▒▒██▒  ██▒▓██░  ██▒▒██  ██▒
   ▒██  ▀█▄  ▒██▒   ▒███   ▓██  ▀█ ██▒▒ ▓██░ ▒░▓██ ░▄█ ▒▒██░  ██▒▓██░ ██▓▒ ▒██ ██░
   ░██▄▄▄▄██ ░██░   ▒▓█  ▄ ▓██▒  ▐▌██▒░ ▓██▓ ░ ▒██▀▀█▄  ▒██   ██░▒██▄█▓▒ ▒ ░ ▐██▓░
    ▓█   ▓██▒░██░   ░▒████▒▒██░   ▓██░  ▒██▒ ░ ░██▓ ▒██▒░ ████▓▒░▒██▒ ░  ░ ░ ██▒▓░
    ▒▒   ▓▒█░░▓     ░░ ▒░ ░░ ▒░   ▒ ▒   ▒ ░░   ░ ▒▓ ░▒▓░░ ▒░▒░▒░ ▒▓▒░ ░  ░  ██▒▒▒ 
     ▒   ▒▒ ░ ▒ ░    ░ ░  ░░ ░░   ░ ▒░    ░      ░▒ ░ ▒░  ░ ▒ ▒░ ░▒ ░     ▓██ ░▒░ 
     ░   ▒    ▒ ░      ░      ░   ░ ░   ░        ░░   ░ ░ ░ ░ ▒  ░░       ▒ ▒ ░░  
         ░  ░ ░        ░  ░         ░             ░         ░ ░           ░ ░     
                                                                          ░ ░     
[/bold red]
[bold cyan]    ====[/bold cyan]
[bold cyan]    |[/bold cyan] [bold white]AI ENTROPY MAPPER[/bold white] [dim]v1.0.0[/dim]                    [bold yellow]NullSec Module 49[/bold yellow] [bold cyan]|[/bold cyan]
[bold cyan]    |[/bold cyan] [dim]Detect • Analyze • Map • Exploit[/dim]                                   [bold cyan]|[/bold cyan]
[bold cyan]    ====[/bold cyan]
"""

MINI_BANNER = """[bold red]◢◤ AI ENTROPY MAPPER[/bold red] [dim]v1.0[/dim] [bold cyan]│[/bold cyan] [bold yellow]NullSec[/bold yellow]"""


def print_banner(mini: bool = False):
    """Print the banner."""
    if mini:
        console.print(MINI_BANNER)
    else:
        console.print(BANNER)


def create_status_table(title: str, data: Dict) -> Table:
    """Create a status table from dictionary."""
    table = Table(title=title, box=box.ROUNDED, border_style="cyan")
    table.add_column("Property", style="cyan")
    table.add_column("Value", style="white")
    
    for key, value in data.items():
        if isinstance(value, float):
            value = f"{value:.4f}"
        elif isinstance(value, dict):
            value = json.dumps(value, indent=2)
        table.add_row(str(key), str(value))
    
    return table


def severity_color(severity: str) -> str:
    """Get color for severity level."""
    colors = {
        "info": "blue",
        "low": "green",
        "medium": "yellow",
        "high": "red",
        "critical": "bold red on white",
    }
    return colors.get(severity.lower(), "white")


# ===========================================================================
# ENTROPY COMMAND
# ===========================================================================

def cmd_entropy(args):
    """Analyze text entropy for AI detection."""
    print_banner(mini=True)
    console.print()
    
    analyzer = EntropyAnalyzer(verbose=args.verbose)
    
    # Get input text
    if args.file:
        with open(args.file, 'r') as f:
            text = f.read()
        source = args.file
    elif args.text:
        text = args.text
        source = "CLI input"
    else:
        console.print("[yellow]Enter text to analyze (Ctrl+D to finish):[/yellow]")
        text = sys.stdin.read()
        source = "stdin"
    
    if not text.strip():
        console.print("[red]✗ No text provided[/red]")
        return 1
    
    with console.status("[cyan]Analyzing entropy...[/cyan]", spinner="dots"):
        result = analyzer.analyze(text)
    
    # Display results
    console.print(Panel(
        f"[bold]Source:[/bold] {source}\n"
        f"[bold]Length:[/bold] {len(text)} characters",
        title="[bold cyan]Entropy Analysis[/bold cyan]",
        border_style="cyan",
    ))
    
    # Main metrics table
    metrics_table = Table(box=box.ROUNDED, border_style="cyan")
    metrics_table.add_column("Metric", style="cyan")
    metrics_table.add_column("Value", style="white")
    metrics_table.add_column("Assessment", style="yellow")
    
    metrics_table.add_row(
        "Shannon Entropy",
        f"{result.shannon_entropy:.4f} bits/char",
        "📊 Randomness measure"
    )
    metrics_table.add_row(
        "Normalized Entropy",
        f"{result.normalized_entropy:.2%}",
        "📐 Scaled 0-100%"
    )
    metrics_table.add_row(
        "Compression Ratio",
        f"{result.compression_ratio:.2%}",
        "📦 Redundancy indicator"
    )
    metrics_table.add_row(
        "Serial Correlation",
        f"{result.serial_correlation:.4f}",
        "🔗 Pattern correlation"
    )
    metrics_table.add_row(
        "Unique Token Ratio",
        f"{result.unique_ratio:.2%}",
        "📝 Vocabulary diversity"
    )
    metrics_table.add_row(
        "Bigram Entropy",
        f"{result.bigram_entropy:.4f}",
        "🔤 2-gram randomness"
    )
    metrics_table.add_row(
        "Trigram Entropy",
        f"{result.trigram_entropy:.4f}",
        "🔤 3-gram randomness"
    )
    
    console.print(metrics_table)
    
    # AI Detection result
    ai_color = "red" if result.ai_likelihood > 0.6 else "yellow" if result.ai_likelihood > 0.4 else "green"
    ai_label = "HIGH" if result.ai_likelihood > 0.6 else "MEDIUM" if result.ai_likelihood > 0.4 else "LOW"
    
    console.print(Panel(
        f"[bold {ai_color}]AI LIKELIHOOD: {result.ai_likelihood:.1%} ({ai_label})[/bold {ai_color}]\n"
        f"[dim]Confidence: {result.confidence:.1%}[/dim]",
        title="[bold]Detection Result[/bold]",
        border_style=ai_color,
    ))
    
    # Notes
    if result.analysis_notes:
        console.print("\n[bold cyan]Analysis Notes:[/bold cyan]")
        for note in result.analysis_notes:
            console.print(f"  [dim]•[/dim] {note}")
    
    # JSON output if requested
    if args.json:
        console.print("\n[bold cyan]JSON Output:[/bold cyan]")
        console.print(Syntax(json.dumps(result.to_dict(), indent=2), "json"))
    
    return 0


# ===========================================================================
# DETECT COMMAND
# ===========================================================================

def cmd_detect(args):
    """Detect AI system type from response."""
    print_banner(mini=True)
    console.print()
    
    detector = AIDetector(verbose=args.verbose, load_perplexity_model=args.perplexity)
    
    # Get input
    if args.file:
        with open(args.file, 'r') as f:
            text = f.read()
    elif args.text:
        text = args.text
    else:
        console.print("[yellow]Enter text to analyze (Ctrl+D to finish):[/yellow]")
        text = sys.stdin.read()
    
    if not text.strip():
        console.print("[red]✗ No text provided[/red]")
        return 1
    
    with console.status("[cyan]Running AI detection...[/cyan]", spinner="dots"):
        result = detector.detect(
            text,
            response_time=args.response_time,
            calculate_perplexity=args.perplexity,
        )
    
    # Display results
    is_ai_color = "red" if result.is_ai else "green"
    is_ai_text = "AI DETECTED" if result.is_ai else "HUMAN (likely)"
    
    console.print(Panel(
        f"[bold {is_ai_color}]{is_ai_text}[/bold {is_ai_color}]\n\n"
        f"[bold]System Type:[/bold] {result.system_type.value}\n"
        f"[bold]Confidence:[/bold] {result.confidence:.1%}\n"
        f"[bold]Fingerprint:[/bold] [dim]{result.fingerprint}[/dim]",
        title="[bold cyan]AI Detection Result[/bold cyan]",
        border_style=is_ai_color,
    ))
    
    # Metrics
    if result.entropy_result:
        console.print(f"\n[bold cyan]Entropy Score:[/bold cyan] {result.entropy_result.ai_likelihood:.1%}")
    
    if result.perplexity:
        console.print(f"[bold cyan]Perplexity:[/bold cyan] {result.perplexity:.2f}")
    
    # Behavioral markers
    if result.behavioral_markers:
        console.print("\n[bold cyan]Behavioral Markers Found:[/bold cyan]")
        for marker in result.behavioral_markers:
            console.print(f"  [red]•[/red] {marker}")
    
    # Timing anomalies
    if result.timing_anomalies:
        console.print("\n[bold cyan]Timing Anomalies:[/bold cyan]")
        for anomaly in result.timing_anomalies:
            console.print(f"  [yellow]⚠[/yellow] {anomaly}")
    
    # JSON output
    if args.json:
        console.print("\n[bold cyan]JSON Output:[/bold cyan]")
        console.print(Syntax(json.dumps(result.to_dict(), indent=2), "json"))
    
    return 0


# ===========================================================================
# SCAN COMMAND
# ===========================================================================

def cmd_scan(args):
    """Scan for prompt injection vulnerabilities."""
    print_banner(mini=True)
    console.print()
    
    scanner = PromptScanner(
        verbose=args.verbose,
        delay_between_requests=args.delay,
    )
    
    # Disclaimer
    if not args.accept:
        console.print(Panel(
            scanner.DISCLAIMER,
            title="[bold red]⚠️  LEGAL DISCLAIMER[/bold red]",
            border_style="red",
        ))
        
        if not console.input("\n[bold]Accept terms? [yes/NO]:[/bold] ").lower() in ['yes', 'y']:
            console.print("[red]Scan aborted.[/red]")
            return 1
    
    scanner.accepted_disclaimer = True
    
    # Filter payloads
    payloads = scanner.payloads
    if args.category:
        payloads = scanner.get_payloads_by_category(args.category)
    if args.severity:
        payloads = scanner.get_payloads_by_severity(SeverityLevel(args.severity))
    
    if not payloads:
        console.print("[red]✗ No payloads match criteria[/red]")
        return 1
    
    console.print(f"\n[cyan]Target:[/cyan] {args.url}")
    console.print(f"[cyan]Payloads:[/cyan] {len(payloads)}")
    console.print(f"[cyan]Delay:[/cyan] {args.delay}s\n")
    
    # Run scan
    async def run_scan():
        headers = {}
        if args.api_key:
            headers["Authorization"] = f"Bearer {args.api_key}"
        
        return await scanner.scan_endpoint(
            url=args.url,
            headers=headers,
            payloads=payloads,
            concurrency=args.concurrency,
        )
    
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
        console=console,
    ) as progress:
        task = progress.add_task("[cyan]Scanning...", total=len(payloads))
        
        # Run async scan
        report = asyncio.run(run_scan())
        progress.update(task, completed=len(payloads))
    
    # Results
    vulns = [r for r in report.results if r.vulnerable]
    
    console.print(Panel(
        f"[bold]Scan Complete[/bold]\n\n"
        f"Duration: {report.scan_time:.1f}s\n"
        f"Payloads Tested: {report.total_payloads}\n"
        f"Vulnerabilities: [{'red' if vulns else 'green'}]{len(vulns)}[/]",
        title="[bold cyan]Scan Results[/bold cyan]",
        border_style="cyan",
    ))
    
    if vulns:
        vuln_table = Table(
            title="[bold red]Vulnerabilities Found[/bold red]",
            box=box.ROUNDED,
            border_style="red"
        )
        vuln_table.add_column("Severity", style="bold")
        vuln_table.add_column("Name")
        vuln_table.add_column("Type")
        vuln_table.add_column("Confidence")
        
        for v in sorted(vulns, key=lambda x: x.severity.value, reverse=True):
            vuln_table.add_row(
                f"[{severity_color(v.severity.value)}]{v.severity.value.upper()}[/]",
                v.payload_name,
                v.vulnerability_type.value,
                f"{v.confidence:.0%}",
            )
        
        console.print(vuln_table)
    
    # Export if requested
    if args.output:
        ext = Path(args.output).suffix
        fmt = "json" if ext == ".json" else "text"
        scanner.export_report(report, args.output, fmt)
        console.print(f"\n[green]✓ Report saved to {args.output}[/green]")
    
    return 0


# ===========================================================================
# MAP COMMAND
# ===========================================================================

def cmd_map(args):
    """Map and visualize AI network."""
    print_banner(mini=True)
    console.print()
    
    mapper = NetworkMapper(verbose=args.verbose)
    
    # Load existing map if specified
    if args.load:
        with open(args.load, 'r') as f:
            data = json.load(f)
        console.print(f"[green]✓ Loaded map from {args.load}[/green]")
        # TODO: Implement load
    
    # Add endpoints from file
    if args.endpoints:
        with open(args.endpoints, 'r') as f:
            for line in f:
                url = line.strip()
                if url and not url.startswith('#'):
                    mapper.add_endpoint(url)
    
    # Probe endpoints if requested
    if args.probe:
        urls = args.probe.split(',')
        console.print(f"\n[cyan]Probing {len(urls)} endpoints...[/cyan]")
        
        async def probe_all():
            discovered = await mapper.discover_endpoints(urls)
            for url in discovered:
                mapper.add_endpoint(url, confidence=0.8)
            return discovered
        
        discovered = asyncio.run(probe_all())
        console.print(f"[green]✓ Discovered {len(discovered)} AI endpoints[/green]")
    
    # Link by fingerprint
    edges = mapper.link_by_fingerprint()
    if edges:
        console.print(f"[cyan]✓ Created {edges} fingerprint links[/cyan]")
    
    # Statistics
    stats = mapper.get_statistics()
    
    stats_table = Table(title="[bold cyan]Network Statistics[/bold cyan]", box=box.ROUNDED)
    stats_table.add_column("Metric", style="cyan")
    stats_table.add_column("Value", style="white")
    
    stats_table.add_row("Total Nodes", str(stats.get("total_nodes", 0)))
    stats_table.add_row("Total Edges", str(stats.get("total_edges", 0)))
    stats_table.add_row("Clusters", str(stats.get("clusters", 0)))
    stats_table.add_row("Density", f"{stats.get('density', 0):.4f}")
    
    if stats.get("node_types"):
        types_str = ", ".join(f"{k}: {v}" for k, v in stats["node_types"].items())
        stats_table.add_row("Node Types", types_str)
    
    console.print(stats_table)
    
    # Central nodes
    central = mapper.get_central_nodes(5)
    if central:
        console.print("\n[bold cyan]Most Central Nodes:[/bold cyan]")
        for node_id, score in central:
            node = mapper.nodes.get(node_id)
            label = node.label if node else node_id
            console.print(f"  • {label} [dim](score: {score:.3f})[/dim]")
    
    # Visualize
    if args.visualize:
        output_path = args.output or "ai_network_map.png"
        mapper.visualize(output_path)
        console.print(f"\n[green]✓ Visualization saved to {output_path}[/green]")
    
    # Export
    if args.export:
        mapper.export_json(args.export)
        console.print(f"[green]✓ Network data exported to {args.export}[/green]")
    
    return 0


# ===========================================================================
# PROBE COMMAND
# ===========================================================================

def cmd_probe(args):
    """Quick probe endpoint for AI presence."""
    print_banner(mini=True)
    console.print()
    
    import aiohttp
    
    async def probe():
        detector = AIDetector(verbose=args.verbose)
        
        headers = {}
        if args.api_key:
            headers["Authorization"] = f"Bearer {args.api_key}"
        
        payload = {
            "messages": [{"role": "user", "content": args.prompt or "Hello, who are you?"}]
        }
        
        console.print(f"[cyan]Probing:[/cyan] {args.url}")
        
        start_time = time.time()
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    args.url,
                    json=payload,
                    headers=headers,
                    timeout=aiohttp.ClientTimeout(total=30),
                ) as response:
                    response_time = time.time() - start_time
                    status = response.status
                    
                    console.print(f"[cyan]Status:[/cyan] {status}")
                    console.print(f"[cyan]Response Time:[/cyan] {response_time:.2f}s")
                    
                    if status == 200:
                        data = await response.json()
                        
                        # Extract response text
                        text = ""
                        if isinstance(data, dict):
                            text = (
                                data.get('choices', [{}])[0].get('message', {}).get('content', '') or
                                data.get('response', '') or
                                data.get('text', '') or
                                str(data)
                            )
                        
                        console.print(f"\n[bold cyan]Response Preview:[/bold cyan]")
                        console.print(Panel(text[:500], border_style="dim"))
                        
                        # Run detection
                        result = detector.detect(text, response_time=response_time)
                        
                        is_ai_color = "red" if result.is_ai else "green"
                        console.print(f"\n[bold {is_ai_color}]AI Detected: {result.is_ai}[/bold {is_ai_color}]")
                        console.print(f"[cyan]System Type:[/cyan] {result.system_type.value}")
                        console.print(f"[cyan]Confidence:[/cyan] {result.confidence:.1%}")
                        console.print(f"[cyan]Fingerprint:[/cyan] [dim]{result.fingerprint}[/dim]")
                        
                        return result
                    else:
                        console.print(f"[red]✗ Request failed[/red]")
                        return None
                        
        except Exception as e:
            console.print(f"[red]✗ Error: {e}[/red]")
            return None
    
    asyncio.run(probe())
    return 0


# ===========================================================================
# MAIN
# ===========================================================================

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="AI Entropy Mapper - Security Research Framework",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  aiem entropy -f response.txt           Analyze file for AI patterns
  aiem detect -t "Hello world"           Quick AI detection
  aiem scan https://api.example.com/v1   Scan for vulnerabilities
  aiem probe https://api.example.com/v1  Quick endpoint probe
  aiem map --probe https://api.example.com --visualize

For authorized security research only.
        """,
    )
    
    parser.add_argument(
        "--version", "-V",
        action="version",
        version="AI Entropy Mapper v1.0.0 - NullSec Module 49",
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    # Entropy command
    entropy_parser = subparsers.add_parser("entropy", help="Analyze text entropy")
    entropy_parser.add_argument("-f", "--file", help="File to analyze")
    entropy_parser.add_argument("-t", "--text", help="Text to analyze")
    entropy_parser.add_argument("--json", action="store_true", help="Output JSON")
    entropy_parser.add_argument("-v", "--verbose", action="store_true")
    entropy_parser.set_defaults(func=cmd_entropy)
    
    # Detect command
    detect_parser = subparsers.add_parser("detect", help="Detect AI system type")
    detect_parser.add_argument("-f", "--file", help="File to analyze")
    detect_parser.add_argument("-t", "--text", help="Text to analyze")
    detect_parser.add_argument("--response-time", type=float, help="Response time in seconds")
    detect_parser.add_argument("--perplexity", action="store_true", help="Calculate perplexity (slow)")
    detect_parser.add_argument("--json", action="store_true", help="Output JSON")
    detect_parser.add_argument("-v", "--verbose", action="store_true")
    detect_parser.set_defaults(func=cmd_detect)
    
    # Scan command
    scan_parser = subparsers.add_parser("scan", help="Scan for vulnerabilities")
    scan_parser.add_argument("url", help="Target URL")
    scan_parser.add_argument("--api-key", help="API key for authentication")
    scan_parser.add_argument("--category", help="Payload category filter")
    scan_parser.add_argument("--severity", choices=["info", "low", "medium", "high", "critical"])
    scan_parser.add_argument("--delay", type=float, default=1.0, help="Delay between requests")
    scan_parser.add_argument("--concurrency", type=int, default=3, help="Concurrent requests")
    scan_parser.add_argument("-o", "--output", help="Output file for report")
    scan_parser.add_argument("--accept", action="store_true", help="Accept disclaimer")
    scan_parser.add_argument("-v", "--verbose", action="store_true")
    scan_parser.set_defaults(func=cmd_scan)
    
    # Map command
    map_parser = subparsers.add_parser("map", help="Map AI network")
    map_parser.add_argument("--probe", help="Comma-separated URLs to probe")
    map_parser.add_argument("--endpoints", help="File with endpoint URLs")
    map_parser.add_argument("--load", help="Load existing map")
    map_parser.add_argument("--export", help="Export map to JSON")
    map_parser.add_argument("--visualize", action="store_true", help="Generate visualization")
    map_parser.add_argument("-o", "--output", help="Visualization output file")
    map_parser.add_argument("-v", "--verbose", action="store_true")
    map_parser.set_defaults(func=cmd_map)
    
    # Probe command
    probe_parser = subparsers.add_parser("probe", help="Quick endpoint probe")
    probe_parser.add_argument("url", help="Target URL")
    probe_parser.add_argument("--prompt", help="Custom probe prompt")
    probe_parser.add_argument("--api-key", help="API key")
    probe_parser.add_argument("-v", "--verbose", action="store_true")
    probe_parser.set_defaults(func=cmd_probe)
    
    args = parser.parse_args()
    
    if not args.command:
        print_banner()
        parser.print_help()
        return 0
    
    try:
        return args.func(args)
    except KeyboardInterrupt:
        console.print("\n[yellow]Interrupted.[/yellow]")
        return 130
    except Exception as e:
        console.print(f"[red]✗ Error: {e}[/red]")
        if os.environ.get("DEBUG"):
            raise
        return 1


if __name__ == "__main__":
    sys.exit(main())
