@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "WSHA_ENTRY=w"
call "%SCRIPT_DIR%wsha.bat" %*
exit /b %errorlevel%
