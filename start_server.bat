@echo off
setlocal
cd /d "%~dp0"
title Angel Game Web Server

echo ============================================================
echo                    ANGEL GAME WEB SERVER
echo ============================================================
echo.

:: Detect Godot executable. GODOT_BIN may point at a specific editor; otherwise
:: use PATH and the common Windows install locations. Do not rely on a
:: developer-specific absolute path, because that made Web export silently
:: unavailable on every other machine.
set "GODOT_EXE="
if defined GODOT_BIN if exist "%GODOT_BIN%" set "GODOT_EXE=%GODOT_BIN%"
if not defined GODOT_EXE (
    for /f "delims=" %%G in ('where godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%~G"
)
if not defined GODOT_EXE (
    for %%G in (
        "%ProgramFiles%\Godot\Godot.exe"
        "%ProgramFiles%\Godot\Godot_v4*.exe"
        "%LOCALAPPDATA%\Godot\Godot.exe"
        "%~dp0Godot.exe"
    ) do if not defined GODOT_EXE if exist "%%~G" set "GODOT_EXE=%%~G"
)

if defined GODOT_EXE (
    echo Godot: %GODOT_EXE%
) else (
    echo Godot: not found in GODOT_BIN, PATH, or common install locations.
)

:: Check for re-export flag
if /i "%~1"=="--reexport" (
    echo [1/3] Re-exporting web build as requested...
    if exist "%GODOT_EXE%" (
        "%GODOT_EXE%" --headless --path "%~dp0." --export-release "Web" "%~dp0build\web\index.html"
        if errorlevel 1 goto :export_failed
        if not exist "%~dp0build\web\index.html" goto :export_missing
    ) else (
        echo Warning: Godot not found at "%GODOT_EXE%". Skipping re-export.
    )
    shift
)

:: Check if build exists
if not exist "%~dp0build\web\index.html" (
    echo [1/3] Web build not found. Exporting project to HTML5 now...
    if exist "%GODOT_EXE%" (
        "%GODOT_EXE%" --headless --path "%~dp0." --export-release "Web" "%~dp0build\web\index.html"
        if errorlevel 1 goto :export_failed
        if not exist "%~dp0build\web\index.html" goto :export_missing
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

goto :eof

:export_failed
echo Error: Web export failed. Check that matching Godot Web export templates are installed.
pause
exit /b 1

:export_missing
echo Error: Godot reported success but did not create build\web\index.html.
echo Check that matching Godot Web export templates are installed.
pause
exit /b 1
