@echo off
setlocal
cd /d "%~dp0"
title Angel Game Web Server

echo ============================================================
echo                    ANGEL GAME WEB SERVER
echo ============================================================
echo.

:: Detect Godot executable
set "GODOT_EXE=C:\Users\Benji-Laptop\Documents\Godot\Godot.exe"
if defined GODOT_BIN (
    set "GODOT_EXE=%GODOT_BIN%"
)

:: Check for re-export flag
if /i "%~1"=="--reexport" (
    echo [1/3] Re-exporting web build as requested...
    if exist "%GODOT_EXE%" (
        "%GODOT_EXE%" --headless --path "%~dp0." --export-release Web build\web\index.html
        if errorlevel 1 (
            echo Error: Web export failed.
            pause
            exit /b 1
        )
    ) else (
        echo Warning: Godot not found at "%GODOT_EXE%". Skipping re-export.
    )
    shift
)

:: Check if build exists
if not exist "%~dp0build\web\index.html" (
    echo [1/3] Web build not found. Exporting project to HTML5 now...
    if exist "%GODOT_EXE%" (
        "%GODOT_EXE%" --headless --path "%~dp0." --export-release Web build\web\index.html
        if errorlevel 1 (
            echo Error: Web export failed.
            pause
            exit /b 1
        )
    ) else (
        echo Error: Godot executable not found at "%GODOT_EXE%".
        echo Please export the project to build\web\index.html first.
        pause
        exit /b 1
    )
)

:: Check Python installation
where python >nul 2>nul
if errorlevel 1 (
    echo Error: Python is not detected in your PATH.
    echo Please install Python 3 or add it to PATH to run the local server.
    pause
    exit /b 1
)

echo [2/3] Starting web server and opening browser...
echo.
python "%~dp0serve_web.py" %*

if errorlevel 1 (
    echo.
    echo Server terminated with error code %errorlevel%.
    pause
)
