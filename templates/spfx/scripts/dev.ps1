<#
.SYNOPSIS
  Start, stop and inspect the SPFx dev server in the background.

.EXAMPLE
  pwsh -File scripts/dev.ps1 start    # start, wait for the port, print the workbench URL
  pwsh -File scripts/dev.ps1 status
  pwsh -File scripts/dev.ps1 logs     # last 50 lines
  pwsh -File scripts/dev.ps1 stop
  pwsh -File scripts/dev.ps1 trust    # trust the dev certificate (once per machine; may show a Windows dialog)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('start', 'stop', 'status', 'logs', 'url', 'trust')][string]$Action = 'status',
    [int]$TimeoutSec = 240,
    [int]$Lines = 50
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/harness.ps1')

$dir = Initialize-StateDir 'dev'
$pidFile = Join-Path $dir 'dev.pid'
$logOut = Join-Path $dir 'server.log'
$logErr = Join-Path $dir 'server.err.log'
$port = Get-ServePort
$toolchain = Get-Toolchain

function Get-ServerProcess {
    if (-not (Test-Path $pidFile)) { return $null }
    $id = [int](Get-Content $pidFile -Raw)
    return Get-Process -Id $id -ErrorAction SilentlyContinue
}

function Get-ManifestsUrl {
    foreach ($rel in @('temp/manifests.js', 'temp/build/manifests.js')) {
        if (Test-Path (Join-Path $script:RepoRoot $rel)) { return "https://localhost:$port/$rel" }
    }
    return "https://localhost:$port/temp/manifests.js"
}

function Get-WorkbenchUrl {
    $cfg = Get-HarnessConfig
    $site = ([string]$cfg.devSiteUrl).TrimEnd('/')
    if (-not $site -or $site -match '<') { return "(set devSiteUrl in .github/spfx-harness.json) debugManifestsFile=$(Get-ManifestsUrl)" }
    return "$site/_layouts/15/workbench.aspx?debug=true&noredir=true&debugManifestsFile=$([uri]::EscapeDataString((Get-ManifestsUrl)))"
}

switch ($Action) {
    'start' {
        $p = Get-ServerProcess
        if ($p) { Write-Host "Already running (PID $($p.Id)) on port $port."; Write-Host "Workbench: $(Get-WorkbenchUrl)"; exit 0 }
        if (Test-Port $port) { Write-Error "Port $port is in use by another process. Stop it or change 'port' in .github/spfx-harness.json and config/serve.json."; exit 1 }
        $nodeIssue = Test-NodeVersion
        if ($nodeIssue) { Write-Error $nodeIssue; exit 1 }
        if (-not (Test-Path (Join-Path $script:RepoRoot 'node_modules'))) { Write-Error 'node_modules missing. Run: npm ci'; exit 1 }

        $argList = if ($toolchain -eq 'gulp') { @('gulp', 'serve', '--nobrowser') } else { @('heft', 'start', '--clean') }
        Write-Host "Starting $toolchain dev server (SPFx $(Get-SpfxVersion)) on port $port ..."
        $sp = @{
            FilePath = (Get-Npx); ArgumentList = $argList; WorkingDirectory = $script:RepoRoot
            RedirectStandardOutput = $logOut; RedirectStandardError = $logErr; PassThru = $true
        }
        if ($script:IsWin) { $sp.WindowStyle = 'Hidden' }
        $proc = Start-Process @sp
        Set-Content -Path $pidFile -Value $proc.Id
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        while ((Get-Date) -lt $deadline) {
            if ($proc.HasExited) { Write-Error "Dev server exited (code $($proc.ExitCode)). Last log lines:"; Get-Content $logOut, $logErr -Tail 30 -ErrorAction SilentlyContinue; Remove-Item $pidFile -Force; exit 1 }
            if (Test-Port $port) { break }
            Start-Sleep -Seconds 2
        }
        if (-not (Test-Port $port)) { Write-Error "Port $port not open after $TimeoutSec s. See: scripts/dev.ps1 logs"; exit 1 }
        Start-Sleep -Seconds 3
        Write-Host "Running (PID $($proc.Id)). Logs: .spfx-dev/dev/server.log"
        Write-Host "Workbench: $(Get-WorkbenchUrl)"
    }
    'stop' {
        $p = Get-ServerProcess
        if (-not $p) { Write-Host 'Not running.'; if (Test-Path $pidFile) { Remove-Item $pidFile -Force }; exit 0 }
        if ($script:IsWin) { & taskkill /PID $p.Id /T /F | Out-Null } else { & pkill -TERM -P $p.Id 2>$null; Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
        Remove-Item $pidFile -Force
        Write-Host "Stopped (PID $($p.Id))."
    }
    'status' {
        $p = Get-ServerProcess
        if ($p) { Write-Host "Running: PID $($p.Id), port $port, toolchain $toolchain, port open: $(Test-Port $port)" }
        else { Write-Host "Not running. Toolchain $toolchain, port $port, SPFx $(Get-SpfxVersion)." }
        $nodeIssue = Test-NodeVersion; if ($nodeIssue) { Write-Warning $nodeIssue }
    }
    'logs' { Get-Content $logOut, $logErr -Tail $Lines -ErrorAction SilentlyContinue }
    'url' { Write-Host (Get-WorkbenchUrl) }
    'trust' {
        Write-Host "Trusting the SPFx dev certificate ($toolchain). Windows may ask you to confirm."
        Push-Location $script:RepoRoot
        try { if ($toolchain -eq 'gulp') { & (Get-Npx) gulp trust-dev-cert } else { & (Get-Npx) heft trust-dev-cert } } finally { Pop-Location }
    }
}
