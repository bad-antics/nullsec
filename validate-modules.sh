#!/bin/bash

# Quick module functionality validator
echo "╭─ NULLSEC MODULE VALIDATION"
echo "│"

# Test modules that were reportedly broken
test_modules=(
    "port-scanner"
    "wifi-deauth"
    "web-exploit"
    "password-crack"
)

working=0
broken=0

for mod in "${test_modules[@]}"; do
    echo "├─ Testing $mod..."
    
    # Check if files exist
    if [ ! -f ~/nullsec/nullsecurity/${mod}.sh ] || [ ! -f ~/nullsec/nullsecurity/${mod}.json ]; then
        echo "│  ❌ Missing files"
        ((broken++))
        continue
    fi
    
    # Check JSON validity
    if ! python3 -m json.tool ~/nullsec/nullsecurity/${mod}.json >/dev/null 2>&1; then
        echo "│  ❌ Invalid JSON"
        ((broken++))
        continue
    fi
    
    # Check bash syntax
    if ! bash -n ~/nullsec/nullsecurity/${mod}.sh 2>/dev/null; then
        echo "│  ❌ Bash syntax error"
        ((broken++))
        continue
    fi
    
    # Try to load with framework (just load, don't execute)
    if timeout 2 python3 -c "
import sys
sys.path.insert(0, '/home/antics/nullsec')
from pathlib import Path
exec(open('/home/antics/nullsec/module-framework.py').read())
fw = InteractiveFramework()
config = fw.load_config_from_json('/home/antics/nullsec/nullsecurity/${mod}.json')
if config:
    print('OK')
    sys.exit(0)
else:
    sys.exit(1)
" 2>/dev/null | grep -q "OK"; then
        echo "│  ✅ Working"
        ((working++))
    else
        echo "│  ❌ Framework load failed"
        ((broken++))
    fi
done

echo "│"
echo "╰─ VALIDATION COMPLETE"
echo ""
echo "📊 Results:"
echo "  ✅ Working: $working"
echo "  ❌ Broken:  $broken"
echo ""

if [ $broken -eq 0 ]; then
    echo "🎉 All tested modules are functional!"
    exit 0
else
    echo "⚠️  Some modules need attention"
    exit 1
fi
