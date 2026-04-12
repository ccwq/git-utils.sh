@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
cargo build --manifest-path "%SCRIPT_DIR%Cargo.toml" --release
if errorlevel 1 exit /b %errorlevel%

copy /Y "%SCRIPT_DIR%target\release\win-helper.exe" "%SCRIPT_DIR%win-helper.exe" >nul
if errorlevel 1 (
    echo [win-helper] warning: failed to copy release exe to root; use "%SCRIPT_DIR%target\release\win-helper.exe"
    exit /b 0
)

echo [win-helper] built "%SCRIPT_DIR%win-helper.exe"
exit /b 0
