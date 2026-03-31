@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
if not defined WSHA_ENTRY set "WSHA_ENTRY=wsha"
git bash -c "'%SCRIPT_DIR%wsha.sh' %*"
exit /b %errorlevel%
