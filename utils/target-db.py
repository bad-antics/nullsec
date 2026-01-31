#!/usr/bin/env python3
"""
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
█  NULLSEC TARGET DATABASE MANAGER                                 █
█  Centralized target management for NULLSEC framework             █
█                    [ bad-antics development ]                    █
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

Features:
- Add/edit/delete targets
- Import from nmap, Shodan, CSV
- Export to various formats
- Quick scan integration
- Target notes and tags
- Status tracking
"""

import sqlite3
import sys
import json
import csv
import subprocess
from datetime import datetime

DB_PATH = '../nullsec.db'

class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    RESET = '\033[0m'
    DIM = '\033[2m'

class TargetDB:
    def __init__(self, db_path=DB_PATH):
        self.conn = sqlite3.connect(db_path)
        self.cursor = self.conn.cursor()
    
    def list_targets(self, workspace='default', status=None):
        """List all targets"""
        query = "SELECT * FROM targets WHERE workspace=?"
        params = [workspace]
        
        if status:
            query += " AND status=?"
            params.append(status)
        
        query += " ORDER BY last_seen DESC"
        
        self.cursor.execute(query, params)
        columns = [desc[0] for desc in self.cursor.description]
        targets = []
        
        for row in self.cursor.fetchall():
            targets.append(dict(zip(columns, row)))
        
        return targets
    
    def add_target(self, ip, hostname='', os='', ports='', services='',
                   status='unknown', notes='', tags='', workspace='default'):
        """Add new target"""
        try:
            self.cursor.execute('''INSERT INTO targets 
                (ip, hostname, os, ports, services, status, first_seen, last_seen, notes, tags, workspace)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                (ip, hostname, os, ports, services, status,
                 datetime.now().isoformat(), datetime.now().isoformat(),
                 notes, tags, workspace))
            self.conn.commit()
            return True
        except sqlite3.IntegrityError:
            return False
    
    def update_target(self, ip, **kwargs):
        """Update target fields"""
        fields = []
        values = []
        
        for key, value in kwargs.items():
            if key in ['hostname', 'os', 'ports', 'services', 'status', 'notes', 'tags']:
                fields.append(f"{key}=?")
                values.append(value)
        
        if not fields:
            return False
        
        fields.append("last_seen=?")
        values.append(datetime.now().isoformat())
        values.append(ip)
        
        query = f"UPDATE targets SET {', '.join(fields)} WHERE ip=?"
        self.cursor.execute(query, values)
        self.conn.commit()
        return True
    
    def delete_target(self, ip):
        """Delete target"""
        self.cursor.execute("DELETE FROM targets WHERE ip=?", (ip,))
        self.conn.commit()
        return True
    
    def import_nmap_xml(self, xml_file, workspace='default'):
        """Import targets from nmap XML output"""
        try:
            import xml.etree.ElementTree as ET
            tree = ET.parse(xml_file)
            root = tree.getroot()
            
            count = 0
            for host in root.findall('.//host'):
                status = host.find('status')
                if status is None or status.get('state') != 'up':
                    continue
                
                # Get IP
                addr = host.find('address[@addrtype="ipv4"]')
                if addr is None:
                    continue
                ip = addr.get('addr')
                
                # Get hostname
                hostname_elem = host.find('.//hostname')
                hostname = hostname_elem.get('name') if hostname_elem is not None else ''
                
                # Get OS
                os_match = host.find('.//osmatch')
                os_info = os_match.get('name') if os_match is not None else ''
                
                # Get ports
                ports_list = []
                for port in host.findall('.//port'):
                    port_id = port.get('portid')
                    service = port.find('service')
                    service_name = service.get('name') if service is not None else 'unknown'
                    ports_list.append(f"{port_id}/{service_name}")
                
                ports = ','.join(ports_list)
                
                self.add_target(ip, hostname, os_info, ports, '', 'alive', '', '', workspace)
                count += 1
            
            return count
        except Exception as e:
            print(f"{Colors.RED}[!] Error importing nmap XML: {e}{Colors.RESET}")
            return 0
    
    def import_csv(self, csv_file, workspace='default'):
        """Import targets from CSV (ip,hostname,os,ports,notes)"""
        count = 0
        try:
            with open(csv_file, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    self.add_target(
                        row.get('ip', ''),
                        row.get('hostname', ''),
                        row.get('os', ''),
                        row.get('ports', ''),
                        '',
                        row.get('status', 'unknown'),
                        row.get('notes', ''),
                        row.get('tags', ''),
                        workspace
                    )
                    count += 1
            return count
        except Exception as e:
            print(f"{Colors.RED}[!] Error importing CSV: {e}{Colors.RESET}")
            return 0
    
    def export_csv(self, output_file, workspace='default'):
        """Export targets to CSV"""
        targets = self.list_targets(workspace)
        
        if not targets:
            return 0
        
        try:
            with open(output_file, 'w', newline='') as f:
                fieldnames = ['ip', 'hostname', 'os', 'ports', 'services',
                            'status', 'notes', 'tags', 'first_seen', 'last_seen']
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                
                for target in targets:
                    writer.writerow({k: target.get(k, '') for k in fieldnames})
            
            return len(targets)
        except Exception as e:
            print(f"{Colors.RED}[!] Error exporting CSV: {e}{Colors.RESET}")
            return 0
    
    def export_json(self, output_file, workspace='default'):
        """Export targets to JSON"""
        targets = self.list_targets(workspace)
        
        try:
            with open(output_file, 'w') as f:
                json.dump(targets, f, indent=2)
            return len(targets)
        except Exception as e:
            print(f"{Colors.RED}[!] Error exporting JSON: {e}{Colors.RESET}")
            return 0
    
    def scan_target(self, ip, scan_type='quick'):
        """Quick scan target with nmap"""
        print(f"{Colors.CYAN}[*] Scanning {ip}...{Colors.RESET}")
        
        if scan_type == 'quick':
            cmd = f"nmap -sV -T4 {ip}"
        elif scan_type == 'full':
            cmd = f"nmap -sV -sC -p- {ip}"
        else:
            cmd = f"nmap -sV {ip}"
        
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
            output = result.stdout
            
            # Parse output
            import re
            ports_match = re.findall(r'(\d+)/tcp\s+open\s+(\S+)', output)
            ports = ','.join([f"{p[0]}/{p[1]}" for p in ports_match])
            
            os_match = re.search(r'OS details: (.+)', output)
            os_info = os_match.group(1) if os_match else ''
            
            self.update_target(ip, ports=ports, os=os_info, status='alive')
            
            print(f"{Colors.GREEN}[✓] Scan complete{Colors.RESET}")
            print(f"{Colors.DIM}    Ports: {ports}{Colors.RESET}")
            if os_info:
                print(f"{Colors.DIM}    OS: {os_info}{Colors.RESET}")
            
            return True
        except Exception as e:
            print(f"{Colors.RED}[!] Scan failed: {e}{Colors.RESET}")
            return False
    
    def close(self):
        """Close database connection"""
        self.conn.close()

def print_banner():
    print(f"""{Colors.CYAN}
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
█{Colors.WHITE}                 NULLSEC TARGET DATABASE MANAGER{Colors.CYAN}                        █
█{Colors.DIM}                    [ bad-antics development ]{Colors.CYAN}                        █
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
{Colors.RESET}""")

def interactive_menu():
    """Interactive menu"""
    db = TargetDB()
    workspace = 'default'
    
    while True:
        print(f"""
{Colors.YELLOW}Current Workspace: {Colors.WHITE}{workspace}{Colors.RESET}

{Colors.CYAN}[1]{Colors.RESET} List targets        {Colors.CYAN}[6]{Colors.RESET} Scan target
{Colors.CYAN}[2]{Colors.RESET} Add target          {Colors.CYAN}[7]{Colors.RESET} Import nmap XML
{Colors.CYAN}[3]{Colors.RESET} Update target       {Colors.CYAN}[8]{Colors.RESET} Import CSV
{Colors.CYAN}[4]{Colors.RESET} Delete target       {Colors.CYAN}[9]{Colors.RESET} Export CSV
{Colors.CYAN}[5]{Colors.RESET} Search targets      {Colors.CYAN}[10]{Colors.RESET} Export JSON
{Colors.CYAN}[W]{Colors.RESET} Switch workspace    {Colors.CYAN}[Q]{Colors.RESET} Quit

{Colors.WHITE}Choice: {Colors.RESET}""", end='')
        
        choice = input().strip().lower()
        
        if choice == 'q':
            break
        elif choice == '1':
            targets = db.list_targets(workspace)
            if targets:
                print(f"\n{Colors.GREEN}Targets in workspace '{workspace}':{Colors.RESET}\n")
                for t in targets:
                    status_color = Colors.GREEN if t['status'] == 'alive' else Colors.RED
                    print(f"  {status_color}●{Colors.RESET} {Colors.WHITE}{t['ip']:<15}{Colors.RESET} "
                          f"{t['hostname']:<25} {Colors.DIM}{t['os'][:30]}{Colors.RESET}")
                print(f"\n{Colors.DIM}Total: {len(targets)} targets{Colors.RESET}")
            else:
                print(f"\n{Colors.YELLOW}[*] No targets in this workspace{Colors.RESET}")
        
        elif choice == '2':
            ip = input(f"{Colors.WHITE}IP Address: {Colors.RESET}").strip()
            hostname = input(f"{Colors.WHITE}Hostname (optional): {Colors.RESET}").strip()
            notes = input(f"{Colors.WHITE}Notes (optional): {Colors.RESET}").strip()
            
            if db.add_target(ip, hostname=hostname, notes=notes, workspace=workspace):
                print(f"{Colors.GREEN}[✓] Target added{Colors.RESET}")
            else:
                print(f"{Colors.RED}[!] Target already exists{Colors.RESET}")
        
        elif choice == '6':
            ip = input(f"{Colors.WHITE}IP to scan: {Colors.RESET}").strip()
            scan_type = input(f"{Colors.WHITE}Scan type (quick/full) [quick]: {Colors.RESET}").strip() or 'quick'
            db.scan_target(ip, scan_type)
        
        elif choice == '7':
            xml_file = input(f"{Colors.WHITE}Nmap XML file: {Colors.RESET}").strip()
            count = db.import_nmap_xml(xml_file, workspace)
            print(f"{Colors.GREEN}[✓] Imported {count} targets{Colors.RESET}")
        
        elif choice == '9':
            output = input(f"{Colors.WHITE}Output CSV file: {Colors.RESET}").strip()
            count = db.export_csv(output, workspace)
            print(f"{Colors.GREEN}[✓] Exported {count} targets{Colors.RESET}")
        
        elif choice == 'w':
            workspace = input(f"{Colors.WHITE}Workspace name: {Colors.RESET}").strip() or 'default'
            print(f"{Colors.GREEN}[✓] Switched to workspace: {workspace}{Colors.RESET}")
    
    db.close()

def main():
    """Main function"""
    if len(sys.argv) > 1:
        # Command line mode
        db = TargetDB()
        
        cmd = sys.argv[1]
        
        if cmd == 'list':
            workspace = sys.argv[2] if len(sys.argv) > 2 else 'default'
            targets = db.list_targets(workspace)
            for t in targets:
                print(f"{t['ip']}\t{t['hostname']}\t{t['status']}\t{t['ports']}")
        
        elif cmd == 'add' and len(sys.argv) > 2:
            ip = sys.argv[2]
            hostname = sys.argv[3] if len(sys.argv) > 3 else ''
            db.add_target(ip, hostname=hostname)
            print(f"Added {ip}")
        
        elif cmd == 'scan' and len(sys.argv) > 2:
            ip = sys.argv[2]
            db.scan_target(ip)
        
        elif cmd == 'import-nmap' and len(sys.argv) > 2:
            xml_file = sys.argv[2]
            workspace = sys.argv[3] if len(sys.argv) > 3 else 'default'
            count = db.import_nmap_xml(xml_file, workspace)
            print(f"Imported {count} targets")
        
        elif cmd == 'export-csv' and len(sys.argv) > 2:
            output = sys.argv[2]
            workspace = sys.argv[3] if len(sys.argv) > 3 else 'default'
            count = db.export_csv(output, workspace)
            print(f"Exported {count} targets")
        
        else:
            print(f"""Usage:
  {sys.argv[0]}                          - Interactive mode
  {sys.argv[0]} list [workspace]         - List targets
  {sys.argv[0]} add <ip> [hostname]      - Add target
  {sys.argv[0]} scan <ip>                - Scan target
  {sys.argv[0]} import-nmap <file> [workspace]
  {sys.argv[0]} export-csv <file> [workspace]
""")
        
        db.close()
    else:
        # Interactive mode
        print_banner()
        interactive_menu()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}[!] Interrupted{Colors.RESET}")
    except Exception as e:
        print(f"{Colors.RED}[!] Error: {e}{Colors.RESET}")
        import traceback
        traceback.print_exc()
