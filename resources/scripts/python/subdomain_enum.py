#!/usr/bin/env python3
"""Subdomain enumeration with DNS resolution"""

import dns.resolver
import concurrent.futures
import sys

def check_subdomain(domain, subdomain):
    """Check if subdomain exists"""
    try:
        full_domain = f"{subdomain}.{domain}"
        answers = dns.resolver.resolve(full_domain, 'A')
        ips = [str(rdata) for rdata in answers]
        return (full_domain, ips)
    except:
        return None

def enumerate_subdomains(domain, wordlist_file, threads=50):
    """Enumerate subdomains from wordlist"""
    found = []
    
    try:
        with open(wordlist_file, 'r') as f:
            subdomains = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"[-] Wordlist not found: {wordlist_file}")
        return found
    
    print(f"[*] Testing {len(subdomains)} subdomains for {domain}")
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=threads) as executor:
        futures = {executor.submit(check_subdomain, domain, sub): sub for sub in subdomains}
        
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            if result:
                subdomain, ips = result
                print(f"[+] {subdomain} → {', '.join(ips)}")
                found.append(result)
    
    return found

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: subdomain_enum.py <domain> [wordlist]")
        sys.exit(1)
    
    domain = sys.argv[1]
    wordlist = sys.argv[2] if len(sys.argv) > 2 else "/home/antics/nullsec/resources/wordlists/subdomains/common-subdomains.txt"
    
    found = enumerate_subdomains(domain, wordlist)
    print(f"\n[✓] Found {len(found)} subdomains")
