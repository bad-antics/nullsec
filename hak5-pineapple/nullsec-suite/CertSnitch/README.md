# 🔐 CertSnitch

**SSL/TLS Certificate Intelligence Gatherer**

Multi-threaded certificate scanner that audits SSL/TLS configurations across your network. Detects expiring certs, weak protocols, self-signed certificates, and suspicious issuers.

## Features

- 🔍 **Multi-threaded scanning** — 20 concurrent workers, scans 12 TLS ports
- 🏥 **Security audit** — Expiry, self-signed, weak ciphers, weak protocols
- 🔗 **Certificate chain analysis** — Subject, issuer, SAN extraction
- ⏰ **Expiry monitoring** — Flag certs expiring within 30 days
- 🎯 **Subnet scanning** — CIDR notation support
- 📊 **SHA-256 fingerprinting** — Unique cert identification
- 🏭 **Issuer analysis** — Detect suspicious/unknown CAs
- 📋 **JSON + Markdown reports**

## Usage

```bash
# Scan specific targets
python3 certsnitch.py 192.168.1.1 google.com 10.0.0.1

# Scan a subnet
python3 certsnitch.py -s 192.168.1.0/24

# Custom ports
python3 certsnitch.py 192.168.1.1 -p 443,8443,9443

# Custom output
python3 certsnitch.py -s 10.0.0.0/24 -o ./cert-results/
```

## Security Checks

| Check | Severity | Description |
|-------|----------|-------------|
| Expired cert | Critical | Certificate past expiry date |
| Expiring soon | High | Expires within 30 days |
| Self-signed | Medium | No CA trust chain |
| Weak cipher | High | DES, RC4, MD5 in cipher suite |
| Weak protocol | High | SSLv2, SSLv3, TLS 1.0 |
| Long validity | Low | Valid for >825 days |
| Hostname mismatch | Medium | Cert doesn't match hostname |

## Requirements

- Python 3.6+
- No external dependencies (uses stdlib ssl)

## Part of [NullSec Security Suite](https://github.com/bad-antics/nullsec-suite)
