# work-harness guard: Copilot preToolUse hook (user level, all repos).
# Reads the hook payload from stdin and prints at most one decision object:
#   {"permissionDecision":"deny"|"ask", "permissionDecisionReason": "..."}
# No output = normal permission flow. Must stay fast: a timeout lets the call through.
# Compatible with Windows PowerShell 5.1 and PowerShell 7.

$ErrorActionPreference = 'Stop'

function Out-Decision([string]$decision, [string]$reason) {
    Write-GuardLog $decision $reason
    $obj = @{ permissionDecision = $decision; permissionDecisionReason = "work-harness guard: $reason" }
    [Console]::Out.Write(($obj | ConvertTo-Json -Compress))
    exit 0
}

function Write-GuardLog([string]$decision, [string]$reason) {
    try {
        $dir = Join-Path $HOME '.copilot/work-harness'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $line = '{0} {1} {2} :: {3}' -f (Get-Date -Format s), $decision, $script:toolName, $reason
        Add-Content -Path (Join-Path $dir 'guard.log') -Value $line
    } catch { }
}

# A repo copy of this guard (.github/hooks/scripts/) steps aside when the user-level guard is
# installed, so you are not asked twice. Teammates without the user-level guard get the repo copy.
$userGuard = Join-Path $HOME '.copilot/hooks/work-harness-guard.json'
if ($PSCommandPath -and ($PSCommandPath -replace '\\', '/') -match '/\.github/hooks/' -and (Test-Path $userGuard)) { exit 0 }

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
$payload = $raw | ConvertFrom-Json
$script:toolName = [string]$payload.toolName
$argsRaw = $payload.toolArgs
if ($argsRaw -isnot [string]) { $argsRaw = $argsRaw | ConvertTo-Json -Compress -Depth 20 }
$argsJson = [string]$argsRaw
$argsText = $argsJson
# JSON escapes backslashes; normalize Windows paths to forward slashes for matching.
$argsText = ($argsText -replace '\\\\', '/') -replace '\\(?=[A-Za-z0-9._ -])', '/'
$cwd = [string]$payload.cwd

# Paths an agent must never read or print (credentials, sessions).
$b = '(^|[\s\\/''"~=:])'   # start of a path segment
$secretPaths = "(\.vault-token|$b\.kube[\\/]|$b\.ssh([\\/'""\s]|$)|\.pfx\b|\.p12\b|\.pem\b|\bid_(rsa|dsa|ecdsa|ed25519)\b|\.pw-edge-profile|secrets(\.[\w-]+)?\.json\b)"
# Files that steer or restrain the agent itself; editing them needs your OK.
$agentConfig = "($b\.copilot[\\/]|\.github[\\/](hooks|copilot|agents|instructions|skills)[\\/]|copilot-instructions\.md|\.agent\.md|$b\.vscode[\\/](settings|mcp)\.json|\.mcp\.json)"
# Files that implement the checks (verify scripts, git hooks, verify result); editing them needs your OK.
$harnessFiles = '(\.git[\\/]hooks[\\/]|scripts[\\/](verify|dev|install-git-hooks)\.ps1|scripts[\\/](lib|git-hooks)[\\/]|spfx-harness\.json|\.spfx-dev[\\/]verify[\\/])'
# Shell verbs that write, move or delete files (redirection excludes 2> and >&1).
$writeVerbs = '(\b(Set-Content|Add-Content|Out-File|New-Item|Remove-Item|Move-Item|Copy-Item|Rename-Item|Clear-Content|Tee-Object)\b|(^|[\s;&|(])(sc|ac|ni|ri|rm|del|erase|mv|move|cp|copy|ren|tee|rmdir|rd)\s|\bsed\s+-i|\bperl\s+-[a-z]*i|\b(WriteAll(Text|Lines|Bytes)|AppendAll(Text|Lines))\b|\bgit\s+(checkout|restore|apply)\b|(?<![0-9&>])>{1,2}\s*[^\s&])'
$prodOverlay = 'overlays[\\/]prod'

$shellTools = @('powershell', 'bash', 'shell')
$editTools = @('edit', 'create', 'str_replace_editor', 'str_replace', 'apply_patch', 'write')
$readTools = @('view', 'read')

if ($shellTools -contains $script:toolName) {
    $cmd = $argsText
    try { $parsed = $argsJson | ConvertFrom-Json; if ($parsed.command) { $cmd = [string]$parsed.command } } catch { }

    # --- never allowed --------------------------------------------------
    if ($cmd -match $secretPaths) { Out-Decision 'deny' 'reads a credential or session file' }
    if ($cmd -match '\b(oc|kubectl)(\.exe)?\b[^|;&\n]*\bget\s+secrets?\b' -or $cmd -match '\boc(\.exe)?\b[^|;&\n]*\bextract\b') {
        Out-Decision 'deny' 'would print Kubernetes secret values; use the OpenShift UI'
    }
    if ($cmd -match '\bm365\b[^|;&\n]*\bspo\s+app\s+(add|deploy|install|upgrade|remove|retract|uninstall)\b' -or
        $cmd -match '\b(Add|Publish|Install|Update|Remove|Unpublish|Uninstall)-PnPApp\b') {
        Out-Decision 'deny' 'App Catalog deploys are done manually'
    }
    if ($cmd -match '\bgit\b[^|;&\n]*\bpush\b[^|;&\n]*(\s--force\b|\s-f\b|\s--force-with-lease\b|\s\+\S)') {
        Out-Decision 'deny' 'force push is not allowed'
    }
    if ($cmd -match '\bgit\b[^|;&\n]*\bpush\b[^|;&\n]*\s(\S+:)?(refs/heads/)?(main|master)(?=[\s;&|]|$)') {
        Out-Decision 'deny' 'push to main/master is not allowed; push a branch and open a PR'
    }

    # --- needs your confirmation -----------------------------------------
    if ($cmd -match '\bgit\b[^|;&\n]*\bpush\b') {
        $branch = ''
        try { if ($cwd) { $branch = (& git -C $cwd rev-parse --abbrev-ref HEAD 2>$null) } } catch { }
        if ($branch -eq 'main' -or $branch -eq 'master') { Out-Decision 'deny' "current branch is $branch; create a branch first" }
        Out-Decision 'ask' 'git push'
    }
    if ($cmd -match '\bgit\b[^|;&\n]*\b(merge|rebase)\b' -or $cmd -match '\bgit\b[^|;&\n]*\breset\s+--hard\b' -or
        $cmd -match '\bgit\b[^|;&\n]*\bclean\s+-[a-z]*f' -or $cmd -match '\bgit\b[^|;&\n]*\bbranch\s+-D\b') {
        Out-Decision 'ask' 'git merge/rebase/reset/clean/branch -D'
    }
    if ($cmd -match '\b(oc|kubectl)(\.exe)?\b[^|;&\n]*\b(apply|create|delete|patch|replace|scale|rollout|edit|label|annotate|set|expose|exec|rsh|cp|debug|drain|cordon|uncordon|adm|new-app|start-build|import-image|tag)\b') {
        Out-Decision 'ask' 'cluster change'
    }
    if ($cmd -match '\bargocd(\.exe)?\b[^|;&\n]*\bapp\s+(sync|rollback|delete|set|unset|patch|terminate-op|actions|edit|create)\b') {
        Out-Decision 'ask' 'Argo CD change'
    }
    if ($cmd -match '(^|[\s;&|(])vault(\.exe)?\s') { Out-Decision 'ask' 'Vault access; secret values must not appear in output' }
    if ($cmd -match $prodOverlay -and ($cmd -match $writeVerbs -or $cmd -match 'kustomize\s+edit')) {
        Out-Decision 'ask' 'changes a PROD overlay'
    }
    if ($cmd -match $agentConfig -and $cmd -match $writeVerbs) { Out-Decision 'ask' 'changes Copilot configuration or guardrails' }
    if ($cmd -match $harnessFiles -and $cmd -match $writeVerbs) { Out-Decision 'ask' 'changes the check scripts, git hooks or verify result' }
    if ($cmd -match '\bRemove-Item\b[^|;&\n]*-Recurse' -or $cmd -match '\brm\s+-[a-z]*r[a-z]*f|\brm\s+-[a-z]*f[a-z]*r') {
        Out-Decision 'ask' 'recursive delete'
    }
    exit 0
}

if ($editTools -contains $script:toolName) {
    if ($argsText -match $secretPaths) { Out-Decision 'deny' 'edits a credential or session file' }
    if ($argsText -match $prodOverlay) { Out-Decision 'ask' 'edits a PROD overlay' }
    if ($argsText -match $agentConfig) { Out-Decision 'ask' 'edits Copilot configuration or guardrails' }
    if ($argsText -match $harnessFiles) { Out-Decision 'ask' 'edits the check scripts, git hooks or verify result' }
    exit 0
}

if ($readTools -contains $script:toolName) {
    if ($argsText -match $secretPaths) { Out-Decision 'deny' 'reads a credential or session file' }
    exit 0
}

exit 0
