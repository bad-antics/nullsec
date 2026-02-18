/* ═══════════════════════════════════════════════════════════════════════════════
 *  NullSec WiFi Analyzer v1.0
 *  802.11 Channel Utilization & Signal Analyzer
 *  Author: bad-antics
 * ═══════════════════════════════════════════════════════════════════════════════
 *
 *  Analyzes WiFi spectrum by parsing beacon frames from monitor mode interface.
 *  Reports: channel congestion, signal strength heatmap, overlap detection,
 *  best channel recommendations, and AP density.
 *
 *  Build:   cargo build --release
 *  Usage:   nullsec-wifi-analyzer <interface>
 *           nullsec-wifi-analyzer wlan0mon --json
 *           nullsec-wifi-analyzer wlan0mon --duration 30
 *
 *  NOTE: Requires interface in monitor mode.
 *  For authorized security testing only.
 */

use std::collections::HashMap;
use std::env;
use std::fmt;
use std::io::{self, Read, Write};
use std::net::UdpSocket;
use std::process::{self, Command};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

// ═══════════════════════════════════════════════════════════════════════════════
// Data Structures
// ═══════════════════════════════════════════════════════════════════════════════

#[derive(Clone, Debug)]
struct AccessPoint {
    bssid: [u8; 6],
    ssid: String,
    channel: u8,
    signal: i8,
    encryption: String,
    beacon_count: u32,
    first_seen: u64,
    last_seen: u64,
    is_hidden: bool,
}

impl AccessPoint {
    fn bssid_str(&self) -> String {
        format!(
            "{:02X}:{:02X}:{:02X}:{:02X}:{:02X}:{:02X}",
            self.bssid[0], self.bssid[1], self.bssid[2],
            self.bssid[3], self.bssid[4], self.bssid[5]
        )
    }
}

#[derive(Clone, Debug)]
struct ChannelStats {
    channel: u8,
    ap_count: u32,
    avg_signal: f64,
    max_signal: i8,
    utilization_score: f64,
    frequency: u32,
}

impl ChannelStats {
    fn new(channel: u8) -> Self {
        let frequency = match channel {
            1..=13 => 2407 + (channel as u32) * 5,
            14 => 2484,
            36..=165 => 5000 + (channel as u32) * 5,
            _ => 0,
        };
        ChannelStats {
            channel,
            ap_count: 0,
            avg_signal: 0.0,
            max_signal: -100,
            utilization_score: 0.0,
            frequency,
        }
    }
}

struct ScanResults {
    aps: Vec<AccessPoint>,
    channels: HashMap<u8, ChannelStats>,
    scan_duration: Duration,
    total_beacons: u64,
}

// ═══════════════════════════════════════════════════════════════════════════════
// Scanner (uses iw/iwlist as backend)
// ═══════════════════════════════════════════════════════════════════════════════

fn run_scan(interface: &str, duration_secs: u64) -> Result<ScanResults, String> {
    let start = Instant::now();
    let mut aps: HashMap<String, AccessPoint> = HashMap::new();
    let mut total_beacons: u64 = 0;

    eprintln!("\x1b[32m⬡\x1b[0m Scanning on {} for {}s...", interface, duration_secs);

    // Use iw to scan
    let output = Command::new("iw")
        .args(&["dev", interface, "scan"])
        .output()
        .map_err(|e| format!("Failed to run iw scan: {}", e))?;

    if !output.status.success() {
        // Try iwlist as fallback
        let output2 = Command::new("iwlist")
            .args(&[interface, "scan"])
            .output()
            .map_err(|e| format!("Failed to run iwlist scan: {}", e))?;

        if !output2.status.success() {
            return Err("Both iw and iwlist scan failed. Is interface in monitor mode?".into());
        }

        parse_iwlist_output(&String::from_utf8_lossy(&output2.stdout), &mut aps, &mut total_beacons);
    } else {
        parse_iw_output(&String::from_utf8_lossy(&output.stdout), &mut aps, &mut total_beacons);
    }

    // If duration > 5s, do multiple scans
    if duration_secs > 5 {
        let iterations = (duration_secs / 5).min(10);
        for i in 1..iterations {
            eprint!("\r  Scan pass {}/{}...", i + 1, iterations);
            thread::sleep(Duration::from_secs(3));

            if let Ok(output) = Command::new("iw")
                .args(&["dev", interface, "scan"])
                .output()
            {
                if output.status.success() {
                    parse_iw_output(
                        &String::from_utf8_lossy(&output.stdout),
                        &mut aps,
                        &mut total_beacons,
                    );
                }
            }
        }
        eprintln!();
    }

    // Build channel stats
    let mut channels: HashMap<u8, ChannelStats> = HashMap::new();
    let ap_list: Vec<AccessPoint> = aps.into_values().collect();

    for ap in &ap_list {
        let entry = channels.entry(ap.channel).or_insert_with(|| ChannelStats::new(ap.channel));
        entry.ap_count += 1;
        if ap.signal > entry.max_signal {
            entry.max_signal = ap.signal;
        }
    }

    // Calculate utilization scores
    for (_, stats) in channels.iter_mut() {
        let channel_aps: Vec<&AccessPoint> = ap_list.iter()
            .filter(|ap| ap.channel == stats.channel)
            .collect();

        if !channel_aps.is_empty() {
            let sig_sum: f64 = channel_aps.iter().map(|ap| ap.signal as f64).sum();
            stats.avg_signal = sig_sum / channel_aps.len() as f64;

            // Utilization score: weighted by AP count and signal strength
            // Higher score = more congested
            stats.utilization_score = (stats.ap_count as f64) *
                (1.0 + (stats.avg_signal as f64 + 100.0) / 60.0);

            // Add overlap penalty for 2.4GHz
            if stats.channel <= 14 {
                for ap in &channel_aps {
                    // Adjacent channels overlap (±4 for 2.4GHz)
                    let overlap_count = ap_list.iter()
                        .filter(|other| {
                            other.channel != ap.channel &&
                            (other.channel as i16 - ap.channel as i16).unsigned_abs() <= 4 &&
                            other.channel <= 14
                        })
                        .count();
                    stats.utilization_score += overlap_count as f64 * 0.3;
                }
            }
        }
    }

    Ok(ScanResults {
        aps: ap_list,
        channels,
        scan_duration: start.elapsed(),
        total_beacons,
    })
}

fn parse_iw_output(output: &str, aps: &mut HashMap<String, AccessPoint>, beacons: &mut u64) {
    let mut current_bssid = String::new();
    let mut current_ssid = String::new();
    let mut current_signal: i8 = -100;
    let mut current_channel: u8 = 0;
    let mut current_enc = String::from("OPN");
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();

    for line in output.lines() {
        let trimmed = line.trim();

        if trimmed.starts_with("BSS ") {
            // Save previous AP
            if !current_bssid.is_empty() {
                save_ap(aps, &current_bssid, &current_ssid, current_channel,
                        current_signal, &current_enc, now);
                *beacons += 1;
            }

            // Parse new BSSID
            if let Some(bssid) = trimmed.strip_prefix("BSS ") {
                current_bssid = bssid.split('(').next().unwrap_or("").trim().to_uppercase();
            }
            current_ssid = String::new();
            current_signal = -100;
            current_channel = 0;
            current_enc = String::from("OPN");
        } else if trimmed.starts_with("SSID:") {
            current_ssid = trimmed.strip_prefix("SSID:").unwrap_or("").trim().to_string();
        } else if trimmed.starts_with("signal:") {
            if let Some(sig_str) = trimmed.strip_prefix("signal:") {
                let sig_clean = sig_str.trim().replace(" dBm", "");
                if let Ok(sig) = sig_clean.parse::<f64>() {
                    current_signal = sig as i8;
                }
            }
        } else if trimmed.starts_with("DS Parameter set: channel") {
            if let Some(ch_str) = trimmed.split("channel").last() {
                if let Ok(ch) = ch_str.trim().parse::<u8>() {
                    current_channel = ch;
                }
            }
        } else if trimmed.contains("WPA:") {
            current_enc = String::from("WPA");
        } else if trimmed.contains("RSN:") {
            current_enc = String::from("WPA2");
        } else if trimmed.contains("SAE") {
            current_enc = String::from("WPA3");
        }
    }

    // Don't forget last AP
    if !current_bssid.is_empty() {
        save_ap(aps, &current_bssid, &current_ssid, current_channel,
                current_signal, &current_enc, now);
        *beacons += 1;
    }
}

fn parse_iwlist_output(output: &str, aps: &mut HashMap<String, AccessPoint>, beacons: &mut u64) {
    let mut current_bssid = String::new();
    let mut current_ssid = String::new();
    let mut current_signal: i8 = -100;
    let mut current_channel: u8 = 0;
    let mut current_enc = String::from("OPN");
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();

    for line in output.lines() {
        let trimmed = line.trim();

        if trimmed.contains("Address:") {
            if !current_bssid.is_empty() {
                save_ap(aps, &current_bssid, &current_ssid, current_channel,
                        current_signal, &current_enc, now);
                *beacons += 1;
            }
            if let Some(addr) = trimmed.split("Address:").last() {
                current_bssid = addr.trim().to_uppercase();
            }
            current_ssid.clear();
            current_signal = -100;
            current_channel = 0;
            current_enc = String::from("OPN");
        } else if trimmed.starts_with("ESSID:") {
            current_ssid = trimmed.replace("ESSID:", "").replace("\"", "").trim().to_string();
        } else if trimmed.contains("Signal level=") {
            if let Some(sig_part) = trimmed.split("Signal level=").last() {
                let sig_clean = sig_part.split(' ').next().unwrap_or("-100");
                if let Ok(sig) = sig_clean.parse::<i8>() {
                    current_signal = sig;
                }
            }
        } else if trimmed.starts_with("Channel:") {
            if let Ok(ch) = trimmed.replace("Channel:", "").trim().parse::<u8>() {
                current_channel = ch;
            }
        } else if trimmed.contains("WPA2") {
            current_enc = String::from("WPA2");
        } else if trimmed.contains("WPA") {
            if current_enc != "WPA2" {
                current_enc = String::from("WPA");
            }
        }
    }

    if !current_bssid.is_empty() {
        save_ap(aps, &current_bssid, &current_ssid, current_channel,
                current_signal, &current_enc, now);
        *beacons += 1;
    }
}

fn save_ap(aps: &mut HashMap<String, AccessPoint>, bssid: &str, ssid: &str,
           channel: u8, signal: i8, enc: &str, now: u64) {
    let bssid_bytes = parse_mac(bssid);

    if let Some(existing) = aps.get_mut(bssid) {
        existing.beacon_count += 1;
        existing.last_seen = now;
        if signal > existing.signal {
            existing.signal = signal;
        }
        if !ssid.is_empty() && existing.is_hidden {
            existing.ssid = ssid.to_string();
            existing.is_hidden = false;
        }
    } else {
        aps.insert(bssid.to_string(), AccessPoint {
            bssid: bssid_bytes,
            ssid: ssid.to_string(),
            channel,
            signal,
            encryption: enc.to_string(),
            beacon_count: 1,
            first_seen: now,
            last_seen: now,
            is_hidden: ssid.is_empty(),
        });
    }
}

fn parse_mac(mac: &str) -> [u8; 6] {
    let mut bytes = [0u8; 6];
    for (i, part) in mac.split(':').enumerate() {
        if i < 6 {
            bytes[i] = u8::from_str_radix(part, 16).unwrap_or(0);
        }
    }
    bytes
}

// ═══════════════════════════════════════════════════════════════════════════════
// Output
// ═══════════════════════════════════════════════════════════════════════════════

fn signal_bar(signal: i8) -> String {
    let strength = ((signal + 100) as f64 / 60.0 * 10.0).min(10.0).max(0.0) as usize;
    let filled = "█".repeat(strength);
    let empty = "░".repeat(10 - strength);

    let color = if signal > -50 {
        "\x1b[32m" // green
    } else if signal > -70 {
        "\x1b[33m" // yellow
    } else {
        "\x1b[31m" // red
    };

    format!("{}{}{}\x1b[0m", color, filled, empty)
}

fn print_results(results: &ScanResults) {
    let g = "\x1b[32m";
    let c = "\x1b[36m";
    let y = "\x1b[33m";
    let r = "\x1b[31m";
    let b = "\x1b[1m";
    let x = "\x1b[0m";

    println!();
    println!("{g}╔════════════════════════════════════════════════════════════════════════════════════════╗{x}");
    println!("{g}║{x}  {b}NullSec WiFi Analyzer v1.0{x} — Scan Results                                          {g}║{x}");
    println!("{g}║{x}  Duration: {:.1}s | APs Found: {} | Channels Active: {}                          {g}║{x}",
        results.scan_duration.as_secs_f64(), results.aps.len(), results.channels.len());
    println!("{g}╠════════════════════════════════════════════════════════════════════════════════════════╣{x}");

    // AP Table
    println!("{g}║{x}                                                                                        {g}║{x}");
    println!("{g}║{x}  {b}ACCESS POINTS{x}                                                                        {g}║{x}");
    println!("{g}║{x}  {c}BSSID              SSID                      CH  SIG    ENC    SIGNAL{x}               {g}║{x}");
    println!("{g}║{x}  ─────────────────  ────────────────────────  ──  ─────  ─────  ──────────               {g}║{x}");

    let mut sorted_aps = results.aps.clone();
    sorted_aps.sort_by(|a, b| b.signal.cmp(&a.signal));

    for ap in &sorted_aps {
        let ssid_display = if ap.is_hidden {
            "<hidden>".to_string()
        } else if ap.ssid.len() > 24 {
            format!("{}...", &ap.ssid[..21])
        } else {
            ap.ssid.clone()
        };

        println!("{g}║{x}  {}  {:<24}  {:>2}  {:>3}dBm  {:<5}  {}  {g}║{x}",
            ap.bssid_str(), ssid_display, ap.channel, ap.signal,
            ap.encryption, signal_bar(ap.signal));
    }

    // Channel Analysis
    println!("{g}║{x}                                                                                        {g}║{x}");
    println!("{g}╠════════════════════════════════════════════════════════════════════════════════════════╣{x}");
    println!("{g}║{x}                                                                                        {g}║{x}");
    println!("{g}║{x}  {b}CHANNEL ANALYSIS (2.4GHz){x}                                                             {g}║{x}");
    println!("{g}║{x}  {c}CH  FREQ     APs  AVG SIG  CONGESTION{x}                                                 {g}║{x}");
    println!("{g}║{x}  ──  ───────  ───  ───────  ──────────                                                 {g}║{x}");

    let mut channel_list: Vec<&ChannelStats> = results.channels.values()
        .filter(|c| c.channel <= 14)
        .collect();
    channel_list.sort_by_key(|c| c.channel);

    for ch in &channel_list {
        let congestion_len = (ch.utilization_score * 2.0).min(20.0) as usize;
        let cong_color = if congestion_len < 5 { g } else if congestion_len < 12 { y } else { r };
        let bar = format!("{}{}{}", cong_color, "█".repeat(congestion_len),
            "░".repeat(20 - congestion_len));

        println!("{g}║{x}  {:>2}  {}MHz  {:>3}  {:>5.0}dBm  {}{x}                                                 {g}║{x}",
            ch.channel, ch.frequency, ch.ap_count, ch.avg_signal, bar);
    }

    // 5GHz channels
    let channels_5g: Vec<&ChannelStats> = results.channels.values()
        .filter(|c| c.channel > 14)
        .collect();

    if !channels_5g.is_empty() {
        println!("{g}║{x}                                                                                        {g}║{x}");
        println!("{g}║{x}  {b}CHANNEL ANALYSIS (5GHz){x}                                                               {g}║{x}");
        println!("{g}║{x}  {c}CH   FREQ     APs  AVG SIG  CONGESTION{x}                                                {g}║{x}");
        println!("{g}║{x}  ───  ───────  ───  ───────  ──────────                                                {g}║{x}");

        let mut sorted_5g = channels_5g;
        sorted_5g.sort_by_key(|c| c.channel);

        for ch in &sorted_5g {
            let congestion_len = (ch.utilization_score * 2.0).min(20.0) as usize;
            let cong_color = if congestion_len < 5 { g } else if congestion_len < 12 { y } else { r };
            let bar = format!("{}{}{}", cong_color, "█".repeat(congestion_len),
                "░".repeat(20 - congestion_len));

            println!("{g}║{x}  {:>3}  {}MHz  {:>3}  {:>5.0}dBm  {}{x}                                                {g}║{x}",
                ch.channel, ch.frequency, ch.ap_count, ch.avg_signal, bar);
        }
    }

    // Recommendations
    println!("{g}║{x}                                                                                        {g}║{x}");
    println!("{g}╠════════════════════════════════════════════════════════════════════════════════════════╣{x}");
    println!("{g}║{x}                                                                                        {g}║{x}");
    println!("{g}║{x}  {b}RECOMMENDATIONS{x}                                                                       {g}║{x}");

    // Find best 2.4GHz channel (1, 6, or 11 - non-overlapping)
    let non_overlap = [1u8, 6, 11];
    let mut best_24 = 1u8;
    let mut best_score = f64::MAX;

    for &ch in &non_overlap {
        let score = results.channels.get(&ch)
            .map(|s| s.utilization_score)
            .unwrap_or(0.0);
        if score < best_score {
            best_score = score;
            best_24 = ch;
        }
    }

    println!("{g}║{x}  {g}►{x} Best 2.4GHz channel: {b}{}{x} (score: {:.1}, lower = better)                          {g}║{x}",
        best_24, best_score);

    // Find best 5GHz channel
    if !results.channels.is_empty() {
        let mut best_5g = 0u8;
        let mut best_5_score = f64::MAX;

        for (ch, stats) in &results.channels {
            if *ch > 14 && stats.utilization_score < best_5_score {
                best_5_score = stats.utilization_score;
                best_5g = *ch;
            }
        }

        if best_5g > 0 {
            println!("{g}║{x}  {g}►{x} Best 5GHz channel: {b}{}{x} (score: {:.1})                                          {g}║{x}",
                best_5g, best_5_score);
        }
    }

    // Hidden networks warning
    let hidden_count = results.aps.iter().filter(|ap| ap.is_hidden).count();
    if hidden_count > 0 {
        println!("{g}║{x}  {y}⚠{x} {hidden_count} hidden network(s) detected                                                     {g}║{x}");
    }

    // Open networks warning
    let open_count = results.aps.iter().filter(|ap| ap.encryption == "OPN").count();
    if open_count > 0 {
        println!("{g}║{x}  {r}!{x} {open_count} open (unencrypted) network(s) — potential targets                              {g}║{x}");
    }

    println!("{g}║{x}                                                                                        {g}║{x}");
    println!("{g}╚════════════════════════════════════════════════════════════════════════════════════════╝{x}");
    println!();
}

fn print_json(results: &ScanResults) {
    println!("{{");
    println!("  \"scan_duration_secs\": {:.1},", results.scan_duration.as_secs_f64());
    println!("  \"total_aps\": {},", results.aps.len());
    println!("  \"access_points\": [");

    for (i, ap) in results.aps.iter().enumerate() {
        let comma = if i < results.aps.len() - 1 { "," } else { "" };
        println!("    {{\"bssid\":\"{}\",\"ssid\":\"{}\",\"channel\":{},\"signal\":{},\"encryption\":\"{}\",\"hidden\":{}}}{}",
            ap.bssid_str(), ap.ssid, ap.channel, ap.signal, ap.encryption, ap.is_hidden, comma);
    }

    println!("  ],");
    println!("  \"channels\": [");

    let channel_list: Vec<&ChannelStats> = results.channels.values().collect();
    for (i, ch) in channel_list.iter().enumerate() {
        let comma = if i < channel_list.len() - 1 { "," } else { "" };
        println!("    {{\"channel\":{},\"frequency\":{},\"ap_count\":{},\"avg_signal\":{:.0},\"utilization\":{:.1}}}{}",
            ch.channel, ch.frequency, ch.ap_count, ch.avg_signal, ch.utilization_score, comma);
    }

    println!("  ]");
    println!("}}");
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main
// ═══════════════════════════════════════════════════════════════════════════════

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 || args[1] == "-h" || args[1] == "--help" {
        eprintln!("\x1b[32mNullSec WiFi Analyzer v1.0\x1b[0m — 802.11 Spectrum Analyzer\n");
        eprintln!("Usage:");
        eprintln!("  {} <interface> [options]", args[0]);
        eprintln!();
        eprintln!("Options:");
        eprintln!("  --json          JSON output");
        eprintln!("  --duration <s>  Scan duration in seconds (default: 10)");
        eprintln!("  -h, --help      Show this help");
        eprintln!();
        eprintln!("Examples:");
        eprintln!("  {} wlan0mon", args[0]);
        eprintln!("  {} wlan0mon --json > wifi-scan.json", args[0]);
        eprintln!("  {} wlan0mon --duration 30", args[0]);
        process::exit(1);
    }

    let interface = &args[1];
    let json_output = args.contains(&"--json".to_string());
    let duration = args.iter()
        .position(|a| a == "--duration")
        .and_then(|i| args.get(i + 1))
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(10);

    match run_scan(interface, duration) {
        Ok(results) => {
            if json_output {
                print_json(&results);
            } else {
                print_results(&results);
            }
        }
        Err(e) => {
            eprintln!("\x1b[31mError:\x1b[0m {}", e);
            process::exit(1);
        }
    }
}
