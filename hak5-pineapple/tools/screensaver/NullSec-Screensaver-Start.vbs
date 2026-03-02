Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & Replace(WScript.ScriptFullName, "NullSec-Screensaver-Start.vbs", "NullSec-IdleWatch.ps1") & """", 0, False
