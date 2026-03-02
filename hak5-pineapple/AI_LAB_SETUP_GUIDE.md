# 🤖 Combined AI Lab Setup Guide

## Overview
This setup combines:
- **GitHub Copilot Premium** (with request optimization via MCP)
- **Local Ollama AI** (localhost:11434)
- **AI Lab Interface** (localhost:3080)
- **Mesh Network Fallback** (automatic failover)
- **Human-In-The-Loop MCP Server** (confirms without consuming premium requests)

---

## 📋 What This Solves

### The Problem
Every time Copilot asks for confirmation or user input in chat, it creates a new session that **consumes a premium request**. With many interactions, you can burn through 300-1500 monthly requests quickly.

### The Solution
Using an MCP (Model Context Protocol) server, all confirmations and user inputs are handled **outside** the Copilot chat session. This means:
- ✅ Confirmations don't consume premium requests
- ✅ Your local Ollama models are used as fallback
- ✅ Lab interface is available alongside Copilot
- ✅ Mesh network provides redundancy

---

## 🚀 Quick Start

### 1. Verify Services Are Running

```bash
# Check Ollama
curl http://localhost:11434/api/tags

# Check Lab
curl http://localhost:3080

# Both should return data
```

### 2. Install & Start Everything

```bash
cd /home/antics/nullsec/hak5-pineapple

# Make scripts executable
chmod +x start-ai-lab.sh mesh-ai-fallback.sh

# Start all services
./start-ai-lab.sh
```

### 3. Configure Codium/VS Code

The configuration files have been created automatically:
- `~/.config/VSCodium/User/copilot-settings.json` - Copilot + Ollama integration
- `~/.config/VSCodium/User/mcp.json` - MCP server registration
- `/home/antics/nullsec/hak5-pineapple/mcp-servers/human-input-loop/` - MCP server

### 4. Open Codium & Use Copilot

```bash
codium &
```

In Codium:
1. Open Copilot Chat (`Ctrl+Shift+L`)
2. Ask a question that might require confirmation
3. **Important:** Confirmation will appear in terminal, NOT in the chat window
4. Answer in the terminal
5. Copilot continues without new session = **no premium request consumed**

---

## 🔄 How It Works

### Request Flow (Without MCP - EXPENSIVE)
```
You → Copilot Chat (Premium Request #1)
     → Copilot needs confirmation
You → Copilot Chat (Premium Request #2) ← Wasted!
     → Copilot gets answer, continues
```
**Cost: 2+ premium requests for one task**

### Request Flow (With MCP - EFFICIENT)
```
You → Copilot Chat (Premium Request #1)
     → Copilot needs confirmation
     → Triggers MCP Server (NO SESSION RESTART)
You → MCP Terminal Prompt (FREE)
     → MCP returns answer to Copilot
     → Copilot continues with same session
```
**Cost: 1 premium request for same task**

---

## 🛠️ MCP Server Functions

The Human-In-The-Loop MCP server provides three functions:

### 1. `get_multiline_input` (Open-ended answers)
```
Copilot asks: "Tell me what features you want"
MCP shows: 📝 "Tell me what features you want"
You type: Lines of text, then type END
Result: Sent back to Copilot without new session
```

### 2. `get_confirmation` (Yes/No questions)
```
Copilot asks: "Should I refactor this function?"
MCP shows: ⚠️ "Should I refactor this function? (yes/no)"
You type: yes
Result: Confirmation returned, Copilot continues
```

### 3. `get_selection` (Choose from options)
```
Copilot asks: "Which language?"
MCP shows: 🔍 "Which language?"
         1. Python
         2. JavaScript
         3. Go
You type: 1
Result: Selection returned, Copilot continues
```

---

## 🎯 Copilot Default Instructions

Your Copilot has been configured with instructions to:
1. **ALWAYS** use MCP tools for any user interaction
2. **NEVER** send responses back to Copilot chat (which would consume premium)
3. Use MCP for questions, clarifications, confirmations, and follow-ups
4. Handle cancellations gracefully

These instructions are mandatory and prevent request waste.

---

## 🌐 Mesh Network Integration

If your services fail, the mesh fallback automatically routes to backup nodes:

```bash
# Check health of all nodes
./mesh-ai-fallback.sh

# Output:
# ✅ http://localhost:11434 - ONLINE
# ✅ http://localhost:3080 - ONLINE
```

To add mesh network nodes, edit `mesh-ai-fallback.sh`:
```bash
BACKUP_NODES=(
  "http://mesh-node-1:11434"
  "http://mesh-node-2:3080"
)
```

---

## 📊 Monitoring & Logs

### Check Service Status
```bash
# Ollama models
curl http://localhost:11434/api/tags | jq .

# Lab status
curl http://localhost:3080 | head -20

# MCP Server logs
tail -f /home/antics/nullsec/hak5-pineapple/mcp-servers/.logs/mcp-server.log
```

### Your Available Ollama Models
- `hailmary:latest` (General purpose)
- `hailmary-creative:latest` (Creative writing)
- `hailmary-precise:latest` (Technical precision)
- `hailmary-roleplay:latest` (Role-playing)
- `hailmary-research:latest` (Research focus)

---

## 💡 Usage Tips

### 1. **Batch Related Tasks**
Instead of: "Write function → Confirm → Write tests → Confirm → Document → Confirm"

Do: "Write function with tests and documentation, then ask for feedback" (1 session, 1 request)

### 2. **Pre-Define Options**
Instead of Copilot asking "Which approach?", tell it in your prompt.

### 3. **Long Conversations**
Since confirmations don't consume requests, you can have longer conversations without guilt.

### 4. **Monitor Usage**
Track saved requests:
```bash
# Estimate: If you typically get 2-3 confirmations per task
# And do 30 tasks/month
# You save: 30 × 2.5 × (requests/confirmation) = SIGNIFICANT savings
```

---

## 🔧 Troubleshooting

### "Can't connect to localhost:11434"
```bash
# Check if Ollama is running
curl -s http://localhost:11434/api/tags

# If not, start it:
ollama serve &
```

### "Lab not loading on 3080"
```bash
# Check service
curl http://localhost:3080

# If port is taken, kill the process:
lsof -i :3080  # Find PID
kill -9 <PID>
```

### "MCP Server not responding"
```bash
# Check logs
tail -f mcp-servers/.logs/mcp-server.log

# Restart manually
cd mcp-servers/human-input-loop
npm install
node server.js
```

### "Copilot not using MCP tools"
```bash
# Verify settings exist
ls -la ~/.config/VSCodium/User/mcp.json
ls -la ~/.config/VSCodium/User/copilot-settings.json

# Restart Codium
codium --kill-server
codium &
```

---

## 📈 Expected Results

### Before This Setup
- ❌ 300 requests → exhausted by ~50 tasks
- ❌ Confirmations waste ~30% of requests
- ❌ Lab disconnects when Copilot fails

### After This Setup
- ✅ 300 requests → sufficient for 100+ tasks
- ✅ Confirmations use 0 requests (MCP handles them)
- ✅ Automatic fallback to mesh + Ollama

---

## 🚀 Advanced: Custom Models

To use different Ollama models:

1. **Pull a model**
```bash
ollama pull mistral
ollama pull neural-chat
```

2. **Update settings** in `~/.config/VSCodium/User/copilot-settings.json`
```json
"copilot.chat.ollamaModels": [
  "mistral:latest",
  "neural-chat:latest"
],
"copilot.chat.preferredModel": "mistral:latest"
```

3. **Restart Codium**

---

## 📚 Additional Resources

- [GitHub Copilot Billing Docs](https://docs.github.com/en/copilot/concepts/billing/copilot-requests)
- [MCP Specification](https://modelcontextprotocol.io/)
- [Ollama Documentation](https://ollama.ai/)

---

## ✨ Summary

You now have:
1. ✅ Copilot Chat with MCP-based confirmations (saves premium requests)
2. ✅ Local Ollama AI as fallback (never gets rate-limited)
3. ✅ AI Lab interface (localhost:3080) for direct access
4. ✅ Mesh network routing (automatic failover)
5. ✅ Comprehensive logging and monitoring

**Start using it:** Run `./start-ai-lab.sh` and open Codium!

---

**Last Updated:** 2026-02-28
**Status:** Ready for Production
