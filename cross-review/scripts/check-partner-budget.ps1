# Budget gate for a cross-provider partner review in T3 Code.
#
# Reads only the usageLimits section of the T3 cache file for one provider
# instance and prints one JSON object: result go, ask, or unknown.
# Exit codes: 0 = go, 1 = ask, 2 = unknown.
#
# The cache file also holds account data (auth). Nothing outside usageLimits
# is ever printed, and error messages are never echoed, so no file content
# can leak into the output.

[CmdletBinding()]
param(
    # Required in practice. Not Mandatory, so a missing value still yields
    # JSON with result unknown instead of a binding error with exit code 1.
    [Parameter(Position = 0)]
    [string]$ProviderInstanceId = '',

    [Parameter()]
    [string]$CacheDir = (Join-Path (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.t3') 'caches'),

    # UTC timestamp with an explicit zone, for tests. A string, not [datetime],
    # so the current culture and time zone cannot reinterpret it.
    [Parameter()]
    [string]$Now
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$usedPercentThreshold = 70
$resetHorizonHours = 72
$maxDataAgeMinutes = 15
$maxClockSkewMinutes = 5
$exitCodes = @{ go = 0; ask = 1; unknown = 2 }

function Get-Field($Object, [string]$Name) {
    if ($null -eq $Object -or $Object -is [string] -or $Object -is [ValueType]) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

# PowerShell 7 turns ISO timestamps into [DateTime]; 5.1 keeps them as strings.
# Both become UTC here. A timestamp without an explicit zone is rejected.
function ConvertTo-UtcDate($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [DateTime]) {
        if ($Value.Kind -eq [DateTimeKind]::Unspecified) { return $null }
        return $Value.ToUniversalTime()
    }
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime }
    if ($Value -isnot [string]) { return $null }
    if ($Value -notmatch '(Z|[+-]\d{2}:?\d{2})$') { return $null }
    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $Value,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,
        [ref]$parsed
    )
    if ($ok) { return $parsed.UtcDateTime }
    return $null
}

function ConvertTo-Percent($Value) {
    if ($null -eq $Value -or $Value -is [bool]) { return $null }
    $number = 0.0
    $text = [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
    $ok = [double]::TryParse(
        $text,
        [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture,
        [ref]$number
    )
    if (-not $ok -or [double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt 0) {
        return $null
    }
    return $number
}

function Format-UtcDate($Value) {
    if ($null -eq $Value) { return $null }
    return $Value.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
}

# Account-wide window: id seven_day, else the only weekly window, else the
# only monthly window. The session window never decides in v1.
function Select-Window($Windows) {
    foreach ($rule in @(@('id', 'seven_day'), @('kind', 'weekly'), @('kind', 'monthly'))) {
        $field = $rule[0]
        $value = $rule[1]
        $found = @($Windows | Where-Object { [string](Get-Field $_ $field) -eq $value })
        if ($found.Count -eq 1) { return @{ window = $found[0] } }
        if ($found.Count -gt 1) { return @{ reason = 'window-ambiguous' } }
    }
    return @{ reason = 'window-missing' }
}

function New-State {
    return [ordered]@{
        result             = 'unknown'
        reason             = $null
        providerInstanceId = $ProviderInstanceId
        windowId           = $null
        usedPercent        = $null
        resetsAt           = $null
        checkedAt          = $null
        dataAgeMinutes     = $null
    }
}

function Get-Decision {
    $state = New-State

    if ($ProviderInstanceId -notmatch '^[A-Za-z0-9_-]+$') {
        $state.reason = 'invalid-instance-id'
        return $state
    }

    if ([string]::IsNullOrEmpty($Now)) {
        $nowUtc = [DateTime]::UtcNow
    }
    else {
        $nowUtc = ConvertTo-UtcDate $Now
        if ($null -eq $nowUtc) {
            $state.reason = 'invalid-now'
            return $state
        }
    }

    # Resolve against the PowerShell location, which .NET file APIs do not see.
    $location = (Get-Location -PSProvider FileSystem).ProviderPath
    $path = [IO.Path]::GetFullPath([IO.Path]::Combine($location, $CacheDir, "$ProviderInstanceId.json"))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $state.reason = 'file-missing'
        return $state
    }

    try {
        $usageLimits = Get-Field ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json) 'usageLimits'
    }
    catch {
        $state.reason = 'file-unreadable'
        return $state
    }
    if ($null -eq $usageLimits) {
        $state.reason = 'usage-limits-missing'
        return $state
    }

    $checkedAt = ConvertTo-UtcDate (Get-Field $usageLimits 'checkedAt')
    if ($null -eq $checkedAt) {
        $state.reason = 'checked-at-invalid'
        return $state
    }
    $state.checkedAt = Format-UtcDate $checkedAt
    $ageMinutes = ($nowUtc - $checkedAt).TotalMinutes
    $state.dataAgeMinutes = [Math]::Round($ageMinutes, 1)
    if ($ageMinutes -gt $maxDataAgeMinutes) {
        $state.reason = 'stale'
        return $state
    }
    if ($ageMinutes -lt -$maxClockSkewMinutes) {
        $state.reason = 'checked-at-in-future'
        return $state
    }

    $windows = @(@(Get-Field $usageLimits 'windows') | Where-Object { $null -ne $_ })
    $selection = Select-Window $windows
    if (-not $selection.Contains('window')) {
        $state.reason = $selection.reason
        return $state
    }
    $window = $selection.window
    $state.windowId = [string](Get-Field $window 'id')

    $usedPercent = ConvertTo-Percent (Get-Field $window 'usedPercent')
    if ($null -eq $usedPercent) {
        $state.reason = 'used-percent-invalid'
        return $state
    }
    $state.usedPercent = $usedPercent

    $resetsAt = ConvertTo-UtcDate (Get-Field $window 'resetsAt')
    if ($null -eq $resetsAt) {
        $state.reason = 'resets-at-invalid'
        return $state
    }
    $state.resetsAt = Format-UtcDate $resetsAt
    $hoursToReset = ($resetsAt - $nowUtc).TotalHours
    if ($hoursToReset -le 0) {
        $state.reason = 'reset-passed'
        return $state
    }

    if ($usedPercent -lt $usedPercentThreshold) {
        $state.result = 'go'
        $state.reason = 'below-threshold'
    }
    elseif ($hoursToReset -le $resetHorizonHours) {
        $state.result = 'go'
        $state.reason = 'reset-soon'
    }
    else {
        $state.result = 'ask'
        $state.reason = 'high-usage-far-reset'
    }
    return $state
}

try {
    $decision = Get-Decision
}
catch {
    $decision = New-State
    $decision.reason = 'internal-error'
}

[pscustomobject]$decision | ConvertTo-Json -Compress
exit $exitCodes[$decision.result]
