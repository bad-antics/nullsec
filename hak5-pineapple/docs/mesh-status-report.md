# NullSec Mesh Network Status Report

**Generated:** February 24, 2026  
**Controller:** nullsec (192.168.40.129)  
**Subnet:** 192.168.40.0/24  
**Mesh Overlay:** batman-adv (10.10.10.0/24)

---

## Node Status Summary

| Node | IP | OS | SSH | Ping | Latency | Updated | Optimized |
|------|----|----|-----|------|---------|---------|-----------|
| **controller** | .129 (local) | Linux 6.17.13+2-amd64 | ✅ | ✅ | — | ✅ | ✅ BBR + sysctl + WiFi PS off |
| **r420** | .209 | Linux (PowerEdge) | ✅ root | ✅ | 5.25ms | ✅ | ✅ BBR + full sysctl tuning |
| **nullkia** | .43 | Debian 12 (RPi) | ✅ antics | ✅ | 5.16ms | ✅ 142 pkgs | ✅ BBR + buffers + fastopen |
| **doomsday-linux** | .141 | Kali (antx) | ✅ | ✅ | 5.19ms | ✅ (msf held) | ✅ BBR + full sysctl tuning |
| **doomsday** | .22 | Windows | ✅ | ⚠️ flaky | — | N/A | N/A |
| **thinkcentre** | .55 | Windows | ✅ | ✅ | 6.03ms | N/A | N/A |
| **desktop65** | .65 | Windows | ✅ | ✅ | 9.22ms | N/A | N/A |
| **fairy** | .163 | Windows | ✅ | ✅ | 5.12ms | N/A | N/A |
| **parrot** | .214 | Linux | ❌ DOWN | ❌ | — | ❌ | ❌ |

---

## Network Speed Tests

| Route | Protocol | Throughput | Retransmits | Notes |
|-------|----------|------------|-------------|-------|
| controller → r420 | TCP (4 streams) | **809 Mbits/sec** | 3,249 | Near gigabit, healthy |
| controller → nullkia | — | *Not tested* | — | RPi hardware limited (~300Mbps max) |
| controller → doomsday-linux | — | *Not tested* | — | Wired ethernet, expected ~900Mbps |

---

## Optimizations Applied

### Controller (192.168.40.129)
- ✅ WiFi power save **disabled** (biggest fix: 30ms → 5ms latency)
- ✅ BBR congestion control enabled
- ✅ `tcp_slow_start_after_idle=0`
- ✅ `tcp_mtu_probing=1`
- ✅ `tcp_fastopen=3`
- ✅ `rmem_max/wmem_max=16MB`
- ✅ `netdev_max_backlog=5000`

### R420 (192.168.40.209)
- ✅ Upgraded from **cubic → BBR** congestion control
- ✅ Full sysctl tuning applied (`/etc/sysctl.d/99-nullsec-network.conf`)
- ✅ All buffers and TCP parameters optimized

### Nullkia (192.168.40.43 — Raspberry Pi)
- ✅ BBR already enabled
- ✅ Buffer sizes already at 16MB
- ✅ `tcp_fastopen` upgraded 1 → 3
- ✅ `netdev_max_backlog` upgraded 1000 → 5000
- ✅ 142 packages upgraded (dpkg locks cleared)

### Doomsday-Linux (192.168.40.141)
- ✅ BBR already enabled
- ✅ Full buffer/backlog tuning applied (`/etc/sysctl.d/99-nullsec-network.conf`)
- ✅ System upgraded (metasploit-framework held due to Rapid7 CDN 403)

---

## batman-adv Mesh Status

| Node | bat0 | gretap-gw | Mesh Role |
|------|------|-----------|-----------|
| nullkia | ✅ UP | ✅ UP (master bat0) | Mesh node |
| doomsday-linux | ✅ UP | ✅ UP (master bat0) | Mesh node |
| controller | ✅ Configured | ✅ Configured | Gateway |

---

## Issues & Recommendations

### 🔴 Critical
- **Parrot (.214)** — Consistently offline across multiple sessions. Needs physical intervention (power check, cable, OS recovery).

### 🟡 Warning
- **Doomsday (.22)** — Windows, ping unreliable (ICMP may be blocked by firewall). SSH works fine.
- **Metasploit on doomsday-linux** — Package held due to Rapid7 CDN returning 403. Retry: `sudo apt-mark unhold metasploit-framework && sudo apt-get upgrade`
- **Nullkia dpkg** — apt/dpkg may still have stale locks. If installs hang: `sudo kill $(pgrep -f 'dpkg|apt') 2>/dev/null; sudo rm -f /var/lib/dpkg/lock*; sudo dpkg --configure -a`

### 🟢 Good
- **8/9 nodes ONLINE** with SSH verified
- **All Linux nodes** updated and network-optimized
- **Latency** consistently 5-9ms across entire mesh (excellent for LAN)
- **Throughput** ~809 Mbits/sec to R420 (near wire speed for GbE)
- **batman-adv overlay** operational on nullkia and doomsday-linux
- **WiFi power save** disabled on controller (eliminated 25ms+ jitter)

---

## Cluster Configuration

```
SSH Key: ~/.ssh/id_ed25519
SSH Config: ConnectTimeout 5, BatchMode
Sysctl Config: /etc/sysctl.d/99-nullsec-network.conf
Congestion: BBR (all Linux nodes)
Queue Discipline: fq (fair queueing)
Mesh Protocol: batman-adv v2024+
Tunnel Type: GRETAP → bat0
```
