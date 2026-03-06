@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem wsha: alias expansion runner for complex commands.
rem usage: wsa <alias> [args...]

set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%..\config\wsh-alias.txt"
if defined WSHA_CONFIG_FILE set "CONFIG_FILE=%WSHA_CONFIG_FILE%"

if /i "%~1"=="-h" goto show_help
if /i "%~1"=="--help" goto show_help
if "%~1"=="" (
  >&2 echo [wsha] missing alias.
  goto show_help_error
)

set "INPUT_ALIAS="
set "RAW_FIRST_ARG=%~1"
set "RUNTIME_ARGS="

rem Support single quoted argument: wsha "ab open t.cn"
if "%~2"=="" goto parse_single_arg

set "INPUT_ALIAS=%~1"
shift
:collect_runtime_args
if "%~1"=="" goto runtime_args_done
if defined RUNTIME_ARGS (
  set "RUNTIME_ARGS=%RUNTIME_ARGS% %~1"
) else (
  set "RUNTIME_ARGS=%~1"
)
shift
goto collect_runtime_args

:parse_single_arg
for /f "tokens=1,* delims= " %%A in ("%~1") do (
  set "INPUT_ALIAS=%%~A"
  set "RUNTIME_ARGS=%%~B"
)

:runtime_args_done

if not exist "%CONFIG_FILE%" (
  >&2 echo [wsha] config file not found: "%CONFIG_FILE%"
  exit /b 1
)

set "LINE_NO=0"
set "MATCH_TEMPLATE="
set "PARSE_ERROR="

rem parse config: <alias> <target...>
for /f "usebackq delims=" %%L in ("%CONFIG_FILE%") do (
  set /a LINE_NO+=1
  set "RAW_LINE=%%L"
  for /f "tokens=* delims= " %%T in ("!RAW_LINE!") do set "LINE=%%T"

  if not "!LINE!"=="" (
    if not "!LINE:~0,1!"=="#" (
      set "CUR_ALIAS="
      set "CUR_TEMPLATE="
      for /f "tokens=1,* delims= " %%A in ("!LINE!") do (
        set "CUR_ALIAS=%%~A"
        set "CUR_TEMPLATE=%%~B"
      )

      if "!CUR_ALIAS!"=="" (
        if not defined PARSE_ERROR set "PARSE_ERROR=[wsha] invalid config at line !LINE_NO!: missing alias"
      )

      if "!CUR_TEMPLATE!"=="" (
        if not defined PARSE_ERROR set "PARSE_ERROR=[wsha] invalid config at line !LINE_NO!: alias \"!CUR_ALIAS!\" has no target command"
      )

      if not "!CUR_ALIAS!"=="" if defined ALIAS_!CUR_ALIAS! (
        if not defined PARSE_ERROR set "PARSE_ERROR=[wsha] duplicate alias \"!CUR_ALIAS!\" at line !LINE_NO!"
      )

      if not "!CUR_ALIAS!"=="" if not defined ALIAS_!CUR_ALIAS! (
        set "ALIAS_!CUR_ALIAS!=1"
      )

      if /i "!CUR_ALIAS!"=="%INPUT_ALIAS%" (
        set "MATCH_TEMPLATE=!CUR_TEMPLATE!"
      )
    )
  )
)

if defined PARSE_ERROR (
  >&2 echo !PARSE_ERROR!
  exit /b 1
)

if not defined MATCH_TEMPLATE (
  set "FALLBACK_CMD="
  if defined RUNTIME_ARGS (
    set "FALLBACK_CMD=%INPUT_ALIAS%"
    set "FALLBACK_CMD=!FALLBACK_CMD! !RUNTIME_ARGS!"
  ) else (
    set "FALLBACK_CMD=%RAW_FIRST_ARG%"
  )

  if not defined FALLBACK_CMD (
    >&2 echo [wsha] fallback command is empty.
    exit /b 1
  )

  "%ComSpec%" /d /s /c "!FALLBACK_CMD!"
  exit /b !errorlevel!
)

set "HAS_PLACEHOLDER=0"
for %%T in (!MATCH_TEMPLATE!) do (
  if "%%~T"=="--" set "HAS_PLACEHOLDER=1"
)

set "FINAL_CMD="

if "!HAS_PLACEHOLDER!"=="1" (
  rem with '--', insert runtime args at placeholder location.
  for %%T in (!MATCH_TEMPLATE!) do (
    if "%%~T"=="--" (
      if defined RUNTIME_ARGS (
        if defined FINAL_CMD (
          set "FINAL_CMD=!FINAL_CMD! !RUNTIME_ARGS!"
        ) else (
          set "FINAL_CMD=!RUNTIME_ARGS!"
        )
      )
    ) else (
      if defined FINAL_CMD (
        set "FINAL_CMD=!FINAL_CMD! %%~T"
      ) else (
        set "FINAL_CMD=%%~T"
      )
    )
  )
) else (
  set "FINAL_CMD=!MATCH_TEMPLATE!"
  if defined RUNTIME_ARGS set "FINAL_CMD=!FINAL_CMD! !RUNTIME_ARGS!"
)

if not defined FINAL_CMD (
  >&2 echo [wsha] expanded command is empty for alias "%INPUT_ALIAS%"
  exit /b 1
)

call !FINAL_CMD!
exit /b %errorlevel%

:show_help
echo wsha - alias command launcher
echo.
echo Usage:
echo   wsa ^<alias^> [args...]
echo.
echo Config:
echo   default: config\wsh-alias.txt
echo   format : ^<alias^> ^<target...^>
echo.
echo Rules:
echo   - Ignore empty lines and lines starting with '#'
echo   - If template contains '--', runtime args are inserted there
echo   - Otherwise runtime args are appended at the end
echo   - If alias not found, run original command directly
echo.
echo Example:
echo   ab agent-browser
echo   foo foobar open
echo   bar barbar -- --name ccwq
echo.
echo   wsa ab open           ^> agent-browser open
echo   wsa foo --ping        ^> foobar open --ping
echo   wsa bar --age 40      ^> barbar --age 40 --name ccwq
exit /b 0

:show_help_error
echo.
echo Run with --help for usage.
exit /b 1
