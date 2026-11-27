<#
.SYNOPSIS
  SPFx dev stack: start, stop, restart and inspect the local dev server and its ports.

.EXAMPLE
  pwsh -File scripts/stack.ps1 status    # server, ports, toolchain, Node check, workbench URL
  pwsh -File scripts/stack.ps1 up        # start in the background, wait for the port, print the URL
  pwsh -File scripts/stack.ps1 down      # list what it stops, stop only our processes, check ports are free
  pwsh -File scripts/stack.ps1 restart
  pwsh -File scripts/stack.ps1 ports     # who listens on the SPFx ports, and whether it is ours
  pwsh -File scripts/stack.ps1 logs      # last 50 lines
  pwsh -File scripts/stack.ps1 url
  pwsh -File scripts/stack.ps1 trust     # trust the dev certificate (once per machine; may show a Windows dialog)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('up', 'down', 'restart', 'status', 'ports', 'logs', 'url', 'trust', 'start', 'stop')]
    [string]$Action = 'status',
    [int]$TimeoutSec = 240,
    [int]$Lines = 50
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/harness.ps1')

if ($Action -eq 'start') { $Action = 'up' }
if ($Action -eq 'stop') { $Action = 'down' }

$dir = Initialize-StateDir 'dev'
$pidFile = Join-Path $dir 'dev.pid'
$logOut = Join-Path $dir 'server.log'
$logErr = Join-Path $dir 'server.err.log'
$port = Get-ServePort
$toolchain = Get-Toolchain
$livePort = 35729
$repoKey = ($script:RepoRoot -replace '\\', '/').ToLower()

# ---------- processes and ports ---------------------------------------------------

function Get-ProcTable {
    if ($script:IsWin) {
        return @(Get-CimInstance Win32_Process | ForEach-Object {
            [pscustomobject]@{ Id = [int]$_.ProcessId; ParentId = [int]$_.ParentProcessId; Name = [string]$_.Name; Cmd = [string]$_.CommandLine }
        })
    }
    return @(& ps -A -o pid= -o ppid= -o command= | ForEach-Object {
        if ($_ -match '^\s*(\d+)\s+(\d+)\s+(.*)$') {
            $cmd = $Matches[3]
            [pscustomobject]@{ Id = [int]$Matches[1]; ParentId = [int]$Matches[2]; Name = (Split-Path -Leaf ($cmd -split '\s+')[0]); Cmd = $cmd }
        }
    })
}

function Get-RootPid {
    if (-not (Test-Path $pidFile)) { return $null }
    $id = [int](Get-Content $pidFile -Raw)
    if (Get-Process -Id $id -ErrorAction SilentlyContinue) { return $id }
    return $null
}

# Root process plus all descendants, children first (so they are stopped before the parent).
function Get-Tree([int]$rootId, $table) {
    $result = New-Object System.Collections.Generic.List[object]
    $queue = New-Object System.Collections.Generic.Queue[int]
    $queue.Enqueue($rootId)
    while ($queue.Count -gt 0) {
        $id = $queue.Dequeue()
        $p = $table | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        if ($p) { $result.Add($p) }
        foreach ($c in ($table | Where-Object { $_.ParentId -eq $id -and $_.Id -ne $id })) { $queue.Enqueue($c.Id) }
    }
    $arr = $result.ToArray(); [array]::Reverse($arr); return $arr
}

function Get-PortOwner([int]$p) {
    if ($script:IsWin) {
        $c = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return [int]$c.OwningProcess }
        $line = & netstat -ano -p tcp | Select-String ":$p\s+\S+\s+LISTENING\s+(\d+)" | Select-Object -First 1
        if ($line) { return [int]$line.Matches[0].Groups[1].Value }
        return $null
    }
    $id = & lsof -nP "-iTCP:$p" -sTCP:LISTEN -t 2>$null | Select-Object -First 1
    if ($id) { return [int]$id }
    return $null
}

# 'ours' = in the tree of the server we started, or a process whose command line points into this repo
# (a server left over after the PID file was lost). Anything else is never stopped.
function Get-Ownership($proc, $treeIds) {
    if (-not $proc) { return 'unknown' }
    if ($treeIds -contains $proc.Id) { return 'ours' }
    if ($proc.Cmd -and (($proc.Cmd -replace '\\', '/').ToLower().Contains($repoKey))) { return 'ours (orphan)' }
    return 'other'
}

function Get-PortReport {
    $table = Get-ProcTable
    $root = Get-RootPid
    $treeIds = if ($root) { @(Get-Tree $root $table | ForEach-Object Id) } else { @() }
    $rows = @()
    foreach ($entry in @(@{ p = $port; what = 'serve' }, @{ p = $livePort; what = 'live reload' })) {
        $ownerId = Get-PortOwner $entry.p
        $proc = if ($ownerId) { $table | Where-Object { $_.Id -eq $ownerId } | Select-Object -First 1 } else { $null }
        $rows += [pscustomobject]@{
            Port = $entry.p; Use = $entry.what
            State = $(if ($ownerId) { 'LISTEN' } else { 'free' })
            Pid = $ownerId; Process = $(if ($proc) { $proc.Name } else { '' })
            Owner = $(if ($ownerId) { Get-Ownership $proc $treeIds } else { '' })
        }
    }
    return @{ rows = $rows; root = $root; table = $table; treeIds = $treeIds }
}

function Show-Ports($report) {
    $report.rows | Format-Table Port, Use, State, Pid, Process, Owner -AutoSize | Out-String | Write-Host
}

# ---------- workbench URL ------------------------------------------------------

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

# ---------- actions -------------------------------------------------------------

function Invoke-Up {
    $report = Get-PortReport
    if ($report.root) {
        Write-Host "Already running (PID $($report.root)) on port $port."
        Write-Host "Workbench: $(Get-WorkbenchUrl)"
        return 0
    }
    $busy = @($report.rows | Where-Object { $_.State -eq 'LISTEN' -and $_.Port -eq $port })
    if ($busy) {
        Show-Ports $report
        if ($busy[0].Owner -like 'ours*') { Write-Host "An old dev server of this repo still holds port $port. Run: scripts/stack.ps1 down" }
        else { Write-Host "Port $port is used by $($busy[0].Process) (PID $($busy[0].Pid)), not by this repo. Stop it yourself or change 'port' in .github/spfx-harness.json and config/serve.json." }
        return 1
    }
    $nodeIssue = Test-NodeVersion
    if ($nodeIssue) { Write-Host "ERROR: $nodeIssue"; return 1 }
    if (-not (Test-Path (Join-Path $script:RepoRoot 'node_modules'))) { Write-Host 'ERROR: node_modules missing. Run: npm ci'; return 1 }

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
        if ($proc.HasExited) {
            Write-Host "ERROR: dev server exited (code $($proc.ExitCode)). Last log lines:"
            Get-Content $logOut, $logErr -Tail 30 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  | $_" }
            Remove-Item $pidFile -Force
            return 1
        }
        if (Test-Port $port) { break }
        Start-Sleep -Seconds 2
    }
    if (-not (Test-Port $port)) { Write-Host "ERROR: port $port not open after $TimeoutSec s. See: scripts/stack.ps1 logs"; return 1 }
    Start-Sleep -Seconds 3
    Write-Host "Running (PID $($proc.Id)). Logs: .spfx-dev/dev/server.log"
    Write-Host "Workbench: $(Get-WorkbenchUrl)"
    return 0
}

function Invoke-Down {
    $report = Get-PortReport
    $targets = @()
    if ($report.root) { $targets += Get-Tree $report.root $report.table }
    foreach ($row in $report.rows) {
        if ($row.Owner -eq 'ours (orphan)' -and -not ($targets | Where-Object { $_.Id -eq $row.Pid })) {
            $targets += Get-Tree $row.Pid $report.table
        }
    }
    if (-not $targets) {
        Write-Host 'Nothing of this repo is running.'
        if (Test-Path $pidFile) { Remove-Item $pidFile -Force }
        $other = @($report.rows | Where-Object { $_.Owner -eq 'other' })
        if ($other) { Show-Ports $report; Write-Host 'Ports above are held by other programs; not touched.' }
        return 0
    }
    Write-Host 'Stopping:'
    $targets | ForEach-Object { Write-Host ('  PID {0,-7} {1,-14} {2}' -f $_.Id, $_.Name, ($_.Cmd -replace '\s+', ' ').Substring(0, [Math]::Min(90, ($_.Cmd -replace '\s+', ' ').Length))) }
    foreach ($t in $targets) {
        if ($script:IsWin) { & taskkill /PID $t.Id /T /F 2>$null | Out-Null }
        else { Stop-Process -Id $t.Id -Force -ErrorAction SilentlyContinue }
    }
    if (Test-Path $pidFile) { Remove-Item $pidFile -Force }

    $deadline = (Get-Date).AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 500
        $stillOurs = @((Get-PortReport).rows | Where-Object { $_.Owner -like 'ours*' })
    } while ($stillOurs -and (Get-Date) -lt $deadline)
    $final = Get-PortReport
    Show-Ports $final
    $leftover = @($final.rows | Where-Object { $_.Owner -like 'ours*' })
    if ($leftover) { Write-Host "ERROR: port(s) $($leftover.Port -join ', ') still held by this repo's processes."; return 1 }
    Write-Host "Stopped $($targets.Count) process(es). Ports of this repo are free."
    return 0
}

function Invoke-Status {
    $report = Get-PortReport
    if ($report.root) { Write-Host "Dev server: running (PID $($report.root))" }
    elseif ($report.rows | Where-Object { $_.Owner -eq 'ours (orphan)' }) { Write-Host 'Dev server: orphan of this repo running without PID file (run: scripts/stack.ps1 down)' }
    else { Write-Host 'Dev server: not running' }
    Write-Host "SPFx $(Get-SpfxVersion), toolchain $toolchain, Node $(try { & node -v } catch { 'missing' })"
    $nodeIssue = Test-NodeVersion; if ($nodeIssue) { Write-Host "WARNING: $nodeIssue" }
    Show-Ports $report
    if ($report.root) { Write-Host "Workbench: $(Get-WorkbenchUrl)" }
    return 0
}

$code = 0
switch ($Action) {
    'up' { $code = Invoke-Up }
    'down' { $code = Invoke-Down }
    'restart' { $code = Invoke-Down; if ($code -eq 0) { $code = Invoke-Up } }
    'status' { $code = Invoke-Status }
    'ports' { Show-Ports (Get-PortReport) }
    'logs' { Get-Content $logOut, $logErr -Tail $Lines -ErrorAction SilentlyContinue }
    'url' { Write-Host (Get-WorkbenchUrl) }
    'trust' {
        Write-Host "Trusting the SPFx dev certificate ($toolchain). Windows may ask you to confirm."
        Push-Location $script:RepoRoot
        try { if ($toolchain -eq 'gulp') { & (Get-Npx) gulp trust-dev-cert } else { & (Get-Npx) heft trust-dev-cert } } finally { Pop-Location }
    }
}
exit $code
