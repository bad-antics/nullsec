#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# NullSec Marketing Outreach Tracker
# Simple CLI CRM for tracking leads, follow-ups, and conversions
# Contact: badxantics@gmail.com
# ═══════════════════════════════════════════════════════════════

MARKETING_DIR="$HOME/nullsec/marketing"
DB="$MARKETING_DIR/leads.csv"
LOG="$MARKETING_DIR/outreach.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; PURPLE='\033[0;35m'; NC='\033[0m'; BOLD='\033[1m'

mkdir -p "$MARKETING_DIR"

# Init CSV if missing
if [ ! -f "$DB" ]; then
    echo "id,date,name,company,email,platform,product,status,notes" > "$DB"
    echo "Initialized leads database at $DB"
fi

show_banner() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${BOLD}        NullSec Marketing Outreach Tracker               ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        badxantics@gmail.com | bad-antics.github.io       ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
}

next_id() {
    tail -n +2 "$DB" 2>/dev/null | wc -l | awk '{print $1 + 1}'
}

add_lead() {
    echo -e "\n${GREEN}${BOLD}➕ Add New Lead${NC}"
    read -p "  Name: " name
    read -p "  Company: " company
    read -p "  Email: " email
    read -p "  Platform (reddit/twitter/linkedin/upwork/fiverr/email/discord/other): " platform
    read -p "  Product interest (linux/marshall/flipper/ecu/rce/armor/consulting/all): " product
    read -p "  Notes: " notes

    id=$(next_id)
    date=$(date +%Y-%m-%d)
    echo "$id,$date,\"$name\",\"$company\",\"$email\",$platform,$product,contacted,\"$notes\"" >> "$DB"
    echo "$(date '+%Y-%m-%d %H:%M') [ADD] Lead #$id: $name ($company) via $platform" >> "$LOG"
    echo -e "  ${GREEN}✅ Lead #$id added${NC}"
}

list_leads() {
    echo -e "\n${BOLD}📋 All Leads${NC}\n"
    if [ "$(wc -l < "$DB")" -le 1 ]; then
        echo -e "  ${YELLOW}No leads yet. Add one with 'add'${NC}"
        return
    fi
    printf "${BOLD}%-4s %-12s %-20s %-20s %-12s %-10s %-12s${NC}\n" "ID" "Date" "Name" "Company" "Platform" "Product" "Status"
    echo "──── ──────────── ──────────────────── ──────────────────── ──────────── ────────── ────────────"
    tail -n +2 "$DB" | while IFS=, read -r id date name company email platform product status notes; do
        name=$(echo "$name" | tr -d '"')
        company=$(echo "$company" | tr -d '"')
        case "$status" in
            contacted)  color="$YELLOW" ;;
            replied)    color="$CYAN" ;;
            negotiating) color="$PURPLE" ;;
            converted)  color="$GREEN" ;;
            lost)       color="$RED" ;;
            *)          color="$NC" ;;
        esac
        printf "%-4s %-12s %-20s %-20s %-12s %-10s ${color}%-12s${NC}\n" "$id" "$date" "$name" "$company" "$platform" "$product" "$status"
    done
}

update_status() {
    echo -e "\n${BOLD}🔄 Update Lead Status${NC}"
    list_leads
    echo ""
    read -p "  Lead ID to update: " lid
    echo "  Statuses: contacted → replied → negotiating → converted | lost"
    read -p "  New status: " new_status
    read -p "  Note: " note

    if grep -q "^$lid," "$DB"; then
        sed -i "s/^\($lid,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,\)[^,]*/\1$new_status/" "$DB"
        echo "$(date '+%Y-%m-%d %H:%M') [UPDATE] Lead #$lid → $new_status: $note" >> "$LOG"
        echo -e "  ${GREEN}✅ Lead #$lid updated to $new_status${NC}"
    else
        echo -e "  ${RED}❌ Lead #$lid not found${NC}"
    fi
}

follow_ups() {
    echo -e "\n${BOLD}📬 Leads Needing Follow-Up${NC}\n"
    today=$(date +%s)
    tail -n +2 "$DB" | while IFS=, read -r id date name company email platform product status notes; do
        if [ "$status" = "contacted" ] || [ "$status" = "replied" ]; then
            lead_date=$(date -d "$date" +%s 2>/dev/null || echo 0)
            days_ago=$(( (today - lead_date) / 86400 ))
            name=$(echo "$name" | tr -d '"')
            company=$(echo "$company" | tr -d '"')
            if [ "$days_ago" -ge 3 ]; then
                echo -e "  ${YELLOW}⚠  #$id $name ($company) — ${days_ago} days since contact — $status${NC}"
            fi
        fi
    done
    echo ""
}

stats() {
    echo -e "\n${BOLD}📊 Outreach Statistics${NC}\n"
    total=$(tail -n +2 "$DB" | wc -l)
    contacted=$(grep -c ",contacted," "$DB" 2>/dev/null || echo 0)
    replied=$(grep -c ",replied," "$DB" 2>/dev/null || echo 0)
    negotiating=$(grep -c ",negotiating," "$DB" 2>/dev/null || echo 0)
    converted=$(grep -c ",converted," "$DB" 2>/dev/null || echo 0)
    lost=$(grep -c ",lost," "$DB" 2>/dev/null || echo 0)

    echo -e "  Total Leads:    ${BOLD}$total${NC}"
    echo -e "  Contacted:      ${YELLOW}$contacted${NC}"
    echo -e "  Replied:        ${CYAN}$replied${NC}"
    echo -e "  Negotiating:    ${PURPLE}$negotiating${NC}"
    echo -e "  Converted:      ${GREEN}$converted${NC}"
    echo -e "  Lost:           ${RED}$lost${NC}"
    if [ "$total" -gt 0 ]; then
        rate=$((converted * 100 / total))
        echo -e "  Conversion:     ${BOLD}${rate}%${NC}"
    fi

    echo -e "\n  ${BOLD}By Platform:${NC}"
    tail -n +2 "$DB" | cut -d, -f6 | sort | uniq -c | sort -rn | while read count platform; do
        echo -e "    $platform: $count"
    done

    echo -e "\n  ${BOLD}By Product:${NC}"
    tail -n +2 "$DB" | cut -d, -f7 | sort | uniq -c | sort -rn | while read count product; do
        echo -e "    $product: $count"
    done
}

compose_email() {
    echo -e "\n${BOLD}✉️  Compose Outreach Email${NC}"
    echo "  Templates:"
    echo "    1) Cold outreach — General consulting"
    echo "    2) Cold outreach — NullSec Linux"
    echo "    3) Cold outreach — AI/Prompt Armor"
    echo "    4) Cold outreach — Hardware security"
    echo "    5) Follow-up (Day 3-5)"
    echo "    6) Follow-up (Day 10-14)"
    read -p "  Template #: " tpl
    read -p "  Recipient name: " rname
    read -p "  Company name: " rcompany
    read -p "  Recipient email: " remail

    TEMPLATES="$MARKETING_DIR/email-templates.md"
    if [ -f "$TEMPLATES" ]; then
        echo -e "\n${GREEN}Template loaded. Opening email...${NC}"
        # Generate mailto link
        case $tpl in
            1) subject="Custom Security Tooling %26 Pentesting — 290%2B Tools Built" ;;
            2) subject="NullSec Linux — Security Distro with 290%2B Tools" ;;
            3) subject="Prompt Injection Defense for Your AI Stack" ;;
            4) subject="430%2B Flipper Zero Payloads %2B WiFi Pineapple Suite" ;;
            5) subject="Re: Following up — Security Services" ;;
            6) subject="Quick question, $rname" ;;
            *) subject="Security Services — bad-antics" ;;
        esac
        echo -e "\n  ${CYAN}mailto:$remail?subject=$subject${NC}"
        echo -e "  ${YELLOW}Copy the template from: $TEMPLATES (section #$tpl)${NC}"
        echo -e "  ${YELLOW}Replace [Name] with: $rname${NC}"
        echo -e "  ${YELLOW}Replace [Company Name] with: $rcompany${NC}"
    fi
}

# Main menu
show_banner
echo ""
echo -e "  ${BOLD}Commands:${NC}"
echo "    add       — Add a new lead"
echo "    list      — List all leads"
echo "    update    — Update lead status"
echo "    followup  — Show leads needing follow-up"
echo "    stats     — Outreach statistics"
echo "    compose   — Compose outreach email"
echo "    log       — View activity log"
echo "    help      — Show this menu"
echo "    quit      — Exit"
echo ""

while true; do
    read -p "$(echo -e ${CYAN}nullsec-marketing${NC})\$ " cmd
    case "$cmd" in
        add)      add_lead ;;
        list)     list_leads ;;
        update)   update_status ;;
        followup) follow_ups ;;
        stats)    stats ;;
        compose)  compose_email ;;
        log)      echo ""; cat "$LOG" 2>/dev/null || echo "No activity yet"; echo "" ;;
        help)     show_banner; echo "  add | list | update | followup | stats | compose | log | quit" ;;
        quit|exit) echo -e "${GREEN}Keep grinding. 💰${NC}"; break ;;
        *)        echo -e "${YELLOW}Unknown: $cmd — try 'help'${NC}" ;;
    esac
done
