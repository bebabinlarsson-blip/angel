@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Angel Godot Debugger

set "GODOT_EXE=C:\Users\Benji-Laptop\Documents\Godot\Godot.exe"
if defined GODOT_BIN set "GODOT_EXE=%GODOT_BIN%"

if not exist "%GODOT_EXE%" (
    echo Godot executable not found at "%GODOT_EXE%"
    echo Set GODOT_BIN to your Godot executable and run this file again.
    pause
    exit /b 1
)

set "DEBUG_ADAPTER_PORT=%~1"
if not defined DEBUG_ADAPTER_PORT set "DEBUG_ADAPTER_PORT=6006"

for /f "usebackq delims=" %%P in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=[int]('%DEBUG_ADAPTER_PORT%'); while (Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue) { $p++ }; $p"`) do set "DEBUG_ADAPTER_PORT=%%P"

echo Starting Angel with Debug Adapter on port %DEBUG_ADAPTER_PORT%...
"%GODOT_EXE%" --path "%~dp0." --editor --debug-adapter %DEBUG_ADAPTER_PORT%
exit /b %errorlevel%
