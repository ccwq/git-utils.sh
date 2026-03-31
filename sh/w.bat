@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
git bash -c "'%SCRIPT_DIR%wsha.sh' %*"
exit /b %errorlevel%
