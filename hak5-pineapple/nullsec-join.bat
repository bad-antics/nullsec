@echo off
:: ============================================================
:: NullSec Mesh Cluster - Auto Join Launcher
:: Double-click this file OR right-click > Run as Administrator
:: ============================================================

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process cmd.exe -ArgumentList '/k cd /d \"%~dp0\" && \"%~f0\"' -Verb RunAs"
    exit /b
)

:: Stay on the USB drive
cd /d "%~dp0"

:: Check the script exists
if not exist "%~dp0nullsec-join.ps1" (
    echo.
    echo ERROR: nullsec-join.ps1 not found on this drive!
    echo Make sure all files are in the same folder.
    echo.
    pause
    exit /b 1
)

:: Run it
echo.
echo Starting NullSec Mesh Cluster Auto-Join...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0nullsec-join.ps1"

:: Keep window open
echo.
echo Script complete. You can close this window.
pause
