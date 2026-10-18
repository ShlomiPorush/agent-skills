# Fixture-based tests for check-partner-budget.ps1. No Pester needed.
# Run on both shells:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File <this file>
#   pwsh -NoProfile -File <this file>
# Exit code 0 when every case passes.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script = Join-Path (Split-Path -Parent $PSScriptRoot) 'check-partner-budget.ps1'
$fixtures = Join-Path $PSScriptRoot 'fixtures'
$secrets = @('example.invalid', 'FIXTURE-SECRET', 'auth', 'oauth')
$failures = New-Object System.Collections.Generic.List[string]
$count = 0

# PowerShell 7 parses ISO strings back into [DateTime]; compare as UTC text.
function Format-Field($Value) {
    if ($Value -is [DateTime]) {
        return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($null -eq $Value) { return $null }
    return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
}

function Test-Case {
    param(
        [string]$Name,
        [string]$Id,
        [string]$Now,
        [hashtable]$Expect
    )
    $script:count++
    $arguments = @{ ProviderInstanceId = $Id; CacheDir = $fixtures }
    if ($Now) { $arguments.Now = $Now }

    $lines = @(& $script @arguments)
    $exitCode = $LASTEXITCODE
    $problems = @()

    if ($lines.Count -ne 1) {
        $problems += "expected one output line, got $($lines.Count)"
    }
    $text = $lines -join "`n"
    foreach ($secret in $secrets) {
        if ($text -match [regex]::Escape($secret)) { $problems += "output contains '$secret'" }
    }

    $parsed = $null
    try { $parsed = $text | ConvertFrom-Json } catch { $problems += 'output is not JSON' }
    if ($parsed) {
        $names = @($parsed.PSObject.Properties.Name)
        $required = @('result', 'reason', 'providerInstanceId', 'windowId', 'usedPercent', 'resetsAt', 'checkedAt', 'dataAgeMinutes')
        foreach ($field in $required) {
            if ($names -notcontains $field) { $problems += "missing field $field" }
        }
        if (@($names | Where-Object { $required -notcontains $_ }).Count -gt 0) {
            $problems += "unexpected fields: $(($names | Where-Object { $required -notcontains $_ }) -join ',')"
        }
        foreach ($key in $Expect.Keys) {
            $actual = if ($names -contains $key) { Format-Field $parsed.$key } else { $null }
            $wanted = Format-Field $Expect[$key]
            if ($actual -ne $wanted) { $problems += "$key = '$actual', expected '$wanted'" }
        }
        $codes = @{ go = 0; ask = 1; unknown = 2 }
        if ($names -contains 'result' -and $codes.ContainsKey([string]$parsed.result) -and $exitCode -ne $codes[[string]$parsed.result]) {
            $problems += "exit code $exitCode does not match result $($parsed.result)"
        }
    }

    if ($problems.Count -gt 0) {
        $script:failures.Add("FAIL $Name`n    " + ($problems -join "`n    ") + "`n    output: $text")
    }
    else {
        Write-Output "ok   $Name"
    }
}

# Decisions
Test-Case 'claude dual weekly uses seven_day, ignores session and Fable' 'claude-dual-weekly' '2026-01-05T12:05:00Z' @{
    result = 'go'; reason = 'below-threshold'; windowId = 'seven_day'; usedPercent = 10
    resetsAt = '2026-01-10T12:00:00Z'; checkedAt = '2026-01-05T12:00:00Z'; dataAgeMinutes = 5
}
Test-Case 'ask at exactly 70% with reset 72h + 1s away' 'codex-weekly' '2026-01-07T11:59:59Z' @{
    result = 'ask'; reason = 'high-usage-far-reset'; windowId = 'secondary'; usedPercent = 70
    resetsAt = '2026-01-10T12:00:00Z'; checkedAt = '2026-01-07T11:50:00Z'
}
Test-Case 'go when reset is exactly 72h away' 'codex-weekly' '2026-01-07T12:00:00Z' @{
    result = 'go'; reason = 'reset-soon'; windowId = 'secondary'
}
Test-Case 'go at 69.9% with reset far away' 'codex-weekly-below' '2026-01-07T11:59:59Z' @{
    result = 'go'; reason = 'below-threshold'; usedPercent = 69.9
}
Test-Case 'single weekly window without seven_day id' 'codex-weekly-only' '2026-01-05T12:00:00Z' @{
    result = 'go'; reason = 'reset-soon'; windowId = 'primary'; usedPercent = 90
}
Test-Case 'codex monthly window, offset reset normalized to UTC' 'codex-monthly' '2026-01-05T12:01:00Z' @{
    result = 'ask'; reason = 'high-usage-far-reset'; windowId = 'primary'; usedPercent = 85
    resetsAt = '2026-02-04T12:00:00Z'
}

# Freshness: usageLimits.checkedAt decides, not the top-level checkedAt.
Test-Case 'fresh at exactly 15 minutes old' 'codex-weekly' '2026-01-07T12:05:00Z' @{
    result = 'go'; reason = 'reset-soon'; dataAgeMinutes = 15
}
Test-Case 'stale after 15 minutes' 'codex-weekly' '2026-01-07T12:05:01Z' @{
    result = 'unknown'; reason = 'stale'; checkedAt = '2026-01-07T11:50:00Z'; windowId = $null
}
Test-Case 'checkedAt up to 5 minutes ahead is accepted' 'codex-weekly' '2026-01-07T11:45:00Z' @{
    result = 'ask'; dataAgeMinutes = -5
}
Test-Case 'checkedAt more than 5 minutes ahead' 'codex-weekly' '2026-01-07T11:44:59Z' @{
    result = 'unknown'; reason = 'checked-at-in-future'
}

# Unknown paths
Test-Case 'reset already passed' 'reset-passed' '2026-01-05T12:01:00Z' @{
    result = 'unknown'; reason = 'reset-passed'; windowId = 'seven_day'
}
Test-Case 'missing file' 'no-such-instance' '2026-01-05T12:01:00Z' @{
    result = 'unknown'; reason = 'file-missing'; providerInstanceId = 'no-such-instance'
}
Test-Case 'no usageLimits section' 'no-usage-limits' '2026-01-05T12:01:00Z' @{
    result = 'unknown'; reason = 'usage-limits-missing'; checkedAt = $null
}
Test-Case 'usageLimits with no windows' 'no-windows' '2026-01-05T12:01:00Z' @{
    result = 'unknown'; reason = 'window-missing'
}
Test-Case 'session window only' 'session-only' '2026-01-05T12:01:00Z' @{
    result = 'unknown'; reason = 'window-missing'; windowId = $null; usedPercent = $null
}
Test-Case 'two weekly windows and no seven_day' 'ambiguous-weekly' '2026-01-05T12:01:00Z' @{
    result = 'unknown'; reason = 'window-ambiguous'
}
Test-Case 'reset without a time zone' 'naked-date' '2026-01-05T12:01:00Z' @{
    result = 'unknown'; reason = 'resets-at-invalid'
}
Test-Case 'usedPercent is not a number' 'bad-percent' '2026-01-05T12:01:00Z' @{
    result = 'unknown'; reason = 'used-percent-invalid'
}
Test-Case 'invalid JSON does not echo file content' 'broken' '2026-01-05T12:01:00Z' @{
    result = 'unknown'; reason = 'file-unreadable'
}
Test-Case 'path characters in instance id' '..\codex-weekly' '2026-01-07T12:00:00Z' @{
    result = 'unknown'; reason = 'invalid-instance-id'
}
Test-Case 'empty instance id' '' '2026-01-07T12:00:00Z' @{
    result = 'unknown'; reason = 'invalid-instance-id'
}
Test-Case 'Now without a time zone' 'codex-weekly' '2026-01-07T12:00:00' @{
    result = 'unknown'; reason = 'invalid-now'
}

# Exit codes through -File in a separate process of the same shell.
$shell = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
foreach ($case in @(
        @{ Id = 'claude-dual-weekly'; Now = '2026-01-05T12:05:00Z'; Code = 0 },
        @{ Id = 'codex-weekly'; Now = '2026-01-07T11:59:59Z'; Code = 1 },
        @{ Id = 'broken'; Now = '2026-01-05T12:01:00Z'; Code = 2 }
    )) {
    $count++
    $output = & $shell -NoProfile -ExecutionPolicy Bypass -File $script -ProviderInstanceId $case.Id -CacheDir $fixtures -Now $case.Now
    if ($LASTEXITCODE -ne $case.Code) {
        $failures.Add("FAIL -File exit code for $($case.Id): $LASTEXITCODE, expected $($case.Code). output: $output")
    }
    else {
        Write-Output "ok   -File exit code $($case.Code) for $($case.Id)"
    }
}

foreach ($failure in $failures) { Write-Output $failure }
Write-Output ("{0} of {1} passed on PowerShell {2}" -f ($count - $failures.Count), $count, $PSVersionTable.PSVersion)
if ($failures.Count -gt 0) { exit 1 }
exit 0
