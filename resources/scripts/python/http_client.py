#!/usr/bin/env python3
"""Advanced HTTP client with retry logic and session management"""

import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
import warnings
warnings.filterwarnings('ignore')

class HTTPClient:
    def __init__(self, timeout=10, retries=3):
        self.timeout = timeout
        self.session = requests.Session()
        
        retry_strategy = Retry(
            total=retries,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
    
    def get(self, url, **kwargs):
        return self.session.get(url, timeout=self.timeout, verify=False, **kwargs)
    
    def post(self, url, **kwargs):
        return self.session.post(url, timeout=self.timeout, verify=False, **kwargs)
    
    def put(self, url, **kwargs):
        return self.session.put(url, timeout=self.timeout, verify=False, **kwargs)
    
    def delete(self, url, **kwargs):
        return self.session.delete(url, timeout=self.timeout, verify=False, **kwargs)

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        client = HTTPClient()
        response = client.get(sys.argv[1])
        print(f"Status: {response.status_code}")
        print(f"Headers: {dict(response.headers)}")
        print(f"\n{response.text[:500]}")
