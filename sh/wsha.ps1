param(
    [Alias('e', 'env')]
    [switch]$EnvPrefix,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$WshaArgs
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot

if ($EnvPrefix) {
    $WshaArgs = @('-e') + $WshaArgs
}

if (-not $env:WSHA_ENTRY) {
    $env:WSHA_ENTRY = 'wsha'
}

$env:APP_HOME = [System.IO.Path]::GetFullPath((Join-Path $scriptDir '..'))
$env:APP_SH = $scriptDir
$env:APP_CONFIG = Join-Path $scriptDir 'config'
$env:WSHA_CMDLINE_OUTPUT = 'powershell'
$pythonEntry = Join-Path $scriptDir 'core\wsha_core.py'

$pythonExe = $null
if ($env:WSHA_PYTHON -and (Test-Path -LiteralPath $env:WSHA_PYTHON)) {
    $pythonExe = $env:WSHA_PYTHON
}
if (-not $pythonExe) {
    $pythonCommand = Get-Command python.exe -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notmatch '\\WindowsApps\\' } |
        Select-Object -First 1
    if ($pythonCommand) {
        $pythonExe = $pythonCommand.Source
    }
}
if (-not $pythonExe) {
    [Console]::Error.WriteLine('[wsha] Python runtime not found. Set WSHA_PYTHON or install python.exe.')
    exit 1
}

$tempBase = Join-Path ([System.IO.Path]::GetTempPath()) ("wsha-core-{0}-{1}" -f $PID, [Guid]::NewGuid().ToString('N'))
$stdoutPath = "$tempBase.out"
$stderrPath = "$tempBase.err"

try {
    & $pythonExe $pythonEntry --entry $env:WSHA_ENTRY @WshaArgs 1> $stdoutPath 2> $stderrPath
    $coreExit = $LASTEXITCODE

    if (Test-Path -LiteralPath $stderrPath) {
        Get-Content -LiteralPath $stderrPath | ForEach-Object { [Console]::Error.WriteLine($_) }
    }
    if ($coreExit -ne 0) {
        exit $coreExit
    }

    $firstArg = if ($WshaArgs.Count -gt 0) { $WshaArgs[0].ToLowerInvariant() } else { '' }
    if ($firstArg -in @('-h', '--help', '-l', '--list', '-lv', '--list-view', '--clear', '--cache-clear')) {
        if (Test-Path -LiteralPath $stdoutPath) {
            Get-Content -LiteralPath $stdoutPath
        }
        exit 0
    }

    $finalCommand = (Get-Content -LiteralPath $stdoutPath -Raw).TrimEnd("`r", "`n")
    if (-not $finalCommand) {
        [Console]::Error.WriteLine('[wsha] no command returned from wsha_core.py.')
        exit 1
    }
    if ($finalCommand -eq '__WSHA_NOOP__') {
        exit 0
    }

    [Console]::Error.WriteLine("[wsha] exec: $finalCommand")
    $hostExe = (Get-Process -Id $PID).Path
    & $hostExe -NoProfile -ExecutionPolicy Bypass -Command $finalCommand
    exit $LASTEXITCODE
}
finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
}
