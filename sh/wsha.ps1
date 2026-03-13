param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Help {
    @"
wsha - alias command launcher

Usage:
  w <alias> [args...]
  w --list | -l

Config priority:
  1. config\wsh-alias.txt
  2. %USERPROFILE%\.config\wsh-alias.txt
  3. %CD%\.config\wsh-alias.txt

Rules:
  - Ignore empty lines and lines starting with '#'
  - Same alias: higher priority overrides lower priority
  - Inject env vars: %APP_HOME%, %APP_SH%, %APP_CONFIG%
  - Alias can be quoted to include spaces, like "pcodex l"
  - Alias supports '*' wildcard (single token capture), map to `$1..`$N
  - Alias supports '**' wildcard (match all remaining input), map to `$$
  - If template contains '--', runtime args are inserted there
  - Otherwise runtime args are appended at the end
  - If alias not found, run original command directly

Example:
  pcodex pnpx @openai/codex
  "pcodex l" pnpx @openai/codex@latest
  "px*" pnpx `$1
  "px *" "pnpx `$1"
  "s**" wsh `$$

  w pcodex               > pnpx @openai/codex
  w pcodex l             > pnpx @openai/codex@latest
  w pxhttp-server        > pnpx http-server
  w px http-server       > pnpx http-server
  w sls -l               > wsh ls -l
"@
}

function Set-AppEnvironmentVariables {
    param([string]$ScriptDir)

    $appHome = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir '..'))
    $appSh = [System.IO.Path]::GetFullPath($ScriptDir)
    $appConfig = [System.IO.Path]::GetFullPath((Join-Path $appHome 'config'))

    $env:APP_HOME = $appHome
    $env:APP_SH = $appSh
    $env:APP_CONFIG = $appConfig
}

function Invoke-CmdLine {
    param([string]$CommandText)
    cmd.exe /d /s /c $CommandText
    exit $LASTEXITCODE
}

function Parse-ConfigLine {
    param(
        [string]$Line,
        [string]$ConfigPath,
        [int]$LineNo
    )

    $trimmed = $Line.TrimStart()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return $null }
    if ($trimmed.StartsWith('#')) { return $null }

    $alias = ''
    $template = ''

    if ($trimmed.StartsWith('"')) {
        $m = [regex]::Match($trimmed, '^"([^"]+)"\s+(.*)$')
        if (-not $m.Success) {
            throw "[wsha] invalid config at line $LineNo in `"$ConfigPath`": missing alias"
        }
        $alias = $m.Groups[1].Value
        $template = $m.Groups[2].Value.TrimStart()
    } else {
        $m = [regex]::Match($trimmed, '^(\S+)\s+(.*)$')
        if (-not $m.Success) {
            if ([regex]::IsMatch($trimmed, '^\S+$')) {
                throw "[wsha] invalid config at line $LineNo in `"$ConfigPath`": alias `"$trimmed`" has no target command"
            }
            throw "[wsha] invalid config at line $LineNo in `"$ConfigPath`": missing alias"
        }
        $alias = $m.Groups[1].Value
        $template = $m.Groups[2].Value.TrimStart()
    }

    if ([string]::IsNullOrWhiteSpace($alias)) {
        throw "[wsha] invalid config at line $LineNo in `"$ConfigPath`": missing alias"
    }
    if ([string]::IsNullOrWhiteSpace($template)) {
        throw "[wsha] invalid config at line $LineNo in `"$ConfigPath`": alias `"$alias`" has no target command"
    }

    if ($template.Length -ge 2 -and $template.StartsWith('"') -and $template.EndsWith('"')) {
        $template = $template.Substring(1, $template.Length - 2)
    }

    return [pscustomobject]@{
        Alias    = $alias
        Template = $template
        LineNo   = $LineNo
    }
}

function Load-Config {
    param(
        [string]$ConfigPath,
        [hashtable]$AliasMap,
        [System.Collections.Generic.List[string]]$Order,
        [bool]$FailOnDuplicate
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) { return }
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return }

    $lineNo = 0
    Get-Content -LiteralPath $ConfigPath | ForEach-Object {
        $lineNo += 1
        $parsed = Parse-ConfigLine -Line $_ -ConfigPath $ConfigPath -LineNo $lineNo
        if ($null -eq $parsed) { return }

        if ($FailOnDuplicate -and $AliasMap.ContainsKey($parsed.Alias)) {
            throw "[wsha] duplicate alias `"$($parsed.Alias)`" at line $($parsed.LineNo) in `"$ConfigPath`""
        }

        if ($AliasMap.ContainsKey($parsed.Alias)) {
            $AliasMap[$parsed.Alias] = $parsed.Template
        } else {
            $AliasMap[$parsed.Alias] = $parsed.Template
            [void]$Order.Add($parsed.Alias)
        }
    }
}

function Get-Tokens {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $items = @($Text -split '\s+' | Where-Object { $_ -ne '' })
    return @($items)
}

function Match-TokenPattern {
    param(
        [string]$Pattern,
        [string]$Token
    )

    if (-not $Pattern.Contains('*')) {
        if ($Pattern.Equals($Token, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{ Ok = $true; Captures = @(); Wildcards = 0 }
        }
        return [pscustomobject]@{ Ok = $false; Captures = @(); Wildcards = 0 }
    }

    $parts = $Pattern -split '\*', -1
    $regex = '^'
    for ($i = 0; $i -lt $parts.Length; $i++) {
        $regex += [regex]::Escape($parts[$i])
        if ($i -lt $parts.Length - 1) {
            $regex += '(.*?)'
        }
    }
    $regex += '$'

    $m = [regex]::Match($Token, $regex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $m.Success) {
        return [pscustomobject]@{ Ok = $false; Captures = @(); Wildcards = $parts.Length - 1 }
    }

    $caps = @()
    for ($g = 1; $g -lt $m.Groups.Count; $g++) {
        $caps += $m.Groups[$g].Value
    }
    return [pscustomobject]@{ Ok = $true; Captures = $caps; Wildcards = $parts.Length - 1 }
}

function Match-DoubleStarRemainder {
    param(
        [string]$Pattern,
        [string]$InputText
    )

    $index = $Pattern.IndexOf('**', [System.StringComparison]::Ordinal)
    if ($index -lt 0) {
        return [pscustomobject]@{ Ok = $false; Captures = @(); Rest = '' }
    }

    $head = $Pattern.Substring(0, $index)
    $tail = $Pattern.Substring($index + 2)

    $headRegex = [regex]::Escape($head) -replace '\\\*', '(.*?)'
    $tailRegex = [regex]::Escape($tail) -replace '\\\*', '(.*?)'
    $regexText = '^' + $headRegex + '([\s\S]*?)' + $tailRegex + '$'

    $m = [regex]::Match($InputText, $regexText, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $m.Success) {
        return [pscustomobject]@{ Ok = $false; Captures = @(); Rest = '' }
    }

    $caps = @()
    if ($m.Groups.Count -gt 2) {
        for ($g = 1; $g -lt $m.Groups.Count - 1; $g++) {
            $caps += $m.Groups[$g].Value
        }
    }

    $rest = $m.Groups[$m.Groups.Count - 1].Value
    return [pscustomobject]@{ Ok = $true; Captures = $caps; Rest = $rest }
}

function Find-BestMatch {
    param(
        [string[]]$InputTokens,
        [string[]]$Order,
        [hashtable]$AliasMap
    )

    $best = $null
    $bestScore = -1
    foreach ($alias in $Order) {
        $aliasTokens = @(Get-Tokens -Text $alias)
        if ($aliasTokens.Count -eq 0) { continue }
        $doubleTokenIndex = -1
        for ($di = 0; $di -lt $aliasTokens.Count; $di++) {
            if ($aliasTokens[$di].Contains('**')) {
                if ($doubleTokenIndex -ne -1) {
                    $doubleTokenIndex = -2
                    break
                }
                $doubleTokenIndex = $di
            }
        }

        if ($doubleTokenIndex -eq -2) { continue }
        if ($doubleTokenIndex -ge 0 -and $doubleTokenIndex -ne $aliasTokens.Count - 1) { continue }

        if ($doubleTokenIndex -lt 0 -and $InputTokens.Count -lt $aliasTokens.Count) { continue }
        if ($doubleTokenIndex -ge 0 -and $InputTokens.Count -lt ($doubleTokenIndex + 1)) { continue }

        $ok = $true
        $wildcardCount = 0
        $captures = @()
        $restCapture = ''
        $inputConsumed = 0

        for ($i = 0; $i -lt $aliasTokens.Count; $i++) {
            if ($i -eq $doubleTokenIndex) {
                $remainText = $InputTokens[$i..($InputTokens.Count - 1)] -join ' '
                $double = Match-DoubleStarRemainder -Pattern $aliasTokens[$i] -InputText $remainText
                if (-not $double.Ok) {
                    $ok = $false
                    break
                }
                if ([string]::IsNullOrWhiteSpace($double.Rest)) {
                    $ok = $false
                    break
                }
                if ($double.Captures.Count -gt 0) {
                    $captures += $double.Captures
                }
                $restCapture = $double.Rest
                $wildcardCount += 1000
                $inputConsumed = $InputTokens.Count
                continue
            }

            $match = Match-TokenPattern -Pattern $aliasTokens[$i] -Token $InputTokens[$i]
            if (-not $match.Ok) {
                $ok = $false
                break
            }
            $wildcardCount += $match.Wildcards
            if ($match.Captures.Count -gt 0) {
                $captures += $match.Captures
            }
            $inputConsumed = $i + 1
        }

        if (-not $ok) { continue }

        $candidate = [pscustomobject]@{
            Alias         = $alias
            Template      = $AliasMap[$alias]
            Captures      = $captures
            RestCapture   = $restCapture
            AliasTokenLen = $aliasTokens.Count
            Wildcards     = $wildcardCount
            ArgsStart     = $inputConsumed
            LiteralChars  = (($alias -replace '\*\*', '' -replace '\*', '').Replace(' ', '')).Length
        }

        $score = ($candidate.AliasTokenLen * 10000) + ($candidate.LiteralChars * 100) - $candidate.Wildcards

        if ($null -eq $best) {
            $best = $candidate
            $bestScore = $score
            continue
        }

        if ($score -gt $bestScore) {
            $best = $candidate
            $bestScore = $score
            continue
        }
    }
    return $best
}

try {
    if ($InputArgs.Count -eq 0) {
        [Console]::Error.WriteLine('[wsha] missing alias.')
        [Console]::Error.WriteLine('')
        [Console]::Error.WriteLine('Run with --help for usage.')
        exit 1
    }

    $first = $InputArgs[0]
    if ($first -ieq '-h' -or $first -ieq '--help') {
        Show-Help
        exit 0
    }

    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-AppEnvironmentVariables -ScriptDir $scriptDir
    $builtinConfig = Join-Path $scriptDir '..\config\wsh-alias.txt'
    $userConfig = Join-Path $env:USERPROFILE '.config\wsh-alias.txt'
    $localConfig = Join-Path (Get-Location).Path '.config\wsh-alias.txt'

    $aliasMap = @{}
    $order = New-Object 'System.Collections.Generic.List[string]'
    $singleConfig = $env:WSHA_CONFIG_FILE
    if ([string]::IsNullOrWhiteSpace($singleConfig)) {
        Load-Config -ConfigPath $builtinConfig -AliasMap $aliasMap -Order $order -FailOnDuplicate:$false
        Load-Config -ConfigPath $userConfig -AliasMap $aliasMap -Order $order -FailOnDuplicate:$false
        Load-Config -ConfigPath $localConfig -AliasMap $aliasMap -Order $order -FailOnDuplicate:$false
    } else {
        Load-Config -ConfigPath $singleConfig -AliasMap $aliasMap -Order $order -FailOnDuplicate:$true
    }

    if ($first -ieq '-l' -or $first -ieq '--list') {
        foreach ($a in $order) {
            Write-Output "$a $($aliasMap[$a])"
        }
        exit 0
    }

    $inputTokens = @($InputArgs)
    if ($InputArgs.Count -eq 1) {
        $split = @(Get-Tokens -Text $InputArgs[0])
        if ($split.Count -gt 1) {
            $inputTokens = $split
        }
    }

    $match = Find-BestMatch -InputTokens $inputTokens -Order $order.ToArray() -AliasMap $aliasMap
    if ($null -eq $match) {
        if ($InputArgs.Count -eq 1) {
            Invoke-CmdLine -CommandText $InputArgs[0]
        } else {
            Invoke-CmdLine -CommandText ($InputArgs -join ' ')
        }
    }

    $finalTemplate = $match.Template
    for ($i = $match.Captures.Count; $i -ge 1; $i--) {
        $value = $match.Captures[$i - 1]
        $finalTemplate = $finalTemplate.Replace('$' + $i, $value)
    }
    $finalTemplate = $finalTemplate.Replace('$$', $match.RestCapture)

    $runtimeArgs = @()
    if ($inputTokens.Count -gt $match.ArgsStart) {
        $runtimeArgs = $inputTokens[$match.ArgsStart..($inputTokens.Count - 1)]
    }

    $templateTokens = @(Get-Tokens -Text $finalTemplate)
    $finalTokens = @()
    $placeholderUsed = $false
    foreach ($t in $templateTokens) {
        if ($t -eq '--') {
            $placeholderUsed = $true
            if ($runtimeArgs.Count -gt 0) {
                $finalTokens += $runtimeArgs
            }
        } else {
            $finalTokens += $t
        }
    }
    if (-not $placeholderUsed -and $runtimeArgs.Count -gt 0) {
        $finalTokens += $runtimeArgs
    }

    $finalCmd = $finalTokens -join ' '
    if ([string]::IsNullOrWhiteSpace($finalCmd)) {
        [Console]::Error.WriteLine("[wsha] expanded command is empty for alias `"$($match.Alias)`"")
        exit 1
    }

    $entry = $env:WSHA_ENTRY
    if ([string]::IsNullOrWhiteSpace($entry)) {
        $entry = 'wsha'
    }
    $rawInput = $inputTokens -join ' '
    [Console]::Error.WriteLine("[wsha] alias hit: $entry $rawInput -> $finalCmd")

    Invoke-CmdLine -CommandText $finalCmd
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    if ($env:WSHA_DEBUG -eq '1') {
        [Console]::Error.WriteLine($_.ScriptStackTrace)
        if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
            [Console]::Error.WriteLine($_.InvocationInfo.PositionMessage)
        }
    }
    exit 1
}
