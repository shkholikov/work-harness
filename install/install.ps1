<#
.SYNOPSIS
  Installs the general work-harness layer into the Copilot user folder (~/.copilot).

.DESCRIPTION
  Copies personal instructions, agents, skills and the guard hook; merges recommended settings;
  adds a `copilot` wrapper with the deny list to your PowerShell profile. Backs up every file it
  replaces to ~/.copilot-backups/. Safe to run again after `git pull`.

.EXAMPLE
  pwsh -File install/install.ps1 -DryRun
  pwsh -File install/install.ps1
#>
[CmdletBinding()]
param(
    [string]$CopilotHome,
    [string]$ProfilePath,
    [switch]$DryRun,
    [switch]$Force,        # overwrite settings keys that already exist
    [switch]$SkipProfile,  # do not touch the PowerShell profile
    [switch]$SkipHook      # do not register the guard hook
)
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$User = Join-Path $Root 'user'
if (-not $CopilotHome) { $CopilotHome = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $HOME '.copilot' } }
if (-not $ProfilePath) { $ProfilePath = $PROFILE.CurrentUserAllHosts }
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path (Split-Path -Parent $CopilotHome) ".copilot-backups/work-harness-$Stamp"
$Installed = New-Object System.Collections.Generic.List[string]

function Say([string]$msg) { Write-Host $msg }
function Act([string]$msg) { if ($DryRun) { Write-Host "[dry-run] $msg" } else { Write-Host $msg } }

function Backup-File([string]$path) {
    if (-not (Test-Path $path)) { return }
    $rel = $path.Substring($CopilotHome.Length).TrimStart('\', '/')
    $dest = Join-Path $BackupDir $rel
    if ($DryRun) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    Copy-Item -Path $path -Destination $dest -Recurse -Force
}

function Install-File([string]$src, [string]$dest) {
    if ((Test-Path $dest) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dest).Hash)) { $Installed.Add($dest); return }
    Backup-File $dest
    Act "  copy $($src.Substring($Root.Length + 1)) -> $dest"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -Path $src -Destination $dest -Force
    }
    $Installed.Add($dest)
}

Say "work-harness install -> $CopilotHome"
if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) { Write-Warning 'copilot CLI not found on PATH. Install it first; continuing with files only.' }

# 1. Instructions, agents, skills
Say '1. Instructions, agents, skills'
Install-File (Join-Path $User 'copilot-instructions.md') (Join-Path $CopilotHome 'copilot-instructions.md')
Get-ChildItem (Join-Path $User 'agents') -Filter '*.agent.md' | ForEach-Object {
    Install-File $_.FullName (Join-Path $CopilotHome "agents/$($_.Name)")
}
Get-ChildItem (Join-Path $User 'skills') -Directory | ForEach-Object {
    $skill = $_
    Get-ChildItem $skill.FullName -File -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($skill.FullName.Length).TrimStart('\', '/')
        Install-File $_.FullName (Join-Path $CopilotHome "skills/$($skill.Name)/$rel")
    }
}
Install-File (Join-Path $User 'deny-tools.txt') (Join-Path $CopilotHome 'work-harness/deny-tools.txt')

# 2. Guard hook (self-tested before it is registered)
Say '2. Guard hook'
$guardDest = Join-Path $CopilotHome 'hooks/work-harness-guard.ps1'
$hookJson = Join-Path $CopilotHome 'hooks/work-harness-guard.json'
Install-File (Join-Path $User 'hooks/guard.ps1') $guardDest
if ($SkipHook) {
    Say '  skipped (-SkipHook)'
} else {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    $testGuard = if ($DryRun) { Join-Path $User 'hooks/guard.ps1' } else { $guardDest }
    $payload = @{ sessionId = 'install-test'; timestamp = 0; cwd = [IO.Path]::GetTempPath(); toolName = 'powershell'; toolArgs = (@{ command = 'git push origin feature/x' } | ConvertTo-Json -Compress) } | ConvertTo-Json -Compress
    $ok = $false
    if ($pwshCmd) {
        try {
            $out = $payload | & $pwshCmd.Source -NoProfile -ExecutionPolicy Bypass -File $testGuard
            $ok = ($LASTEXITCODE -eq 0) -and ($out -match '"permissionDecision":"ask"')
        } catch { $ok = $false }
    }
    if (-not $ok) {
        Write-Warning '  Guard self-test failed (pwsh missing or script blocked by execution policy). Hook NOT registered, because a failing preToolUse hook blocks every tool call.'
        Write-Warning "  Test manually: '<payload>' | pwsh -NoProfile -ExecutionPolicy Bypass -File `"$guardDest`""
    } else {
        Say '  self-test passed (git push -> ask)'
        $guardPath = $guardDest -replace '\\', '/'
        $hook = [ordered]@{
            version = 1
            hooks   = [ordered]@{
                preToolUse = @(
                    [ordered]@{ type = 'command'; powershell = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$guardPath`""; bash = "pwsh -NoProfile -File '$guardPath'"; timeoutSec = 15 }
                )
            }
        }
        $json = $hook | ConvertTo-Json -Depth 10
        Backup-File $hookJson
        Act "  write $hookJson"
        if (-not $DryRun) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $hookJson) | Out-Null; Set-Content -Path $hookJson -Value $json -Encoding utf8 }
        $Installed.Add($hookJson)
    }
}

# 3. Settings (merge, never drop your keys)
Say '3. Settings'
$settingsPath = Join-Path $CopilotHome 'settings.json'
$wanted = Get-Content (Join-Path $User 'settings.json') -Raw | ConvertFrom-Json
if (-not (Test-Path $settingsPath)) {
    Act "  write $settingsPath"
    if (-not $DryRun) { Copy-Item (Join-Path $User 'settings.json') $settingsPath }
} else {
    $text = Get-Content $settingsPath -Raw
    $current = $null
    try { $current = $text | ConvertFrom-Json } catch { }
    if (-not $current -or $text -match '(^|\s)//|/\*') {
        Write-Warning "  $settingsPath has comments or is not plain JSON; not rewriting it. Add these keys yourself if missing:"
        Write-Host (Get-Content (Join-Path $User 'settings.json') -Raw)
    } else {
        $changed = @()
        foreach ($p in $wanted.PSObject.Properties) {
            $has = $current.PSObject.Properties.Name -contains $p.Name
            if (-not $has) { $current | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value; $changed += $p.Name }
            elseif ($Force) { $current.($p.Name) = $p.Value; $changed += $p.Name }
        }
        if ($changed.Count -gt 0) {
            Backup-File $settingsPath
            Act "  set $($changed -join ', ') in $settingsPath"
            if (-not $DryRun) { Set-Content -Path $settingsPath -Value ($current | ConvertTo-Json -Depth 10) -Encoding utf8 }
        } else { Say '  already up to date (use -Force to overwrite existing keys)' }
    }
}

# 4. PowerShell profile wrapper
Say '4. PowerShell profile wrapper'
$begin = '# >>> work-harness >>>'
$end = '# <<< work-harness <<<'
$denyPath = (Join-Path $CopilotHome 'work-harness/deny-tools.txt') -replace "'", "''"
$block = @"
$begin
# Adds the work-harness deny list to interactive and -p runs. Bypass once: `$env:WORK_HARNESS_NO_WRAPPER='1'
function copilot {
    `$real = Get-Command copilot -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not `$real) { Write-Error 'copilot CLI not found on PATH'; return }
    `$sub = (`$args.Count -gt 0) -and -not ([string]`$args[0]).StartsWith('-')
    if (`$env:WORK_HARNESS_NO_WRAPPER -eq '1' -or `$sub) { & `$real.Source @args; return }
    `$deny = @()
    if (Test-Path '$denyPath') {
        `$deny = Get-Content '$denyPath' | Where-Object { `$_.Trim() -and -not `$_.Trim().StartsWith('#') } | ForEach-Object { "--deny-tool=`$(`$_.Trim())" }
    }
    & `$real.Source @deny @args
}
$end
"@
if ($SkipProfile) {
    Say '  skipped (-SkipProfile)'
} else {
    $existing = if (Test-Path $ProfilePath) { Get-Content $ProfilePath -Raw } else { '' }
    if ($null -eq $existing) { $existing = '' }
    $pattern = [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end) + '\r?\n?'
    $new = if ($existing -match $pattern) { [regex]::Replace($existing, $pattern, ($block + [Environment]::NewLine).Replace('$', '$$')) } else { $existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block + [Environment]::NewLine }
    if ($new -ne $existing) {
        if ((Test-Path $ProfilePath) -and -not $DryRun) {
            New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
            Copy-Item $ProfilePath (Join-Path $BackupDir 'profile.ps1')
        }
        Act "  update $ProfilePath"
        if (-not $DryRun) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ProfilePath) | Out-Null; Set-Content -Path $ProfilePath -Value $new -Encoding utf8 }
    } else { Say '  already up to date' }
}

# 5. Manifest for uninstall
$version = try { (& git -C $Root rev-parse --short HEAD 2>$null) } catch { 'unknown' }
$manifest = [ordered]@{ version = $version; installedAt = (Get-Date -Format s); copilotHome = $CopilotHome; profile = $ProfilePath; files = $Installed }
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path (Join-Path $CopilotHome 'work-harness') | Out-Null
    Set-Content -Path (Join-Path $CopilotHome 'work-harness/installed.json') -Value ($manifest | ConvertTo-Json -Depth 5) -Encoding utf8
}

Say ''
Say "Done ($version). Backups: $(if (Test-Path $BackupDir) { $BackupDir } else { 'none needed' })"
Say 'Next:'
Say '  1. Open a NEW PowerShell window (loads the wrapper), then run: copilot'
Say '  2. In copilot: /env  (instructions, agents, skills, hooks loaded?)  and  /model'
Say '  3. Run the guardrail tests in docs/work-laptop-setup.md'
Say '  4. VS Code: paste user/vscode-settings.jsonc keys into your user settings'
