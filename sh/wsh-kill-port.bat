@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "PORT="
set "ASSUME_YES=0"
set "DRY_RUN=0"

if /i "%~1"=="--help" goto show_help
if /i "%~1"=="-h" goto show_help
if "%~1"=="" goto show_help

set "PORT=%~1"
shift

:parse_args
if "%~1"=="" goto validate
if /i "%~1"=="--yes" (
  set "ASSUME_YES=1"
  shift
  goto parse_args
)
if /i "%~1"=="--dry-run" (
  set "DRY_RUN=1"
  shift
  goto parse_args
)

echo [wsh-kill-port] unknown option: %~1
exit /b 2

:validate
set "NON_DIGITS="
for /f "delims=0123456789" %%A in ("%PORT%") do set "NON_DIGITS=%%A"
if defined NON_DIGITS (
  echo [wsh-kill-port] invalid port: %PORT%
  exit /b 2
)

set "MATCH_COUNT=0"
set "PID_LIST="
for /f "tokens=1,2,3,4,5" %%A in ('netstat -ano ^| findstr /r /c:":%PORT%[ ]"') do (
  set /a MATCH_COUNT+=1
  set "MATCH_!MATCH_COUNT!=%%A %%B %%C %%D %%E"
  call :append_pid %%E
)

if "%MATCH_COUNT%"=="0" (
  echo [wsh-kill-port] port %PORT% not found.
  exit /b 1
)

echo [wsh-kill-port] matched netstat rows for port %PORT%:
for /L %%I in (1,1,%MATCH_COUNT%) do echo   !MATCH_%%I!
echo.

if not defined PID_LIST (
  echo [wsh-kill-port] no PID resolved for port %PORT%.
  exit /b 1
)

echo [wsh-kill-port] matched process list:
for %%P in (!PID_LIST!) do call :show_process %%P
echo.

if "%DRY_RUN%"=="1" (
  echo [wsh-kill-port] dry-run mode, no process killed.
  exit /b 0
)

if not "%ASSUME_YES%"=="1" (
  set "CONFIRM="
  set /p "CONFIRM=Confirm kill all processes on port %PORT%? [y/N]: "
  if /i not "!CONFIRM!"=="y" if /i not "!CONFIRM!"=="yes" (
    echo [wsh-kill-port] cancelled.
    exit /b 1
  )
)

set "FAILED=0"
for %%P in (!PID_LIST!) do (
  echo [wsh-kill-port] taskkill /f /pid %%P
  taskkill /f /pid %%P
  if errorlevel 1 set "FAILED=1"
)

if "%FAILED%"=="1" exit /b 1
echo [wsh-kill-port] done.
exit /b 0

:append_pid
set "CANDIDATE=%~1"
if "%CANDIDATE%"=="0" exit /b 0
if not defined PID_LIST (
  set "PID_LIST=%CANDIDATE%"
  exit /b 0
)
for %%P in (!PID_LIST!) do if "%%P"=="%CANDIDATE%" exit /b 0
set "PID_LIST=!PID_LIST! %CANDIDATE%"
exit /b 0

:show_process
set "TARGET_PID=%~1"
for /f "skip=3 tokens=*" %%L in ('tasklist /fi "PID eq %TARGET_PID%"') do (
  if not "%%L"=="INFO: No tasks are running which match the specified criteria." echo   %%L
)
exit /b 0

:show_help
echo wsh-kill-port - find and kill process by TCP port
echo.
echo Usage:
echo   wsh-kill-port ^<port^>
echo   wsh-kill-port ^<port^> --yes
echo   wsh-kill-port ^<port^> --dry-run
echo   wsh-kill-port --help
echo.
echo Behavior:
echo   - show matched netstat rows first
echo   - resolve PID to process name
echo   - ask for confirmation by default
echo   - kill all matched PIDs after confirmation
exit /b 0
