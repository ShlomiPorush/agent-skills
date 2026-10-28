# Tests for doc.ps1. No Pester needed.
# Run on both shells, with a work directory you choose:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File <this file> -WorkDir <dir>
#   pwsh -NoProfile -File <this file> -WorkDir <dir>
# Each run creates a new run-<timestamp>-<random> folder under <dir> and deletes nothing.
# Its cases folder keeps every case as pos-*.html or neg-*.html.
# Exit code 0 when every case passes.

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$skillDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$doc = Join-Path $skillDir 'scripts/doc.ps1'
$template = Join-Path $skillDir 'assets/document.html'
$shell = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$utf8 = New-Object System.Text.UTF8Encoding($false)

$WorkDir = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkDir))
$runDir = Join-Path $WorkDir ('run-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [IO.Path]::GetRandomFileName().Replace('.', ''))
$cases = Join-Path $runDir 'cases'
$scratch = Join-Path $runDir 'embed'
foreach ($dir in @($cases, $scratch)) { New-Item -ItemType Directory -Path $dir | Out-Null }
Write-Output "run folder: $runDir"

$failures = New-Object System.Collections.Generic.List[string]
$count = 0

function Invoke-Doc([string[]]$Arguments) {
    # Windows PowerShell 5.1 turns native stderr into terminating errors under Stop.
    $ErrorActionPreference = 'Continue'
    $output = & $shell -NoProfile -ExecutionPolicy Bypass -File $doc @Arguments 2>&1 | ForEach-Object { "$_" }
    [pscustomobject]@{ Code = $LASTEXITCODE; Text = ($output -join "`n") }
}

function Assert([string]$Name, [bool]$Condition, [string]$Detail) {
    $script:count++
    if ($Condition) { Write-Output "ok   $Name" }
    else { $script:failures.Add("FAIL $Name. $Detail") }
}

# ------------------------------------------------------------ embed-fonts

$base = Join-Path $scratch 'base.html'
$r = Invoke-Doc @('embed-fonts', $template, $base)
Assert 'embed-fonts on the template' ($r.Code -eq 0) $r.Text
$baseHtml = [IO.File]::ReadAllText($base)
$r = Invoke-Doc @('check', $base)
Assert 'check passes on the embedded template' ($r.Code -eq 0) $r.Text

$r = Invoke-Doc @('embed-fonts', $template, $base)
Assert 'embed-fonts overwrites an earlier output' (($r.Code -eq 0) -and ([IO.File]::ReadAllText($base) -eq $baseHtml)) $r.Text

$r = Invoke-Doc @('embed-fonts', $template)
Assert 'embed-fonts without an output fails' ($r.Code -ne 0) $r.Text

$noMarker = Join-Path $scratch 'no-marker.html'
[IO.File]::WriteAllText($noMarker, $baseHtml.Replace('/* html-communication:fonts:start */', '').Replace('/* html-communication:fonts:end */', ''), $utf8)
$r = Invoke-Doc @('embed-fonts', $noMarker, (Join-Path $scratch 'x1.html'))
Assert 'source without a marker fails' (($r.Code -ne 0) -and ($r.Text -match 'exactly once') -and -not (Test-Path (Join-Path $scratch 'x1.html'))) $r.Text

$twoMarkers = Join-Path $scratch 'two-markers.html'
$templateHtml = [IO.File]::ReadAllText($template)
[IO.File]::WriteAllText($twoMarkers, $templateHtml.Replace('/* html-communication:fonts */', "/* html-communication:fonts */`n/* html-communication:fonts */"), $utf8)
$r = Invoke-Doc @('embed-fonts', $twoMarkers, (Join-Path $scratch 'x2.html'))
Assert 'source with two markers fails' (($r.Code -ne 0) -and ($r.Text -match 'found 2')) $r.Text

$markerInComment = Join-Path $scratch 'marker-in-comment.html'
[IO.File]::WriteAllText($markerInComment, $templateHtml.Replace('/* html-communication:fonts */', '').Replace('<body>', '<body><!-- /* html-communication:fonts */ -->'), $utf8)
$r = Invoke-Doc @('embed-fonts', $markerInComment, (Join-Path $scratch 'x5.html'))
Assert 'a marker outside <style> fails' (($r.Code -ne 0) -and ($r.Text -match 'inside a <style>') -and -not (Test-Path (Join-Path $scratch 'x5.html'))) $r.Text

$r = Invoke-Doc @('embed-fonts', $base, (Join-Path $scratch 'x3.html'))
Assert 'an already embedded file is refused as source' (($r.Code -ne 0) -and ($r.Text -match 'already contains')) $r.Text

$badUtf8 = Join-Path $scratch 'bad-utf8.html'
$bytes = $utf8.GetBytes($templateHtml)
$bytes = $bytes + [byte[]](0xC3, 0x28)
[IO.File]::WriteAllBytes($badUtf8, $bytes)
$r = Invoke-Doc @('embed-fonts', $badUtf8, (Join-Path $scratch 'x4.html'))
Assert 'invalid UTF-8 source fails before writing' (($r.Code -ne 0) -and ($r.Text -match 'UTF-8') -and -not (Test-Path (Join-Path $scratch 'x4.html'))) $r.Text

# The output must never be the source, through any alias.
$real = Join-Path $scratch 'real'
New-Item -ItemType Directory -Path $real | Out-Null
$source = Join-Path $real 'source.html'
[IO.File]::WriteAllText($source, $templateHtml, $utf8)
$sourceHash = (Get-FileHash -LiteralPath $source).Hash
$junction = Join-Path $scratch 'junction'
New-Item -ItemType Junction -Path $junction -Target $real | Out-Null
$hardLink = Join-Path $scratch 'hardlink.html'
New-Item -ItemType HardLink -Path $hardLink -Target $source | Out-Null
foreach ($alias in @($source, $source.ToUpperInvariant(), (Join-Path $junction 'source.html'), $hardLink)) {
    $r = Invoke-Doc @('embed-fonts', $source, $alias)
    Assert "output aliasing the source is refused: $alias" (($r.Code -ne 0) -and ((Get-FileHash -LiteralPath $source).Hash -eq $sourceHash)) $r.Text
}
[IO.Directory]::Delete($junction, $false)

# ------------------------------------------------------------ check

function New-Case([string]$Name, [string]$Html) {
    $file = Join-Path $cases "$Name.html"
    [IO.File]::WriteAllText($file, $Html, $utf8)
    $file
}

function Add-Body([string]$Snippet) { $baseHtml.Replace('</main>', "$Snippet`n</main>") }
function Add-Head([string]$Snippet) { $baseHtml.Replace('</head>', "$Snippet`n</head>") }
function Add-Css([string]$Css) { $baseHtml.Replace('</style>', "$Css`n</style>") }

$positive = [ordered]@{
    'pos-code-as-text'      = Add-Body '<div class="doc-text"><pre><code>&lt;script&gt;alert(1)&lt;/script&gt; onload=x @import url(https://example.com/a.css) local(x)</code></pre></div>'
    'pos-html-comment'      = Add-Body '<!-- <script>alert(1)</script> <a href="relative.html"> -->'
    'pos-https-link'        = Add-Body '<p><a href="https://example.com/path?q=1#x">link</a> <a href=''#top''>top</a> <a href=#top>top</a></p>'
    'pos-inline-svg'        = Add-Body '<svg width="20" height="20" viewBox="0 0 20 20"><defs><linearGradient id="g"><stop offset="0" stop-color="red"/></linearGradient><path id="p" d="M0 0h20v20z"/></defs><use href="#p" fill="url(#g)"/></svg>'
    'pos-css-strings'       = Add-Css '.doc-x::after { content: "@import url(https://example.com/) local() \"q\""; } .doc-y { background: url(""); }'
    'pos-numeric-entity'    = Add-Body '<p><a href="&#35;top">top</a> <span title="a &amp; b &lt; c">t</span></p>'
    'pos-static-controls'   = Add-Body '<div class="doc-frame"><button type="button" disabled>Save</button><input type="text" value="x" readonly></div>'
    'pos-quoted-font-urls'  = [regex]::Replace($baseHtml, 'url\((data:font/woff2;base64,[A-Za-z0-9+/=]+)\)', 'url("$1")')
    'pos-embedded-bitmap'   = Add-Body '<img alt="" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=">'
}
foreach ($name in $positive.Keys) {
    $r = Invoke-Doc @('check', (New-Case $name $positive[$name]))
    Assert "check accepts $name" ($r.Code -eq 0) $r.Text
}

$negative = [ordered]@{
    'neg-script'            = @((Add-Body '<script>1</script>'), '<script>')
    'neg-event-handler'     = @((Add-Body '<p onclick="x()">x</p>'), 'onclick')
    'neg-form'              = @((Add-Body '<form><p>x</p></form>'), '<form>')
    'neg-iframe'            = @((Add-Body '<iframe title="x"></iframe>'), '<iframe>')
    'neg-object'            = @((Add-Body '<object title="x"></object>'), '<object>')
    'neg-embed'             = @((Add-Body '<embed title="x">'), '<embed>')
    'neg-base'              = @((Add-Head '<base href="https://example.com/">'), '<base>')
    'neg-link'              = @((Add-Head '<link rel="stylesheet" href="https://example.com/a.css">'), '<link>')
    'neg-meta-refresh'      = @((Add-Head '<meta http-equiv="refresh" content="0">'), 'refresh')
    'neg-srcset'            = @((Add-Body '<img alt="" srcset="a.png 1x">'), 'srcset')
    'neg-img-svg-data'      = @((Add-Body '<img alt="" src="data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=">'), 'src')
    'neg-img-https'         = @((Add-Body '<img alt="" src="https://example.com/a.png">'), 'src')
    'neg-href-relative'     = @((Add-Body '<a href="other.html">x</a>'), 'href')
    'neg-href-protocol-rel' = @((Add-Body '<a href="//example.com/">x</a>'), 'href')
    'neg-href-credentials'  = @((Add-Body '<a href="https://user:pw@example.com/">x</a>'), 'href')
    'neg-href-empty-https'  = @((Add-Body '<a href="https://">x</a>'), 'href')
    'neg-href-javascript'   = @((Add-Body '<a href="javascript:alert(1)">x</a>'), 'href')
    'neg-css-import'        = @((Add-Css '@import "x.css";'), '@import')
    'neg-css-remote-url'    = @((Add-Css '.doc-x { background: url(https://example.com/a.png); }'), 'url(')
    'neg-css-local'         = @((Add-Css '@font-face { font-family: X; src: local(Arial); }'), 'local')
    'neg-css-image-set'     = @((Add-Css '.doc-x { background: image-set("data:image/png;base64,AA==" 1x); }'), 'image-set')
    'neg-css-behavior'      = @((Add-Css '.doc-x { behavior: none; }'), 'behavior')
    'neg-css-escape'        = @((Add-Css '.doc-x { background: u\72l(https://example.com/a.png); }'), 'escapes')
    'neg-style-attr-entity' = @((Add-Body '<p style="background:&#117;rl(https://example.com/x.png)">x</p>'), 'url(')
    'neg-named-entity'      = @((Add-Body '<a href="&num;top">x</a>'), 'named entity')
    'neg-two-doctypes'      = @(("<!DOCTYPE html>`n" + $baseHtml), 'DOCTYPE')
    'neg-truncated'         = @($baseHtml.Substring(0, $baseHtml.IndexOf('</body>')), '</body>')
    'neg-no-rtl'            = @($baseHtml.Replace('<html lang="he" dir="rtl">', '<html lang="he">'), 'dir="rtl"')
    'neg-fonts-missing'     = @($templateHtml, 'not embedded')
    'neg-fonts-in-html-comment' = @($templateHtml.Replace('<body>', '<body><!-- ' + ([regex]::Match($baseHtml, '(?s)/\* html-communication:fonts:start \*/.*?/\* html-communication:fonts:end \*/').Value) + ' -->'), 'not embedded')
    'neg-fonts-in-css-comment'  = @($baseHtml.Replace('/* html-communication:fonts:start */', '/* disabled').Replace('/* html-communication:fonts:end */', '*/'), 'not embedded')
    'neg-too-large'         = @((Add-Body ('<!-- ' + ('x' * (520 * 1024)) + ' -->')), '512 KB')
}
foreach ($name in $negative.Keys) {
    $r = Invoke-Doc @('check', (New-Case $name $negative[$name][0]))
    Assert "check rejects $name" (($r.Code -ne 0) -and $r.Text.Contains($negative[$name][1])) $r.Text
}

$badFile = Join-Path $cases 'neg-invalid-utf8.html'
[IO.File]::WriteAllBytes($badFile, ($utf8.GetBytes($baseHtml) + [byte[]](0xC3, 0x28)))
$r = Invoke-Doc @('check', $badFile)
Assert 'check rejects neg-invalid-utf8' (($r.Code -ne 0) -and ($r.Text -match 'UTF-8')) $r.Text

foreach ($failure in $failures) { Write-Output $failure }
Write-Output ("{0} of {1} passed on PowerShell {2}" -f ($count - $failures.Count), $count, $PSVersionTable.PSVersion)
if ($failures.Count -gt 0) { exit 1 }
exit 0
