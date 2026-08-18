# Links every skill in this repo into the agent-specific skill folders.
# Run once after cloning (or after adding a new skill): pwsh ./install.ps1
# Junctions don't require admin rights and look like real folders to the agents.

$repo = $PSScriptRoot
$targets = @(
    (Join-Path $HOME '.claude\skills'),
    (Join-Path $HOME '.codex\skills')
)

$skills = Get-ChildItem -Path $repo -Directory | Where-Object { $_.Name -notmatch '^\.' }

foreach ($target in $targets) {
    New-Item -ItemType Directory -Force $target | Out-Null
    foreach ($skill in $skills) {
        $link = Join-Path $target $skill.Name
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
        New-Item -ItemType Junction -Path $link -Target $skill.FullName | Out-Null
        Write-Host "Linked $link -> $($skill.FullName)"
    }
}
