# Work laptop setup (v1: general + SPFx)

Windows, PowerShell 7, no admin rights. About 30 minutes. Do the steps in order; each ends with a check.

## 0. Before you start

```powershell
copilot --version          # need 1.0.117-2 or newer (PowerShell hooks deny correctly from there)
pwsh --version             # PowerShell 7
git --version; node -v
```
- Copilot CLI: run `/model` and note the exact model IDs. If they differ from the ones in
  `user/settings.json` and `user/agents/*.agent.md` (`claude-sonnet-5.5`, `claude-opus-5.5`, `gpt-6.2-sol`),
  fix them in this repo before installing (or in `~/.copilot` after).
- VS Code: "Developer: Policy Diagnostics" - note what policy disables (hooks, agents, skills, MCP).

## 1. Get the harness

```powershell
git clone https://github.com/shkholikov/work-harness.git $HOME\src\work-harness
cd $HOME\src\work-harness
```
No GitHub access from the laptop: download the repo as ZIP on another device and copy it over.

## 2. Install the general layer (user level, all repos)

```powershell
pwsh -File install\install.ps1 -DryRun   # shows what it will do
pwsh -File install\install.ps1
```
It installs into `~/.copilot`:

| What | Where |
|---|---|
| Global instructions | `copilot-instructions.md` |
| Agents: planner, reviewer, reviewer-high, deep-reviewer | `agents/` |
| Skills: grill, ship | `skills/` |
| Guard hook (asks/denies risky commands) | `hooks/work-harness-guard.json` + `.ps1` |
| Settings: model, effort, manual permission mode, footer with AI credits | `settings.json` (only missing keys; `-Force` overwrites) |
| `copilot` wrapper with the `--deny-tool` list | your PowerShell `$PROFILE` |

Backups of everything it replaces: `~/.copilot-backups/work-harness-<time>/`. Undo: `pwsh -File install\uninstall.ps1`.
Update later: `git pull`, run `install.ps1` again.

Check: open a NEW PowerShell window, run `copilot`, then `/env` (instructions, 4 agents, 2 skills, 1 hook listed) and `/model`.

## 3. VS Code

Open user settings (JSON) and add the keys from `user/vscode-settings.jsonc`. VS Code's Copilot harness
reads the same `~/.copilot` instructions, agents, skills and hooks. Check Policy Diagnostics again if
something does not show up.

## 4. Test the guardrails (in copilot, any repo)

Ask Copilot to run each line. Expected result on the right. Log of decisions: `~/.copilot/work-harness/guard.log`.

| Ask Copilot to run | Expected |
|---|---|
| `git status` | runs (after the normal permission prompt) |
| `git push origin feature/test` | guard asks |
| `git push origin main` | denied |
| `git push --force origin feature/test` | denied |
| `oc get pods` | runs |
| `oc delete pod x` / `oc -n dev scale deploy x --replicas=0` | guard asks |
| `argocd app sync dev` | guard asks |
| `vault kv get secret/x` | guard asks |
| `oc get secret x -o yaml` / `oc extract secret/x` | denied |
| `cat ~/.ssh/id_rsa` | denied |
| `m365 spo app deploy ...` / `Add-PnPApp ...` | denied |
| edit a file under `overlays/prod/` | guard asks |
| edit `~/.copilot/settings.json` | guard asks |

If a row fails, send the matching `guard.log` lines (they contain no secret values).

## 5. Set up an SPFx repo (repo level, shared with the team)

```powershell
cd C:\src\<spfx-repo>
git switch -c chore/copilot-setup
pwsh -File $HOME\src\work-harness\install\new-spfx-setup.ps1 -RepoPath . -DryRun
pwsh -File $HOME\src\work-harness\install\new-spfx-setup.ps1 -RepoPath . -LsgSkillsPath <folder with your LSG skills>
```
It adds (never overwrites existing files without `-Force`):
- `.github/copilot-instructions.md` (versions filled from `package.json`), `.github/instructions/` (code, config)
- `.github/skills/`: `verify`, `dev`, `upgrade-spfx` + your LSG skills (main one must be named `lsg`)
- `.github/hooks/`: repo copy of the guard, for teammates without the user-level install (yours steps aside)
- `.github/spfx-harness.json`: dev site, port, web part titles, risk-tier globs
- `scripts/dev.ps1`, `scripts/verify.ps1`, `scripts/git-hooks/pre-push` (installed into `.git/hooks`, blocks push to main)
- `REVIEW.md`, `incidents.md`, `docs/specs/SPEC.template.md`, Playwright config + smoke test

Then:
1. Fill `.github/spfx-harness.json`: `devSiteUrl` (a DEV site, never production), `port` (from `config/serve.json`), `webParts` (titles as in the toolbox). Check the `riskTiers` globs match your folders.
2. Trust the folder in copilot when asked (repo hooks only run in trusted folders).
3. `npm ci`, then `pwsh -File scripts/dev.ps1 trust` once (dev certificate).
4. `pwsh -File scripts/verify.ps1` - must PASS on the current code. This is your baseline. Fails on Node: switch to the Node the message names (nvm-windows / fnm).
5. Smoke test:
   ```powershell
   npm i -D @playwright/test --save-exact
   pwsh -File scripts/dev.ps1 start
   $env:SPFX_PW_SIGNIN='1'; npx playwright test -g "sign in"; Remove-Item Env:SPFX_PW_SIGNIN   # once: sign in the test Edge profile if needed
   pwsh -File scripts/verify.ps1 -E2E -Only e2e
   ```
   Screenshots land in `.spfx-dev/screenshots/`. If the toolbox selectors miss, send the error and a screenshot.
6. Commit (`git add -A`; `.spfx-dev/` is ignored), push the branch, open the PR in Bitbucket for the team.
7. Repeat for the second SPFx repo.

## 6. Daily use

| Task | How |
|---|---|
| Small fix | Just ask. When done: "verify", then "ship". |
| Feature | `/agent planner` (Opus, runs `grill`, writes `docs/specs/<date>-<slug>.md` with a plan). New session (`/new`): "implement docs/specs/...". Then verify, ship. |
| SPFx upgrade | "use upgrade-spfx" - writes `docs/upgrade-<version>.md`. Approve it, then one PR per step (A: 1.23.x + Heft + Node 22, B: 1.24.2 + React 18, C: LSG). |
| Dev server | "start the dev server" (`dev` skill) |
| Verify | "verify": checks, smoke test, review agents by tier (Low 0, Medium `reviewer`, High `reviewer-high` + `deep-reviewer`) |
| Ship | "ship": checks the verify fingerprint, commits, asks before push, writes `.spfx-dev/pr.md` for the Bitbucket PR |

Cost habits: one session per task, `/compact` long sessions, watch the footer AI-credit counter, `/usage` weekly.
