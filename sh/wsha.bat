@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if not defined WSHA_ENTRY set "WSHA_ENTRY=wsha"

for %%I in ("%SCRIPT_DIR%..") do set "APP_HOME=%%~fI"
for %%I in ("%SCRIPT_DIR%.") do set "APP_SH=%%~fI"
set "APP_CONFIG=%APP_SH%\config"
set "PY_ENTRY=%SCRIPT_DIR%wsha-core.py"
set "FIRST_ARG=%~1"
set "PYTHON_EXE="

if /i "%FIRST_ARG%"=="-lv" set "FIRST_ARG=--list"
if /i "%FIRST_ARG%"=="--list-view" set "FIRST_ARG=--list"

if defined WSHA_PYTHON if exist "%WSHA_PYTHON%" set "PYTHON_EXE=%WSHA_PYTHON%"

if not defined PYTHON_EXE (
    for /f "delims=" %%P in ('where.exe python 2^>nul ^| findstr /i /v /c:"\\WindowsApps\\"') do if not defined PYTHON_EXE set "PYTHON_EXE=%%P"
)

if not defined PYTHON_EXE (
    for /f "delims=" %%P in ('where.exe python3 2^>nul ^| findstr /i /v /c:"\\WindowsApps\\"') do if not defined PYTHON_EXE set "PYTHON_EXE=%%P"
)

if not defined PYTHON_EXE (
    echo [wsha] Python runtime not found. Set WSHA_PYTHON or install python.exe. 1>&2
    exit /b 1
)

if /i "%FIRST_ARG%"=="--list" goto run_core_passthrough
if /i "%FIRST_ARG%"=="-l" goto run_core_passthrough
if /i "%FIRST_ARG%"=="--clear" goto run_core_passthrough
if /i "%FIRST_ARG%"=="--help" goto run_core_passthrough
if /i "%FIRST_ARG%"=="-h" goto run_core_passthrough

set "TMP_BASE=%TEMP%\wsha-core-%RANDOM%-%RANDOM%"
set "CORE_STDOUT=%TMP_BASE%.out"
set "CORE_STDERR=%TMP_BASE%.err"

if /i "%FIRST_ARG%"=="--list" (
    "%PYTHON_EXE%" "%PY_ENTRY%" -e "%WSHA_ENTRY%" --list > "%CORE_STDOUT%" 2> "%CORE_STDERR%"
) else (
    "%PYTHON_EXE%" "%PY_ENTRY%" -e "%WSHA_ENTRY%" %* > "%CORE_STDOUT%" 2> "%CORE_STDERR%"
)
set "CORE_EXIT=%errorlevel%"

type "%CORE_STDERR%" 2>nul
if not "%CORE_EXIT%"=="0" goto cleanup_and_exit

set "FINAL_CMD="
set /p FINAL_CMD=<"%CORE_STDOUT%"

if not defined FINAL_CMD (
    echo [wsha] no command returned from wsha-core.py. 1>&2
    set "CORE_EXIT=1"
    goto cleanup_and_exit
)

if /i "%FINAL_CMD%"=="%*" (
    call :print_exec "%FINAL_CMD%"
) else (
    call :print_alias_hit "%WSHA_ENTRY%" "%*" "%FINAL_CMD%"
    call :print_exec "%FINAL_CMD%"
)

cmd /c "%FINAL_CMD%"
set "CORE_EXIT=%errorlevel%"
goto cleanup_and_exit

:run_core_passthrough
if /i "%FIRST_ARG%"=="--list" (
    "%PYTHON_EXE%" "%PY_ENTRY%" --list
) else (
    "%PYTHON_EXE%" "%PY_ENTRY%" %*
)
exit /b %errorlevel%

:cleanup_and_exit
if defined CORE_STDOUT del /q "%CORE_STDOUT%" >nul 2>nul
if defined CORE_STDERR del /q "%CORE_STDERR%" >nul 2>nul
exit /b %CORE_EXIT%

:print_exec
if "%WSHA_PRINT_EXEC%"=="0" exit /b 0
echo [wsha] exec: %~1 1>&2
exit /b 0

:print_alias_hit
echo [wsha] alias hit: %~1 %~2 -^> %~3 1>&2
exit /b 0
