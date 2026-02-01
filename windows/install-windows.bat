@echo off
REM ═══════════════════════════════════════════════════════════════════════════════
REM NullSec Linux - NULLSEC FRAMEWORK v2.0 - WINDOWS INSTALLER
REM Compatible with NullSec Linux 1.0 (void)
REM ═══════════════════════════════════════════════════════════════════════════════

title NullSec Linux - NULLSEC Framework v2.0 Installer
color 0C

echo.
echo  ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄  
echo  ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█  
echo ▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄ 
echo ▓██▒  ▐▌██▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒▒▓█  ▄ ▒▓▓▄ ▄██▒
echo ▒██░   ▓██░▒▒█████▓ ░██████▒░██████▒▒██████▒▒░▒████▒▒ ▓███▀ ░
echo.
color 0B
echo   ═══════════════════════════════════════════════════════════════════
echo   ☠  NullSec Linux - NULLSEC FRAMEWORK v2.0 INSTALLER  ☠
echo   ═══════════════════════════════════════════════════════════════════
echo.
color 07

echo [*] Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo [!] Python not found! Please install Python 3.8+
    echo [*] Download from: https://www.python.org/downloads/
    pause
    exit /b 1
)

echo [+] Python found!
echo.

echo [*] Installing Python dependencies...
pip install --upgrade pip >nul 2>&1
pip install requests colorama pyqt5 >nul 2>&1
echo [+] Dependencies installed!
echo.

echo [*] Creating directories...
if not exist "powershell-modules" mkdir powershell-modules
if not exist "logs" mkdir logs
echo [+] Directories created!
echo.

echo ═══════════════════════════════════════════════════════════════════
echo.
echo [*] Checking for Ollama (AI Support)...
where ollama >nul 2>&1
if errorlevel 1 (
    echo [!] Ollama not found
    echo.
    echo Would you like to install Ollama for AI support?
    echo This enables offline AI-powered pentesting assistance.
    echo.
    set /p install_ollama="Install Ollama? (y/n): "
    if /i "%install_ollama%"=="y" (
        echo [*] Installing Ollama...
        winget install Ollama.Ollama
        echo.
        echo [*] Pulling recommended AI model...
        ollama pull deepseek-coder:6.7b
    )
) else (
    echo [+] Ollama found!
    ollama list
)
echo.

echo ═══════════════════════════════════════════════════════════════════
echo.
color 0A
echo   INSTALLATION COMPLETE!
echo.
echo   Available Components:
echo   ─────────────────────────────────────────────────────────────────
echo.
echo   [1] NULLSEC Launcher (CLI)
echo       python nullsec-launcher-windows.py
echo.
echo   [2] NULLSEC AI v3.0 (Pentesting AI)
echo       python nullsec-ai-windows.py
echo.
echo   [3] NULLSEC Desktop (GUI)
echo       python nullsec-desktop-windows.py
echo.
echo   ─────────────────────────────────────────────────────────────────
echo.
color 07

set /p launch="Launch NULLSEC now? (1/2/3/n): "

if "%launch%"=="1" (
    python nullsec-launcher-windows.py
) else if "%launch%"=="2" (
    python nullsec-ai-windows.py
) else if "%launch%"=="3" (
    python nullsec-desktop-windows.py
)

echo.
echo [+] Thank you for using NULLSEC Framework!
echo.
pause
