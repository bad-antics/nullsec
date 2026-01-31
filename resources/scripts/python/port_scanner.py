#!/usr/bin/env python3
"""Fast multi-threaded port scanner"""

import socket
import concurrent.futures
from datetime import datetime

def scan_port(host, port, timeout=1):
    """Scan a single port"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return port if result == 0 else None
    except:
        return None

def scan_ports(host, ports=range(1, 1025), threads=100):
    """Scan multiple ports using threading"""
    open_ports = []
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=threads) as executor:
        future_to_port = {executor.submit(scan_port, host, port): port for port in ports}
        for future in concurrent.futures.as_completed(future_to_port):
            result = future.result()
            if result:
                open_ports.append(result)
                print(f"[+] Port {result} is open")
    
    return sorted(open_ports)

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        host = sys.argv[1]
        print(f"Scanning {host}...")
        start = datetime.now()
        open_ports = scan_ports(host)
        elapsed = (datetime.now() - start).total_seconds()
        print(f"\nFound {len(open_ports)} open ports in {elapsed:.2f} seconds")
