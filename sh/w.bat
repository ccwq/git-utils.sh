@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "WSHA_ENTRY=w"
set "PYTHON=C:\Users\Administrator\.local\bin\python.exe"

call :run_wsha %*
exit /b %errorlevel%

:run_wsha
set "PYTHON_EXE=C:\Users\Administrator\.local\bin\python.exe"
set "WSHA_SCRIPT=%SCRIPT_DIR%wsha-core.py"
set "WSHA_CMD=!PYTHON_EXE! !WSHA_SCRIPT! -e w %*"

for /f "delims=" %%R in ('!WSHA_CMD!') do (
    echo %%R
    call %%R
)
goto :eof