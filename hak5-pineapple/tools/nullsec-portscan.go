/*
═══════════════════════════════════════════════════════════════════════════════
 NullSec PortScan v1.0 — Concurrent TCP Port Scanner
 Author: bad-antics
═══════════════════════════════════════════════════════════════════════════════

 A fast, concurrent TCP port scanner written in Go with:
  - Concurrent scanning with configurable worker pool
  - Service fingerprinting via banner grabbing
  - Common port detection with service names
  - JSON, CSV, or table output
  - CIDR range support
  - Configurable timeouts and rate limiting

 Build:   go build -o nullsec-portscan nullsec-portscan.go
 Usage:   nullsec-portscan -target 192.168.40.0/24 -ports 22,80,443
          nullsec-portscan -target 192.168.40.209 -ports 1-1024 -json
*/

package main

import (
	"encoding/binary"
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// ═══════════════════════════════════════════════════════════════════════════════
// Data Types
// ═══════════════════════════════════════════════════════════════════════════════

type ScanResult struct {
	Host    string `json:"host"`
	Port    int    `json:"port"`
	State   string `json:"state"`
	Service string `json:"service"`
	Banner  string `json:"banner,omitempty"`
	Latency string `json:"latency"`
}

type HostResult struct {
	Host     string       `json:"host"`
	Hostname string       `json:"hostname,omitempty"`
	Ports    []ScanResult `json:"ports"`
}

// ═══════════════════════════════════════════════════════════════════════════════
// Well-Known Ports
// ═══════════════════════════════════════════════════════════════════════════════

var commonPorts = map[int]string{
	21: "ftp", 22: "ssh", 23: "telnet", 25: "smtp", 53: "dns",
	80: "http", 110: "pop3", 111: "rpc", 135: "msrpc", 139: "netbios",
	143: "imap", 161: "snmp", 389: "ldap", 443: "https", 445: "smb",
	465: "smtps", 514: "syslog", 587: "submission", 631: "ipp", 636: "ldaps",
	993: "imaps", 995: "pop3s", 1080: "socks", 1433: "mssql", 1471: "pineapple",
	1521: "oracle", 2049: "nfs", 2222: "alt-ssh", 3306: "mysql",
	3389: "rdp", 5432: "postgres", 5900: "vnc", 6379: "redis",
	8080: "http-proxy", 8443: "https-alt", 8888: "http-alt",
	9090: "web-console", 9200: "elasticsearch", 27017: "mongodb",
}

// ═══════════════════════════════════════════════════════════════════════════════
// Network Helpers
// ═══════════════════════════════════════════════════════════════════════════════

// expandCIDR returns all host IPs in a CIDR range
func expandCIDR(cidr string) ([]string, error) {
	// If no CIDR notation, treat as single host
	if !strings.Contains(cidr, "/") {
		return []string{cidr}, nil
	}

	ip, ipnet, err := net.ParseCIDR(cidr)
	if err != nil {
		return nil, err
	}

	var ips []string
	mask := binary.BigEndian.Uint32(ipnet.Mask)
	start := binary.BigEndian.Uint32(ip.To4()) & mask
	end := start | ^mask

	for i := start + 1; i < end; i++ {
		ipBytes := make(net.IP, 4)
		binary.BigEndian.PutUint32(ipBytes, i)
		ips = append(ips, ipBytes.String())
	}

	return ips, nil
}

// parsePorts converts port specification to int slice
// Supports: "22", "22,80,443", "1-1024", "22,80,100-200"
func parsePorts(spec string) ([]int, error) {
	var ports []int
	seen := make(map[int]bool)

	for _, part := range strings.Split(spec, ",") {
		part = strings.TrimSpace(part)
		if strings.Contains(part, "-") {
			bounds := strings.SplitN(part, "-", 2)
			start, err := strconv.Atoi(bounds[0])
			if err != nil {
				return nil, fmt.Errorf("invalid port: %s", bounds[0])
			}
			end, err := strconv.Atoi(bounds[1])
			if err != nil {
				return nil, fmt.Errorf("invalid port: %s", bounds[1])
			}
			for p := start; p <= end; p++ {
				if !seen[p] {
					ports = append(ports, p)
					seen[p] = true
				}
			}
		} else {
			p, err := strconv.Atoi(part)
			if err != nil {
				return nil, fmt.Errorf("invalid port: %s", part)
			}
			if !seen[p] {
				ports = append(ports, p)
				seen[p] = true
			}
		}
	}
	return ports, nil
}

// ═══════════════════════════════════════════════════════════════════════════════
// Scanner
// ═══════════════════════════════════════════════════════════════════════════════

type Scanner struct {
	Timeout    time.Duration
	Workers    int
	GrabBanner bool
	scanned    int64
	open       int64
}

func (s *Scanner) scanPort(host string, port int) ScanResult {
	addr := fmt.Sprintf("%s:%d", host, port)
	start := time.Now()

	result := ScanResult{
		Host:  host,
		Port:  port,
		State: "closed",
	}

	// Service name lookup
	if name, ok := commonPorts[port]; ok {
		result.Service = name
	}

	conn, err := net.DialTimeout("tcp", addr, s.Timeout)
	if err != nil {
		atomic.AddInt64(&s.scanned, 1)
		return result
	}
	defer conn.Close()

	result.State = "open"
	result.Latency = fmt.Sprintf("%.1fms", float64(time.Since(start).Microseconds())/1000)
	atomic.AddInt64(&s.open, 1)

	// Banner grabbing
	if s.GrabBanner {
		conn.SetReadDeadline(time.Now().Add(2 * time.Second))
		buf := make([]byte, 1024)
		n, _ := conn.Read(buf)
		if n > 0 {
			banner := strings.TrimSpace(string(buf[:n]))
			// Truncate and sanitize
			if len(banner) > 128 {
				banner = banner[:128]
			}
			result.Banner = strings.Map(func(r rune) rune {
				if r >= 32 && r < 127 {
					return r
				}
				return '.'
			}, banner)

			// Auto-detect service from banner
			if result.Service == "" {
				bannerLower := strings.ToLower(result.Banner)
				switch {
				case strings.Contains(bannerLower, "ssh"):
					result.Service = "ssh"
				case strings.Contains(bannerLower, "http"):
					result.Service = "http"
				case strings.Contains(bannerLower, "ftp"):
					result.Service = "ftp"
				case strings.Contains(bannerLower, "smtp"):
					result.Service = "smtp"
				case strings.Contains(bannerLower, "mysql"):
					result.Service = "mysql"
				case strings.Contains(bannerLower, "redis"):
					result.Service = "redis"
				}
			}
		}
	}

	atomic.AddInt64(&s.scanned, 1)
	return result
}

func (s *Scanner) ScanHost(host string, ports []int) HostResult {
	result := HostResult{Host: host}

	// Reverse DNS
	names, err := net.LookupAddr(host)
	if err == nil && len(names) > 0 {
		result.Hostname = strings.TrimSuffix(names[0], ".")
	}

	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, s.Workers)

	for _, port := range ports {
		wg.Add(1)
		sem <- struct{}{}
		go func(p int) {
			defer wg.Done()
			defer func() { <-sem }()

			sr := s.scanPort(host, p)
			if sr.State == "open" {
				mu.Lock()
				result.Ports = append(result.Ports, sr)
				mu.Unlock()
			}
		}(port)
	}

	wg.Wait()

	// Sort by port number
	sort.Slice(result.Ports, func(i, j int) bool {
		return result.Ports[i].Port < result.Ports[j].Port
	})

	return result
}

// ═══════════════════════════════════════════════════════════════════════════════
// Output Formatters
// ═══════════════════════════════════════════════════════════════════════════════

func outputTable(results []HostResult) {
	green := "\033[32m"
	cyan := "\033[36m"
	reset := "\033[0m"

	fmt.Printf("\n%s╔══════════════════════════════════════════════════════════════════════════════╗%s\n", green, reset)
	fmt.Printf("%s║%s  NullSec PortScan Results                                                   %s║%s\n", green, reset, green, reset)
	fmt.Printf("%s╠══════════════════════════════════════════════════════════════════════════════╣%s\n", green, reset)

	totalOpen := 0
	for _, host := range results {
		if len(host.Ports) == 0 {
			continue
		}

		label := host.Host
		if host.Hostname != "" {
			label = fmt.Sprintf("%s (%s)", host.Host, host.Hostname)
		}
		fmt.Printf("%s║%s  %s%-50s%s  %d open ports        %s║%s\n",
			green, reset, cyan, label, reset, len(host.Ports), green, reset)
		fmt.Printf("%s║%s  %-7s %-8s %-14s %-8s %-30s %s║%s\n",
			green, reset, "PORT", "STATE", "SERVICE", "LATENCY", "BANNER", green, reset)
		fmt.Printf("%s║%s  %-7s %-8s %-14s %-8s %-30s %s║%s\n",
			green, reset, "───────", "────────", "──────────────", "────────", "──────────────────────────────", green, reset)

		for _, p := range host.Ports {
			banner := p.Banner
			if len(banner) > 30 {
				banner = banner[:27] + "..."
			}
			fmt.Printf("%s║%s  %-7d %-8s %-14s %-8s %-30s %s║%s\n",
				green, reset, p.Port, p.State, p.Service, p.Latency, banner, green, reset)
			totalOpen++
		}
		fmt.Printf("%s║%s                                                                              %s║%s\n", green, reset, green, reset)
	}

	fmt.Printf("%s╠══════════════════════════════════════════════════════════════════════════════╣%s\n", green, reset)
	fmt.Printf("%s║%s  Total: %d hosts scanned, %d open ports found                                %s║%s\n",
		green, reset, len(results), totalOpen, green, reset)
	fmt.Printf("%s╚══════════════════════════════════════════════════════════════════════════════╝%s\n\n", green, reset)
}

func outputJSON(results []HostResult) {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.Encode(results)
}

func outputCSV(results []HostResult) {
	w := csv.NewWriter(os.Stdout)
	w.Write([]string{"host", "hostname", "port", "state", "service", "banner", "latency"})

	for _, host := range results {
		for _, p := range host.Ports {
			w.Write([]string{
				host.Host, host.Hostname,
				strconv.Itoa(p.Port), p.State, p.Service,
				p.Banner, p.Latency,
			})
		}
	}
	w.Flush()
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main
// ═══════════════════════════════════════════════════════════════════════════════

func main() {
	target := flag.String("target", "", "Target host or CIDR (e.g. 192.168.40.0/24)")
	ports := flag.String("ports", "22,80,443,8080", "Port specification (e.g. 22,80 or 1-1024)")
	workers := flag.Int("workers", 200, "Concurrent workers per host")
	timeout := flag.Int("timeout", 1000, "Connection timeout in ms")
	banner := flag.Bool("banner", true, "Enable banner grabbing")
	jsonOut := flag.Bool("json", false, "JSON output")
	csvOut := flag.Bool("csv", false, "CSV output")
	topPorts := flag.Bool("top", false, "Scan top 40 common ports")
	allPorts := flag.Bool("all", false, "Scan all 65535 ports (slow)")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "\033[32mNullSec PortScan v1.0\033[0m — Concurrent TCP Scanner\n\n")
		fmt.Fprintf(os.Stderr, "Usage:\n")
		fmt.Fprintf(os.Stderr, "  nullsec-portscan -target <host|CIDR> [options]\n\n")
		fmt.Fprintf(os.Stderr, "Examples:\n")
		fmt.Fprintf(os.Stderr, "  nullsec-portscan -target 192.168.40.209 -ports 1-1024\n")
		fmt.Fprintf(os.Stderr, "  nullsec-portscan -target 192.168.40.0/24 -top\n")
		fmt.Fprintf(os.Stderr, "  nullsec-portscan -target 10.10.10.0/24 -json > scan.json\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
	}

	flag.Parse()

	if *target == "" {
		flag.Usage()
		os.Exit(1)
	}

	// Determine ports to scan
	var portList []int
	var err error

	if *allPorts {
		portList = make([]int, 65535)
		for i := range portList {
			portList[i] = i + 1
		}
	} else if *topPorts {
		for p := range commonPorts {
			portList = append(portList, p)
		}
		sort.Ints(portList)
	} else {
		portList, err = parsePorts(*ports)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	}

	// Expand targets
	hosts, err := expandCIDR(*target)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	scanner := &Scanner{
		Timeout:    time.Duration(*timeout) * time.Millisecond,
		Workers:    *workers,
		GrabBanner: *banner,
	}

	if !*jsonOut && !*csvOut {
		fmt.Fprintf(os.Stderr, "\033[32m⬡ NullSec PortScan v1.0\033[0m\n")
		fmt.Fprintf(os.Stderr, "  Targets: %d hosts, %d ports per host\n", len(hosts), len(portList))
		fmt.Fprintf(os.Stderr, "  Workers: %d, Timeout: %dms, Banner: %v\n\n", *workers, *timeout, *banner)
	}

	start := time.Now()
	var results []HostResult

	for i, host := range hosts {
		if !*jsonOut && !*csvOut {
			fmt.Fprintf(os.Stderr, "\r  Scanning %s (%d/%d)...", host, i+1, len(hosts))
		}
		result := scanner.ScanHost(host, portList)
		if len(result.Ports) > 0 {
			results = append(results, result)
		}
	}

	elapsed := time.Since(start)

	if !*jsonOut && !*csvOut {
		fmt.Fprintf(os.Stderr, "\r  Scan complete in %s                              \n", elapsed.Round(time.Millisecond))
	}

	// Output
	switch {
	case *jsonOut:
		outputJSON(results)
	case *csvOut:
		outputCSV(results)
	default:
		outputTable(results)
	}
}
