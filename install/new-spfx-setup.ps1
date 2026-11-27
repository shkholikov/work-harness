<#
.SYNOPSIS
  Adds the work-harness SPFx setup to an SPFx repo: Copilot instructions, skills, guard hook,
  REVIEW.md, dev/verify scripts, Playwright smoke test, pre-push hook.

.DESCRIPTION
  Never overwrites existing files unless -Force. Fills versions from package.json.
  -Update refreshes only the files the harness owns (scripts, skills verify/stack/upgrade-spfx,
  hooks, instructions, SPEC template) and removes renamed old files; your filled-in files
  (copilot-instructions.md, spfx-harness.json, REVIEW.md, incidents.md, Playwright tests) stay.
  Run it on a branch (for example chore/copilot-setup), review the changes, open a PR.

.EXAMPLE
  pwsh -File install/new-spfx-setup.ps1 -RepoPath C:\src\my-spfx -DryRun
  pwsh -File install/new-spfx-setup.ps1 -RepoPath C:\src\my-spfx -LsgSkillsPath C:\backup\lsg-skills
  pwsh -File install/new-spfx-setup.ps1 -RepoPath C:\src\my-spfx -Update    # after git pull of work-harness
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepoPath,
    [string]$LsgSkillsPath,
    [switch]$Force,
    [switch]$Update,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Template = Join-Path $Root 'templates/spfx'
$Repo = (Resolve-Path $RepoPath).Path

function Act([string]$msg) { if ($DryRun) { Write-Host "[dry-run] $msg" } else { Write-Host $msg } }

$pkgPath = Join-Path $Repo 'package.json'
if (-not (Test-Path $pkgPath)) { throw "$Repo has no package.json" }
$pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
$deps = @{}
foreach ($section in @($pkg.dependencies, $pkg.devDependencies)) {
    if ($section) { foreach ($p in $section.PSObject.Properties) { $deps[$p.Name] = ([string]$p.Value).TrimStart('^', '~') } }
}
if (-not $deps.ContainsKey('@microsoft/sp-core-library')) { throw "$Repo does not look like an SPFx solution (@microsoft/sp-core-library missing)." }

$branch = (& git -C $Repo rev-parse --abbrev-ref HEAD 2>$null)
if ($branch -eq 'main' -or $branch -eq 'master') { Write-Warning "Repo is on $branch. Create a branch first: git -C `"$Repo`" switch -c chore/copilot-setup" }

# Facts for placeholders
$spfx = $deps['@microsoft/sp-core-library']
$minor = if ($spfx -match '^1\.(\d+)') { [int]$Matches[1] } else { 0 }
$node = if ($minor -le 20) { '18' } else { '22' }
$toolchain = if ($deps.ContainsKey('@rushstack/heft')) { 'heft' } elseif (Test-Path (Join-Path $Repo 'gulpfile.js')) { 'gulp' } else { 'heft' }
$react = if ($deps.ContainsKey('react')) { $deps['react'] } else { '<react>' }
$ts = if ($deps.ContainsKey('typescript')) { $deps['typescript'] } else { ($deps.Keys | Where-Object { $_ -like '@microsoft/rush-stack-compiler-*' } | Select-Object -First 1) -replace '@microsoft/rush-stack-compiler-', '' }
if (-not $ts) { $ts = '<ts>' }
$lsgName = $deps.Keys | Where-Object { $_ -match 'lsg' } | Select-Object -First 1
$lsg = if ($lsgName) { "$lsgName $($deps[$lsgName])" } else { '<package + version>' }
$solution = if ($pkg.name) { $pkg.name } else { Split-Path -Leaf $Repo }
Write-Host "SPFx $spfx, toolchain $toolchain, React $react, TypeScript $ts, Node $node, LSG $lsg"

# Files the harness owns: -Update overwrites them. Everything else is yours after the first setup.
$owned = '^(scripts/|\.github/skills/(verify|stack|upgrade-spfx)/|\.github/hooks/|\.github/instructions/|docs/specs/SPEC\.template\.md$)'
# Files from older harness versions, removed by -Update.
$legacy = @('scripts/dev.ps1', '.github/skills/dev/SKILL.md')

# 1. Copy template files
$created = 0; $updated = 0; $skipped = @()
Get-ChildItem $Template -Recurse -File -Force | ForEach-Object {
    $rel = $_.FullName.Substring($Template.Length).TrimStart('\', '/')
    $dest = Join-Path $Repo $rel
    $relKey = $rel -replace '\\', '/'
    if (Test-Path $dest) {
        $mayReplace = $Force -or ($Update -and $relKey -match $owned)
        if (-not $mayReplace) { $skipped += $rel; return }
        if ((Get-FileHash $dest).Hash -eq (Get-FileHash $_.FullName).Hash) { return }
        Act "  update $rel"
        if (-not $DryRun) { Copy-Item $_.FullName $dest -Force }
        $updated++
        return
    }
    Act "  add $rel"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item $_.FullName $dest -Force
    }
    $created++
}
# Guard script: single source in user/hooks/guard.ps1
$guardDest = Join-Path $Repo '.github/hooks/scripts/work-harness-guard.ps1'
$guardSrc = Join-Path $Root 'user/hooks/guard.ps1'
if ((Test-Path $guardDest) -and -not ($Force -or $Update)) { $skipped += '.github/hooks/scripts/work-harness-guard.ps1' }
elseif ((Test-Path $guardDest) -and (Get-FileHash $guardDest).Hash -eq (Get-FileHash $guardSrc).Hash) { }
else {
    $verb = if (Test-Path $guardDest) { 'update' } else { 'add' }
    Act "  $verb .github/hooks/scripts/work-harness-guard.ps1"
    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $guardDest) | Out-Null; Copy-Item $guardSrc $guardDest -Force }
    $created++
}

# Remove files renamed in newer harness versions
if ($Update) {
    foreach ($old in $legacy) {
        $path = Join-Path $Repo $old
        if (Test-Path $path) {
            Act "  remove $old (replaced in this harness version)"
            if (-not $DryRun) {
                Remove-Item $path -Force
                $parent = Split-Path -Parent $path
                if ((Test-Path $parent) -and -not (Get-ChildItem $parent -Force)) { Remove-Item $parent -Force }
            }
        }
    }
    foreach ($f in @('.github/copilot-instructions.md', 'docs/work-laptop-setup.md')) {
        $path = Join-Path $Repo $f
        if ((Test-Path $path) -and (Select-String -Path $path -Pattern 'scripts/dev\.ps1' -Quiet)) {
            Write-Warning "$f still mentions scripts/dev.ps1: change it to scripts/stack.ps1 (up/down/restart/status/ports)."
        }
    }
}

# 2. Fill placeholders in the repo instructions
$instr = Join-Path $Repo '.github/copilot-instructions.md'
if ((Test-Path $instr) -and -not $DryRun -and ($skipped -notcontains '.github/copilot-instructions.md')) {
    $text = Get-Content $instr -Raw
    $text = $text.Replace('<Solution name>', $solution).Replace('<1.20.1>', $spfx).Replace('<18>', $node).Replace('<17.0.1>', $react).Replace('<4.7>', $ts).Replace('<gulp>', $toolchain).Replace('LSG <version>', "LSG $lsg")
    Set-Content -Path $instr -Value $text -Encoding utf8
}

# 3. .gitignore
$gi = Join-Path $Repo '.gitignore'
$want = @('.spfx-dev/', 'test-results/', 'playwright-report/', '.github/hooks/logs/')
$have = if (Test-Path $gi) { Get-Content $gi } else { @() }
$add = @($want | Where-Object { $have -notcontains $_ })
if ($add.Count -gt 0) {
    Act "  .gitignore += $($add -join ', ')"
    if (-not $DryRun) { Add-Content -Path $gi -Value (@('', '# work-harness') + $add) }
}

# 4. LSG skills
if ($LsgSkillsPath) {
    $found = Get-ChildItem $LsgSkillsPath -Recurse -Filter 'SKILL.md' -File
    if (-not $found) { Write-Warning "No SKILL.md found under $LsgSkillsPath" }
    foreach ($s in $found) {
        $name = $s.Directory.Name
        $dest = Join-Path $Repo ".github/skills/$name"
        Act "  add LSG skill .github/skills/$name"
        if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $dest | Out-Null; Copy-Item (Join-Path $s.Directory.FullName '*') $dest -Recurse -Force }
    }
    if (-not ($found | Where-Object { $_.Directory.Name -eq 'lsg' })) {
        Write-Warning "The instructions refer to a skill named 'lsg'. Rename your main LSG skill folder to 'lsg' or change the name in .github/copilot-instructions.md."
    }
} elseif (-not $Update) {
    Write-Warning "No -LsgSkillsPath given: copy your LSG skills into .github/skills/<name>/SKILL.md (main one named 'lsg')."
}

# 5. Local git hook
if (-not $DryRun -and (Test-Path (Join-Path $Repo '.git'))) { & pwsh -NoProfile -File (Join-Path $Repo 'scripts/install-git-hooks.ps1') }

Write-Host ''
if ($Update) { Write-Host ''; Write-Host "Updated $updated, added $created files. Check with: git -C `"$Repo`" diff --stat"; exit 0 }
Write-Host "Added $created files. Kept existing: $(if ($skipped) { $skipped -join ', ' } else { 'none' })"
Write-Host 'Next, in the SPFx repo:'
Write-Host '  1. Fill .github/spfx-harness.json: devSiteUrl (DEV site), port, webParts (toolbox titles). Check the riskTiers globs.'
Write-Host '  2. npm i -D @playwright/test --save-exact   (Playwright uses your installed Edge, no browser download)'
Write-Host '  3. pwsh -File scripts/stack.ps1 up, open the printed URL, then: $env:SPFX_PW_SIGNIN=1; npx playwright test -g "sign in"'
Write-Host '  4. pwsh -File scripts/verify.ps1   (expect PASS on the current code = your baseline)'
Write-Host '  5. Commit on a branch, open a PR for your teammates.'
