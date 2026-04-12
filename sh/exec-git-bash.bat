@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "EXE_RUNNER=%SCRIPT_DIR%..\bin\win-helper\win-helper.exe"
if exist "%EXE_RUNNER%" goto :run_exe

if /i "%~1"=="--help" goto :help
if /i "%~1"=="-h" goto :help

call :resolve_git_bash
if errorlevel 1 exit /b 1

if /i "%~1"=="--print-path" (
    echo %GIT_BASH%
    exit /b 0
)

if "%~1"=="" (
    "%GIT_BASH%"
    exit /b %errorlevel%
)

"%GIT_BASH%" %*
exit /b %errorlevel%

:run_exe
"%EXE_RUNNER%" %*
exit /b %errorlevel%

:help
echo exec-git-bash - Resolve and run Git Bash on Windows.
echo.
echo Usage:
echo   exec-git-bash --print-path
echo   exec-git-bash -lc "echo hello"
echo   exec-git-bash -lc "cd /d/path; exec /usr/bin/bash -i"
exit /b 0

:resolve_git_bash
REM 1) Prefer inherited process env when valid.
if defined GIT_BASH if exist "%GIT_BASH%" goto :cache_ok
set "GIT_BASH="

REM 2) Reuse persisted user-level cache from HKCU\Environment.
for /f "skip=2 tokens=1,2,*" %%A in ('reg query HKCU\Environment /v GIT_BASH 2^>nul') do (
    if /i "%%A"=="GIT_BASH" (
        set "GIT_BASH=%%C"
    )
)
if defined GIT_BASH if exist "%GIT_BASH%" goto :cache_ok
set "GIT_BASH="

REM 3) Discover from git.exe location first.
for /f "delims=" %%G in ('where git 2^>nul') do (
    if not defined GIT_BASH (
        for %%B in ("%%~dpG..\bin\bash.exe") do if exist "%%~fB" set "GIT_BASH=%%~fB"
        if not defined GIT_BASH for %%B in ("%%~dpG..\usr\bin\bash.exe") do if exist "%%~fB" set "GIT_BASH=%%~fB"
    )
)

REM 4) Fallback to default install paths.
if not defined GIT_BASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "GIT_BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined GIT_BASH if exist "%ProgramFiles%\Git\usr\bin\bash.exe" set "GIT_BASH=%ProgramFiles%\Git\usr\bin\bash.exe"

if not defined GIT_BASH (
    echo [exec-git-bash] Cannot find Git Bash executable.
    echo [exec-git-bash] Tried inherited env, HKCU cache, where git relative paths, and default install paths.
    echo [exec-git-bash] Please install Git for Windows or add git.exe to PATH.
    exit /b 1
)

:cache_ok
set "GIT_BASH=%GIT_BASH:"=%"
setx GIT_BASH "%GIT_BASH%" >nul 2>nul
exit /b 0
