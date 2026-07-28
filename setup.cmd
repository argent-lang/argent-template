@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-win.ps1" %*
exit /b %errorlevel%
