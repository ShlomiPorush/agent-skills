# Links skills into the agent-specific skill folders.
# Run once after cloning (or after adding a new skill): pwsh ./install.ps1
# Junctions don't require admin rights and look like real folders to the agents.
#
# Two sources are linked:
#   1. Every skill folder in this repo (any directory containing SKILL.md).
#   2. A curated subset of third-party skills, cloned as sibling repos.

$repo = $PSScriptRoot
$targets = @(
    (Join-Path $HOME '.claude\skills'),
    (Join-Path $HOME '.codex\skills')
)

function New-SkillLink {
    param([string]$Target, [string]$Name, [string]$Source)

    $link = Join-Path $Target $Name
    if (Test-Path $link) {
        $item = Get-Item $link -Force
        if ($item.LinkType) {
            Remove-Item $link -Force -Confirm:$false
        } else {
            # A real folder with the same name: keep it aside instead of deleting.
            Move-Item $link "$link.bak" -Force
            Write-Host "Existing folder moved to $link.bak"
        }
    }
    New-Item -ItemType Junction -Path $link -Target $Source | Out-Null
    Write-Host "Linked $link -> $Source"
}

# --- 1. Skills owned by this repo -------------------------------------------
# Filter on SKILL.md so non-skill folders (reports, scripts, ...) are ignored.
$own = Get-ChildItem -Path $repo -Directory |
    Where-Object { $_.Name -notmatch '^\.' -and (Test-Path (Join-Path $_.FullName 'SKILL.md')) }

# --- 2. Curated third-party skills ------------------------------------------
# Cloned as a sibling of this repo:
#   git clone https://github.com/mattpocock/skills ../mattpocock-skills
$mattpocock = Join-Path (Split-Path $repo -Parent) 'mattpocock-skills'
$externalPaths = @(
    'skills\productivity\grilling',
    'skills\productivity\grill-me',
    'skills\productivity\handoff',
    'skills\engineering\diagnosing-bugs',
    'skills\engineering\prototype'
) | ForEach-Object { Join-Path $mattpocock $_ }

$external = @()
if (Test-Path $mattpocock) {
    foreach ($p in $externalPaths) {
        if (Test-Path (Join-Path $p 'SKILL.md')) {
            $external += Get-Item $p
        } else {
            Write-Warning "Skipped missing skill: $p"
        }
    }
} else {
    Write-Warning "mattpocock-skills not found at $mattpocock - skipping third-party skills."
}

# --- Link everything ---------------------------------------------------------
foreach ($target in $targets) {
    New-Item -ItemType Directory -Force $target | Out-Null
    foreach ($skill in ($own + $external)) {
        New-SkillLink -Target $target -Name $skill.Name -Source $skill.FullName
    }
}
