#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# NullSec Pre-Release PII Cleaner
# Audits and sanitizes personal information before public release
#
# Run BEFORE every commit/push to public repos.
#
# Modes:
#   ./nullsec-clean-release.sh              Audit only (default, safe)
#   ./nullsec-clean-release.sh --clean      Audit + auto-fix what it can
#   ./nullsec-clean-release.sh --hook       Install as git pre-commit hook
#   ./nullsec-clean-release.sh --ci         Exit 1 if PII found (for CI/CD)
#
# Config:
#   .nullsec-clean.conf      Per-repo allowlist & custom patterns
#
# Developed by: bad-antics
#═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/.nullsec-clean.conf"
VERSION="1.0.0"

# ─── Colors ───
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
CYN='\033[0;36m'
MAG='\033[0;35m'
DIM='\033[2m'
BLD='\033[1m'
RST='\033[0m'

# ─── Counters ───
TOTAL_HITS=0
TOTAL_FILES=0
TOTAL_FIXED=0
CLEAN_MODE=0
CI_MODE=0
VERBOSE=0
declare -A FILE_HITS

# ─── Default PII Patterns ───
# Each entry: "CATEGORY|GREP_PATTERN|DESCRIPTION|SED_REPLACEMENT(optional)"
# Patterns are checked with grep -Pn (PCRE). Replacement is optional (audit-only if empty).

declare -a PII_PATTERNS=()
declare -a ALLOWLIST=()

load_defaults() {
    PII_PATTERNS=(
        # ── Private IP addresses (hardcoded, not in variables) ──
        "IP|192\.168\.\d+\.\d+|Private IP 192.168.x.x"
        "IP|10\.\d+\.\d+\.\d+|Private IP 10.x.x.x"
        "IP|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+|Private IP 172.16-31.x.x"

        # ── SSH keys & credentials ──
        "CRED|ssh-(rsa|ed25519|ecdsa) AAAA[A-Za-z0-9+/=]{20,}|SSH public key"
        "CRED|sshpass -p ['\"][^'\"]+['\"]|Hardcoded SSH password"
        "CRED|PASS(WORD)?=['\"][^'\"]{4,}['\"]|Hardcoded password variable"

        # ── Usernames / home dirs ──
        "USER|/home/(?!user|USER|\\\$)[a-zA-Z][a-zA-Z0-9_-]+/|Hardcoded home directory"
        "USER|(?<!\\\$\{?)(antics|nullsec-laptop)@|Hardcoded username in SSH/email"

        # ── Network interface names (hardware-specific) ──
        "IFACE|(?<!\w)(enp\d+s\d+|eno\d+|enx[a-f0-9]+|wlp\d+s\d+)(?!\w)|Hardware-specific interface name"
        "IFACE|\"wlo1\"|Hardcoded WiFi interface wlo1"
        "IFACE|wg0-mullvad|Named VPN interface (Mullvad-specific)"

        # ── VPN / service provider names ──
        "VPN|[Mm]ullvad|VPN provider name (Mullvad)"
        "VPN|[Nn]ord[Vv][Pp][Nn]|VPN provider name (NordVPN)"
        "VPN|[Pp]roton[Vv][Pp][Nn]|VPN provider name (ProtonVPN)"

        # ── Machine hostnames (common personal names) ──
        "HOST|(?<!\w)(doomsday|nullkia|alienware|fairy|thinkcentre)(?!\w)|Personal hostname"
        "HOST|DESKTOP-[A-Z0-9]{6,}|Windows machine name"

        # ── Hardware specs that identify specific machines ──
        "HW|i[357]-[0-9]{4,5}[A-Z]?|Specific CPU model"
        "HW|(?<!\w)(GTX|RTX)\s*\d{3,4}|Specific GPU model"
        "HW|BCM2[0-9]{3}|Broadcom SoC model (RPi)"

        # ── MAC addresses ──
        "MAC|([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}|MAC address"

        # ── Routing tables / policy IDs ──
        "NET|lookup\s+\d{8,}|Hardcoded routing table ID"

        # ── Webhooks & API tokens ──
        "API|discord\.com/api/webhooks/\d+/[A-Za-z0-9_-]+|Discord webhook URL"
        "API|api\.telegram\.org/bot[A-Za-z0-9:_-]+|Telegram bot token"
        "API|['\"][A-Za-z0-9]{32,}['\"]|Potential API key/token (32+ chars)"

        # ── WiFi credentials ──
        "WIFI|SSID:\s*null(?!\w)|SSID matching personal network name"
        "WIFI|psk=['\"]?[A-Za-z0-9!@#\$%^&*]{8,}|WiFi PSK"

        # ── Email addresses ──
        "EMAIL|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|Email address"

        # ── Absolute paths to personal workspace ──
        "PATH|/home/(?!user|USER|\\\$)[a-z][a-z0-9_-]+/nullsec|Personal workspace path"
    )
}

# ─── Auto-fix replacements ──
# These are safe transformations applied in --clean mode.
# Format: "GREP_PATTERN|SED_PATTERN|SED_REPLACEMENT"
declare -a AUTOFIXES=(
    # IP replacements
    '192\.168\.40\.\d+|192\.168\.40\.[0-9]+|192.168.1.X'

    # Interface names
    '"enp45s0"|"enp45s0"|"eth0"'
    '"wlo1"|"wlo1"|"wlan0"'
    'wg0-mullvad|wg0-mullvad|wg0'

    # VPN provider
    'Mullvad VPN|Mullvad VPN|WireGuard VPN'
    'Mullvad|Mullvad|VPN'

    # Usernames in SSH
    'antics@|antics@|${USER}@'

    # Home directories
    '/home/antics/|/home/antics/|/home/user/'

    # Hostnames
    '\bdoomsday\b|doomsday|node-1'
    '\bnullkia\b|nullkia|node-2'
    '\balienware\b|alienware|node-3'
    '\bfairy\b\s|fairy|node-4'
    '\bthinkcentre\b|thinkcentre|node-5'

    # Routing table
    'lookup 1836018789|1836018789|$(VPN_TABLE)'
)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION FILE
# ═══════════════════════════════════════════════════════════════════════════════

load_config() {
    [[ ! -f "$CONF_FILE" ]] && return 0

    local section=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip comments and whitespace
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue

        # Section headers
        if [[ "$line" == "[allowlist]" ]]; then
            section="allowlist"
            continue
        elif [[ "$line" == "[patterns]" ]]; then
            section="patterns"
            continue
        elif [[ "$line" == "[autofixes]" ]]; then
            section="autofixes"
            continue
        fi

        case "$section" in
            allowlist)  ALLOWLIST+=("$line") ;;
            patterns)   PII_PATTERNS+=("$line") ;;
            autofixes)  AUTOFIXES+=("$line") ;;
        esac
    done < "$CONF_FILE"
}

generate_default_config() {
    cat > "$CONF_FILE" << 'CONF'
# ═══════════════════════════════════════════════════════════════════════════
# NullSec Pre-Release PII Cleaner - Configuration
# ═══════════════════════════════════════════════════════════════════════════
#
# Lines starting with # are comments.
# Each section is defined by a [header].

# ── Files/patterns to SKIP (grep -P regex matched against each hit line) ──
# Use this for known-safe matches: example IPs in docs, variable names, etc.
[allowlist]
# Variable assignments that SHOULD have generic IPs (these are the defaults)
192\.168\.1\.\d+
10\.10\.10\.\d+
172\.16\.52\.\d+
10\.0\.0\.\d+
YOUR_PUBKEY
YOUR_PASSWORD
YOUR_WEBHOOK
YOUR_TOKEN
user@example\.com
AAAA_YOUR_PUBKEY
# Attribution is fine
Developed by.*bad-antics
# GitHub username references
github\.com/bad-antics
# Generic config placeholders
\$\{NULLSEC_
\$NULLSEC_
\$\{MESH_USER
\$USER
\$\(whoami\)
# Regex patterns in code (scanning for IPs is not a leak)
grep.*192\\.168
sed.*192\\.168
regex.*192\\.168
match.*192\\.168
# Docs that reference example IPs
\.md:.*example
README.*192\.168

# ── Additional PII patterns (add your own) ──
# Format: CATEGORY|GREP_PCRE_PATTERN|Description
[patterns]
# Add custom patterns here, e.g.:
# CUSTOM|my-secret-project|Internal project codename

# ── Additional auto-fix rules for --clean mode ──
# Format: GREP_PATTERN|SED_FIND|SED_REPLACE
[autofixes]
# Add custom fixes here, e.g.:
# my-secret-project|my-secret-project|project-name
CONF

    echo -e "${GRN}[✓]${RST} Generated default config: ${CYN}${CONF_FILE}${RST}"
    echo -e "    Edit this file to customize allowlist and patterns."
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCANNING
# ═══════════════════════════════════════════════════════════════════════════════

# Get list of files to scan
get_scan_files() {
    local mode="${1:-all}"

    case "$mode" in
        staged)
            # Only files staged for commit
            git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | \
                grep -E '\.(sh|ps1|bat|py|conf|json|yaml|yml|toml|txt|md|cfg)$' || true
            ;;
        branch)
            # Files changed on this branch vs main
            local base
            base=$(git merge-base HEAD main 2>/dev/null || echo "HEAD~1")
            git diff --name-only "$base"..HEAD 2>/dev/null | \
                grep -E '\.(sh|ps1|bat|py|conf|json|yaml|yml|toml|txt|md|cfg)$' || true
            ;;
        all)
            # All tracked + untracked script/config files
            {
                git ls-files 2>/dev/null
                git ls-files --others --exclude-standard 2>/dev/null
            } | sort -u | \
                grep -E '\.(sh|ps1|bat|py|conf|json|yaml|yml|toml|txt|md|cfg)$' || true
            ;;
    esac
}

# Check if a match is allowlisted
is_allowlisted() {
    local line="$1"
    for pattern in "${ALLOWLIST[@]}"; do
        if echo "$line" | grep -qP "$pattern" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

# Scan a single file for PII
scan_file() {
    local filepath="$1"
    local file_hits=0
    local results=""

    [[ ! -f "$filepath" ]] && return 0

    # Skip binary files
    if file "$filepath" 2>/dev/null | grep -q "binary\|executable\|ELF"; then
        return 0
    fi

    # Skip this script itself and the config file
    local basename
    basename=$(basename "$filepath")
    [[ "$basename" == "nullsec-clean-release.sh" ]] && return 0
    [[ "$basename" == ".nullsec-clean.conf" ]] && return 0

    for entry in "${PII_PATTERNS[@]}"; do
        IFS='|' read -r category pattern description <<< "$entry"

        # Run grep with PCRE
        local matches
        matches=$(grep -Pn "$pattern" "$filepath" 2>/dev/null || true)

        [[ -z "$matches" ]] && continue

        while IFS= read -r match_line; do
            [[ -z "$match_line" ]] && continue

            # Check allowlist
            if is_allowlisted "$filepath:$match_line"; then
                [[ $VERBOSE -eq 1 ]] && echo -e "    ${DIM}SKIP (allowlisted): $match_line${RST}"
                continue
            fi

            ((file_hits++)) || true
            ((TOTAL_HITS++)) || true

            local lineno="${match_line%%:*}"
            local content="${match_line#*:}"
            # Truncate long lines
            [[ ${#content} -gt 120 ]] && content="${content:0:117}..."

            results+="    ${YEL}${lineno}${RST}  ${MAG}[${category}]${RST} ${content}\n"

        done <<< "$matches"
    done

    if [[ $file_hits -gt 0 ]]; then
        ((TOTAL_FILES++)) || true
        FILE_HITS["$filepath"]=$file_hits
        echo -e "\n  ${RED}■${RST} ${BLD}${filepath}${RST}  ${RED}(${file_hits} hit$([ $file_hits -ne 1 ] && echo s))${RST}"
        echo -e "$results"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-FIX
# ═══════════════════════════════════════════════════════════════════════════════

apply_fixes() {
    local filepath="$1"
    local fixed=0

    for fix_entry in "${AUTOFIXES[@]}"; do
        IFS='|' read -r grep_pat sed_find sed_replace <<< "$fix_entry"

        # Check if this file has the pattern
        if grep -qP "$grep_pat" "$filepath" 2>/dev/null; then
            local count
            count=$(grep -cP "$grep_pat" "$filepath" 2>/dev/null || echo 0)
            sed -i "s|${sed_find}|${sed_replace}|g" "$filepath" 2>/dev/null
            echo -e "    ${GRN}FIXED${RST} ${sed_find} → ${sed_replace} (${count} occurrence$([ "$count" -ne 1 ] && echo s))"
            ((fixed += count)) || true
        fi
    done

    if [[ $fixed -gt 0 ]]; then
        ((TOTAL_FIXED += fixed)) || true
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# GIT HOOK
# ═══════════════════════════════════════════════════════════════════════════════

install_hook() {
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ -z "$git_dir" ]]; then
        echo -e "${RED}[!] Not a git repository${RST}"
        exit 1
    fi

    local hook_path="${git_dir}/hooks/pre-commit"
    local script_rel
    script_rel=$(realpath --relative-to="$(git rev-parse --show-toplevel)" "$0")

    cat > "$hook_path" << HOOK
#!/bin/bash
# NullSec PII Cleaner - Pre-commit hook
# Auto-installed by nullsec-clean-release.sh --hook
# Scans staged files for personal information before commit.

REPO_ROOT="\$(git rev-parse --show-toplevel)"

# Run the cleaner in CI mode on staged files only
"\${REPO_ROOT}/${script_rel}" --ci --staged

exit_code=\$?
if [ \$exit_code -ne 0 ]; then
    echo ""
    echo "  Commit blocked: PII detected in staged files."
    echo "  Run: ./${script_rel} --clean"
    echo "  Or:  ./${script_rel}   (audit only)"
    echo ""
fi
exit \$exit_code
HOOK

    chmod +x "$hook_path"
    echo -e "${GRN}[✓]${RST} Pre-commit hook installed at ${CYN}${hook_path}${RST}"
    echo -e "    Staged files will be scanned for PII before every commit."
    echo -e "    To bypass (emergency): ${YEL}git commit --no-verify${RST}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# REPORT
# ═══════════════════════════════════════════════════════════════════════════════

print_report() {
    echo ""
    echo -e "${CYN}═══════════════════════════════════════════════════════════════${RST}"

    if [[ $TOTAL_HITS -eq 0 ]]; then
        echo -e "${GRN}${BLD}  ✓ ALL CLEAN — No personal information detected${RST}"
        echo -e "${CYN}═══════════════════════════════════════════════════════════════${RST}"
        return 0
    fi

    echo -e "${RED}${BLD}  ✗ PII DETECTED — ${TOTAL_HITS} hit(s) in ${TOTAL_FILES} file(s)${RST}"
    echo -e "${CYN}═══════════════════════════════════════════════════════════════${RST}"
    echo ""

    # Category breakdown
    echo -e "  ${BLD}Breakdown by file:${RST}"
    for filepath in "${!FILE_HITS[@]}"; do
        printf "    %-50s %s\n" "$filepath" "${RED}${FILE_HITS[$filepath]} hit(s)${RST}"
    done

    echo ""
    if [[ $CLEAN_MODE -eq 1 && $TOTAL_FIXED -gt 0 ]]; then
        echo -e "  ${GRN}Auto-fixed: ${TOTAL_FIXED} replacement(s)${RST}"
        echo -e "  ${YEL}Re-run to verify all issues are resolved.${RST}"
    elif [[ $CLEAN_MODE -eq 0 ]]; then
        echo -e "  ${YEL}To auto-fix:${RST}  $0 --clean"
        echo -e "  ${YEL}To allowlist:${RST} Add patterns to ${CYN}.nullsec-clean.conf${RST} [allowlist] section"
    fi
    echo ""

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════════════════

banner() {
    echo -e "${CYN}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║         NullSec Pre-Release PII Cleaner v${VERSION}          ║"
    echo "  ╠═══════════════════════════════════════════════════════════╣"
    if [[ $CLEAN_MODE -eq 1 ]]; then
        echo -e "  ║  Mode: ${GRN}CLEAN${CYN} (audit + auto-fix)                           ║"
    elif [[ $CI_MODE -eq 1 ]]; then
        echo -e "  ║  Mode: ${YEL}CI${CYN} (audit, exit 1 on findings)                    ║"
    else
        echo -e "  ║  Mode: ${MAG}AUDIT${CYN} (report only, no changes)                   ║"
    fi
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RST}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  (no args)       Audit mode — report PII, change nothing"
    echo "  --clean         Audit + auto-fix known patterns"
    echo "  --ci            Audit, exit 1 if PII found (for CI/CD pipelines)"
    echo "  --hook          Install as git pre-commit hook"
    echo "  --init          Generate default .nullsec-clean.conf"
    echo "  --staged        Only scan git-staged files"
    echo "  --branch        Only scan files changed on current branch vs main"
    echo "  --verbose, -v   Show allowlisted matches (skips)"
    echo "  --help, -h      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                     # Quick audit before push"
    echo "  $0 --clean             # Fix everything, then review"
    echo "  $0 --ci --branch       # CI check on PR files only"
    echo "  $0 --hook              # Never forget again"
    echo ""
}

main() {
    local scan_scope="all"

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --clean)   CLEAN_MODE=1 ;;
            --ci)      CI_MODE=1 ;;
            --hook)    install_hook; exit 0 ;;
            --init)    generate_default_config; exit 0 ;;
            --staged)  scan_scope="staged" ;;
            --branch)  scan_scope="branch" ;;
            --verbose|-v) VERBOSE=1 ;;
            --help|-h) usage; exit 0 ;;
            *)
                echo -e "${RED}Unknown option: $1${RST}"
                usage
                exit 1
                ;;
        esac
        shift
    done

    cd "$SCRIPT_DIR"

    banner

    # Load patterns
    load_defaults
    load_config

    # Get files to scan
    local files
    files=$(get_scan_files "$scan_scope")

    if [[ -z "$files" ]]; then
        echo -e "  ${YEL}No files to scan (scope: ${scan_scope}).${RST}"
        exit 0
    fi

    local file_count
    file_count=$(echo "$files" | wc -l)
    echo -e "  Scanning ${BLD}${file_count}${RST} files (scope: ${scan_scope})..."

    # Phase 1: Scan
    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue
        scan_file "$filepath"
    done <<< "$files"

    # Phase 2: Auto-fix (if --clean)
    if [[ $CLEAN_MODE -eq 1 && $TOTAL_HITS -gt 0 ]]; then
        echo ""
        echo -e "  ${CYN}── Applying auto-fixes ──${RST}"
        for filepath in "${!FILE_HITS[@]}"; do
            echo -e "\n  ${BLD}${filepath}${RST}"
            apply_fixes "$filepath"
        done

        # Re-scan to show remaining issues
        echo ""
        echo -e "  ${CYN}── Re-scanning after fixes ──${RST}"
        TOTAL_HITS=0
        TOTAL_FILES=0
        FILE_HITS=()

        while IFS= read -r filepath; do
            [[ -z "$filepath" ]] && continue
            scan_file "$filepath"
        done <<< "$files"
    fi

    # Phase 3: Report
    print_report
    local result=$?

    if [[ $CI_MODE -eq 1 && $result -ne 0 ]]; then
        exit 1
    fi

    exit 0
}

main "$@"
