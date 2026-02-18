/*
 * ═══════════════════════════════════════════════════════════════════════════════
 *  NullSec Beacon Dump v1.0
 *  Fast 802.11 Beacon Frame Parser
 *  Author: bad-antics
 * ═══════════════════════════════════════════════════════════════════════════════
 *
 *  Reads pcap files and parses 802.11 beacon/probe frames.
 *  Extracts: SSID, BSSID, channel, signal, encryption, vendor, rates.
 *  Outputs: CSV, JSON, or human-readable table.
 *
 *  Build:   gcc -O2 -o beacon-dump beacon-dump.c -lpcap
 *  Usage:   beacon-dump [-j|-c] <capture.pcap>
 *           beacon-dump -l wlan0mon    (live capture)
 *
 *  For authorized security testing only.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <getopt.h>
#include <signal.h>
#include <pcap.h>

#define MAX_SSID 33
#define MAX_BSSIDS 4096
#define RADIOTAP_SIGNAL_OFFSET 22  /* common offset for dBm signal */
#define IEEE80211_BEACON 0x80
#define IEEE80211_PROBE_RESP 0x50
#define IEEE80211_PROBE_REQ 0x40

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Data structures                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

typedef struct {
    uint8_t  bssid[6];
    char     ssid[MAX_SSID];
    int      channel;
    int8_t   signal;
    uint8_t  encryption;  /* 0=OPN, 1=WEP, 2=WPA, 3=WPA2, 4=WPA3 */
    uint32_t beacon_count;
    uint32_t data_count;
    time_t   first_seen;
    time_t   last_seen;
    uint16_t max_rate;     /* in 0.5 Mbps */
    uint8_t  is_hidden;
    uint8_t  wps;
} ap_record_t;

static ap_record_t ap_table[MAX_BSSIDS];
static int ap_count = 0;
static volatile int running = 1;

/* Output modes */
enum { OUT_TABLE, OUT_CSV, OUT_JSON };

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Utility functions                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void signal_handler(int sig) {
    (void)sig;
    running = 0;
}

static const char *enc_str(uint8_t enc) {
    switch (enc) {
        case 0: return "OPN";
        case 1: return "WEP";
        case 2: return "WPA";
        case 3: return "WPA2";
        case 4: return "WPA3";
        default: return "???";
    }
}

static void mac_str(const uint8_t *mac, char *buf) {
    sprintf(buf, "%02X:%02X:%02X:%02X:%02X:%02X",
            mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

static int find_ap(const uint8_t *bssid) {
    for (int i = 0; i < ap_count; i++) {
        if (memcmp(ap_table[i].bssid, bssid, 6) == 0)
            return i;
    }
    return -1;
}

static int add_or_update_ap(const uint8_t *bssid, const char *ssid,
                             int channel, int8_t signal, uint8_t enc) {
    int idx = find_ap(bssid);
    time_t now = time(NULL);

    if (idx >= 0) {
        ap_table[idx].beacon_count++;
        ap_table[idx].last_seen = now;
        if (signal > ap_table[idx].signal || ap_table[idx].signal == 0)
            ap_table[idx].signal = signal;
        if (ssid[0] && ap_table[idx].is_hidden) {
            strncpy(ap_table[idx].ssid, ssid, MAX_SSID - 1);
            ap_table[idx].is_hidden = 0;
        }
        if (enc > ap_table[idx].encryption)
            ap_table[idx].encryption = enc;
        return idx;
    }

    if (ap_count >= MAX_BSSIDS)
        return -1;

    idx = ap_count++;
    memcpy(ap_table[idx].bssid, bssid, 6);
    strncpy(ap_table[idx].ssid, ssid, MAX_SSID - 1);
    ap_table[idx].channel = channel;
    ap_table[idx].signal = signal;
    ap_table[idx].encryption = enc;
    ap_table[idx].beacon_count = 1;
    ap_table[idx].first_seen = now;
    ap_table[idx].last_seen = now;
    ap_table[idx].is_hidden = (ssid[0] == 0);

    return idx;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* 802.11 Frame Parser                                                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void parse_beacon(const uint8_t *pkt, int len, int8_t signal) {
    if (len < 36) return;  /* minimum beacon frame size */

    /* 802.11 header: FC(2) + Duration(2) + DA(6) + SA(6) + BSSID(6) + SeqCtl(2) */
    uint16_t fc = pkt[0] | (pkt[1] << 8);
    uint8_t type = fc & 0xFC;

    if (type != IEEE80211_BEACON && type != IEEE80211_PROBE_RESP)
        return;

    const uint8_t *bssid = pkt + 16;

    /* Fixed params: Timestamp(8) + Interval(2) + Capability(2) = 12 bytes at offset 24 */
    int offset = 24 + 12;
    if (offset >= len) return;

    char ssid[MAX_SSID] = {0};
    int channel = 0;
    uint8_t encryption = 0;
    uint16_t capability = pkt[24 + 10] | (pkt[24 + 11] << 8);

    /* Privacy bit in capability */
    if (capability & 0x0010)
        encryption = 1;  /* at least WEP */

    /* Parse tagged parameters */
    while (offset + 2 <= len) {
        uint8_t tag_id = pkt[offset];
        uint8_t tag_len = pkt[offset + 1];

        if (offset + 2 + tag_len > len) break;

        switch (tag_id) {
            case 0:  /* SSID */
                if (tag_len > 0 && tag_len < MAX_SSID) {
                    memcpy(ssid, pkt + offset + 2, tag_len);
                    ssid[tag_len] = 0;
                    /* Filter non-printable */
                    for (int i = 0; i < tag_len; i++)
                        if (ssid[i] < 32 || ssid[i] > 126) ssid[i] = '?';
                }
                break;

            case 3:  /* DS Parameter Set (channel) */
                if (tag_len >= 1)
                    channel = pkt[offset + 2];
                break;

            case 48:  /* RSN (WPA2/WPA3) */
                encryption = 3;
                /* Check for SAE (WPA3) in AKM suite */
                if (tag_len >= 8) {
                    const uint8_t *rsn = pkt + offset + 2;
                    /* Simple check: if AKM includes type 8 (SAE), it's WPA3 */
                    for (int i = 8; i + 4 <= tag_len; i += 4) {
                        if (rsn[i + 3] == 8) encryption = 4;
                    }
                }
                break;

            case 221: /* Vendor specific (WPA1) */
                if (tag_len >= 4) {
                    const uint8_t *oui = pkt + offset + 2;
                    if (oui[0] == 0x00 && oui[1] == 0x50 && oui[2] == 0xf2 && oui[3] == 0x01) {
                        if (encryption < 2) encryption = 2;
                    }
                    /* WPS */
                    if (oui[0] == 0x00 && oui[1] == 0x50 && oui[2] == 0xf2 && oui[3] == 0x04) {
                        int aidx = find_ap(bssid);
                        if (aidx >= 0) ap_table[aidx].wps = 1;
                    }
                }
                break;
        }

        offset += 2 + tag_len;
    }

    add_or_update_ap(bssid, ssid, channel, signal, encryption);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Radiotap Header Parser                                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void process_packet(const uint8_t *data, int caplen) {
    if (caplen < 30) return;

    /* Radiotap header */
    uint16_t rt_len = data[2] | (data[3] << 8);
    if (rt_len >= caplen) return;

    /* Extract signal from radiotap (simplified - look for dBm antenna signal) */
    int8_t signal = 0;
    uint32_t rt_present = data[4] | (data[5] << 8) | (data[6] << 16) | (data[7] << 24);

    /* Bit 5 = dBm Antenna Signal */
    if (rt_present & (1 << 5)) {
        /* Walk the radiotap fields to find signal */
        int pos = 8;
        /* Skip TSFT (bit 0, 8 bytes) */
        if (rt_present & (1 << 0)) { pos = (pos + 7) & ~7; pos += 8; }
        /* Skip Flags (bit 1, 1 byte) */
        if (rt_present & (1 << 1)) pos += 1;
        /* Skip Rate (bit 2, 1 byte) */
        if (rt_present & (1 << 2)) pos += 1;
        /* Skip Channel (bit 3, 4 bytes, aligned to 2) */
        if (rt_present & (1 << 3)) { pos = (pos + 1) & ~1; pos += 4; }
        /* Skip FHSS (bit 4, 2 bytes) */
        if (rt_present & (1 << 4)) pos += 2;
        /* Signal (bit 5, 1 byte) */
        if (pos < rt_len)
            signal = (int8_t)data[pos];
    }

    /* Parse 802.11 frame */
    parse_beacon(data + rt_len, caplen - rt_len, signal);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Output Functions                                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

static int cmp_signal(const void *a, const void *b) {
    return ((const ap_record_t *)b)->signal - ((const ap_record_t *)a)->signal;
}

static void output_table(void) {
    qsort(ap_table, ap_count, sizeof(ap_record_t), cmp_signal);

    printf("\n\033[32m╔══════════════════════════════════════════════════════════════════════════════════════╗\033[0m\n");
    printf("\033[32m║\033[0m  %-17s  %-32s  %3s  %5s  %5s  %5s  %3s  \033[32m║\033[0m\n",
           "BSSID", "SSID", "CH", "SIG", "ENC", "BCNS", "WPS");
    printf("\033[32m╠══════════════════════════════════════════════════════════════════════════════════════╣\033[0m\n");

    for (int i = 0; i < ap_count; i++) {
        char mac[18];
        mac_str(ap_table[i].bssid, mac);

        const char *ssid = ap_table[i].is_hidden ? "<hidden>" : ap_table[i].ssid;
        const char *enc = enc_str(ap_table[i].encryption);

        /* Color signal strength */
        const char *sig_color = "\033[32m";  /* green */
        if (ap_table[i].signal < -70) sig_color = "\033[33m";  /* yellow */
        if (ap_table[i].signal < -80) sig_color = "\033[31m";  /* red */

        printf("\033[32m║\033[0m  %s  %-32.32s  %3d  %s%3ddBm\033[0m  %-5s  %5u  %s  \033[32m║\033[0m\n",
               mac, ssid, ap_table[i].channel,
               sig_color, ap_table[i].signal,
               enc, ap_table[i].beacon_count,
               ap_table[i].wps ? "Yes" : " - ");
    }

    printf("\033[32m╚══════════════════════════════════════════════════════════════════════════════════════╝\033[0m\n");
    printf("\n  Total: %d unique APs\n\n", ap_count);
}

static void output_csv(void) {
    printf("bssid,ssid,channel,signal_dbm,encryption,beacons,wps,first_seen,last_seen\n");
    for (int i = 0; i < ap_count; i++) {
        char mac[18];
        mac_str(ap_table[i].bssid, mac);
        printf("%s,\"%s\",%d,%d,%s,%u,%d,%ld,%ld\n",
               mac, ap_table[i].ssid, ap_table[i].channel,
               ap_table[i].signal, enc_str(ap_table[i].encryption),
               ap_table[i].beacon_count, ap_table[i].wps,
               (long)ap_table[i].first_seen, (long)ap_table[i].last_seen);
    }
}

static void output_json(void) {
    printf("[\n");
    for (int i = 0; i < ap_count; i++) {
        char mac[18];
        mac_str(ap_table[i].bssid, mac);
        printf("  {\"bssid\":\"%s\",\"ssid\":\"%s\",\"channel\":%d,\"signal\":%d,"
               "\"encryption\":\"%s\",\"beacons\":%u,\"wps\":%s,"
               "\"hidden\":%s,\"first_seen\":%ld,\"last_seen\":%ld}%s\n",
               mac, ap_table[i].ssid, ap_table[i].channel,
               ap_table[i].signal, enc_str(ap_table[i].encryption),
               ap_table[i].beacon_count,
               ap_table[i].wps ? "true" : "false",
               ap_table[i].is_hidden ? "true" : "false",
               (long)ap_table[i].first_seen, (long)ap_table[i].last_seen,
               i < ap_count - 1 ? "," : "");
    }
    printf("]\n");
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Main                                                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

static void usage(const char *prog) {
    fprintf(stderr,
        "\033[32mNullSec Beacon Dump v1.0\033[0m — Fast 802.11 Beacon Parser\n\n"
        "Usage:\n"
        "  %s [options] <capture.pcap>         Parse pcap file\n"
        "  %s -l <interface>                   Live capture\n\n"
        "Options:\n"
        "  -c          CSV output\n"
        "  -j          JSON output\n"
        "  -l <iface>  Live capture on interface\n"
        "  -n <count>  Stop after N packets\n"
        "  -h          Show this help\n\n",
        prog, prog);
}

int main(int argc, char *argv[]) {
    int output_mode = OUT_TABLE;
    char *iface = NULL;
    char *pcap_file = NULL;
    int max_packets = 0;
    int opt;

    while ((opt = getopt(argc, argv, "cjl:n:h")) != -1) {
        switch (opt) {
            case 'c': output_mode = OUT_CSV; break;
            case 'j': output_mode = OUT_JSON; break;
            case 'l': iface = optarg; break;
            case 'n': max_packets = atoi(optarg); break;
            case 'h': usage(argv[0]); return 0;
            default: usage(argv[0]); return 1;
        }
    }

    if (optind < argc)
        pcap_file = argv[optind];

    if (!iface && !pcap_file) {
        usage(argv[0]);
        return 1;
    }

    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_t *handle;

    if (iface) {
        /* Live capture */
        handle = pcap_open_live(iface, 65535, 1, 100, errbuf);
        if (!handle) {
            fprintf(stderr, "Error opening %s: %s\n", iface, errbuf);
            return 1;
        }
        fprintf(stderr, "\033[32m⬡\033[0m Capturing on %s (Ctrl+C to stop)...\n", iface);
    } else {
        /* File */
        handle = pcap_open_offline(pcap_file, errbuf);
        if (!handle) {
            fprintf(stderr, "Error opening %s: %s\n", pcap_file, errbuf);
            return 1;
        }
    }

    /* Verify radiotap header */
    if (pcap_datalink(handle) != DLT_IEEE802_11_RADIO) {
        fprintf(stderr, "Error: expected radiotap link type (DLT_IEEE802_11_RADIO)\n");
        fprintf(stderr, "Hint: make sure interface is in monitor mode\n");
        pcap_close(handle);
        return 1;
    }

    struct pcap_pkthdr *header;
    const uint8_t *data;
    int pkt_count = 0;

    while (running) {
        int ret = pcap_next_ex(handle, &header, &data);
        if (ret == 0) continue;     /* timeout */
        if (ret < 0) break;         /* error or EOF */

        process_packet(data, header->caplen);
        pkt_count++;

        /* Live status update */
        if (iface && pkt_count % 100 == 0) {
            fprintf(stderr, "\r  Packets: %d  APs: %d  ", pkt_count, ap_count);
        }

        if (max_packets > 0 && pkt_count >= max_packets)
            break;
    }

    pcap_close(handle);

    if (iface)
        fprintf(stderr, "\r  Captured %d packets, found %d unique APs\n\n", pkt_count, ap_count);

    /* Output results */
    switch (output_mode) {
        case OUT_CSV: output_csv(); break;
        case OUT_JSON: output_json(); break;
        default: output_table(); break;
    }

    return 0;
}
