# work-harness TODO

Copilot harness for the work laptop. Updated 2026-11-27. v1 (general + SPFx) is built; see docs/work-laptop-setup.md.
M = on the Mac (Claude Code), W = on the work laptop, T = needs someone else.

## 0. Repo for this harness (M)

- [x] `git init` this folder, add `.gitignore` (exclude `.remember/`)
- [x] Create a private GitHub repo and connect it as `origin` (push only after confirmation)
- [ ] W: check that the work laptop can clone a private GitHub repo; if not, plan a copy-based install

## 1. Check the work laptop (W)

- [ ] `copilot --version` (PowerShell hooks need 1.0.117-2 or newer to deny correctly)
- [ ] VS Code: run "Developer: Policy Diagnostics", note what is disabled by policy
- [ ] CLI: `/settings` Problems tab, `/mcp`, `/model`, `/usage`
- [ ] Check `%ProgramFiles%\GitHubCopilot\managed-settings.json` and `HKLM:\SOFTWARE\Policies\GitHubCopilot`
- [ ] Find out whether plugin installs are allowed (`strictKnownMarketplaces`)
- [ ] Confirm `~/.copilot` is clean (no old agents, skills, hooks)

## 2. General harness skeleton (M, then install on W)

- [ ] v2: structure the repo as a Copilot plugin marketplace (v1 uses copy install)
- [x] Guard hook (`preToolUse`, PowerShell): ask before git push/merge, `oc`/`kubectl` mutations, `argocd app sync/rollback`, Vault; deny commands that print secrets
- [x] PowerShell profile wrapper for `copilot` with the `--deny-tool` list
- [x] Personal `copilot-instructions.md` (short: stack, Windows/PS7, guardrails)
- [x] Fallback install script (copy into `~/.copilot`)
- [ ] v2 W: install with `copilot plugin marketplace add` + `copilot plugin install`; in VS Code via `chat.pluginLocations`

## 3. Test the guardrails (W)

- [ ] Ask Copilot to `git push`, `oc delete`, `oc -n x delete`, `vault read`, edit `overlays/prod/` and confirm each is asked or blocked
- [ ] Check that a hook timeout does not silently let calls through (keep hooks fast)

## 4. Workflow pieces (M)

- [x] Planner agent instead of an orchestrator (fresh session per phase). Old idea: orchestrator agent (plan -> implement -> review via subagents; no handoffs, they are Local-harness only)
- [x] Read-only reviewer agent (correctness + security)
- [x] PR-text skill (Testing / Risk / How to revert) for Bitbucket
- [x] `grill` skill (port of Claude grilling): read code first, max 5 questions per round, ends by writing a short `SPEC.md` (goal, non-goals, decisions, acceptance criteria, verify commands, risk tier)
- [x] Task triage step: trivial -> direct + checks; feature -> grill + spec + plan; risky upgrade -> read-only spike first
- [x] Reviewer checks the diff against `SPEC.md` acceptance criteria
- [x] Pin models per agent by tier (cheap / mid / strong), see "Token budget" below

## Token budget (pay per token)

- [ ] W: send `/model` list and `/usage`; ask admin for the monthly AI-credit budget
- [ ] Fill real model IDs into the tier table (cheap / mid / strong)
- [x] Scripts pre-filter logs before the model sees them (failed step, last N lines)
- [x] Keep always-on instructions short; everything else in `applyTo` files and skills
- [ ] Few tools per agent, no MCP unless needed
- [ ] Autopilot always with `--max-ai-credits`; `/fleet` only for real parallel work
- [x] Reviewer effort by risk tier (Low: skip, Medium: mid model, High: strong model)
- [ ] Habit: one session per task, `/compact` long sessions, check `/usage` weekly

## 5. SPFx repos (repo-level, shared with the team)

- [x] Review workflow: plan -> branch -> code + check -> `/verify` (checks + reviewer agent) -> `/ship` (commit, ask before push, PR text) -> Bitbucket PR by risk tier -> manual App Catalog deploy with previous `.sppkg` kept
- [ ] Get from one repo: `package.json`, `.yo-rc.json`, `gulpfile.js`
- [ ] Bring the existing LSG (internal UI library) skills into `templates/spfx/.github/skills/lsg*/` (check names, frontmatter, no internal URLs)
- [ ] Ask: does LSG support React 18? (blocks upgrade step B)
- [x] Add `.github/copilot-instructions.md`, `.github/instructions/*`, `verify` skill, reviewer, Microsoft SPFx skill, `REVIEW.md`, `incidents.md`
- [x] `.git/hooks/pre-push` blocking main
- [ ] Open as a PR for teammates to review
- [ ] Upgrade step A: 1.20.1 -> 1.23.x, Heft, Node 22 (keep old `.sppkg` for rollback)
- [ ] Upgrade step B: 1.24.2, React 18
- [ ] Repeat for the second SPFx repo
- [ ] Tests level 1: Jest + React Testing Library via `heft test` (no login)
- [x] Tests level 2: Playwright on the hosted workbench, `channel: 'msedge'`, separate Edge profile, dev site only
- [ ] W: check `npx playwright open --channel msedge https://<tenant>.sharepoint.com` signs in automatically
- [x] Upgrade plan as `docs/upgrade-1.24.md` in the repo (no Spec Kit)

## 6. GitOps repo (repo-level)

- [ ] Instructions: overlay structure, `kustomize edit set image` for tag changes
- [ ] `validate` skill: `kustomize build`, kubeconform, kube-linter, `argocd app diff`
- [ ] Hook: ask before any edit under `overlays/prod/**`
- [ ] T: Bitbucket `CODEOWNERS` for `overlays/prod/` and branch permissions

## 7. .NET API + React repo: DevOps part only

Colleagues own this repo's Copilot setup (Spec Kit, agents, skills). Don't touch their files.

- [ ] `devops-teamcity.instructions.md` with `applyTo: ".teamcity/**"`: keep IDs/uuid, secrets as `credentialsJSON:`, run `mvn teamcity-configs:generate`
- [ ] `devops-docker.instructions.md` with `applyTo: "**/Dockerfile*,**/Containerfile*"`
- [ ] Skills `devops-teamcity-validate` and `devops-image-check` (podman build + Dockerfile lint)
- [ ] Everything prefixed `devops-`; bring in as a PR the team reviews

## 8. DevOps skills (general harness)

- [ ] W: TeamCity version (2026.1+ has MCP) and auth method (token or username/password)
- [ ] TeamCity failure-triage skill (read-only PowerShell, REST token)
- [ ] `devops-triage` skill: analyze pod events, logs and ArgoCD status pasted from the UIs (user uses OpenShift, ArgoCD and Vault only through the UI; no cluster access for Copilot)
- [ ] Later, only if wanted: read-only `oc`/`argocd` CLI with a view-only account

## Open questions

- [x] Bitbucket Cloud or Data Center: Data Center (version still unknown)
- [ ] What TUC and TUD stand for
- [ ] Separate non-admin `oc` account for the agent
- [ ] T: Vault admin setup + `vault kv put` for `secret/<app>/local`
- [ ] T: sign-off for Terraform apply on Azure PostgreSQL
