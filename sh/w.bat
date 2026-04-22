@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "WSHA_ENTRY=w"
python "%SCRIPT_DIR%wsha-core.py" -e w %*
exit /b %errorlevel%
