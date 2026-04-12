@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%exec-git-bash.bat" -lc "'%SCRIPT_DIR%wsha.sh' %*"
exit /b %errorlevel%
