@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop_app.ps1"
set "launcher_exit=%errorlevel%"
pause
exit /b %launcher_exit%
