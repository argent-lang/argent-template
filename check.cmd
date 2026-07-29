@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-win.ps1"
exit /b %errorlevel%
