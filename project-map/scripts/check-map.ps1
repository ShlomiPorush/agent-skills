[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('check', 'embed-fonts')]
    [string]$Command,

    [Parameter()]
    [string]$MapDir = '.project-map'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8 = New-Object System.Text.UTF8Encoding($false)
$skillDir = Split-Path -Parent $PSScriptRoot
$fontDir = Join-Path $skillDir 'assets/fonts'
$mapPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $MapDir))
$statePath = Join-Path $mapPath 'state.json'
$htmlPath = Join-Path $mapPath 'index.html'

$maxHtmlBytes = 512 * 1024
$fontMarker = '/* project-map:fonts */'
$fontStart = '/* project-map:fonts:start */'
$fontEnd = '/* project-map:fonts:end */'

$fonts = @(
    @{
        File = 'heebo-hebrew-wght-normal.woff2'
        Range = 'U+0307-0308,U+0590-05FF,U+200C-2010,U+20AA,U+25CC,U+FB1D-FB4F'
    },
    @{
        File = 'heebo-latin-wght-normal.woff2'
        Range = 'U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD'
    }
)

function Get-FontBase64([string]$File) {
    [Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Join-Path $fontDir $File)))
}

function Get-FontCss {
    $rules = foreach ($font in $fonts) {
        @(
            '@font-face {'
            '  font-family: "Heebo Variable";'
            '  font-style: normal;'
            '  font-display: swap;'
            '  font-weight: 100 900;'
            "  src: url(data:font/woff2;base64,$(Get-FontBase64 $font.File)) format(`"woff2-variations`");"
            "  unicode-range: $($font.Range);"
            '}'
        ) -join "`n"
    }
    (@($fontStart) + $rules + @($fontEnd)) -join "`n"
}

function Write-TextAtomic([string]$Path, [string]$Text) {
    $temp = "$Path.tmp"
    [System.IO.File]::WriteAllText($temp, $Text, $utf8)
    if (Test-Path -LiteralPath $Path) {
        [System.IO.File]::Replace($temp, $Path, [NullString]::Value)
    }
    else {
        [System.IO.File]::Move($temp, $Path)
    }
}

function Invoke-EmbedFonts {
    if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) {
        throw "Map page not found: $htmlPath. Write index.html first, with $fontMarker inside its <style> element."
    }
    $html = [System.IO.File]::ReadAllText($htmlPath, $utf8)
    $css = Get-FontCss
    $start = $html.IndexOf($fontStart)
    $end = $html.IndexOf($fontEnd)
    if ($start -ge 0 -and $end -gt $start) {
        $html = $html.Substring(0, $start) + $css + $html.Substring($end + $fontEnd.Length)
    }
    elseif ($html.Contains($fontMarker)) {
        $html = $html.Replace($fontMarker, $css)
    }
    else {
        throw "No font marker in $htmlPath. Put $fontMarker inside the <style> element, then run embed-fonts again."
    }
    Write-TextAtomic -Path $htmlPath -Text $html
    "Embedded Heebo into $htmlPath"
}

$problems = New-Object System.Collections.Generic.List[string]

function Add-Problem([string]$File, [string]$Message) {
    $problems.Add("FAIL ${File}: $Message")
}

function Get-Prop($Object, [string]$Name) {
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $null
}

function Test-Text($Value) {
    return ($Value -is [string]) -and -not [string]::IsNullOrWhiteSpace($Value)
}

function Test-State($State) {
    $f = 'state.json'
    if ((Get-Prop $State 'version') -ne 1) { Add-Problem $f 'version must be 1.' }

    $updatedAt = Get-Prop $State 'updatedAt'
    $parsed = [DateTimeOffset]::MinValue
    if (-not (Test-Text $updatedAt) -and -not ($updatedAt -is [datetime])) {
        Add-Problem $f 'updatedAt must be an ISO 8601 timestamp.'
    }
    elseif ($updatedAt -is [string] -and -not [DateTimeOffset]::TryParse($updatedAt, [ref]$parsed)) {
        Add-Problem $f "updatedAt is not a valid timestamp: $updatedAt"
    }

    $lastCommit = Get-Prop $State 'lastCommit'
    if (-not ($lastCommit -is [string]) -or $lastCommit -notmatch '^[0-9a-f]{40}$') {
        Add-Problem $f 'lastCommit must be the full 40-character SHA of HEAD at this update.'
    }

    $partIds = @{}
    $partStatus = @{}
    $parts = @(Get-Prop $State 'parts' | Where-Object { $null -ne $_ })
    if ($parts.Count -eq 0) { Add-Problem $f 'parts must list the main parts of the project.' }
    foreach ($part in $parts) {
        $id = Get-Prop $part 'id'
        $label = if (Test-Text $id) { "part '$id'" } else { 'a part' }
        if (-not (Test-Text $id)) { Add-Problem $f 'every part needs an id.' }
        elseif ($partIds.ContainsKey($id)) { Add-Problem $f "${label}: duplicate id." }
        else { $partIds[$id] = $true }

        if (-not (Test-Text (Get-Prop $part 'name'))) { Add-Problem $f "${label}: name is missing." }
        if (-not (Test-Text (Get-Prop $part 'summary'))) { Add-Problem $f "${label}: summary is missing." }

        $status = Get-Prop $part 'status'
        if (@('done', 'in-progress', 'not-started', 'blocked', 'unknown') -notcontains $status) {
            Add-Problem $f "${label}: status '$status' is not one of done, in-progress, not-started, blocked, unknown."
        }
        if (Test-Text $id) { $partStatus[$id] = $status }

        $evidence = @(Get-Prop $part 'evidence' | Where-Object { Test-Text $_ })
        if ($status -ne 'unknown' -and $evidence.Count -eq 0) {
            Add-Problem $f "${label}: status '$status' has no evidence. Cite evidence or use 'unknown'."
        }

        $blockedOn = Get-Prop $part 'blockedOn'
        if ($status -eq 'blocked' -and -not (Test-Text $blockedOn)) {
            Add-Problem $f "${label}: blocked parts must name what they wait on in blockedOn."
        }
        if ($status -ne 'blocked' -and $null -ne $blockedOn) {
            Add-Problem $f "${label}: blockedOn must be null unless status is 'blocked'."
        }
    }

    $milestoneIds = @{}
    foreach ($milestone in @(Get-Prop $State 'milestones' | Where-Object { $null -ne $_ })) {
        $id = Get-Prop $milestone 'id'
        $label = "milestone '$id'"
        if (-not (Test-Text $id)) { Add-Problem $f 'every milestone needs an id.'; $label = 'a milestone' }
        elseif ($milestoneIds.ContainsKey($id)) { Add-Problem $f "${label}: duplicate id." }
        else { $milestoneIds[$id] = $true }

        if (-not (Test-Text (Get-Prop $milestone 'name'))) { Add-Problem $f "${label}: name is missing." }
        $status = Get-Prop $milestone 'status'
        if (@('proposed', 'approved', 'reached') -notcontains $status) {
            Add-Problem $f "${label}: status '$status' is not one of proposed, approved, reached."
        }
        $members = @(Get-Prop $milestone 'parts' | Where-Object { $null -ne $_ })
        foreach ($member in $members) {
            if (-not $partIds.ContainsKey([string]$member)) { Add-Problem $f "${label}: unknown part '$member'." }
        }
        if ($status -eq 'reached') {
            $open = @($members | Where-Object { $partIds.ContainsKey([string]$_) -and $partStatus[[string]$_] -ne 'done' })
            if ($open.Count -gt 0) {
                Add-Problem $f "${label}: marked reached but these parts are not done: $($open -join ', ')."
            }
        }
    }

    $decisionIds = @{}
    foreach ($decision in @(Get-Prop $State 'decisions' | Where-Object { $null -ne $_ })) {
        $id = Get-Prop $decision 'id'
        $label = "decision '$id'"
        if (-not (Test-Text $id)) { Add-Problem $f 'every decision needs an id.'; $label = 'a decision' }
        elseif ($decisionIds.ContainsKey($id)) { Add-Problem $f "${label}: duplicate id." }
        else { $decisionIds[$id] = $true }

        if (-not (Test-Text (Get-Prop $decision 'question'))) { Add-Problem $f "${label}: question is missing." }
        $status = Get-Prop $decision 'status'
        $answer = Get-Prop $decision 'answer'
        if ($status -eq 'open') {
            if (-not (Test-Text (Get-Prop $decision 'recommendation'))) {
                Add-Problem $f "${label}: open decisions need a recommendation."
            }
            if ($null -ne $answer) { Add-Problem $f "${label}: open decisions must have answer null." }
        }
        elseif ($status -eq 'answered') {
            if ($null -eq $answer -or ($answer -is [string] -and [string]::IsNullOrWhiteSpace($answer))) {
                Add-Problem $f "${label}: answered decisions must record the answer."
            }
        }
        else {
            Add-Problem $f "${label}: status '$status' is not one of open, answered."
        }
        foreach ($blocked in @(Get-Prop $decision 'blocks' | Where-Object { $null -ne $_ })) {
            if (-not $partIds.ContainsKey([string]$blocked)) { Add-Problem $f "${label}: blocks unknown part '$blocked'." }
        }
    }

    if (-not (Test-Text (Get-Prop $State 'nextStep'))) { Add-Problem $f 'nextStep must name one concrete action.' }
}

function Get-VisibleText([string]$Html) {
    $options = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Singleline'
    $text = [regex]::Replace($Html, '<!--.*?-->', ' ', $options)
    $text = [regex]::Replace($text, '<(script|style|template)\b[^>]*>.*?</\1\s*>', ' ', $options)
    $text = [regex]::Replace($text, '<[^>]+>', ' ', $options)
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    return [regex]::Replace($text, '\s+', ' ')
}

function Test-Html([string]$Html, [long]$Bytes, $State) {
    $f = 'index.html'
    $options = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Singleline'

    if ($Bytes -gt $maxHtmlBytes) {
        Add-Problem $f "size is $([math]::Ceiling($Bytes / 1024)) KB; the limit is 512 KB."
    }

    $htmlTag = [regex]::Match($Html, '<html\b[^>]*>', $options)
    if (-not $htmlTag.Success) {
        Add-Problem $f 'no <html> element.'
    }
    else {
        if ($htmlTag.Value -notmatch '\blang\s*=\s*["'']?he\b') { Add-Problem $f '<html> must have lang="he".' }
        if ($htmlTag.Value -notmatch '\bdir\s*=\s*["'']?rtl\b') { Add-Problem $f '<html> must have dir="rtl".' }
    }

    $code = [regex]::Replace($Html, '<!--.*?-->', ' ', $options)
    $external = @(
        @{ Pattern = '<script\b[^>]*\ssrc\s*='; Message = 'loads an external script. Inline all scripts.' },
        @{ Pattern = '<link\b[^>]*\shref\s*=\s*["'']?\s*(?!data:)[^\s"''>]'; Message = 'has a <link> to an external resource. Inline styles, icons, and fonts.' },
        @{ Pattern = '<(iframe|frame|object|embed)\b'; Message = 'embeds a frame or plugin. The page must be self-contained.' },
        @{ Pattern = '\s(src|poster|data)\s*=\s*["'']?\s*(?!data:|#)[^\s"''>]'; Message = 'has a src, poster, or data attribute that is not a data: URL.' },
        @{ Pattern = 'url\(\s*["'']?\s*(?!data:|#)[^\s"'')]'; Message = 'has a CSS url() that is not a data: URL.' },
        @{ Pattern = '@import\b'; Message = 'uses CSS @import.' },
        @{ Pattern = '\bfetch\s*\(|\bXMLHttpRequest\b|\bimport\s*\(|\bnew\s+(Worker|SharedWorker|EventSource|WebSocket)\b'; Message = 'fetches at runtime. Embed the state data in the page instead.' }
    )
    foreach ($rule in $external) {
        $match = [regex]::Match($code, $rule.Pattern, $options)
        if ($match.Success) {
            $snippet = $code.Substring($match.Index, [math]::Min(60, $code.Length - $match.Index)) -replace '\s+', ' '
            Add-Problem $f "$($rule.Message) Found: $snippet"
        }
    }

    if ($Html -notmatch '"Heebo Variable"') {
        Add-Problem $f "Heebo is not declared. Put $fontMarker in <style> and run embed-fonts."
    }
    foreach ($font in $fonts) {
        if (-not $Html.Contains((Get-FontBase64 $font.File))) {
            Add-Problem $f "$($font.File) is not embedded byte-for-byte. Run embed-fonts."
        }
        elseif (-not $Html.Contains("unicode-range: $($font.Range);")) {
            Add-Problem $f "$($font.File) has the wrong unicode-range. Run embed-fonts."
        }
    }

    if ($Html -notmatch 'prefers-color-scheme\s*:\s*(dark|light)') {
        Add-Problem $f 'no prefers-color-scheme rule. Support both light and dark themes.'
    }

    $visible = Get-VisibleText $Html
    $dashes = [regex]::Matches($visible, "[$([char]0x2010)-$([char]0x2015)$([char]0x2212)]")
    foreach ($dash in @($dashes | Select-Object -First 5)) {
        $from = [math]::Max(0, $dash.Index - 25)
        $context = $visible.Substring($from, [math]::Min(50, $visible.Length - $from)).Trim()
        Add-Problem $f ("visible text has dash U+{0:X4}. Rewrite without it: ...{1}..." -f [int][char]$dash.Value, $context)
    }
    if ($dashes.Count -gt 5) { Add-Problem $f "$($dashes.Count - 5) more forbidden dashes in visible text." }

    if ($null -ne $State) {
        # Inline elements such as <bdi> split text, so compare without any whitespace.
        $compact = ($visible -replace '\s+', '').Normalize()
        foreach ($part in @(Get-Prop $State 'parts' | Where-Object { $null -ne $_ })) {
            $name = Get-Prop $part 'name'
            if ((Test-Text $name) -and -not $compact.Contains(($name -replace '\s+', '').Normalize())) {
                Add-Problem $f "part name '$name' from state.json is not on the page. Render index.html from the current state.json."
            }
        }
        $nextStep = Get-Prop $State 'nextStep'
        if ((Test-Text $nextStep) -and -not $compact.Contains(($nextStep -replace '\s+', '').Normalize())) {
            Add-Problem $f 'nextStep from state.json is not on the page. Render index.html from the current state.json.'
        }
    }
}

function Invoke-Check {
    $state = $null
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        Add-Problem 'state.json' "not found at $statePath."
    }
    else {
        try {
            $state = [System.IO.File]::ReadAllText($statePath, $utf8) | ConvertFrom-Json
        }
        catch {
            Add-Problem 'state.json' "is not valid JSON: $($_.Exception.Message)"
        }
        if ($null -ne $state) { Test-State $state }
    }

    if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) {
        Add-Problem 'index.html' "not found at $htmlPath."
    }
    else {
        $html = [System.IO.File]::ReadAllText($htmlPath, $utf8)
        Test-Html -Html $html -Bytes (Get-Item -LiteralPath $htmlPath).Length -State $state
    }

    if ($problems.Count -eq 0) {
        "project-map check passed: $mapPath"
        return
    }
    $problems
    "project-map check found $($problems.Count) problem(s). Fix them and run check again."
    exit 1
}

switch ($Command) {
    'check' { Invoke-Check }
    'embed-fonts' { Invoke-EmbedFonts }
}
