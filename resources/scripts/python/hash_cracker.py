#!/usr/bin/env python3
"""Multi-algorithm hash cracker"""

import hashlib
import sys

ALGORITHMS = {
    'md5': hashlib.md5,
    'sha1': hashlib.sha1,
    'sha256': hashlib.sha256,
    'sha512': hashlib.sha512,
}

def crack_hash(target_hash, wordlist_file, algorithm='md5'):
    """Attempt to crack hash using wordlist"""
    
    if algorithm not in ALGORITHMS:
        print(f"[-] Unsupported algorithm: {algorithm}")
        return None
    
    hash_func = ALGORITHMS[algorithm]
    
    try:
        with open(wordlist_file, 'r', encoding='utf-8', errors='ignore') as f:
            for i, line in enumerate(f, 1):
                password = line.strip()
                hashed = hash_func(password.encode()).hexdigest()
                
                if i % 10000 == 0:
                    print(f"[*] Tried {i} passwords...", end='\r')
                
                if hashed == target_hash.lower():
                    print(f"\n[+] Password found: {password}")
                    return password
        
        print(f"\n[-] Password not found in wordlist")
        return None
        
    except FileNotFoundError:
        print(f"[-] Wordlist not found: {wordlist_file}")
        return None

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: hash_cracker.py <hash> <wordlist> [algorithm]")
        print("Algorithms: md5, sha1, sha256, sha512")
        sys.exit(1)
    
    target = sys.argv[1]
    wordlist = sys.argv[2]
    algo = sys.argv[3] if len(sys.argv) > 3 else 'md5'
    
    crack_hash(target, wordlist, algo)
