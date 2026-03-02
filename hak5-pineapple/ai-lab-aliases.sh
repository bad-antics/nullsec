#!/usr/bin/env bash
# Quick Reference: AI Lab Commands

# 🚀 Start everything
alias ai-start='bash /home/antics/nullsec/hak5-pineapple/start-ai-lab.sh'

# ✅ Verify setup
alias ai-verify='bash /home/antics/nullsec/hak5-pineapple/verify-ai-lab.sh'

# 🌐 Check mesh health
alias ai-health='bash /home/antics/nullsec/hak5-pineapple/mesh-ai-fallback.sh'

# 🔗 Quick service checks
ai-status() {
  echo "Ollama:"
  curl -s http://localhost:11434/api/tags | jq '.models | length' && echo "  ✅ Running"
  echo ""
  echo "Lab:"
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3080
}

# 📊 View logs
ai-logs() {
  tail -f /home/antics/nullsec/hak5-pineapple/mcp-servers/.logs/mcp-server.log
}

# 🌐 Open lab in browser
ai-open() {
  xdg-open http://localhost:3080 2>/dev/null || open http://localhost:3080
}

# 💬 Open Codium with AI setup
ai-code() {
  codium /home/antics/nullsec/hak5-pineapple &
}

# 🔧 Setup aliases in your shell
# Add to ~/.bashrc or ~/.zshrc:
# source /home/antics/nullsec/hak5-pineapple/ai-lab-aliases.sh

echo "AI Lab aliases loaded!"
echo ""
echo "Available commands:"
echo "  ai-start    - Start all AI services"
echo "  ai-verify   - Verify setup"
echo "  ai-health   - Check mesh network health"
echo "  ai-status   - Quick service status"
echo "  ai-logs     - View MCP server logs"
echo "  ai-open     - Open Lab in browser"
echo "  ai-code     - Open Codium with workspace"
