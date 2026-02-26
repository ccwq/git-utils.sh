@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "WANT_HELP=0"
if /i "%~1"=="--help" set "WANT_HELP=1"
if /i "%~1"=="-h" set "WANT_HELP=1"
if "%~1"=="" set "WANT_HELP=1"

if "%WANT_HELP%"=="1" (
    echo wsh - Run commands in Git Bash on Windows.
    echo.
    echo Usage:
    echo   wsh --help ^| -h
    echo   wsh .
    echo   wsh ^<command^>
    echo.
    echo Behavior:
    echo   - No args or --help: print this help and exit.
    echo   - wsh .: open interactive Git Bash in current directory.
    echo   - Command without pipe: appends --color.
    echo   - Command with pipe: runs as-is.
    echo.
    echo Examples:
    echo   wsh ls -l
    echo   wsh "ls -l ^| grep foo"
    echo   wsh .
    exit /b 0
)

REM Purpose: Run commands in Git Bash.
REM Behavior:
REM 1) Normal command -> append --color (example: sh ls -l)
REM 2) Command with pipe (^) -> run as-is in Git Bash (example: sh "ls -l ^| grep foo")
REM 3) No args -> open interactive Git Bash session

REM Resolve bash.exe from where git first, then fallback paths.
set "GIT_BASH="
for /f "delims=" %%G in ('where git 2^>nul') do (
    if not defined GIT_BASH (
        for %%B in ("%%~dpG..\bin\bash.exe") do if exist "%%~fB" set "GIT_BASH=%%~fB"
        if not defined GIT_BASH for %%B in ("%%~dpG..\usr\bin\bash.exe") do if exist "%%~fB" set "GIT_BASH=%%~fB"
    )
)

if not defined GIT_BASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "GIT_BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined GIT_BASH if exist "%ProgramFiles%\Git\usr\bin\bash.exe" set "GIT_BASH=%ProgramFiles%\Git\usr\bin\bash.exe"

if not defined GIT_BASH (
    echo [sh.bat] Cannot find Git Bash executable.
    echo [sh.bat] Tried where git relative paths and default install paths.
    echo [sh.bat] Please install Git for Windows or add git.exe to PATH.
    exit /b 1
)

if "%~1"=="." (
    set "CUR_DIR=%CD%"
    set "BASH_DIR=%CUR_DIR:\=/%"
    set "DRIVE=%BASH_DIR:~0,1%"
    set "PATH_NO_DRIVE=%BASH_DIR:~2%"
    set "BASH_DIR=/%DRIVE%%PATH_NO_DRIVE%"
    "%GIT_BASH%" -lc "cd \"%BASH_DIR%\"; exec /usr/bin/bash -i"
    exit /b %errorlevel%
)

if "%~2"=="" (
    set "CMD=%~1"
) else (
    set "CMD=%*"
)

setlocal EnableDelayedExpansion
if "!CMD:|=!"=="!CMD!" (
    "%GIT_BASH%" -lc "!CMD! --color"
) else (
    "%GIT_BASH%" -lc "!CMD!"
)
exit /b %errorlevel%
