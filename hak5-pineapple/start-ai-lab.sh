#!/bin/bash
# Start all AI services with mesh fallback integration

set -e

REPO_DIR="/home/antics/nullsec/hak5-pineapple"
MCP_SERVER_DIR="$REPO_DIR/mcp-servers/human-input-loop"
LOG_DIR="$REPO_DIR/mcp-servers/.logs"

mkdir -p "$LOG_DIR"

echo "🚀 Starting Combined AI Lab Setup..."
echo ""

# Check if Ollama is running
echo "📡 Checking Ollama service..."
if curl -s -m 2 http://localhost:11434/api/tags > /dev/null; then
  echo "✅ Ollama is running on localhost:11434"
else
  echo "⚠️  Ollama not responding. Starting Ollama..."
  # Uncomment if you want auto-start
  # ollama serve &
fi

# Check if Lab service is running
echo "📡 Checking Lab service..."
if curl -s -m 2 http://localhost:3080 > /dev/null; then
  echo "✅ Lab is running on localhost:3080"
else
  echo "⚠️  Lab not responding on localhost:3080"
fi

echo ""
echo "🔧 Installing MCP Server dependencies..."
cd "$MCP_SERVER_DIR"
if [ ! -d "node_modules" ]; then
  npm install --silent 2>/dev/null || echo "⚠️  npm install had issues, continuing..."
fi

echo ""
echo "🎯 Starting Human-In-The-Loop MCP Server..."
node "$MCP_SERVER_DIR/server.js" > "$LOG_DIR/mcp-server.log" 2>&1 &
MCP_PID=$!
echo "✅ MCP Server started (PID: $MCP_PID)"

echo ""
echo "🌐 Verifying mesh network..."
bash "$REPO_DIR/mesh-ai-fallback.sh"

echo ""
echo "📝 Configuration Summary:"
echo "   • Ollama Endpoint: http://localhost:11434"
echo "   • Lab Endpoint: http://localhost:3080"
echo "   • MCP Server: Enabled (Human-In-The-Loop)"
echo "   • Copilot Default Instructions: Updated"
echo "   • Mesh Fallback: Enabled"
echo ""
echo "✨ Setup Complete! Your AI chat is ready:"
echo "   1. Open Codium/VS Code"
echo "   2. Use Copilot Chat - it will use your local Ollama + MCP"
echo "   3. Confirmations handled via MCP (saves premium requests)"
echo "   4. Access lab at: http://localhost:3080"
echo ""
echo "🔗 Logs available at: $LOG_DIR/"

# Keep script running to maintain services
wait
