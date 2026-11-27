<#
.SYNOPSIS
  Removes what install.ps1 installed (files listed in ~/.copilot/work-harness/installed.json)
  and the work-harness block in your PowerShell profile. settings.json is left as is.
  Restore older versions from ~/.copilot-backups/ if needed.
#>
[CmdletBinding()]
param([string]$CopilotHome, [switch]$DryRun)
$ErrorActionPreference = 'Stop'
if (-not $CopilotHome) { $CopilotHome = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $HOME '.copilot' } }
$manifestPath = Join-Path $CopilotHome 'work-harness/installed.json'
if (-not (Test-Path $manifestPath)) { throw "No manifest at $manifestPath; nothing to uninstall." }
$m = Get-Content $manifestPath -Raw | ConvertFrom-Json

foreach ($f in $m.files) {
    if (Test-Path $f) {
        if ($DryRun) { Write-Host "[dry-run] remove $f" } else { Remove-Item $f -Force; Write-Host "removed $f" }
    }
}
# Remove now-empty skill folders
Get-ChildItem (Join-Path $CopilotHome 'skills') -Directory -ErrorAction SilentlyContinue |
    Where-Object { -not (Get-ChildItem $_.FullName -Recurse -File) } |
    ForEach-Object { if (-not $DryRun) { Remove-Item $_.FullName -Recurse -Force } }

if ($m.profile -and (Test-Path $m.profile)) {
    $text = Get-Content $m.profile -Raw
    $pattern = [regex]::Escape('# >>> work-harness >>>') + '[\s\S]*?' + [regex]::Escape('# <<< work-harness <<<') + '\r?\n?'
    if ($text -match $pattern) {
        if ($DryRun) { Write-Host "[dry-run] remove wrapper from $($m.profile)" }
        else { Set-Content -Path $m.profile -Value ([regex]::Replace($text, $pattern, '')) -Encoding utf8; Write-Host "removed wrapper from $($m.profile)" }
    }
}
if (-not $DryRun) { Remove-Item $manifestPath -Force }
Write-Host 'Done. Open a new PowerShell window.'
