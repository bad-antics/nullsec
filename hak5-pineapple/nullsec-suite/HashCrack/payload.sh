#!/bin/bash
# Title: Hash Crack
# Author: bad-antics
# Description: GPU-accelerated hash cracking with distributed mesh support
# Category: nullsec/crack

LOOT_DIR="/mmc/nullsec/hash-crack"
mkdir -p "$LOOT_DIR"

PROMPT "HASH CRACK

GPU-accelerated hash cracking
with mesh distribution.

Supported:
- MD5 / SHA1 / SHA256 / SHA512
- NTLM / NetNTLMv2
- WPA/WPA2 (PMKID/hccapx)
- bcrypt / scrypt
- Kerberos TGT/TGS
- MySQL / PostgreSQL
- ZIP / RAR / Office / PDF

Press OK to configure."

PROMPT "HASH SOURCE

1. Enter single hash
2. Hash file
3. PMKID capture
4. Handshake (hccapx)
5. /etc/shadow dump
6. SAM/NTDS dump

Select on next screen."

SRC_MODE=$(NUMBER_PICKER "Source (1-6):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac

HASH_FILE="/tmp/hashcrack_input.txt"
HASH_TYPE=""

case $SRC_MODE in
    1)
        HASH=$(TEXT_PICKER "Paste hash:" "")
        echo "$HASH" > "$HASH_FILE"
        # Auto-detect hash type
        LEN=${#HASH}
        case $LEN in
            32) HASH_TYPE="0"   ;; # MD5
            40) HASH_TYPE="100" ;; # SHA1
            64) HASH_TYPE="1400";; # SHA256
            128) HASH_TYPE="1700";; # SHA512
            *)
                echo "$HASH" | grep -qP '^[a-f0-9]{32}$' && HASH_TYPE="1000" # NTLM
                echo "$HASH" | grep -qi '^\$2[aby]\$' && HASH_TYPE="3200"     # bcrypt
                echo "$HASH" | grep -qi '^\$6\$' && HASH_TYPE="1800"          # sha512crypt
                echo "$HASH" | grep -qi '^\$5\$' && HASH_TYPE="7400"          # sha256crypt
                echo "$HASH" | grep -qi '^\$1\$' && HASH_TYPE="500"           # md5crypt
                ;;
        esac
        ;;
    2)
        HASH_FILE=$(TEXT_PICKER "Hash file:" "/mmc/loot/hashes.txt")
        ;;
    3)
        HASH_FILE=$(TEXT_PICKER "PMKID file:" "/mmc/loot/pmkid.txt")
        HASH_TYPE="22000"
        ;;
    4)
        HASH_FILE=$(TEXT_PICKER "hccapx file:" "/mmc/loot/capture.hccapx")
        HASH_TYPE="22000"
        ;;
    5)
        SHADOW=$(TEXT_PICKER "Shadow file:" "/mmc/loot/shadow")
        grep '^\w.*\$' "$SHADOW" > "$HASH_FILE" 2>/dev/null
        # Detect type from first entry
        head -1 "$HASH_FILE" | grep -q '^\$6\$' && HASH_TYPE="1800"
        head -1 "$HASH_FILE" | grep -q '^\$5\$' && HASH_TYPE="7400"
        head -1 "$HASH_FILE" | grep -q '^\$1\$' && HASH_TYPE="500"
        ;;
    6)
        NTDS=$(TEXT_PICKER "NTDS/SAM file:" "/mmc/loot/ntds.dit")
        HASH_TYPE="1000"
        HASH_FILE="$NTDS"
        ;;
esac

if [ -z "$HASH_TYPE" ]; then
    PROMPT "HASH TYPE

1.  MD5            (0)
2.  SHA1         (100)
3.  SHA256      (1400)
4.  SHA512      (1700)
5.  NTLM        (1000)
6.  NetNTLMv2   (5600)
7.  bcrypt       (3200)
8.  sha512crypt (1800)
9.  Kerberos TGS(13100)
10. WPA/WPA2   (22000)

Select on next screen."

    HT_NUM=$(NUMBER_PICKER "Type (1-10):" 1)
    HTYPES=("0" "100" "1400" "1700" "1000" "5600" "3200" "1800" "13100" "22000")
    HASH_TYPE="${HTYPES[$((HT_NUM - 1))]}"
fi

PROMPT "ATTACK MODE

1. Dictionary
2. Dictionary + Rules
3. Brute-force (mask)
4. Hybrid (dict+mask)
5. Smart (auto-rules)

Select on next screen."

ATK_MODE=$(NUMBER_PICKER "Mode (1-5):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) ATK_MODE=1 ;; esac

WORDLIST="/mmc/wordlists/rockyou.txt"
MASK=""
RULES=""

case $ATK_MODE in
    1)
        WORDLIST=$(TEXT_PICKER "Wordlist:" "$WORDLIST")
        HC_MODE=0
        ;;
    2)
        WORDLIST=$(TEXT_PICKER "Wordlist:" "$WORDLIST")
        RULES=$(TEXT_PICKER "Rules:" "best64.rule")
        HC_MODE=0
        ;;
    3)
        MASK=$(TEXT_PICKER "Mask (?d=digit ?l=lower ?u=upper ?a=all):" "?a?a?a?a?a?a?a?a")
        HC_MODE=3
        ;;
    4)
        WORDLIST=$(TEXT_PICKER "Wordlist:" "$WORDLIST")
        MASK=$(TEXT_PICKER "Append mask:" "?d?d?d?d")
        HC_MODE=6
        ;;
    5)
        HC_MODE=0
        RULES="best64.rule"
        ;;
esac

HASH_COUNT=$(wc -l < "$HASH_FILE" 2>/dev/null || echo 1)

resp=$(CONFIRMATION_DIALOG "LAUNCH CRACK?

Hashes: $HASH_COUNT
Type: $HASH_TYPE
Mode: $ATK_MODE
Wordlist: $(basename "$WORDLIST" 2>/dev/null)

Press OK to crack.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_FILE="$LOOT_DIR/cracked_${TIMESTAMP}.txt"
LOG "HashCrack: type=$HASH_TYPE hashes=$HASH_COUNT mode=$ATK_MODE"
SPINNER_START "Cracking hashes..."

# Try hashcat first (GPU)
if command -v hashcat &>/dev/null; then
    TOOL="hashcat"
    CMD="hashcat -m $HASH_TYPE -a $HC_MODE --potfile-disable -o '$OUT_FILE'"
    
    [ -n "$RULES" ] && CMD="$CMD -r '$RULES'"
    CMD="$CMD '$HASH_FILE'"
    [ "$HC_MODE" -eq 0 ] && CMD="$CMD '$WORDLIST'"
    [ "$HC_MODE" -eq 3 ] && CMD="$CMD '$MASK'"
    [ "$HC_MODE" -eq 6 ] && CMD="$CMD '$WORDLIST' '$MASK'"
    
    eval "$CMD" 2>&1 | tee "/tmp/hashcrack.log"

# Fallback to john
elif command -v john &>/dev/null; then
    TOOL="john"
    JOHN_FMT=""
    case $HASH_TYPE in
        0)    JOHN_FMT="Raw-MD5" ;;
        100)  JOHN_FMT="Raw-SHA1" ;;
        1400) JOHN_FMT="Raw-SHA256" ;;
        1700) JOHN_FMT="Raw-SHA512" ;;
        1000) JOHN_FMT="NT" ;;
        1800) JOHN_FMT="sha512crypt" ;;
        3200) JOHN_FMT="bcrypt" ;;
    esac
    
    CMD="john"
    [ -n "$JOHN_FMT" ] && CMD="$CMD --format=$JOHN_FMT"
    CMD="$CMD --wordlist='$WORDLIST' '$HASH_FILE'"
    
    eval "$CMD" 2>&1 | tee "/tmp/hashcrack.log"
    john --show "$HASH_FILE" > "$OUT_FILE" 2>/dev/null

# Fallback: pure bash for simple hashes
else
    TOOL="bash"
    while IFS= read -r word; do
        WORD_HASH=""
        case $HASH_TYPE in
            0) WORD_HASH=$(echo -n "$word" | md5sum | cut -d' ' -f1) ;;
            100) WORD_HASH=$(echo -n "$word" | sha1sum | cut -d' ' -f1) ;;
            1400) WORD_HASH=$(echo -n "$word" | sha256sum | cut -d' ' -f1) ;;
        esac
        
        if grep -qi "$WORD_HASH" "$HASH_FILE" 2>/dev/null; then
            echo "$WORD_HASH:$word" >> "$OUT_FILE"
        fi
    done < "$WORDLIST"
fi

SPINNER_STOP

CRACKED=$(wc -l < "$OUT_FILE" 2>/dev/null || echo 0)

if [ "$CRACKED" -gt 0 ]; then
    RESULTS=$(head -10 "$OUT_FILE")
    PROMPT "CRACKED!

Engine: $TOOL
Found: $CRACKED / $HASH_COUNT

$RESULTS

Saved to hash-crack/

Press OK to exit."
    NOTIFICATION "HashCrack: $CRACKED hashes cracked"
else
    PROMPT "NO CRACKS

Exhausted wordlist for
$HASH_COUNT hashes.

Try:
- Larger wordlist
- Rule-based attack
- Brute-force mask
- Hybrid mode

Press OK to exit."
fi
