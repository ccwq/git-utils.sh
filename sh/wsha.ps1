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
  w --list-view | -lv

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
  - `-l` uses table view in console
  - `-lv` opens table view in Out-GridView
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

function Normalize-PathString {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    return [System.IO.Path]::GetFullPath($Path)
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
        [bool]$FailOnDuplicate,
        [string]$SourceName
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) { return }
    $normalizedConfigPath = Normalize-PathString -Path $ConfigPath
    if (-not (Test-Path -LiteralPath $normalizedConfigPath)) { return }

    $lineNo = 0
    Get-Content -LiteralPath $normalizedConfigPath | ForEach-Object {
        $lineNo += 1
        $parsed = Parse-ConfigLine -Line $_ -ConfigPath $normalizedConfigPath -LineNo $lineNo
        if ($null -eq $parsed) { return }

        if ($FailOnDuplicate -and $AliasMap.ContainsKey($parsed.Alias)) {
            throw "[wsha] duplicate alias `"$($parsed.Alias)`" at line $($parsed.LineNo) in `"$ConfigPath`""
        }

        $entry = [pscustomobject]@{
            Alias      = $parsed.Alias
            Template   = $parsed.Template
            LineNo     = $parsed.LineNo
            ConfigPath = $normalizedConfigPath
            SourceName = $SourceName
        }

        if ($AliasMap.ContainsKey($parsed.Alias)) {
            $AliasMap[$parsed.Alias] = $entry
        } else {
            $AliasMap[$parsed.Alias] = $entry
            [void]$Order.Add($parsed.Alias)
        }
    }
}

function New-SourceDescriptor {
    param(
        [string]$Name,
        [string]$Path
    )

    return [pscustomobject]@{
        Name = $Name
        Path = (Normalize-PathString -Path $Path)
    }
}

function Get-ListGroups {
    param(
        [string[]]$Order,
        [hashtable]$AliasMap,
        [object[]]$Sources
    )

    $groups = New-Object 'System.Collections.Generic.List[object]'
    foreach ($source in $Sources) {
        $rows = New-Object 'System.Collections.Generic.List[object]'
        foreach ($alias in $Order) {
            $entry = $AliasMap[$alias]
            if ($null -eq $entry) { continue }
            if ($entry.ConfigPath -ne $source.Path) { continue }
            [void]$rows.Add([pscustomobject]@{
                别名 = $entry.Alias
                命令 = $entry.Template
            })
        }

        if ($rows.Count -eq 0) { continue }

        [void]$groups.Add([pscustomobject]@{
            来源     = $source.Name
            配置文件 = $source.Path
            数据     = $rows.ToArray()
        })
    }

    return $groups.ToArray()
}

function Show-ListTable {
    param([object[]]$Groups)

    if ($Groups.Count -eq 0) {
        Write-Output '[wsha] no alias found.'
        return
    }

    $blocks = New-Object 'System.Collections.Generic.List[string]'
    foreach ($group in $Groups) {
        $table = $group.数据 |
            Format-Table 别名, 命令 -AutoSize |
            Out-String -Width 4096

        [void]$blocks.Add(('[{0}] {1}' -f $group.来源, $group.配置文件))
        [void]$blocks.Add($table.TrimEnd())
    }

    Write-Output (($blocks.ToArray() -join [Environment]::NewLine + [Environment]::NewLine + [Environment]::NewLine).TrimEnd())
}

function Show-ListGridView {
    param([object[]]$Groups)

    if ($Groups.Count -eq 0) {
        Write-Output '[wsha] no alias found.'
        return
    }

    if ($env:WSHA_TEST_GRID_CAPTURE -eq '1') {
        Show-ListTable -Groups $Groups
        return
    }

    $payloadPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wsha-list-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $launcherPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wsha-list-{0}.ps1" -f ([guid]::NewGuid().ToString('N')))
    $Groups | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $payloadPath -Encoding UTF8

    @"
param(
    [string]`$PayloadPath
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

`$raw = Get-Content -LiteralPath `$PayloadPath -Raw -Encoding UTF8
`$groups = @((ConvertFrom-Json -InputObject `$raw))

`$form = New-Object System.Windows.Forms.Form
`$form.Text = 'wsha alias list'
`$form.StartPosition = 'CenterScreen'
`$form.Width = 1100
`$form.Height = 720

`$tabs = New-Object System.Windows.Forms.TabControl
`$tabs.Dock = 'Fill'

foreach (`$group in `$groups) {
    `$tab = New-Object System.Windows.Forms.TabPage
    `$tab.Text = [string]`$group.来源

    `$pathBox = New-Object System.Windows.Forms.TextBox
    `$pathBox.ReadOnly = `$true
    `$pathBox.Multiline = `$true
    `$pathBox.Dock = 'Top'
    `$pathBox.Height = 56
    `$pathBox.Text = [string]`$group.配置文件

    `$grid = New-Object System.Windows.Forms.DataGridView
    `$grid.Dock = 'Fill'
    `$grid.ReadOnly = `$true
    `$grid.AllowUserToAddRows = `$false
    `$grid.AllowUserToDeleteRows = `$false
    `$grid.AutoSizeColumnsMode = 'Fill'
    `$grid.AutoGenerateColumns = `$true
    `$grid.DataSource = [System.Collections.ArrayList]@(`$group.数据)

    `$tab.Controls.Add(`$grid)
    `$tab.Controls.Add(`$pathBox)
    [void]`$tabs.TabPages.Add(`$tab)
}

`$form.Controls.Add(`$tabs)

try {
    [void]`$form.ShowDialog()
}
finally {
    Remove-Item -LiteralPath `$PayloadPath -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath `$PSCommandPath -ErrorAction SilentlyContinue
}
"@ | Set-Content -LiteralPath $launcherPath -Encoding UTF8

    $hostProcessPath = (Get-Process -Id $PID).Path
    Start-Process -FilePath $hostProcessPath -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $launcherPath,
        '-PayloadPath', $payloadPath
    ) | Out-Null

    Write-Output '[wsha] list view opened.'
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
            Template      = $AliasMap[$alias].Template
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
    $sources = New-Object 'System.Collections.Generic.List[object]'
    $singleConfig = $env:WSHA_CONFIG_FILE
    if ([string]::IsNullOrWhiteSpace($singleConfig)) {
        [void]$sources.Add((New-SourceDescriptor -Name '内置' -Path $builtinConfig))
        [void]$sources.Add((New-SourceDescriptor -Name '用户级' -Path $userConfig))
        [void]$sources.Add((New-SourceDescriptor -Name '项目级' -Path $localConfig))

        Load-Config -ConfigPath $builtinConfig -AliasMap $aliasMap -Order $order -FailOnDuplicate:$false -SourceName '内置'
        Load-Config -ConfigPath $userConfig -AliasMap $aliasMap -Order $order -FailOnDuplicate:$false -SourceName '用户级'
        Load-Config -ConfigPath $localConfig -AliasMap $aliasMap -Order $order -FailOnDuplicate:$false -SourceName '项目级'
    } else {
        [void]$sources.Add((New-SourceDescriptor -Name '自定义' -Path $singleConfig))
        Load-Config -ConfigPath $singleConfig -AliasMap $aliasMap -Order $order -FailOnDuplicate:$true -SourceName '自定义'
    }

    if ($first -ieq '-l' -or $first -ieq '--list') {
        $groups = Get-ListGroups -Order $order.ToArray() -AliasMap $aliasMap -Sources $sources.ToArray()
        Show-ListTable -Groups $groups
        exit 0
    }

    if ($first -ieq '-lv' -or $first -ieq '--list-view') {
        $groups = Get-ListGroups -Order $order.ToArray() -AliasMap $aliasMap -Sources $sources.ToArray()
        Show-ListGridView -Groups $groups
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
