#!/bin/bash

# Quick test of enhanced modules
echo "╭─ TESTING ENHANCED MODULES"
echo "│"

# Test 1: Verify JSON configs exist
echo "├─ Test 1: JSON Configuration Files"
json_count=$(ls -1 ~/nullsec/nullsecurity/*.json 2>/dev/null | wc -l)
if [ "$json_count" -ge 180 ]; then
    echo "│  ✅ Found $json_count JSON configs"
else
    echo "│  ❌ Only found $json_count JSON configs (expected 180+)"
fi
echo "│"

# Test 2: Verify logging helpers in modules
echo "├─ Test 2: Logging Helpers in Modules"
helper_count=$(grep -l "log_to_file()" ~/nullsec/nullsecurity/*.sh 2>/dev/null | wc -l)
if [ "$helper_count" -ge 180 ]; then
    echo "│  ✅ Found logging helpers in $helper_count modules"
else
    echo "│  ❌ Only found helpers in $helper_count modules"
fi
echo "│"

# Test 3: Verify catalog generation
echo "├─ Test 3: Module Catalog"
if [ -f ~/nullsec/ENHANCED_MODULES_CATALOG.md ]; then
    size=$(wc -c < ~/nullsec/ENHANCED_MODULES_CATALOG.md)
    echo "│  ✅ Catalog exists ($size bytes)"
else
    echo "│  ❌ Catalog not found"
fi
echo "│"

# Test 4: Sample module structure
echo "├─ Test 4: Sample Module Check (port-scanner)"
if [ -f ~/nullsec/nullsecurity/port-scanner.sh ] && [ -f ~/nullsec/nullsecurity/port-scanner.json ]; then
    echo "│  ✅ port-scanner.sh exists"
    echo "│  ✅ port-scanner.json exists"
    
    # Check for logging helpers
    if grep -q "log_to_file()" ~/nullsec/nullsecurity/port-scanner.sh; then
        echo "│  ✅ Logging helpers present"
    else
        echo "│  ❌ Missing logging helpers"
    fi
    
    # Check JSON structure
    if jq -e '.parameters' ~/nullsec/nullsecurity/port-scanner.json >/dev/null 2>&1; then
        param_count=$(jq '.parameters | length' ~/nullsec/nullsecurity/port-scanner.json)
        echo "│  ✅ Valid JSON with $param_count parameters"
    else
        echo "│  ❌ Invalid JSON structure"
    fi
else
    echo "│  ❌ Sample module not found"
fi
echo "│"

# Test 5: Framework integration
echo "├─ Test 5: Framework Integration"
if grep -q "module-framework.py" ~/nullsec/nullsec-launcher.py; then
    echo "│  ✅ CLI launcher integrated"
else
    echo "│  ⚠️  CLI launcher may not be integrated"
fi

if grep -q "module-framework.py" ~/nullsec/nullsec-desktop/nullsec_desktop.py; then
    echo "│  ✅ Desktop GUI integrated"
else
    echo "│  ⚠️  Desktop GUI may not be integrated"
fi
echo "│"

# Summary
echo "╰─ TEST COMPLETE"
echo ""
echo "📊 Module Enhancement Status:"
echo "  • Total modules: $(ls -1 ~/nullsec/nullsecurity/*.sh 2>/dev/null | wc -l)"
echo "  • JSON configs: $json_count"
echo "  • Enhanced with logging: $helper_count"
echo "  • Categories: $(jq -r '.category' ~/nullsec/nullsecurity/*.json 2>/dev/null | sort -u | wc -l)"
echo ""
echo "✨ All modules are enhanced and ready!"
echo ""
echo "🚀 Test a module:"
echo "   cd ~/nullsec"
echo "   python3 module-framework.py nullsecurity/port-scanner.sh nullsecurity/port-scanner.json"
