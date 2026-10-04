@echo off
REM Double-click-friendly wrapper for run.ps1, for people using plain cmd.exe
REM or who just want to double-click a file in Explorer instead of opening
REM PowerShell themselves. Does the exact same thing as .\run.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
pause
