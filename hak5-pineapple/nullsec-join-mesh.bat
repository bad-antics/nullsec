@echo off
title NullSec Cluster — Windows Join
color 0A
echo.
echo  ====================================================
echo   NullSec Cluster — Windows Auto-Join
echo  ====================================================
echo.

:: Check admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  Requesting Administrator privileges...
    echo  A UAC prompt will appear — click Yes.
    echo.
    :: Re-launch this exact bat file as admin, keeping the drive path
    powershell -Command "Start-Process cmd.exe -ArgumentList '/k \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:: We're admin now. Change to the drive/directory where the bat lives.
:: This is critical when running from USB — admin CMD defaults to C:\Windows\System32
cd /d "%~dp0"
echo  Running as Administrator ✓
echo  Script directory: %~dp0
echo.

:: Find the PS1 script
if not exist "%~dp0nullsec-join-mesh.ps1" (
    echo  [!] ERROR: nullsec-join-mesh.ps1 not found!
    echo  Expected at: %~dp0nullsec-join-mesh.ps1
    echo  Make sure both files are on the same USB drive.
    echo.
    pause
    exit /b 1
)

echo  Launching PowerShell script...
echo  ====================================================
echo.

:: Run with -NoExit so window stays open if it crashes, -NoProfile to avoid profile issues
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0nullsec-join-mesh.ps1"

:: Catch PowerShell exit code
if %errorlevel% neq 0 (
    echo.
    echo  [!] Script exited with error code: %errorlevel%
    echo.
)

:: Always pause so the user can see the output
pause
