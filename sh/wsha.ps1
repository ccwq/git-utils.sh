# Keep repeated -e/--env options and target-command flags in their original order.
$WshaArgs = @($args)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot

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
    # Windows PowerShell 将原生 stderr 包装为 ErrorRecord，不能因此跳过 core 的退出码。
    $ErrorActionPreference = 'Continue'
    & $pythonExe $pythonEntry --entry $env:WSHA_ENTRY @WshaArgs 1> $stdoutPath 2> $stderrPath
    $coreExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

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
    # EncodedCommand 避免 PowerShell 5.1 的 native argv 重组吞掉命令中的双引号。
    $exitPrelude = '$LASTEXITCODE = $null; '
    $exitSuffix = '; if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE }; if (-not $?) { exit 1 }'
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($exitPrelude + $finalCommand + $exitSuffix))
    & $hostExe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand
    exit $LASTEXITCODE
}
finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
}
