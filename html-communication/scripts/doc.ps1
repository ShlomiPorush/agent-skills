param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('embed-fonts', 'check')]
    [string]$Command,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Path,

    [Parameter(Position = 2)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$skillDir = Split-Path -Parent $PSScriptRoot
$fontDir = Join-Path $skillDir 'assets/fonts'
$maxHtmlBytes = 512 * 1024
$fontMarker = '/* html-communication:fonts */'
$fontStart = '/* html-communication:fonts:start */'
$fontEnd = '/* html-communication:fonts:end */'
$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)

$fonts = @(
    @{
        File = 'onest-latin.woff2'; Family = 'Onest'; Weight = '100 900'
        Range = 'U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD'
    },
    @{
        File = 'noto-sans-hebrew-hebrew.woff2'; Family = 'Noto Sans Hebrew'; Weight = '100 900'
        Range = 'U+0307-0308, U+0590-05FF, U+200C-2010, U+20AA, U+25CC, U+FB1D-FB4F'
    },
    @{
        File = 'ibm-plex-mono-latin-400.woff2'; Family = 'IBM Plex Mono'; Weight = '400'
        Range = 'U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD'
    }
)

# Mirrors ALLOWED_EMBEDDED_RESOURCE in the YAAPS HTML policy.
$embeddedResource = '^data:(?:image/(?:avif|gif|jpeg|png|webp)|font/(?:otf|ttf|woff|woff2));base64,[a-z0-9+/]+=*$'
$embeddedBitmap = '^data:image/(?:avif|gif|jpeg|png|webp);base64,[a-z0-9+/]+=*$'
$blockedElements = @('applet', 'base', 'embed', 'form', 'iframe', 'object', 'script', 'link')
$blockedAttributes = @('action', 'background', 'cite', 'data', 'formaction', 'manifest', 'ping', 'poster', 'srcset', 'srcdoc')
$cssValueAttributes = @('clip-path', 'fill', 'filter', 'marker', 'marker-end', 'marker-mid', 'marker-start', 'mask', 'stroke')
$rawTextElements = @('style', 'script', 'textarea', 'title', 'xmp', 'iframe', 'noembed', 'noframes', 'noscript', 'plaintext')
$basicEntities = @{ amp = '&'; lt = '<'; gt = '>'; quot = '"'; apos = "'" }

function Resolve-UserPath([string]$Value) {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Value)
}

function ConvertFrom-StrictUtf8([byte[]]$Bytes, [string]$Label) {
    try { $text = $strictUtf8.GetString($Bytes) }
    catch { throw "$Label is not valid UTF-8. Save it as UTF-8 and run again." }
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $text
}

function Get-FontBase64([string]$File) {
    [Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Join-Path $fontDir $File)))
}

function Get-FontCss {
    $rules = foreach ($font in $fonts) {
        "@font-face { font-family: `"$($font.Family)`"; font-style: normal; font-weight: $($font.Weight); font-display: swap; src: url(data:font/woff2;base64,$(Get-FontBase64 $font.File)) format(`"woff2`"); unicode-range: $($font.Range); }"
    }
    (@($fontStart) + $rules + @($fontEnd)) -join "`n"
}

function Get-Occurrences([string]$Text, [string]$Value) {
    $count = 0
    $at = $Text.IndexOf($Value, [StringComparison]::Ordinal)
    while ($at -ge 0) {
        $count++
        $at = $Text.IndexOf($Value, $at + $Value.Length, [StringComparison]::Ordinal)
    }
    $count
}

# Content ranges of <style> elements, skipping HTML comments and other raw-text elements,
# as start and length pairs.
function Get-StyleRanges([string]$Html) {
    $ranges = New-Object System.Collections.Generic.List[object]
    $i = 0
    while ($i -lt $Html.Length) {
        $lt = $Html.IndexOf('<', $i)
        if ($lt -lt 0) { break }
        if ([string]::CompareOrdinal($Html, $lt, '<!--', 0, 4) -eq 0) {
            $close = $Html.IndexOf('-->', $lt + 4, [StringComparison]::Ordinal)
            if ($close -lt 0) { break }
            $i = $close + 3
            continue
        }
        $m = [regex]::Match($Html.Substring($lt, [math]::Min(24, $Html.Length - $lt)), '^<([A-Za-z][A-Za-z0-9-]*)[\s/>]')
        if ($m.Success -and ($rawTextElements -contains $m.Groups[1].Value.ToLowerInvariant())) {
            $tag = $m.Groups[1].Value.ToLowerInvariant()
            $gt = $Html.IndexOf('>', $lt)
            if ($gt -lt 0) { break }
            $close = $Html.IndexOf('</' + $tag, $gt + 1, [StringComparison]::OrdinalIgnoreCase)
            if ($close -lt 0) { break }
            if ($tag -eq 'style') { $ranges.Add(@(($gt + 1), ($close - $gt - 1))) }
            $i = $close + 2
            continue
        }
        $i = $lt + 1
    }
    , $ranges
}

function Invoke-EmbedFonts([string]$Source, [string]$Output) {
    if (-not $Output) { throw 'Usage: embed-fonts <source> <output>. The output must be a different file.' }
    $sourceFull = [System.IO.Path]::GetFullPath((Resolve-UserPath $Source))
    $outputFull = [System.IO.Path]::GetFullPath((Resolve-UserPath $Output))
    if ([string]::Equals($sourceFull, $outputFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Output is the same file as the source: $outputFull. Choose another output path."
    }
    if (-not [System.IO.File]::Exists($sourceFull)) { throw "Source not found: $sourceFull" }

    # Hold the source open, read-only and shared for reading only, until the output is
    # written. If the output is the same physical file through any alias (junction, symlink,
    # hard link, short name), opening it for writing fails before anything is truncated.
    $sourceStream = [System.IO.File]::Open($sourceFull, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        $buffer = New-Object System.IO.MemoryStream
        $sourceStream.CopyTo($buffer)
        $html = ConvertFrom-StrictUtf8 $buffer.ToArray() "Source $sourceFull"

        if ($html.Contains($fontStart) -or $html.Contains($fontEnd)) {
            throw "Source already contains embedded fonts: $sourceFull. Run embed-fonts on the editable source, which has the marker $fontMarker."
        }
        $markers = Get-Occurrences $html $fontMarker
        $inStyle = 0
        foreach ($range in (Get-StyleRanges $html)) { $inStyle += Get-Occurrences $html.Substring($range[0], $range[1]) $fontMarker }
        if ($markers -ne 1 -or $inStyle -ne 1) {
            throw "Source must contain $fontMarker exactly once, inside a <style> element; found $markers, of which $inStyle inside <style>."
        }
        $bytes = $strictUtf8.GetBytes($html.Replace($fontMarker, (Get-FontCss)))

        try {
            $outputStream = New-Object System.IO.FileStream($outputFull, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        }
        catch {
            throw "Cannot open the output for writing: $outputFull. It is the source file itself through a link, or another program has it open."
        }
        try { $outputStream.Write($bytes, 0, $bytes.Length) }
        finally { $outputStream.Dispose() }
    }
    finally {
        $sourceStream.Dispose()
    }
    "Embedded fonts: $outputFull ($([math]::Ceiling($bytes.Length / 1024)) KB). Run check on it next."
}

# ---------------------------------------------------------------- check

$script:problems = New-Object System.Collections.Generic.List[string]
$script:html = ''
$script:styleUrls = New-Object System.Collections.Generic.List[string]

function Add-Problem([int]$Index, [string]$Message) {
    if ($Index -ge 0) {
        $line = 1
        for ($i = 0; $i -lt $Index -and $i -lt $script:html.Length; $i++) { if ($script:html[$i] -eq "`n") { $line++ } }
        $script:problems.Add("line ${line}: $Message")
    }
    else {
        $script:problems.Add($Message)
    }
}

function ConvertFrom-AttributeValue([string]$Value, [int]$Index) {
    foreach ($m in [regex]::Matches($Value, '&([A-Za-z][A-Za-z0-9]*);')) {
        if (-not $basicEntities.ContainsKey($m.Groups[1].Value)) {
            Add-Problem $Index "named entity &$($m.Groups[1].Value); in an attribute is not supported by check. Use the literal character or a numeric reference."
        }
    }
    $decoded = [regex]::Replace($Value, '&(#[0-9]+|#[xX][0-9A-Fa-f]+|amp|lt|gt|quot|apos);', {
            param($m)
            $name = $m.Groups[1].Value
            try {
                if ($name.StartsWith('#x') -or $name.StartsWith('#X')) { return [char]::ConvertFromUtf32([Convert]::ToInt32($name.Substring(2), 16)) }
                if ($name.StartsWith('#')) { return [char]::ConvertFromUtf32([int]$name.Substring(1)) }
            }
            catch { return [string][char]0xFFFD }
            return $basicEntities[$name]
        })
    $decoded.Trim()
}

function Test-HttpsUrl([string]$Value) {
    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) { return $false }
    ($uri.Scheme -eq 'https') -and ($uri.Host -ne '') -and ($uri.UserInfo -eq '')
}

# CSS is scanned in three states: code, comment and string. Only code counts, so text inside
# a string such as content: "@import" is never flagged.
function Test-Css([string]$Css, [int]$Index, [bool]$IsStylesheet = $false) {
    $code = New-Object System.Text.StringBuilder
    $strings = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $Css.Length) {
        $c = $Css[$i]
        if ($c -eq '/' -and $i + 1 -lt $Css.Length -and $Css[$i + 1] -eq '*') {
            $close = $Css.IndexOf('*/', $i + 2, [StringComparison]::Ordinal)
            if ($close -lt 0) { Add-Problem $Index 'CSS comment is not closed.'; return }
            [void]$code.Append(' ')
            $i = $close + 2
            continue
        }
        if ($c -eq '"' -or $c -eq "'") {
            $value = New-Object System.Text.StringBuilder
            $j = $i + 1
            while ($j -lt $Css.Length -and $Css[$j] -ne $c) {
                if ($Css[$j] -eq '\' -and $j + 1 -lt $Css.Length) { [void]$value.Append($Css[$j]); $j++ }
                [void]$value.Append($Css[$j])
                $j++
            }
            if ($j -ge $Css.Length) { Add-Problem $Index 'CSS string is not closed.'; return }
            $strings.Add($value.ToString())
            [void]$code.Append('"' + ($strings.Count - 1) + '"')
            $i = $j + 1
            continue
        }
        [void]$code.Append($c)
        $i++
    }
    $text = $code.ToString()

    if ($text.Contains('\')) { Add-Problem $Index 'CSS escapes outside strings are not supported by check, and the server may reject them. Write the plain characters.' }
    if ($text -match '(?i)@import\b') { Add-Problem $Index 'CSS @import is not allowed. Inline the styles.' }
    if ($text -match '(?i)(?<![\w-])(local|image-set|-webkit-image-set)\s*\(') { Add-Problem $Index "CSS $($Matches[1])() is not allowed." }
    if ($text -match '(?i)(?<![\w-])(behavior|-moz-binding)\s*:') { Add-Problem $Index "CSS property $($Matches[1]) is not allowed." }

    $urlCalls = [regex]::Matches($text, '(?i)(?<![\w-])url\(')
    $urlValues = [regex]::Matches($text, '(?i)(?<![\w-])url\(\s*(?:"(\d+)"|([^)"''\s]*))\s*\)')
    if ($urlCalls.Count -ne $urlValues.Count) { Add-Problem $Index 'a CSS url() could not be read. Write it as url(data:...) or url("data:...").' }
    foreach ($m in $urlValues) {
        if ($m.Groups[1].Success) { $value = $strings[[int]$m.Groups[1].Value].Trim() } else { $value = $m.Groups[2].Value }
        if ($IsStylesheet) { $script:styleUrls.Add($value) }
        if ($value -eq '' -or $value.StartsWith('#') -or $value -match $embeddedResource) { continue }
        Add-Problem $Index "CSS url($(if ($value.Length -gt 60) { $value.Substring(0, 60) + '...' } else { $value })) is not embedded. Use a base64 data URL of an image or font."
    }
}

function Test-StartTag([string]$Tag, [System.Collections.Generic.List[object]]$Attributes, [int]$Index) {
    if ($blockedElements -contains $Tag) {
        if ($Tag -eq 'link') { Add-Problem $Index '<link> is not allowed. Inline styles, icons and fonts.' }
        else { Add-Problem $Index "<$Tag> is not allowed." }
    }
    $isRefresh = $false
    foreach ($attribute in $Attributes) {
        $name = $attribute.Name
        $baseName = $name
        if ($name.Contains(':')) { $baseName = $name.Substring($name.LastIndexOf(':') + 1) }
        $value = ConvertFrom-AttributeValue $attribute.Value $Index

        if ($name.StartsWith('on')) { Add-Problem $Index "event handler attribute $name is not allowed."; continue }
        if ($blockedAttributes -contains $name) { Add-Problem $Index "attribute $name is not allowed."; continue }
        if ($name -eq 'src') {
            if (@('img', 'image') -notcontains $Tag) { Add-Problem $Index "src is not allowed on <$Tag>." }
            elseif ($value -notmatch $embeddedResource) { Add-Problem $Index 'image src must be a base64 data URL of avif, gif, jpeg, png or webp. SVG data URLs and remote images are rejected.' }
        }
        if ($baseName -eq 'href') {
            $ok = $value.StartsWith('#') -or
                ((@('a', 'area') -contains $Tag) -and (Test-HttpsUrl $value)) -or
                (($Tag -eq 'image') -and ($value -match $embeddedBitmap))
            if (-not $ok) { Add-Problem $Index "href `"$value`" must be an in-page #anchor or, on a link, a full https:// URL without credentials." }
        }
        if ($name -eq 'style') { Test-Css $value $Index }
        if ($cssValueAttributes -contains $name) { Test-Css $value $Index }
        if ($Tag -eq 'meta' -and $name -eq 'http-equiv' -and $value.ToLowerInvariant() -eq 'refresh') { $isRefresh = $true }
    }
    if ($isRefresh) { Add-Problem $Index 'meta refresh is not allowed.' }
}

function Invoke-Check([string]$File) {
    $full = [System.IO.Path]::GetFullPath((Resolve-UserPath $File))
    if (-not [System.IO.File]::Exists($full)) { throw "File not found: $full" }
    $bytes = [System.IO.File]::ReadAllBytes($full)
    if ($bytes.Length -eq 0) { Add-Problem -1 'the file is empty.' }
    if ($bytes.Length -gt $maxHtmlBytes) { Add-Problem -1 "size is $([math]::Ceiling($bytes.Length / 1024)) KB; the limit is 512 KB." }
    $script:html = ConvertFrom-StrictUtf8 $bytes "File $full"
    $html = $script:html

    $doctypes = 0
    $counts = @{ 'html' = @(0, 0); 'head' = @(0, 0); 'body' = @(0, 0) }
    $htmlTagSeen = $false
    $i = 0
    while ($i -lt $html.Length) {
        $lt = $html.IndexOf('<', $i)
        if ($lt -lt 0) { break }
        $i = $lt
        if ([string]::CompareOrdinal($html, $i, '<!--', 0, 4) -eq 0) {
            $close = $html.IndexOf('-->', $i + 4, [StringComparison]::Ordinal)
            if ($close -lt 0) { Add-Problem $i 'HTML comment is not closed.'; break }
            $i = $close + 3
            continue
        }
        if ($i + 1 -lt $html.Length -and $html[$i + 1] -eq '!') {
            $close = $html.IndexOf('>', $i)
            if ($close -lt 0) { Add-Problem $i 'declaration is not closed.'; break }
            if ($html.Substring($i, $close - $i + 1) -match '^<!doctype\s+html\s*>$') { $doctypes++ }
            else { Add-Problem $i 'only <!DOCTYPE html> is allowed as a declaration.' }
            $i = $close + 1
            continue
        }
        $end = ($i + 1 -lt $html.Length) -and ($html[$i + 1] -eq '/')
        $nameStart = $i + 1
        if ($end) { $nameStart++ }
        if ($nameStart -ge $html.Length -or -not [char]::IsLetter($html[$nameStart])) { $i++; continue }
        $j = $nameStart
        while ($j -lt $html.Length -and $html[$j] -notmatch '[\s/>]') { $j++ }
        $tag = $html.Substring($nameStart, $j - $nameStart).ToLowerInvariant()

        $attributes = New-Object System.Collections.Generic.List[object]
        while ($j -lt $html.Length -and $html[$j] -ne '>') {
            if ($html[$j] -match '[\s/]') { $j++; continue }
            $k = $j
            while ($k -lt $html.Length -and $html[$k] -notmatch '[\s/>=]') { $k++ }
            $attrName = $html.Substring($j, $k - $j).ToLowerInvariant()
            while ($k -lt $html.Length -and $html[$k] -match '\s') { $k++ }
            $attrValue = ''
            if ($k -lt $html.Length -and $html[$k] -eq '=') {
                $k++
                while ($k -lt $html.Length -and $html[$k] -match '\s') { $k++ }
                if ($k -lt $html.Length -and ($html[$k] -eq '"' -or $html[$k] -eq "'")) {
                    $quote = $html[$k]
                    $close = $html.IndexOf($quote, $k + 1)
                    if ($close -lt 0) { Add-Problem $i "attribute $attrName has no closing quote."; $k = $html.Length; break }
                    $attrValue = $html.Substring($k + 1, $close - $k - 1)
                    $k = $close + 1
                }
                else {
                    $v = $k
                    while ($k -lt $html.Length -and $html[$k] -notmatch '[\s>]') { $k++ }
                    $attrValue = $html.Substring($v, $k - $v)
                }
            }
            if ($attrName -ne '') { $attributes.Add([pscustomobject]@{ Name = $attrName; Value = $attrValue }) }
            $j = $k
        }
        if ($j -ge $html.Length) { Add-Problem $i "tag <$tag> is not closed."; break }
        $tagEnd = $j + 1

        if ($counts.ContainsKey($tag)) {
            if ($end) { $counts[$tag][1]++ } else { $counts[$tag][0]++ }
        }
        if ($end) { $i = $tagEnd; continue }

        Test-StartTag $tag $attributes $i
        if ($tag -eq 'html' -and -not $htmlTagSeen) {
            $htmlTagSeen = $true
            $lang = @($attributes | Where-Object { $_.Name -eq 'lang' } | ForEach-Object { $_.Value.Trim().ToLowerInvariant() })
            $dir = @($attributes | Where-Object { $_.Name -eq 'dir' } | ForEach-Object { $_.Value.Trim().ToLowerInvariant() })
            if ($lang -notcontains 'he' -or $dir -notcontains 'rtl') { Add-Problem $i 'the root must be <html lang="he" dir="rtl">.' }
        }

        if ($rawTextElements -contains $tag) {
            $closeAt = $html.IndexOf('</' + $tag, $tagEnd, [StringComparison]::OrdinalIgnoreCase)
            if ($closeAt -lt 0) { Add-Problem $i "<$tag> is not closed."; break }
            if ($tag -eq 'style') { Test-Css $html.Substring($tagEnd, $closeAt - $tagEnd) $i $true }
            $i = $closeAt
            continue
        }
        $i = $tagEnd
    }

    if ($doctypes -ne 1) { Add-Problem -1 "the document needs exactly one <!DOCTYPE html>; found $doctypes." }
    foreach ($name in @('html', 'head', 'body')) {
        if ($counts[$name][0] -ne 1 -or $counts[$name][1] -ne 1) {
            Add-Problem -1 "the document needs exactly one <$name> and one </$name>; found $($counts[$name][0]) and $($counts[$name][1]). A missing end tag usually means the file was cut short."
        }
    }
    # Fonts count only as a url() in active CSS: inside <style>, outside comments, quoted or not.
    foreach ($font in $fonts) {
        if (-not $script:styleUrls.Contains('data:font/woff2;base64,' + (Get-FontBase64 $font.File))) {
            Add-Problem -1 "font $($font.File) is not embedded in active CSS. Run embed-fonts on the source and check the output."
        }
    }

    if ($script:problems.Count -gt 0) {
        [Console]::Error.WriteLine("check failed for ${full}:")
        foreach ($problem in $script:problems) { [Console]::Error.WriteLine("  - $problem") }
        exit 1
    }
    "check passed: $full ($([math]::Ceiling($bytes.Length / 1024)) KB). This is a pre-publish check; the YAAPS server has the final word."
}

switch ($Command) {
    'embed-fonts' { Invoke-EmbedFonts $Path $OutputPath }
    'check' { Invoke-Check $Path }
}
