@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
if not defined WSHA_ENTRY set "WSHA_ENTRY=wsha"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%wsha.ps1" %*
exit /b %errorlevel%
