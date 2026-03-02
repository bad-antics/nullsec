"""
Manticore Engine — TLS/SSL Certificate Chain Analyzer.
A beast with three heads: certificate inspection, chain validation,
and cipher audit. Its sting is finding your weakest TLS link.
"""

import ssl
import socket
import hashlib
import time
from datetime import datetime, timezone
from typing import List, Dict, Optional


def inspect_cert(host: str, port: int = 443, timeout: float = 5.0) -> Dict:
    """Inspect a host's TLS certificate — the manticore's first head."""
    result = {
        "host": host,
        "port": port,
        "certificate": None,
        "chain_length": 0,
        "findings": [],
    }

    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE  # We want to inspect, not reject

        with socket.create_connection((host, port), timeout=timeout) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as ssock:
                cert = ssock.getpeercert(binary_form=False)
                cert_bin = ssock.getpeercert(binary_form=True)
                cipher = ssock.cipher()
                version = ssock.version()

                if not cert:
                    # Try with verification disabled fully
                    result["findings"].append({
                        "emoji": "🔴", "severity": "CRITICAL",
                        "detail": "No certificate presented",
                    })
                    return result

                # Parse certificate
                cert_info = _parse_cert(cert, cert_bin)
                cert_info["negotiated_cipher"] = cipher[0] if cipher else "unknown"
                cert_info["cipher_bits"] = cipher[2] if cipher and len(cipher) > 2 else 0
                cert_info["tls_version"] = version
                result["certificate"] = cert_info

                # Analyze
                _analyze_cert(cert_info, host, result)

    except ssl.SSLCertVerificationError as e:
        result["findings"].append({
            "emoji": "🔴", "severity": "CRITICAL",
            "detail": f"Certificate verification failed: {str(e)[:100]}",
        })
    except ssl.SSLError as e:
        result["findings"].append({
            "emoji": "⚠️", "severity": "HIGH",
            "detail": f"SSL error: {str(e)[:100]}",
        })
    except (socket.timeout, ConnectionRefusedError, OSError) as e:
        result["findings"].append({
            "emoji": "💀", "severity": "HIGH",
            "detail": f"Connection failed: {str(e)[:100]}",
        })

    return result


def _parse_cert(cert: dict, cert_bin: bytes) -> Dict:
    """Parse certificate fields into a clean dict."""
    info = {}

    # Subject
    subject = dict(x[0] for x in cert.get('subject', ()))
    info["subject_cn"] = subject.get('commonName', 'N/A')
    info["subject_org"] = subject.get('organizationName', 'N/A')

    # Issuer
    issuer = dict(x[0] for x in cert.get('issuer', ()))
    info["issuer_cn"] = issuer.get('commonName', 'N/A')
    info["issuer_org"] = issuer.get('organizationName', 'N/A')

    # Dates
    not_before = cert.get('notBefore', '')
    not_after = cert.get('notAfter', '')
    info["not_before"] = not_before
    info["not_after"] = not_after

    # Calculate days remaining
    try:
        expiry = datetime.strptime(not_after, "%b %d %H:%M:%S %Y %Z")
        days_left = (expiry - datetime.utcnow()).days
        info["days_remaining"] = days_left
    except (ValueError, TypeError):
        info["days_remaining"] = None

    # SANs
    san_list = []
    for san_type, san_value in cert.get('subjectAltName', ()):
        san_list.append(f"{san_type}:{san_value}")
    info["sans"] = san_list
    info["san_count"] = len(san_list)

    # Serial number
    info["serial"] = cert.get('serialNumber', 'N/A')

    # Version
    info["version"] = cert.get('version', 'N/A')

    # Fingerprints
    if cert_bin:
        info["sha256"] = hashlib.sha256(cert_bin).hexdigest()
        info["sha1"] = hashlib.sha1(cert_bin).hexdigest()

    # Check for wildcard
    info["is_wildcard"] = any('*' in san for san in san_list)

    # Self-signed check
    info["is_self_signed"] = (info["subject_cn"] == info["issuer_cn"] and
                               info["subject_org"] == info["issuer_org"])

    return info


def _analyze_cert(cert_info: Dict, host: str, result: Dict) -> None:
    """Analyze certificate for security issues."""
    findings = result["findings"]

    # Expiry checks
    days = cert_info.get("days_remaining")
    if days is not None:
        if days < 0:
            findings.append({
                "emoji": "💀", "severity": "CRITICAL",
                "detail": f"Certificate EXPIRED {abs(days)} days ago",
            })
        elif days < 7:
            findings.append({
                "emoji": "🔴", "severity": "CRITICAL",
                "detail": f"Certificate expires in {days} days!",
            })
        elif days < 30:
            findings.append({
                "emoji": "🟡", "severity": "HIGH",
                "detail": f"Certificate expires in {days} days",
            })
        elif days < 90:
            findings.append({
                "emoji": "🟠", "severity": "MEDIUM",
                "detail": f"Certificate expires in {days} days",
            })
        else:
            findings.append({
                "emoji": "✅", "severity": "GOOD",
                "detail": f"Certificate valid for {days} more days",
            })

    # Self-signed
    if cert_info.get("is_self_signed"):
        findings.append({
            "emoji": "⚠️", "severity": "HIGH",
            "detail": "Self-signed certificate",
        })

    # Wildcard
    if cert_info.get("is_wildcard"):
        findings.append({
            "emoji": "🌟", "severity": "INFO",
            "detail": "Wildcard certificate in use",
        })

    # Cipher strength
    bits = cert_info.get("cipher_bits", 0)
    cipher = cert_info.get("negotiated_cipher", "")
    if bits < 128:
        findings.append({
            "emoji": "🔴", "severity": "CRITICAL",
            "detail": f"Weak cipher: {cipher} ({bits}-bit)",
        })
    elif bits < 256:
        findings.append({
            "emoji": "🟡", "severity": "INFO",
            "detail": f"Cipher: {cipher} ({bits}-bit)",
        })
    else:
        findings.append({
            "emoji": "✅", "severity": "GOOD",
            "detail": f"Strong cipher: {cipher} ({bits}-bit)",
        })

    # TLS version
    version = cert_info.get("tls_version", "")
    if "TLSv1.3" in version:
        findings.append({"emoji": "✅", "severity": "GOOD", "detail": f"Using {version}"})
    elif "TLSv1.2" in version:
        findings.append({"emoji": "🟡", "severity": "INFO", "detail": f"Using {version} (1.3 preferred)"})
    elif "TLSv1.1" in version or "TLSv1.0" in version:
        findings.append({"emoji": "🔴", "severity": "CRITICAL", "detail": f"Using DEPRECATED {version}"})
    elif "SSLv" in version:
        findings.append({"emoji": "💀", "severity": "CRITICAL", "detail": f"Using INSECURE {version}"})

    # CN / SAN hostname match
    sans = [s.split(":", 1)[1] if ":" in s else s for s in cert_info.get("sans", [])]
    cn = cert_info.get("subject_cn", "")
    all_names = sans + [cn]
    host_match = any(_hostname_matches(host, name) for name in all_names)
    if not host_match:
        findings.append({
            "emoji": "⚠️", "severity": "HIGH",
            "detail": f"Hostname '{host}' not in certificate names",
        })


def _hostname_matches(hostname: str, pattern: str) -> bool:
    """Check if hostname matches a certificate name pattern (with wildcard support)."""
    if pattern.startswith("*."):
        # Wildcard: *.example.com matches foo.example.com
        suffix = pattern[1:]
        return hostname.endswith(suffix) or hostname == pattern[2:]
    return hostname == pattern


def audit_ciphers(host: str, port: int = 443, timeout: float = 3.0) -> List[Dict]:
    """Audit supported cipher suites — the manticore's second head."""
    results = []

    # Test different TLS versions and ciphers
    test_configs = [
        ("TLSv1.3", ssl.PROTOCOL_TLS_CLIENT, True),
        ("DEFAULT", ssl.PROTOCOL_TLS_CLIENT, False),
    ]

    for label, protocol, tls13_only in test_configs:
        try:
            ctx = ssl.SSLContext(protocol)
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            if tls13_only:
                ctx.minimum_version = ssl.TLSVersion.TLSv1_3
                ctx.maximum_version = ssl.TLSVersion.TLSv1_3

            with socket.create_connection((host, port), timeout=timeout) as sock:
                with ctx.wrap_socket(sock, server_hostname=host) as ssock:
                    cipher = ssock.cipher()
                    if cipher:
                        results.append({
                            "config": label,
                            "cipher": cipher[0],
                            "version": cipher[1],
                            "bits": cipher[2],
                            "strong": cipher[2] >= 256,
                        })
        except (ssl.SSLError, OSError, socket.timeout):
            results.append({
                "config": label,
                "cipher": None,
                "error": "Not supported",
            })

    return results


def multi_inspect(hosts: List[str], port: int = 443) -> List[Dict]:
    """Inspect certificates for multiple hosts."""
    results = []
    for host in hosts:
        result = inspect_cert(host, port)
        results.append(result)
    return results
