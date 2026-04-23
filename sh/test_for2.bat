@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PYTHON=C:\Users\Administrator\.local\bin\python.exe"

set "CMD=%PYTHON% "%SCRIPT_DIR%wsha-core.py" -e w fox"
echo CMD=%CMD%

for /f "delims=" %%R in ('%CMD%') do (
    echo FOR result=%%R
)
echo FOR done
