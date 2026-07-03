@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\..\"
set "PYTHON=C:\Users\Administrator\.local\bin\python.exe"

set "CMD=%PYTHON% "%PROJECT_ROOT%sh\wsha-core.py" -e w fox"
echo CMD=%CMD%

for /f "delims=" %%R in ('%CMD%') do (
    echo FOR result=%%R
)
echo FOR done
