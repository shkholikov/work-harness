# Copies the repo's git hooks into .git/hooks (local only; run once per clone).
$ErrorActionPreference = 'Stop'
$root = (& git -C $PSScriptRoot rev-parse --show-toplevel)
$hooksDir = Join-Path $root '.git/hooks'
Get-ChildItem (Join-Path $PSScriptRoot 'git-hooks') -File | ForEach-Object {
    $dest = Join-Path $hooksDir $_.Name
    if ((Test-Path $dest) -and ((Get-FileHash $dest).Hash -ne (Get-FileHash $_.FullName).Hash)) {
        Copy-Item $dest "$dest.before-work-harness" -Force
        Write-Host "existing $($_.Name) saved as $($_.Name).before-work-harness"
    }
    Copy-Item $_.FullName $dest -Force
    if ($env:OS -ne 'Windows_NT') { & chmod +x $dest }
    Write-Host "installed .git/hooks/$($_.Name)"
}
