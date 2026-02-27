@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "TCPING_EXE=%SCRIPT_DIR%..\bin\tcping.exe"
set "CONFIG_FILE=%SCRIPT_DIR%..\config\wsh-ping.txt"

if /i "%~1"=="-h" goto show_help
if /i "%~1"=="--help" goto show_help

if not exist "%TCPING_EXE%" (
  echo [wsh-ping] tcping.exe not found: "%TCPING_EXE%"
  echo [wsh-ping] Please ensure bin\tcping.exe exists.
  exit /b 1
)

if "%~1"=="" goto preset_menu
goto run_tcping

:load_presets
set "PRESET_COUNT=0"

if not exist "%CONFIG_FILE%" (
  echo [wsh-ping] config file not found: "%CONFIG_FILE%"
  exit /b 1
)

for /f "usebackq tokens=1,2,3 delims= " %%A in ("%CONFIG_FILE%") do (
  set "LINE_NAME=%%~A"
  if not "!LINE_NAME!"=="" if not "!LINE_NAME:~0,1!"=="#" (
    set "LINE_HOST=%%~B"
    set "LINE_PORT=%%~C"
    if not "!LINE_HOST!"=="" if not "!LINE_PORT!"=="" (
      set /a PRESET_COUNT+=1
      set "PRESET_NAME_!PRESET_COUNT!=!LINE_NAME!"
      set "PRESET_HOST_!PRESET_COUNT!=!LINE_HOST!"
      set "PRESET_PORT_!PRESET_COUNT!=!LINE_PORT!"
    )
  )
)

if "!PRESET_COUNT!"=="0" (
  echo [wsh-ping] no valid preset found in: "%CONFIG_FILE%"
  exit /b 1
)

exit /b 0

:preset_menu
call :load_presets
if errorlevel 1 exit /b 1

echo --------------------------------
echo Select target:
for /L %%I in (1,1,!PRESET_COUNT!) do (
  echo   [%%I] !PRESET_NAME_%%I!  ^(!PRESET_HOST_%%I!:!PRESET_PORT_%%I!^)
)
echo   [Q] quit
echo --------------------------------

set "PICK="
set /p "PICK=Input(1-!PRESET_COUNT!/Q, default 1): "
if "!PICK!"=="" set "PICK=1"

if /i "!PICK!"=="Q" goto exit_ok

set "TARGET_INDEX="
for /L %%I in (1,1,!PRESET_COUNT!) do (
  if "!PICK!"=="%%I" set "TARGET_INDEX=%%I"
)

if not defined TARGET_INDEX (
  echo Invalid input. Please type 1-!PRESET_COUNT! or Q.
  goto preset_menu
)

set "TARGET_HOST=!PRESET_HOST_%TARGET_INDEX%!"
set "TARGET_PORT=!PRESET_PORT_%TARGET_INDEX%!"
"%TCPING_EXE%" !TARGET_HOST! !TARGET_PORT!
exit /b %errorlevel%

:run_tcping
"%TCPING_EXE%" %*
exit /b %errorlevel%

:show_help
echo wsh-ping - tcping wrapper
echo.
echo Usage:
echo   wsh-ping
echo   wsh-ping ^<tcping args...^>
echo.
echo Behavior:
echo   - No args: show preset menu loaded from config\wsh-ping.txt.
echo   - With args: forward all args to tcping.
echo.
echo Presets:
if exist "%CONFIG_FILE%" (
  call :load_presets >nul
  if not errorlevel 1 (
    for /L %%I in (1,1,!PRESET_COUNT!) do (
      echo   %%I^) !PRESET_NAME_%%I! - !PRESET_HOST_%%I!:!PRESET_PORT_%%I!
    )
  ) else (
    echo   ^(no valid preset found in %CONFIG_FILE%^)
  )
) else (
  echo   ^(config file not found: %CONFIG_FILE%^)
)
echo.
echo Examples:
echo   wsh-ping 1.1.1.1 443 -c 4 -D
echo   wsh-ping qq.com 443 -t 2
echo.
echo ----- tcping --help -----
if exist "%TCPING_EXE%" (
  set "SKIP_EXAMPLE_LINES=0"
  for /f "usebackq delims=" %%L in (`"%TCPING_EXE%" --help`) do (
    set "LINE=%%L"
    set "SKIP_LINE=0"

    if "!SKIP_EXAMPLE_LINES!"=="1" (
      set "SKIP_LINE=1"
      set "SKIP_EXAMPLE_LINES=0"
    ) else if "!SKIP_EXAMPLE_LINES!"=="2" (
      set "SKIP_LINE=1"
      set "SKIP_EXAMPLE_LINES=1"
    )

    if "!LINE:Try running =!" neq "!LINE!" (
      set "SKIP_LINE=1"
      set "SKIP_EXAMPLE_LINES=2"
    )
    if "!LINE:<hostname/ip> <port number>=!" neq "!LINE!" set "SKIP_LINE=1"
    if "!LINE:For example:=!" neq "!LINE!" set "SKIP_LINE=1"

    if "!SKIP_LINE!"=="0" echo(!LINE!
  )
) else (
  echo tcping.exe not found: "%TCPING_EXE%"
)
exit /b 0

:exit_ok
exit /b 0
