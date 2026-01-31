# NULLSEC AI v3.0 - Offline-First AI Guide

## 🚀 Revolutionary Features

**NO API KEYS REQUIRED** - NULLSEC AI v3.0 works 100% offline with no accounts, no subscriptions, and no API keys needed!

## ✨ What's New in v3.0

### 1. **Offline-First Architecture**
- Works without any internet connection
- No API keys or user accounts required
- Privacy-focused - all data stays local
- Rule-based expert system as fallback

### 2. **Multiple Free AI Models**
All models are open source and run locally:

| Model | Size | Specialty | Best For |
|-------|------|-----------|----------|
| **DeepSeek Coder** | 6.7B | Code generation | Exploit development, shellcode |
| **CodeLlama** | 13B | Meta's code model | General coding, payloads |
| **WizardCoder** | 15B | Enhanced coding | Complex exploit chains |
| **Mistral** | 7B | Fast general | Quick analysis, recon |
| **Mixtral** | 8x7B | Expert mixture | Advanced scenarios |
| **OpenHermes** | 7B | Instruction tuned | Detailed explanations |
| **Solar** | 10.7B | Advanced reasoning | Attack planning |
| **Phi-2** | 2.7B | Efficient | Low resource systems |
| **Orca2** | 13B | Reasoning | Complex problem solving |
| **Neural Chat** | 7B | Conversational | Interactive pentesting |

### 3. **Built-in Expert System**
When no AI is available, the system uses:
- 100+ pre-programmed pentesting rules
- Methodology-based command generation
- Tool recommendation engine
- Best practice guidance

### 4. **Supported AI Providers**
- **Ollama** (Recommended) - Full featured local AI
- **LM Studio** - GUI-based local AI
- **GPT4All** - Easy to use desktop app
- **LocalAI** - OpenAI-compatible local server

## 📦 Quick Start (3 Methods)

### Method 1: Ollama (Recommended - Best Performance)

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull your first model (choose one or all)
ollama pull deepseek-coder:6.7b    # Best for exploits
ollama pull codellama:13b          # General purpose
ollama pull mistral:7b             # Fast and efficient

# Launch NULLSEC AI
cd /home/antics/nullsec
python3 nullsec-ai.py
```

### Method 2: No AI Setup Required

```bash
# Just run it - works immediately with expert system
cd /home/antics/nullsec
python3 nullsec-ai.py

# The system will use rule-based expert mode
# Still provides pentesting commands and advice
```

### Method 3: LM Studio (GUI Option)

1. Download LM Studio from https://lmstudio.ai
2. Download a model through the GUI
3. Start the local server (default port 1234)
4. Run NULLSEC AI - auto-detects LM Studio

## 💡 Usage Examples

### Interactive Mode

```bash
$ python3 nullsec-ai.py

# Set your target
set target 192.168.1.100

# Choose attack category
set category web

# Ask questions
How do I test for SQL injection?
What ports should I scan first?
Generate a reverse shell payload for Linux

# Execute commands directly
execute nmap -sV 192.168.1.100

# View available models
models

# Install new model
install wizardcoder:15b
```

### Categories Available

- **network** - Port scanning, pivoting, MITM attacks
- **web** - SQLi, XSS, directory fuzzing, API testing
- **wireless** - WiFi cracking, Bluetooth, RFID, SDR
- **credentials** - Password cracking, hash attacks, Kerberos
- **malware** - Payload generation, C2, persistence, evasion
- **recon** - OSINT, subdomain enum, technology detection
- **cloud** - AWS/Azure/GCP exploitation, container security
- **mobile** - Android/iOS testing, APK analysis
- **general** - All-purpose pentesting guidance

### Example Session

```
nullsec-ai(general) > set target testsite.com
[+] Target set to: testsite.com

nullsec-ai(general) > set category web
[+] Category set to: web

nullsec-ai(web)[testsite.com] > enumerate this web application

[AI Response]

WEB APPLICATION ENUMERATION:

1. Technology Detection:
   whatweb http://testsite.com
   wappalyzer testsite.com

2. Directory/File Discovery:
   gobuster dir -u http://testsite.com -w /usr/share/wordlists/dirb/common.txt
   ffuf -u http://testsite.com/FUZZ -w wordlist.txt

3. Subdomain Enumeration:
   subfinder -d testsite.com
   amass enum -d testsite.com

4. Parameter Discovery:
   arjun -u http://testsite.com

5. Vulnerability Scanning:
   nikto -h http://testsite.com
   nuclei -u http://testsite.com

nullsec-ai(web)[testsite.com] > execute gobuster dir -u http://testsite.com -w /usr/share/wordlists/dirb/common.txt
[>] gobuster dir -u http://testsite.com -w /usr/share/wordlists/dirb/common.txt

[gobuster output...]
```

## 🎯 Advanced Features

### 1. Model Management

```bash
# List installed models
nullsec-ai> models

# Install specific model
nullsec-ai> install deepseek-coder:6.7b

# Change preferred model (edit ~/.nullsec-ai-v3.json)
{
  "preferred_provider": "ollama",
  "preferred_model": "deepseek-coder:6.7b"
}
```

### 2. Command Execution

```bash
# Execute commands and log to knowledge base
nullsec-ai> execute nmap -sV 192.168.1.0/24

# View command history
nullsec-ai> history
```

### 3. Knowledge Base

The AI learns from your attacks and stores:
- Commands executed
- Vulnerabilities found
- Attack patterns
- Successful exploits

Database location: `/home/antics/nullsec/.nullsec-ai-v3.db`

## 🔧 Configuration

Edit `/home/antics/nullsec/.nullsec-ai-v3.json`:

```json
{
  "preferred_provider": "ollama",
  "preferred_model": "deepseek-coder:6.7b",
  "temperature": 0.7,
  "max_tokens": 2000,
  "learning_enabled": true,
  "auto_execute": false
}
```

**Options:**
- `preferred_provider`: ollama, lmstudio, gpt4all, localai
- `preferred_model`: Model name to use
- `temperature`: 0.0-1.0 (creativity level)
- `max_tokens`: Response length limit
- `learning_enabled`: Store attack patterns
- `auto_execute`: Auto-run AI-suggested commands (dangerous!)

## 📊 Model Comparison

### Small & Fast (2-7B parameters)
- **Phi-2** (2.7B) - Very fast, good for low-spec systems
- **Mistral** (7B) - Excellent speed/quality balance
- **OpenHermes** (7B) - Great for conversations
- **Neural Chat** (7B) - Good interaction quality

**Use when:** Quick responses needed, limited resources

### Medium (13B parameters)
- **CodeLlama** (13B) - Meta's code specialist
- **Orca2** (13B) - Strong reasoning abilities

**Use when:** Balance of speed and capability

### Large & Powerful (15B+ parameters)
- **WizardCoder** (15B) - Enhanced code generation
- **Mixtral** (8x7B = ~47B) - Expert mixture, very capable
- **Solar** (10.7B) - Advanced reasoning

**Use when:** Complex exploit chains, detailed analysis

### Specialized
- **DeepSeek Coder** (6.7B) - **RECOMMENDED for pentesting**
  - Trained specifically on code and security
  - Excellent at exploit generation
  - Great balance of size and capability

## 🚀 Performance Tips

### Faster Responses
1. Use smaller models (Phi-2, Mistral 7B)
2. Reduce max_tokens in config
3. Use GPU acceleration if available

### Better Quality
1. Use larger models (Mixtral, WizardCoder)
2. Increase temperature for creativity
3. Provide detailed context

### Resource Management
```bash
# Check Ollama status
ollama list

# Monitor resource usage
htop

# Clear GPU cache (if applicable)
ollama stop <model>
```

## 🔒 Privacy & Security

**100% Private:**
- All processing happens locally
- No data sent to external servers
- No telemetry or tracking
- No API keys or accounts

**Security Note:**
The AI runs on your machine and can suggest potentially dangerous commands. Always:
1. Review commands before executing
2. Use in isolated test environments
3. Understand what commands do
4. Keep auto_execute disabled

## 🆘 Troubleshooting

### "No AI providers detected"
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model
ollama pull deepseek-coder:6.7b

# Restart NULLSEC AI
python3 nullsec-ai.py
```

### "Model not found"
```bash
# List available models
ollama list

# Pull the specific model
ollama pull <model-name>
```

### Slow Responses
```bash
# Use a smaller model
ollama pull mistral:7b

# Then in config, set:
"preferred_model": "mistral:7b"
```

### Out of Memory
```bash
# Use Phi-2 (smallest)
ollama pull phi:2.7b

# Or increase swap space
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 📚 Example Queries

### Reconnaissance
```
"How do I discover all subdomains for example.com?"
"What's the best way to enumerate SMB shares?"
"Generate a comprehensive recon plan for 192.168.1.0/24"
```

### Exploitation
```
"Create a reverse shell payload for Windows"
"How to test for SQL injection in POST parameters?"
"Generate a XXE attack payload"
"What's the best approach to exploit EternalBlue?"
```

### Post-Exploitation
```
"How to escalate privileges on Linux?"
"Commands to dump credentials from Windows"
"How to establish persistence on a compromised system?"
```

### Evasion
```
"How to bypass Windows Defender when running Mimikatz?"
"Obfuscate this PowerShell payload"
"Techniques to avoid IDS detection during port scanning"
```

## 🎓 Learning Resources

The AI provides guidance on:
- OWASP Top 10 exploitation
- Network pentesting methodologies
- Privilege escalation techniques
- Wireless security attacks
- Cloud penetration testing
- Mobile app security
- Red team operations

## ⚡ Quick Commands

```bash
# Fast start with specific target
echo -e "set target 192.168.1.100\nscan this target\nexit" | python3 nullsec-ai.py

# Get web enumeration commands
echo -e "set category web\nenumerate web app\nexit" | python3 nullsec-ai.py

# Check installed models
ollama list

# Update Ollama
curl -fsSL https://ollama.com/install.sh | sh
```

## 🌟 Integration with NULLSEC Framework

The AI integrates seamlessly with NULLSEC:

```bash
# From NULLSEC launcher
python3 nullsec-launcher.py
[I] AI Console    # Launches AI assistant

# Direct from command line
python3 nullsec-ai.py

# In scripts
python3 nullsec-ai.py < queries.txt
```

## 📈 Future Enhancements

Planned features:
- Fine-tuned models specifically for pentesting
- Automated exploit chain generation
- Integration with Metasploit
- Real-time vulnerability database queries
- Collaborative multi-agent attacks
- Visual attack graph generation

## 🎉 Summary

NULLSEC AI v3.0 brings professional AI-powered pentesting to everyone:

✅ **No API keys or accounts** - 100% free and private  
✅ **Works offline** - No internet required  
✅ **10+ AI models** - Choose based on your needs  
✅ **Expert fallback** - Works even without AI  
✅ **Learns from you** - Builds knowledge base  
✅ **Easy to use** - Simple command interface  

Get started in 2 minutes - no signup, no payment, no tracking!

---

**Author:** bad-antics development  
**Repository:** github.com/bad-antics/nullsec  
**Version:** 3.0  
**License:** For authorized security testing only
