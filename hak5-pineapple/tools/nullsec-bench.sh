#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  NullSec Cluster Benchmark v2.0
#  Comprehensive multi-node performance testing suite
#  Author: bad-antics
# ═══════════════════════════════════════════════════════════════════════════════
#
#  Tests: CPU (single/multi), Memory bandwidth, Disk I/O, Network throughput,
#         SSH latency, cluster aggregate compute, and parallel job scaling.
#
#  Usage: ./nullsec-bench.sh [test] [options]
#         ./nullsec-bench.sh all          Full benchmark suite
#         ./nullsec-bench.sh cpu          CPU benchmark only
#         ./nullsec-bench.sh network      Network benchmark only
#         ./nullsec-bench.sh --quick      Quick 60-second benchmark
#
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────

NODES_CONF="${HOME}/.nullsec/cluster/nodes.conf"
RESULTS_DIR="${HOME}/.nullsec/benchmarks/$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="${RESULTS_DIR}/benchmark_report.html"
LOG_FILE="${RESULTS_DIR}/benchmark.log"
QUICK_MODE=false

# Colors
G="\033[32m"; Y="\033[33m"; R="\033[31m"; C="\033[36m"; B="\033[1m"; X="\033[0m"

# ─── Utilities ───────────────────────────────────────────────────────────────

log() { echo -e "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
header() {
    echo -e "\n${G}╔══════════════════════════════════════════════════════════════╗${X}"
    echo -e "${G}║${X}  ${B}$1${X}"
    echo -e "${G}╚══════════════════════════════════════════════════════════════╝${X}\n"
}

mkdir -p "$RESULTS_DIR"
touch "$LOG_FILE"

# ─── Node Discovery ─────────────────────────────────────────────────────────

declare -A NODE_IPS
declare -A NODE_USERS
declare -A NODE_PASSES
ONLINE_NODES=()

load_nodes() {
    [[ ! -f "$NODES_CONF" ]] && { log "${R}No nodes.conf found${X}"; exit 1; }

    while IFS='|' read -r name ip user pass port; do
        [[ -z "$name" || "$name" == "#"* ]] && continue
        NODE_IPS["$name"]="$ip"
        NODE_USERS["$name"]="${user:-root}"
        NODE_PASSES["$name"]="${pass:-}"
    done < "$NODES_CONF"

    log "Loaded ${#NODE_IPS[@]} nodes from config"
}

check_online() {
    log "Checking node availability..."
    for name in "${!NODE_IPS[@]}"; do
        ip="${NODE_IPS[$name]}"
        if timeout 3 bash -c "echo >/dev/tcp/$ip/22" 2>/dev/null; then
            ONLINE_NODES+=("$name")
            echo -e "  ${G}✓${X} $name ($ip)"
        else
            echo -e "  ${R}✗${X} $name ($ip) — offline"
        fi
    done
    log "${#ONLINE_NODES[@]}/${#NODE_IPS[@]} nodes online"
}

run_remote() {
    local name="$1" cmd="$2"
    local ip="${NODE_IPS[$name]}"
    local user="${NODE_USERS[$name]}"
    local pass="${NODE_PASSES[$name]}"

    if [[ -n "$pass" ]]; then
        sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "${user}@${ip}" "$cmd" 2>/dev/null
    else
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            "${user}@${ip}" "$cmd" 2>/dev/null
    fi
}

# ─── CPU Benchmark ───────────────────────────────────────────────────────────

bench_cpu() {
    header "CPU BENCHMARK"
    local results_file="${RESULTS_DIR}/cpu.csv"
    echo "node,cores,single_thread_ops,multi_thread_ops,pi_time_ms" > "$results_file"

    for name in "${ONLINE_NODES[@]}"; do
        log "  Testing CPU on ${C}$name${X}..."

        result=$(run_remote "$name" '
            CORES=$(nproc)

            # Single-thread: count to 1M with arithmetic
            START=$(date +%s%N)
            i=0; while [ $i -lt 1000000 ]; do i=$((i+1)); done
            SINGLE_NS=$(( $(date +%s%N) - START ))
            SINGLE_OPS=$(( 1000000000 / (SINGLE_NS + 1) ))

            # Multi-thread: parallel dd operations
            START=$(date +%s%N)
            for c in $(seq 1 $CORES); do
                dd if=/dev/zero of=/dev/null bs=1M count=256 2>/dev/null &
            done
            wait
            MULTI_NS=$(( $(date +%s%N) - START ))
            MULTI_OPS=$(( CORES * 256 * 1000000000 / (MULTI_NS + 1) ))

            # Pi calculation (bc)
            START=$(date +%s%N)
            echo "scale=1000; 4*a(1)" | bc -l >/dev/null 2>&1 || true
            PI_NS=$(( $(date +%s%N) - START ))
            PI_MS=$(( PI_NS / 1000000 ))

            echo "$CORES|$SINGLE_OPS|$MULTI_OPS|$PI_MS"
        ' 2>/dev/null)

        if [[ -n "$result" ]]; then
            IFS='|' read -r cores single multi pi_ms <<< "$result"
            echo "$name,$cores,$single,$multi,$pi_ms" >> "$results_file"
            echo -e "    Cores: ${B}$cores${X} | Single: ${G}${single} ops/s${X} | Multi: ${G}${multi} MB/s${X} | Pi: ${pi_ms}ms"
        else
            echo -e "    ${R}Failed${X}"
        fi
    done
}

# ─── Memory Benchmark ───────────────────────────────────────────────────────

bench_memory() {
    header "MEMORY BENCHMARK"
    local results_file="${RESULTS_DIR}/memory.csv"
    echo "node,total_gb,free_gb,write_speed_mbs,read_speed_mbs" > "$results_file"

    for name in "${ONLINE_NODES[@]}"; do
        log "  Testing memory on ${C}$name${X}..."

        result=$(run_remote "$name" '
            TOTAL=$(free -g | awk "/Mem/{print \$2}")
            FREE=$(free -g | awk "/Mem/{print \$4}")

            # Memory write speed (dd to tmpfs)
            mkdir -p /tmp/bench_mem
            mount -t tmpfs -o size=512M tmpfs /tmp/bench_mem 2>/dev/null || true
            WRITE=$(dd if=/dev/zero of=/tmp/bench_mem/test bs=1M count=256 2>&1 | grep -oP "[\d.]+ [GM]B/s" | head -1)
            READ=$(dd if=/tmp/bench_mem/test of=/dev/null bs=1M 2>&1 | grep -oP "[\d.]+ [GM]B/s" | head -1)
            rm -f /tmp/bench_mem/test
            umount /tmp/bench_mem 2>/dev/null || true

            echo "$TOTAL|$FREE|${WRITE:-N/A}|${READ:-N/A}"
        ' 2>/dev/null)

        if [[ -n "$result" ]]; then
            IFS='|' read -r total free write read <<< "$result"
            echo "$name,$total,$free,$write,$read" >> "$results_file"
            echo -e "    RAM: ${B}${total}GB${X} (${free}GB free) | Write: ${G}$write${X} | Read: ${G}$read${X}"
        else
            echo -e "    ${R}Failed${X}"
        fi
    done
}

# ─── Disk I/O Benchmark ─────────────────────────────────────────────────────

bench_disk() {
    header "DISK I/O BENCHMARK"
    local results_file="${RESULTS_DIR}/disk.csv"
    echo "node,disk_total,disk_free,seq_write,seq_read,iops" > "$results_file"

    for name in "${ONLINE_NODES[@]}"; do
        log "  Testing disk I/O on ${C}$name${X}..."

        result=$(run_remote "$name" '
            TOTAL=$(df -BG / | awk "NR==2{print \$2}")
            FREE=$(df -BG / | awk "NR==2{print \$4}")

            # Sequential write
            WRITE=$(dd if=/dev/zero of=/tmp/bench_disk_test bs=1M count=256 conv=fdatasync 2>&1 | \
                grep -oP "[\d.]+ [GM]B/s" | head -1)

            # Sequential read (drop cache first)
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            READ=$(dd if=/tmp/bench_disk_test of=/dev/null bs=1M 2>&1 | \
                grep -oP "[\d.]+ [GM]B/s" | head -1)

            # Random I/O (approximate IOPS)
            START=$(date +%s%N)
            for i in $(seq 1 1000); do
                dd if=/tmp/bench_disk_test of=/dev/null bs=4K count=1 skip=$((RANDOM % 64000)) 2>/dev/null
            done
            ELAPSED_NS=$(( $(date +%s%N) - START ))
            IOPS=$(( 1000 * 1000000000 / (ELAPSED_NS + 1) ))

            rm -f /tmp/bench_disk_test
            echo "$TOTAL|$FREE|${WRITE:-N/A}|${READ:-N/A}|$IOPS"
        ' 2>/dev/null)

        if [[ -n "$result" ]]; then
            IFS='|' read -r total free write read iops <<< "$result"
            echo "$name,$total,$free,$write,$read,$iops" >> "$results_file"
            echo -e "    Disk: ${B}$total${X} (${free} free) | Write: ${G}$write${X} | Read: ${G}$read${X} | IOPS: ${G}$iops${X}"
        else
            echo -e "    ${R}Failed${X}"
        fi
    done
}

# ─── Network Benchmark ──────────────────────────────────────────────────────

bench_network() {
    header "NETWORK BENCHMARK"
    local results_file="${RESULTS_DIR}/network.csv"
    echo "node,ssh_latency_ms,throughput_mbs,packet_loss_pct" > "$results_file"

    for name in "${ONLINE_NODES[@]}"; do
        ip="${NODE_IPS[$name]}"
        log "  Testing network to ${C}$name${X} ($ip)..."

        # SSH latency
        START=$(date +%s%N)
        run_remote "$name" "echo ok" >/dev/null 2>&1
        LATENCY_NS=$(( $(date +%s%N) - START ))
        LATENCY_MS=$(( LATENCY_NS / 1000000 ))

        # Throughput test (transfer 10MB)
        dd if=/dev/zero bs=1M count=10 2>/dev/null | \
            ssh -o StrictHostKeyChecking=no "${NODE_USERS[$name]}@$ip" "cat > /dev/null" 2>/dev/null
        # Approximate throughput from latency (simplified)
        THROUGHPUT=$(( 10 * 1000 / (LATENCY_MS + 1) ))

        # Packet loss
        PING_RESULT=$(ping -c 10 -W 2 "$ip" 2>/dev/null | tail -1)
        LOSS=$(echo "$PING_RESULT" | grep -oP '\d+(?=% packet loss)' || echo "0")

        echo "$name,$LATENCY_MS,$THROUGHPUT,$LOSS" >> "$results_file"
        echo -e "    Latency: ${B}${LATENCY_MS}ms${X} | Throughput: ~${G}${THROUGHPUT}MB/s${X} | Loss: ${LOSS}%"
    done
}

# ─── Cluster Aggregate Score ────────────────────────────────────────────────

bench_aggregate() {
    header "CLUSTER AGGREGATE PERFORMANCE"
    local results_file="${RESULTS_DIR}/aggregate.csv"

    # Collect totals
    TOTAL_CORES=0
    TOTAL_RAM=0

    for name in "${ONLINE_NODES[@]}"; do
        result=$(run_remote "$name" 'echo "$(nproc)|$(free -g | awk "/Mem/{print \$2}")"' 2>/dev/null)
        if [[ -n "$result" ]]; then
            IFS='|' read -r cores ram <<< "$result"
            TOTAL_CORES=$((TOTAL_CORES + cores))
            TOTAL_RAM=$((TOTAL_RAM + ram))
        fi
    done

    echo -e "  ${B}Cluster Summary:${X}"
    echo -e "    Online Nodes:  ${G}${#ONLINE_NODES[@]}${X}"
    echo -e "    Total Cores:   ${G}${TOTAL_CORES}${X}"
    echo -e "    Total RAM:     ${G}${TOTAL_RAM} GB${X}"
    echo

    # Parallel compute test: all nodes calculate pi simultaneously
    log "  Running parallel compute test across all nodes..."
    START=$(date +%s%N)

    for name in "${ONLINE_NODES[@]}"; do
        run_remote "$name" '
            for i in $(seq 1 $(nproc)); do
                echo "scale=500; 4*a(1)" | bc -l >/dev/null 2>&1 &
            done
            wait
        ' &
    done
    wait

    PARALLEL_NS=$(( $(date +%s%N) - START ))
    PARALLEL_MS=$(( PARALLEL_NS / 1000000 ))

    echo -e "    Parallel Pi (all ${TOTAL_CORES} cores): ${G}${PARALLEL_MS}ms${X}"

    # Calculate performance score
    SCORE=$(( TOTAL_CORES * 100 + TOTAL_RAM * 10 + (1000000 / (PARALLEL_MS + 1)) ))
    echo -e "    ${B}NullSec Performance Score: ${G}${SCORE}${X}"

    echo "${#ONLINE_NODES[@]},$TOTAL_CORES,$TOTAL_RAM,$PARALLEL_MS,$SCORE" > "$results_file"
}

# ─── HTML Report ─────────────────────────────────────────────────────────────

generate_report() {
    header "GENERATING REPORT"

    cat > "$REPORT_FILE" <<REPORT_HEAD
<!DOCTYPE html><html><head><meta charset="utf-8"><title>NullSec Cluster Benchmark</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,sans-serif;background:#0a0a0a;color:#e0e0e0;padding:40px}
.container{max-width:1000px;margin:0 auto}h1{color:#00ff88;margin-bottom:8px}
h2{color:#00ff88;font-size:18px;margin:24px 0 12px;border-bottom:1px solid #333;padding-bottom:8px}
.subtitle{color:#888;margin-bottom:32px}
.stat-grid{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin:16px 0}
.stat{background:#1a1a1a;border:1px solid #333;border-radius:8px;padding:16px;text-align:center}
.stat-num{font-size:28px;font-weight:bold;color:#00ff88}.stat-label{color:#888;font-size:12px;margin-top:4px}
table{width:100%;border-collapse:collapse;margin:12px 0}
th,td{text-align:left;padding:8px 12px;border-bottom:1px solid #222}th{color:#00ff88;font-size:13px}
.bar{height:12px;background:#00ff88;border-radius:6px;display:inline-block}
.bar-bg{height:12px;background:#222;border-radius:6px;width:200px;display:inline-block}
.footer{margin-top:40px;padding-top:16px;border-top:1px solid #333;color:#666;font-size:12px;text-align:center}
</style></head><body><div class="container">
<h1>⬡ NullSec Cluster Benchmark Report</h1>
<p class="subtitle">Generated: $(date '+%Y-%m-%d %H:%M:%S') | Nodes: ${#ONLINE_NODES[@]}</p>
REPORT_HEAD

    # Stats grid
    cat >> "$REPORT_FILE" <<STATS
<div class="stat-grid">
<div class="stat"><div class="stat-num">${#ONLINE_NODES[@]}</div><div class="stat-label">Nodes Online</div></div>
<div class="stat"><div class="stat-num">${TOTAL_CORES:-0}</div><div class="stat-label">Total Cores</div></div>
<div class="stat"><div class="stat-num">${TOTAL_RAM:-0}GB</div><div class="stat-label">Total RAM</div></div>
<div class="stat"><div class="stat-num">${PARALLEL_MS:-0}ms</div><div class="stat-label">Parallel Pi</div></div>
<div class="stat"><div class="stat-num">${SCORE:-0}</div><div class="stat-label">Performance Score</div></div>
</div>
STATS

    # Add CSV tables as HTML
    for csv_file in "${RESULTS_DIR}"/*.csv; do
        [[ ! -f "$csv_file" ]] && continue
        SECTION=$(basename "$csv_file" .csv | tr '[:lower:]' '[:upper:]')
        echo "<h2>$SECTION</h2><table>" >> "$REPORT_FILE"

        first=true
        while IFS=',' read -r -a fields; do
            if $first; then
                echo "<tr>$(printf '<th>%s</th>' "${fields[@]}")</tr>" >> "$REPORT_FILE"
                first=false
            else
                echo "<tr>$(printf '<td>%s</td>' "${fields[@]}")</tr>" >> "$REPORT_FILE"
            fi
        done < "$csv_file"

        echo "</table>" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" <<'REPORT_FOOT'
<div class="footer">
<p>Generated by NullSec Cluster Benchmark v2.0 | bad-antics | github.com/bad-antics/nullsec</p>
</div></div></body></html>
REPORT_FOOT

    log "Report saved to ${G}$REPORT_FILE${X}"
}

# ─── Main ────────────────────────────────────────────────────────────────────

usage() {
    echo -e "${G}NullSec Cluster Benchmark v2.0${X}\n"
    echo "Usage: $0 [test] [options]"
    echo
    echo "Tests:"
    echo "  all        Run full benchmark suite (default)"
    echo "  cpu        CPU performance only"
    echo "  memory     Memory bandwidth only"
    echo "  disk       Disk I/O only"
    echo "  network    Network latency/throughput only"
    echo "  aggregate  Cluster aggregate score only"
    echo
    echo "Options:"
    echo "  --quick    Quick 60-second benchmark"
    echo "  -h         Show this help"
}

TEST="${1:-all}"
[[ "${2:-}" == "--quick" || "$TEST" == "--quick" ]] && QUICK_MODE=true

case "$TEST" in
    -h|--help) usage; exit 0 ;;
esac

echo -e "\n${G}╔══════════════════════════════════════════════════════════════╗${X}"
echo -e "${G}║${X}  ${B}NullSec Cluster Benchmark v2.0${X}                              ${G}║${X}"
echo -e "${G}╚══════════════════════════════════════════════════════════════╝${X}\n"

load_nodes
check_online

[[ ${#ONLINE_NODES[@]} -eq 0 ]] && { log "${R}No nodes online!${X}"; exit 1; }

case "$TEST" in
    all|--quick)
        bench_cpu
        bench_memory
        bench_disk
        bench_network
        bench_aggregate
        ;;
    cpu)       bench_cpu ;;
    memory)    bench_memory ;;
    disk)      bench_disk ;;
    network)   bench_network ;;
    aggregate) bench_aggregate ;;
    *)         log "${R}Unknown test: $TEST${X}"; usage; exit 1 ;;
esac

generate_report

echo -e "\n${G}${B}Benchmark complete!${X}"
echo -e "  Results: ${C}$RESULTS_DIR${X}"
echo -e "  Report:  ${C}$REPORT_FILE${X}\n"
