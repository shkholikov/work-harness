<#
.SYNOPSIS
  Deterministic checks for an SPFx change: Node version, lint, typecheck, tests, ship build,
  optional Playwright smoke test, and the risk tier of the changed files.
  Full output goes to .spfx-dev/verify/*.log; the console shows a short summary (saves tokens).

.EXAMPLE
  pwsh -File scripts/verify.ps1              # all checks except e2e
  pwsh -File scripts/verify.ps1 -E2E         # also the Playwright smoke test (dev server must run)
  pwsh -File scripts/verify.ps1 -Only tier   # just the risk tier
  pwsh -File scripts/verify.ps1 -CheckFresh  # exit 0 if the code is exactly what the last PASS checked
#>
[CmdletBinding()]
param(
    [string]$Base = 'main',
    [string[]]$Only,
    [switch]$E2E,
    [switch]$CheckFresh
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/harness.ps1')
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

$dir = Initialize-StateDir 'verify'
$lastPath = Join-Path $dir 'last.json'

if ($CheckFresh) {
    if (-not (Test-Path $lastPath)) { Write-Host 'STALE: no verify run recorded. Run the verify skill.'; exit 1 }
    $last = Get-Content $lastPath -Raw | ConvertFrom-Json
    if ($last.result -ne 'PASS') { Write-Host "STALE: last verify result was $($last.result)."; exit 1 }
    if ($last.fingerprint -ne (Get-TreeFingerprint)) { Write-Host 'STALE: code changed since the last verify. Run the verify skill again.'; exit 1 }
    Write-Host "FRESH: verified at $($last.at), tier $($last.tier)."
    exit 0
}

$pkg = Get-PackageJson
$scripts = $pkg.scripts
$toolchain = Get-Toolchain
$npx = Get-Npx
$npm = Get-Npm
$results = New-Object System.Collections.Generic.List[object]

function Want([string]$step) { return (-not $Only) -or ($Only -contains $step) }
function Has-Script([string]$name) { return $scripts -and ($scripts.PSObject.Properties.Name -contains $name) -and ($scripts.$name -notmatch 'no test specified') }

function Invoke-Native([string]$step, [string]$file, [string[]]$argList) {
    $log = Join-Path $dir "$step.log"
    $err = Join-Path $dir "$step.err.log"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $file -ArgumentList $argList -WorkingDirectory $script:RepoRoot -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError $err
    $sw.Stop()
    Add-Content -Path $log -Value (Get-Content $err -ErrorAction SilentlyContinue)
    Remove-Item $err -ErrorAction SilentlyContinue
    return @{ code = $p.ExitCode; secs = [int]$sw.Elapsed.TotalSeconds; log = $log }
}

function Add-Result([string]$step, [string]$status, [string]$note) {
    $results.Add([pscustomobject]@{ step = $step; status = $status; note = $note })
    $color = switch ($status) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'DarkGray' } }
    Write-Host ('  {0,-10} {1,-5} {2}' -f $step, $status, $note) -ForegroundColor $color
}

function Run-Step([string]$step, [string]$file, [string[]]$argList) {
    $r = Invoke-Native $step $file $argList
    if ($r.code -eq 0) { Add-Result $step 'PASS' "$($r.secs)s" ; return $true }
    Add-Result $step 'FAIL' "$($r.secs)s, exit $($r.code), log .spfx-dev/verify/$step.log"
    Write-Host "  --- last 40 lines of $step ---"
    Get-Content $r.log -Tail 40 | ForEach-Object { Write-Host "  | $_" }
    return $false
}

Write-Host "verify: SPFx $(Get-SpfxVersion), toolchain $toolchain, base $Base"
$ok = $true

if (Want 'node') {
    $issue = Test-NodeVersion
    if ($issue) { Add-Result 'node' 'FAIL' $issue; $ok = $false } else { Add-Result 'node' 'PASS' (& node -v) }
}
if ($ok -and (Want 'lint')) {
    if (Has-Script 'lint') { $ok = (Run-Step 'lint' $npm @('run', 'lint')) -and $ok }
    else { Add-Result 'lint' 'SKIP' 'no lint script (eslint runs inside the build)' }
}
if ($ok -and (Want 'typecheck')) {
    $ok = (Run-Step 'typecheck' $npx @('tsc', '--noEmit', '-p', 'tsconfig.json')) -and $ok
}
if ($ok -and (Want 'test')) {
    if ($toolchain -eq 'heft' -and -not (Has-Script 'test')) { Add-Result 'test' 'SKIP' 'heft runs tests inside the build' }
    elseif (Has-Script 'test') { $ok = (Run-Step 'test' $npm @('test')) -and $ok }
    else { Add-Result 'test' 'SKIP' 'no test script' }
}
if ($ok -and (Want 'build')) {
    $started = Get-Date
    if ($toolchain -eq 'gulp') {
        $ok = (Run-Step 'bundle' $npx @('gulp', 'bundle', '--ship')) -and $ok
        if ($ok) { $ok = (Run-Step 'package' $npx @('gulp', 'package-solution', '--ship')) -and $ok }
    } elseif (Has-Script 'build') {
        $ok = (Run-Step 'build' $npm @('run', 'build')) -and $ok
    } else {
        $ok = (Run-Step 'build' $npx @('heft', 'test', '--clean', '--production')) -and $ok
        if ($ok) { $ok = (Run-Step 'package' $npx @('heft', 'package-solution', '--production')) -and $ok }
    }
    if ($ok) {
        $sppkg = Get-ChildItem (Join-Path $script:RepoRoot 'sharepoint/solution') -Filter '*.sppkg' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $started }
        if ($sppkg) { Add-Result 'sppkg' 'PASS' (($sppkg | ForEach-Object Name) -join ', ') } else { Add-Result 'sppkg' 'FAIL' 'no new .sppkg in sharepoint/solution'; $ok = $false }
    }
}
if ($ok -and ($E2E -or ($Only -contains 'e2e'))) {
    $port = Get-ServePort
    if (-not (Test-Port $port)) { Add-Result 'e2e' 'FAIL' "dev server not running on $port; run: scripts/stack.ps1 up"; $ok = $false }
    else { $ok = (Run-Step 'e2e' $npx @('playwright', 'test', '--reporter=line')) -and $ok }
} elseif (-not $Only) { Add-Result 'e2e' 'SKIP' 'use -E2E with the dev server running' }

$changed = Get-ChangedFiles $Base
$risk = Get-RiskTier $changed
$result = if ($ok) { 'PASS' } else { 'FAIL' }
$fingerprint = if ($ok -and -not $Only) { Get-TreeFingerprint } else { $null }

$summary = [ordered]@{
    result = $(if ($Only) { "$result (partial: $($Only -join ','))" } else { $result })
    at = (Get-Date -Format s); base = $Base; tier = $risk.tier; highFiles = $risk.highFiles
    changedFiles = $changed.Count; steps = $results; fingerprint = $fingerprint
}
Set-Content -Path $lastPath -Value ($summary | ConvertTo-Json -Depth 5) -Encoding utf8

Write-Host ''
Write-Host "VERIFY RESULT: $($summary.result)"
Write-Host "TIER: $($risk.tier) ($($changed.Count) changed files vs $Base)"
if ($risk.highFiles.Count -gt 0) { Write-Host "HIGH FILES: $($risk.highFiles -join ', ')" }
switch ($risk.tier) {
    'High' { Write-Host 'NEXT: run agents reviewer-high and deep-reviewer; you read every High file diff yourself.' }
    'Medium' { Write-Host 'NEXT: run agent reviewer.' }
    'Low' { Write-Host 'NEXT: no review agent needed; ship when checks pass.' }
}
if (-not $ok) { exit 1 }
