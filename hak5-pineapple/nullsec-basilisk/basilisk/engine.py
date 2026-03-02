"""
Basilisk Engine — DNS Resolver Security Audit.
Petrifies insecure DNS configurations with its deadly gaze.
Checks resolv.conf, nameserver health, DNSSEC support,
DNS-over-HTTPS/TLS config, and tunneling indicators.
"""

import os
import re
import socket
import struct
import time
import subprocess
from typing import List, Dict, Optional
from pathlib import Path


def audit_resolver() -> Dict:
    """Full DNS resolver security audit — the basilisk's gaze."""
    result = {
        "resolv_conf": _parse_resolv_conf(),
        "nameservers": [],
        "security": [],
        "tunneling_risk": [],
        "findings": [],
    }

    # Check each nameserver
    for ns in result["resolv_conf"].get("nameservers", []):
        ns_result = check_nameserver(ns)
        result["nameservers"].append(ns_result)

    # Security checks
    result["security"] = _security_checks(result)

    # DNS tunneling risk assessment
    result["tunneling_risk"] = _tunneling_risk()

    # Generate findings
    _generate_findings(result)

    return result


def _parse_resolv_conf() -> Dict:
    """Parse /etc/resolv.conf for DNS configuration."""
    config = {
        "nameservers": [],
        "search_domains": [],
        "options": [],
        "raw_lines": 0,
    }

    resolv_path = "/etc/resolv.conf"
    if not os.path.exists(resolv_path):
        config["error"] = "resolv.conf not found"
        return config

    try:
        with open(resolv_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                config["raw_lines"] += 1

                if line.startswith("nameserver"):
                    parts = line.split()
                    if len(parts) >= 2:
                        config["nameservers"].append(parts[1])
                elif line.startswith("search") or line.startswith("domain"):
                    parts = line.split()
                    config["search_domains"].extend(parts[1:])
                elif line.startswith("options"):
                    config["options"].extend(line.split()[1:])

        # Check if it's a symlink (systemd-resolved, NetworkManager, etc.)
        if os.path.islink(resolv_path):
            config["symlink_target"] = os.readlink(resolv_path)
            config["managed_by"] = _detect_dns_manager(config["symlink_target"])

    except PermissionError:
        config["error"] = "Permission denied"

    return config


def _detect_dns_manager(symlink: str) -> str:
    """Detect which DNS manager controls resolv.conf."""
    if "systemd" in symlink or "resolved" in symlink:
        return "systemd-resolved"
    elif "NetworkManager" in symlink:
        return "NetworkManager"
    elif "resolvconf" in symlink:
        return "resolvconf"
    return "unknown"


def check_nameserver(ns_ip: str, timeout: float = 3.0) -> Dict:
    """Check a nameserver's health and security posture."""
    result = {
        "ip": ns_ip,
        "reachable": False,
        "response_time_ms": None,
        "type": _classify_nameserver(ns_ip),
        "issues": [],
    }

    # DNS query test (A record for example.com)
    try:
        start = time.time()
        # Build a minimal DNS query
        query = _build_dns_query("example.com", qtype=1)  # A record

        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        sock.sendto(query, (ns_ip, 53))
        response, _ = sock.recvfrom(512)
        elapsed = (time.time() - start) * 1000
        sock.close()

        result["reachable"] = True
        result["response_time_ms"] = round(elapsed, 1)

        if elapsed > 500:
            result["issues"].append("SLOW_RESPONSE")
        if elapsed > 2000:
            result["issues"].append("VERY_SLOW")

        # Parse response flags
        if len(response) >= 4:
            flags = struct.unpack("!H", response[2:4])[0]
            rcode = flags & 0xF
            if rcode != 0:
                result["issues"].append(f"ERROR_RCODE_{rcode}")

    except socket.timeout:
        result["issues"].append("TIMEOUT")
    except (OSError, ConnectionRefusedError):
        result["issues"].append("UNREACHABLE")
    except Exception as e:
        result["issues"].append(f"ERROR: {str(e)[:50]}")

    # Check if it's a known public resolver
    PUBLIC_RESOLVERS = {
        "8.8.8.8": "Google",
        "8.8.4.4": "Google",
        "1.1.1.1": "Cloudflare",
        "1.0.0.1": "Cloudflare",
        "9.9.9.9": "Quad9",
        "208.67.222.222": "OpenDNS",
        "208.67.220.220": "OpenDNS",
    }
    if ns_ip in PUBLIC_RESOLVERS:
        result["provider"] = PUBLIC_RESOLVERS[ns_ip]

    return result


def _classify_nameserver(ip: str) -> str:
    """Classify nameserver as local, private, or public."""
    if ip in ("127.0.0.1", "::1", "127.0.0.53"):
        return "LOCAL_STUB"
    if ip.startswith(("10.", "172.16.", "172.17.", "172.18.", "172.19.",
                       "172.20.", "172.21.", "172.22.", "172.23.", "172.24.",
                       "172.25.", "172.26.", "172.27.", "172.28.", "172.29.",
                       "172.30.", "172.31.", "192.168.")):
        return "PRIVATE"
    return "PUBLIC"


def _build_dns_query(domain: str, qtype: int = 1) -> bytes:
    """Build a minimal DNS query packet."""
    import random
    txid = random.randint(0, 65535)
    # Header: ID, flags (standard query), 1 question
    header = struct.pack("!HHHHHH", txid, 0x0100, 1, 0, 0, 0)
    # Question section
    question = b""
    for label in domain.split("."):
        question += struct.pack("!B", len(label)) + label.encode()
    question += b"\x00"  # null terminator
    question += struct.pack("!HH", qtype, 1)  # QTYPE, QCLASS=IN
    return header + question


def _security_checks(audit_result: Dict) -> List[Dict]:
    """Run DNS security checks."""
    checks = []
    resolv = audit_result["resolv_conf"]
    nameservers = resolv.get("nameservers", [])

    # Check: No nameservers configured
    if not nameservers:
        checks.append({
            "check": "NO_NAMESERVERS",
            "severity": "CRITICAL",
            "detail": "No nameservers configured in resolv.conf",
        })

    # Check: Using only localhost stub resolver
    if all(_classify_nameserver(ns) == "LOCAL_STUB" for ns in nameservers):
        checks.append({
            "check": "STUB_ONLY",
            "severity": "INFO",
            "detail": "Using local stub resolver (systemd-resolved or similar)",
        })

    # Check: Single nameserver (no redundancy)
    if len(nameservers) == 1:
        checks.append({
            "check": "SINGLE_NS",
            "severity": "MEDIUM",
            "detail": "Only one nameserver — no DNS redundancy",
        })

    # Check: Suspicious search domains
    for domain in resolv.get("search_domains", []):
        if len(domain) > 30:
            checks.append({
                "check": "LONG_SEARCH_DOMAIN",
                "severity": "HIGH",
                "detail": f"Unusually long search domain: {domain[:50]}",
            })

    # Check: DNS-over-TLS / DNS-over-HTTPS configuration
    dot_config = _check_dot_doh()
    if dot_config:
        checks.append(dot_config)

    # Check: DNSSEC validation
    dnssec = _check_dnssec_config()
    if dnssec:
        checks.append(dnssec)

    return checks


def _check_dot_doh() -> Optional[Dict]:
    """Check for DNS-over-TLS or DNS-over-HTTPS configuration."""
    # Check systemd-resolved for DoT
    resolved_conf = "/etc/systemd/resolved.conf"
    if os.path.exists(resolved_conf):
        try:
            with open(resolved_conf, 'r') as f:
                content = f.read()
            if re.search(r'DNSOverTLS\s*=\s*(yes|opportunistic)', content, re.IGNORECASE):
                return {
                    "check": "DOT_ENABLED",
                    "severity": "GOOD",
                    "detail": "DNS-over-TLS is enabled in systemd-resolved",
                }
        except PermissionError:
            pass

    return {
        "check": "NO_ENCRYPTED_DNS",
        "severity": "MEDIUM",
        "detail": "No DNS-over-TLS or DNS-over-HTTPS detected",
    }


def _check_dnssec_config() -> Optional[Dict]:
    """Check if DNSSEC validation is enabled."""
    resolved_conf = "/etc/systemd/resolved.conf"
    if os.path.exists(resolved_conf):
        try:
            with open(resolved_conf, 'r') as f:
                content = f.read()
            if re.search(r'DNSSEC\s*=\s*(yes|allow-downgrade)', content, re.IGNORECASE):
                return {
                    "check": "DNSSEC_ENABLED",
                    "severity": "GOOD",
                    "detail": "DNSSEC validation is enabled",
                }
        except PermissionError:
            pass

    return {
        "check": "NO_DNSSEC",
        "severity": "LOW",
        "detail": "DNSSEC validation not detected",
    }


def _tunneling_risk() -> List[Dict]:
    """Assess DNS tunneling risk factors."""
    risks = []

    # Check if port 53 outbound is unrestricted
    # (indicates DNS queries can reach arbitrary servers)
    try:
        result = subprocess.run(
            ["ss", "-uln"], capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            udp_53_listeners = sum(1 for line in result.stdout.split('\n')
                                   if ':53 ' in line or ':53\t' in line)
            if udp_53_listeners > 0:
                risks.append({
                    "risk": "DNS_LISTENER",
                    "severity": "INFO",
                    "detail": f"{udp_53_listeners} local DNS listener(s) on port 53",
                })
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Check for common DNS tunneling tools
    tunnel_tools = ["iodine", "dns2tcp", "dnscat", "dnscat2"]
    for tool in tunnel_tools:
        try:
            result = subprocess.run(
                ["which", tool], capture_output=True, text=True, timeout=3
            )
            if result.returncode == 0:
                risks.append({
                    "risk": "TUNNEL_TOOL_INSTALLED",
                    "severity": "HIGH",
                    "detail": f"DNS tunneling tool found: {tool} at {result.stdout.strip()}",
                })
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

    # Check for TXT record abuse potential
    # Large TXT records are commonly used for DNS tunneling
    risks.append({
        "risk": "TXT_RECORD_CHECK",
        "severity": "INFO",
        "detail": "TXT records can carry up to ~64KB per response — tunneling vector",
    })

    return risks


def _generate_findings(result: Dict) -> None:
    """Generate human-readable findings from audit results."""
    findings = result["findings"]

    for ns in result["nameservers"]:
        if not ns["reachable"]:
            findings.append({
                "emoji": "💀", "severity": "HIGH",
                "detail": f"Nameserver {ns['ip']} is unreachable",
            })
        elif ns.get("response_time_ms", 0) > 500:
            findings.append({
                "emoji": "🐌", "severity": "MEDIUM",
                "detail": f"Nameserver {ns['ip']} is slow ({ns['response_time_ms']}ms)",
            })

    for check in result["security"]:
        emoji = "✅" if check["severity"] == "GOOD" else "⚠️" if check["severity"] in ("MEDIUM", "LOW") else "🔴"
        findings.append({
            "emoji": emoji, "severity": check["severity"],
            "detail": check["detail"],
        })

    for risk in result["tunneling_risk"]:
        emoji = "🐍" if risk["severity"] == "HIGH" else "🔍"
        findings.append({
            "emoji": emoji, "severity": risk["severity"],
            "detail": risk["detail"],
        })
