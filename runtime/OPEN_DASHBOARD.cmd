@echo off
setlocal
set "ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\open-dashboard.ps1"
if errorlevel 1 pause
