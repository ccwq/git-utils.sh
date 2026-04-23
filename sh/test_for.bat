@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PYTHON=C:\Users\Administrator\.local\bin\python.exe"

echo Test 1: Direct call
"%PYTHON%" "%SCRIPT_DIR%wsha-core.py" -e w fox

echo Test 2: FOR loop
for /f "delims=" %%R in ('"%PYTHON%" "%SCRIPT_DIR%wsha-core.py" -e w fox') do (
    echo FOR result=%%R
)
echo FOR done
