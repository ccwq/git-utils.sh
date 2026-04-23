@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "WSHA_ENTRY=w"
call "%SCRIPT_DIR%exec-git-bash.bat" "%SCRIPT_DIR%wsha.sh" %*
exit /b %errorlevel%
