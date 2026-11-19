@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run_app.ps1" %*
if errorlevel 1 (
    echo.
    echo Falha no launcher. Consulte as mensagens acima.
    pause
    exit /b 1
)
