# Shared helpers for scripts/dev.ps1 and scripts/verify.ps1 (dot-source this file).
# Compatible with Windows PowerShell 5.1 and PowerShell 7.

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script:StateDir = Join-Path $script:RepoRoot '.spfx-dev'
$script:IsWin = ($env:OS -eq 'Windows_NT')

function Get-HarnessConfig {
    $path = Join-Path $script:RepoRoot '.github/spfx-harness.json'
    if (-not (Test-Path $path)) { throw "Missing $path (copy it from the work-harness SPFx template)." }
    Get-Content $path -Raw | ConvertFrom-Json
}

function Get-PackageJson { Get-Content (Join-Path $script:RepoRoot 'package.json') -Raw | ConvertFrom-Json }

function Get-SpfxVersion {
    $pkg = Get-PackageJson
    foreach ($section in @($pkg.dependencies, $pkg.devDependencies)) {
        if ($section -and $section.'@microsoft/sp-core-library') { return ([string]$section.'@microsoft/sp-core-library').TrimStart('^', '~') }
    }
    return 'unknown'
}

# gulp (SPFx <= 1.21) or heft (SPFx >= 1.22)
function Get-Toolchain {
    $pkg = Get-PackageJson
    $dev = $pkg.devDependencies
    if ($dev -and ($dev.PSObject.Properties.Name -contains '@rushstack/heft')) { return 'heft' }
    if (Test-Path (Join-Path $script:RepoRoot 'gulpfile.js')) { return 'gulp' }
    return 'heft'
}

function Get-ExpectedNodeMajor {
    $v = Get-SpfxVersion
    if ($v -match '^1\.(\d+)') { if ([int]$Matches[1] -le 20) { return 18 } else { return 22 } }
    return $null
}

function Test-NodeVersion {
    $expected = Get-ExpectedNodeMajor
    $actual = try { (& node -v).TrimStart('v') } catch { '' }
    if (-not $actual) { return "Node.js not found on PATH (SPFx $(Get-SpfxVersion) needs Node $expected)." }
    $major = [int]($actual.Split('.')[0])
    if ($expected -and ($major -ne $expected) -and -not ($expected -eq 22 -and $major -ge 22)) {
        return "Node $actual active, SPFx $(Get-SpfxVersion) needs Node $expected. Switch with fnm/nvm-windows."
    }
    return ''
}

function Get-Npx { if ($script:IsWin) { 'npx.cmd' } else { 'npx' } }
function Get-Npm { if ($script:IsWin) { 'npm.cmd' } else { 'npm' } }

function Test-Port([int]$port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync('127.0.0.1', $port)
        return ($task.Wait(400) -and $client.Connected)
    } catch { return $false } finally { $client.Dispose() }
}

function Get-ServePort {
    $cfg = Get-HarnessConfig
    if ($cfg.port) { return [int]$cfg.port }
    $serve = Join-Path $script:RepoRoot 'config/serve.json'
    if (Test-Path $serve) { $s = Get-Content $serve -Raw | ConvertFrom-Json; if ($s.port) { return [int]$s.port } }
    return 4321
}

# Glob -> regex: ** = any depth, * = within one folder.
function ConvertTo-GlobRegex([string]$glob) {
    $g = $glob -replace '\\', '/'
    $rx = [regex]::Escape($g)
    $rx = $rx -replace '\\\*\\\*/', '(.*/)?' -replace '\\\*\\\*', '.*' -replace '\\\*', '[^/]*' -replace '\\\?', '.'
    return "^$rx$"
}

function Test-GlobMatch([string]$path, $globs) {
    $p = $path -replace '\\', '/'
    foreach ($g in @($globs)) { if ($p -match (ConvertTo-GlobRegex $g)) { return $true } }
    return $false
}

function Get-ChangedFiles([string]$base) {
    Push-Location $script:RepoRoot
    try {
        $files = @()
        $mergeBase = (& git merge-base HEAD $base 2>$null)
        if ($mergeBase) { $files += (& git diff --name-only "$mergeBase" HEAD) }
        $files += (& git diff --name-only HEAD)
        $files += (& git ls-files --others --exclude-standard)
        return @($files | Where-Object { $_ -and ($_ -notmatch '^\.spfx-dev/') } | Sort-Object -Unique)
    } finally { Pop-Location }
}

function Get-RiskTier([string[]]$files) {
    $cfg = Get-HarnessConfig
    $high = @($files | Where-Object { Test-GlobMatch $_ $cfg.riskTiers.high })
    if ($high.Count -gt 0) { return @{ tier = 'High'; highFiles = $high } }
    $low = @($files | Where-Object { Test-GlobMatch $_ $cfg.riskTiers.low })
    if ($files.Count -gt 0 -and $low.Count -eq $files.Count) { return @{ tier = 'Low'; highFiles = @() } }
    if ($files.Count -eq 0) { return @{ tier = 'None'; highFiles = @() } }
    return @{ tier = 'Medium'; highFiles = @() }
}

# Fingerprint of the working tree (HEAD + tracked changes + untracked files), used to prove
# that what gets committed is exactly what verify checked.
function Get-TreeFingerprint {
    Push-Location $script:RepoRoot
    try {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine((& git rev-parse HEAD 2>$null))
        [void]$sb.AppendLine(((& git diff HEAD --binary 2>$null) -join "`n"))
        foreach ($f in (& git ls-files --others --exclude-standard | Where-Object { $_ -notmatch '^\.spfx-dev/' } | Sort-Object)) {
            [void]$sb.AppendLine($f)
            if (Test-Path $f -PathType Leaf) { [void]$sb.AppendLine((Get-FileHash $f -Algorithm SHA256).Hash) }
        }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLower() } finally { $sha.Dispose() }
    } finally { Pop-Location }
}

function Initialize-StateDir([string]$sub) {
    $dir = if ($sub) { Join-Path $script:StateDir $sub } else { $script:StateDir }
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    return $dir
}
