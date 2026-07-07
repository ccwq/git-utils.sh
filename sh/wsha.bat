@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if not defined WSHA_ENTRY set "WSHA_ENTRY=wsha"

for %%I in ("%SCRIPT_DIR%..") do set "APP_HOME=%%~fI"
for %%I in ("%SCRIPT_DIR%.") do set "APP_SH=%%~fI"
set "APP_CONFIG=%APP_SH%\config"
set "PY_ENTRY=%SCRIPT_DIR%core\wsha_core.py"
set "FIRST_ARG=%~1"
set "PYTHON_EXE="
set "WSHA_CMDLINE_OUTPUT=cmd"

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
if /i "%FIRST_ARG%"=="--cache-clear" goto run_core_passthrough
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

rem 先在 core 输出文件上判断 no-op sentinel，避免把含双引号的 FINAL_CMD 展开进 IF 表达式。
findstr /r /c:"^__WSHA_NOOP__$" "%CORE_STDOUT%" >nul 2>nul
if not errorlevel 1 (
    set "CORE_EXIT=0"
    goto cleanup_and_exit
)

set "FINAL_CMD="
set /p FINAL_CMD=<"%CORE_STDOUT%"

if not defined FINAL_CMD (
    echo [wsha] no command returned from wsha_core.py. 1>&2
    set "CORE_EXIT=1"
    goto cleanup_and_exit
)

set "RAW_INPUT=%*"
setlocal EnableDelayedExpansion
if /i "#!FINAL_CMD!"=="#!RAW_INPUT!" (
    endlocal
    call :print_exec
) else (
    endlocal
    set "LOG_ENTRY=%WSHA_ENTRY%"
    set "LOG_INPUT=%*"
    call :print_alias_hit
    call :print_exec
)

call :exec_final_cmd
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
set "LOG_ENTRY="
set "LOG_INPUT="
set "RAW_INPUT="
exit /b %CORE_EXIT%

:exec_final_cmd
setlocal EnableExtensions DisableDelayedExpansion
set "CMDLINE=%FINAL_CMD%"

setlocal EnableDelayedExpansion
set "CMD_PREFIX=!CMDLINE:~0,4!"
if /i "!CMD_PREFIX!"=="env " goto exec_env_cmd
endlocal
endlocal
cmd /c "%FINAL_CMD%"
exit /b %errorlevel%

:exec_env_cmd
set "REMAINDER=!CMDLINE:~4!"
set "TMP_ENV_CMD=%TEMP%\wsha-env-%RANDOM%-%RANDOM%.cmd"
set "ENV_COMMAND="

(
    echo @echo off
    echo setlocal EnableExtensions DisableDelayedExpansion
) > "!TMP_ENV_CMD!"

:parse_env_prefix
set "TOKEN="
set "TAIL="
for /f "tokens=1* delims= " %%A in ("!REMAINDER!") do (
    set "TOKEN=%%~A"
    set "TAIL=%%~B"
)

if not defined TOKEN (
    >> "!TMP_ENV_CMD!" echo echo [wsha] invalid env command. 1^>^&2
    >> "!TMP_ENV_CMD!" echo exit /b 1
    goto run_env_script
)

echo(!TOKEN!| findstr "=" >nul
if errorlevel 1 (
    set "ENV_COMMAND=!TOKEN!"
    if defined TAIL set "ENV_COMMAND=!ENV_COMMAND! !TAIL!"
    >> "!TMP_ENV_CMD!" echo !ENV_COMMAND!
    >> "!TMP_ENV_CMD!" echo exit /b %%errorlevel%%
    goto run_env_script
)

for /f "tokens=1* delims==" %%K in ("!TOKEN!") do (
    set "ENV_NAME=%%~K"
    set "ENV_VALUE=%%~L"
)
>> "!TMP_ENV_CMD!" echo set "!ENV_NAME!=!ENV_VALUE!"
set "REMAINDER=!TAIL!"
goto parse_env_prefix

:run_env_script
call "!TMP_ENV_CMD!"
set "EXEC_EXIT=%errorlevel%"
del /q "!TMP_ENV_CMD!" >nul 2>nul
endlocal & exit /b %EXEC_EXIT%

:print_exec
if "%WSHA_PRINT_EXEC%"=="0" exit /b 0
setlocal EnableDelayedExpansion
echo([wsha] exec: !FINAL_CMD! 1>&2
endlocal
exit /b 0

:print_alias_hit
setlocal EnableDelayedExpansion
echo([wsha] alias hit: !LOG_ENTRY! !LOG_INPUT! -^> !FINAL_CMD! 1>&2
endlocal
exit /b 0
