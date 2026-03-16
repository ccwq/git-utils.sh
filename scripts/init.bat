@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM Initialize Windows user env for this repo.
REM - Add repo sh directory to user Path when missing.
REM - Ensure CLINK_PATH points to repo clink-lua-scripts directory.

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "SH_DIR=%PROJECT_ROOT%\sh"
set "CLINK_DIR=%PROJECT_ROOT%\clink-lua-scripts"

echo [INFO] Project root: %PROJECT_ROOT%
echo [INFO] sh dir: %SH_DIR%
echo [INFO] clink dir: %CLINK_DIR%
echo --------------------------------

call :ensure_user_path "%SH_DIR%"
if errorlevel 1 exit /b 1

call :ensure_clink_path "%CLINK_DIR%"
if errorlevel 1 exit /b 1

echo --------------------------------
echo [INFO] Init complete.
echo [INFO] Open a new terminal to pick up updated user environment variables.
exit /b 0

:ensure_user_path
set "TARGET_PATH=%~1"
call :get_effective_path CURRENT_PATH
call :path_contains "%CURRENT_PATH%" "%TARGET_PATH%"
if not errorlevel 1 (
    echo [INFO] Current PATH already contains the sh directory.
    exit /b 0
)

call :get_user_env "Path" USER_PATH
call :path_contains "%USER_PATH%" "%TARGET_PATH%"
if not errorlevel 1 (
    echo [INFO] User Path already contains the sh directory.
    exit /b 0
)

if defined USER_PATH (
    set "NEW_USER_PATH=%USER_PATH%;%TARGET_PATH%"
) else (
    set "NEW_USER_PATH=%TARGET_PATH%"
)

call :set_user_env "Path" "%NEW_USER_PATH%"
if errorlevel 1 (
    echo [ERROR] Failed to update user Path.
    exit /b 1
)

echo [INFO] Added the sh directory to user Path.
exit /b 0

:ensure_clink_path
set "TARGET_CLINK=%~1"
call :get_user_env "CLINK_PATH" CURRENT_CLINK

if not defined CURRENT_CLINK (
    call :set_user_env "CLINK_PATH" "%TARGET_CLINK%"
    if errorlevel 1 (
        echo [ERROR] Failed to set CLINK_PATH.
        exit /b 1
    )
    echo [INFO] Set CLINK_PATH=%TARGET_CLINK%
    exit /b 0
)

if /I "%CURRENT_CLINK%"=="%TARGET_CLINK%" (
    echo [INFO] CLINK_PATH already points to this repo.
    exit /b 0
)

echo [WARN] Existing CLINK_PATH detected.
echo [WARN] Current: %CURRENT_CLINK%
echo [WARN] Target : %TARGET_CLINK%

call :confirm_overwrite OVERWRITE_CHOICE
if /I not "%OVERWRITE_CHOICE%"=="Y" (
    echo [INFO] Keeping the current CLINK_PATH.
    exit /b 0
)

call :set_user_env "CLINK_PATH" "%TARGET_CLINK%"
if errorlevel 1 (
    echo [ERROR] Failed to overwrite CLINK_PATH.
    exit /b 1
)

echo [INFO] Updated CLINK_PATH to this repo.
exit /b 0

:confirm_overwrite
if defined GIT_UTILS_INIT_OVERWRITE_CHOICE (
    set "%~1=%GIT_UTILS_INIT_OVERWRITE_CHOICE%"
    exit /b 0
)

choice /C YN /N /M "Overwrite CLINK_PATH with this repo? [Y/N]: "
if errorlevel 2 (
    set "%~1=N"
) else (
    set "%~1=Y"
)
exit /b 0

:get_effective_path
if defined GIT_UTILS_INIT_PROCESS_PATH (
    set "%~1=%GIT_UTILS_INIT_PROCESS_PATH%"
) else (
    set "%~1=%PATH%"
)
exit /b 0

:get_user_env
set "%~2="
set "__GU_NAME=%~1"

if defined GIT_UTILS_INIT_STATE_FILE (
    set "__GU_STATE_FILE=%GIT_UTILS_INIT_STATE_FILE%"
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$file = $env:__GU_STATE_FILE; $name = $env:__GU_NAME; if (-not (Test-Path $file)) { exit 0 }; $line = Get-Content -LiteralPath $file | Where-Object { $_ -like ($name + '=*') } | Select-Object -First 1; if ($null -ne $line) { [Console]::Write(($line -split '=', 2)[1]) }"`) do set "%~2=%%A"
    exit /b 0
)

for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$value = [Environment]::GetEnvironmentVariable($env:__GU_NAME, 'User'); if ($null -ne $value) { [Console]::Write($value) }"`) do set "%~2=%%A"
exit /b 0

:set_user_env
set "__GU_NAME=%~1"
set "__GU_VALUE=%~2"

if defined GIT_UTILS_INIT_STATE_FILE (
    set "__GU_STATE_FILE=%GIT_UTILS_INIT_STATE_FILE%"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$file = $env:__GU_STATE_FILE; $name = $env:__GU_NAME; $value = $env:__GU_VALUE; $map = [ordered]@{}; if (Test-Path $file) { foreach ($line in [System.IO.File]::ReadAllLines($file)) { if ($line -match '=') { $pair = $line -split '=', 2; $map[$pair[0]] = $pair[1] } } }; $map[$name] = $value; $lines = foreach ($key in $map.Keys) { '{0}={1}' -f $key, $map[$key] }; [System.IO.File]::WriteAllLines($file, $lines)"
    exit /b %errorlevel%
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Environment]::SetEnvironmentVariable($env:__GU_NAME, $env:__GU_VALUE, 'User')"
exit /b %errorlevel%

:path_contains
set "__GU_PATHS=%~1"
set "__GU_TARGET=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$paths = @(); if ($env:__GU_PATHS) { $paths = $env:__GU_PATHS -split ';' }; $target = $env:__GU_TARGET.Trim().TrimEnd('\'); foreach ($item in $paths) { $candidate = $item.Trim(); if (-not $candidate) { continue }; $candidate = $candidate.TrimEnd('\'); if ($candidate.Equals($target, [System.StringComparison]::OrdinalIgnoreCase)) { exit 0 } }; exit 1"
exit /b %errorlevel%
