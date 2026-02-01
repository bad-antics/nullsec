#!/usr/bin/env python3
"""
NullSec Performance Monitor v1.1
Monitor and optimize module execution

GitHub: https://github.com/bad-antics/nullsec
"""
import time
import psutil
import json
from datetime import datetime

__version__ = "1.1"
__author__ = "bad-antics"

class PerformanceMonitor:
    def __init__(self):
        self.metrics = {}
        self.start_time = None
        
    def start(self, module_name):
        self.metrics[module_name] = {
            'start': time.time(),
            'cpu_start': psutil.cpu_percent(),
            'mem_start': psutil.virtual_memory().percent
        }
        
    def stop(self, module_name):
        if module_name in self.metrics:
            m = self.metrics[module_name]
            m['end'] = time.time()
            m['duration'] = m['end'] - m['start']
            m['cpu_end'] = psutil.cpu_percent()
            m['mem_end'] = psutil.virtual_memory().percent
            
    def report(self):
        return json.dumps(self.metrics, indent=2)
        
    def save_report(self, path='performance_report.json'):
        with open(path, 'w') as f:
            f.write(self.report())

if __name__ == '__main__':
    monitor = PerformanceMonitor()
    print("NullSec Performance Monitor v1.0")

# Updated: Sun 01 Feb 2026 02:13:07 PM PST
VERSION = '1.1'
