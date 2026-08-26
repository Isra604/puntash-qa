@echo off
setlocal
set "ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\install-gui.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" if not "%RC%"=="4" pause
exit /b %RC%
