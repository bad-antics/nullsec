#!/bin/bash
# Verify AI Lab Setup - Check all components

echo "🔍 AI Lab Setup Verification"
echo "=============================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_status() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✅${NC} $2"
  else
    echo -e "${RED}❌${NC} $2"
  fi
}

echo "📡 Service Status:"
echo "-----------------"

# Check Ollama
if curl -s -m 2 http://localhost:11434/api/tags > /dev/null 2>&1; then
  check_status 0 "Ollama (11434)"
  OLLAMA_MODELS=$(curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | wc -l)
  echo "   └─ $OLLAMA_MODELS models loaded"
else
  check_status 1 "Ollama (11434)"
fi

# Check Lab
if curl -s -m 2 http://localhost:3080 > /dev/null 2>&1; then
  check_status 0 "Lab Interface (3080)"
else
  check_status 1 "Lab Interface (3080)"
fi

echo ""
echo "📁 Configuration Files:"
echo "-----------------------"

# Check config files
[ -f ~/.config/VSCodium/User/copilot-settings.json ] && check_status 0 "Copilot Settings" || check_status 1 "Copilot Settings"
[ -f ~/.config/VSCodium/User/mcp.json ] && check_status 0 "MCP Configuration" || check_status 1 "MCP Configuration"
[ -f /home/antics/nullsec/hak5-pineapple/mcp-servers/human-input-loop/server.js ] && check_status 0 "MCP Server" || check_status 1 "MCP Server"

echo ""
echo "🛠️  Scripts:"
echo "-------------"

[ -x /home/antics/nullsec/hak5-pineapple/start-ai-lab.sh ] && check_status 0 "Start Script" || check_status 1 "Start Script"
[ -x /home/antics/nullsec/hak5-pineapple/mesh-ai-fallback.sh ] && check_status 0 "Mesh Fallback" || check_status 1 "Mesh Fallback"
[ -f /home/antics/nullsec/hak5-pineapple/AI_LAB_SETUP_GUIDE.md ] && check_status 0 "Documentation" || check_status 1 "Documentation"

echo ""
echo "🚀 Ready to Use:"
echo "----------------"

if curl -s -m 2 http://localhost:11434/api/tags > /dev/null 2>&1 && \
   curl -s -m 2 http://localhost:3080 > /dev/null 2>&1 && \
   [ -f ~/.config/VSCodium/User/copilot-settings.json ]; then
  echo -e "${GREEN}✨ Your AI Lab is fully configured and ready!${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Open Codium: codium &"
  echo "2. Open Copilot Chat: Ctrl+Shift+L"
  echo "3. Ask a question that needs confirmation"
  echo "4. Answer in the terminal (not in the chat)"
  echo "5. Copilot continues without consuming a premium request!"
  echo ""
  echo "Access Lab directly: http://localhost:3080"
else
  echo -e "${YELLOW}⚠️  Some components are offline.${NC}"
  echo ""
  echo "Make sure Ollama and Lab are running:"
  echo "• ollama serve (if not already running)"
  echo "• Your lab application on port 3080"
fi

echo ""
