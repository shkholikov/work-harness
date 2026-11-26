# work-harness TODO

Copilot harness for the work laptop. Updated 2026-11-26.
M = on the Mac (Claude Code), W = on the work laptop, T = needs someone else.

## 0. Repo for this harness (M)

- [ ] `git init` this folder, add `.gitignore` (exclude `.remember/`)
- [ ] Create a private GitHub repo and connect it as `origin` (push only after confirmation)
- [ ] W: check that the work laptop can clone a private GitHub repo; if not, plan a copy-based install

## 1. Check the work laptop (W)

- [ ] `copilot --version` (PowerShell hooks need 1.0.117-2 or newer to deny correctly)
- [ ] VS Code: run "Developer: Policy Diagnostics", note what is disabled by policy
- [ ] CLI: `/settings` Problems tab, `/mcp`, `/model`, `/usage`
- [ ] Check `%ProgramFiles%\GitHubCopilot\managed-settings.json` and `HKLM:\SOFTWARE\Policies\GitHubCopilot`
- [ ] Find out whether plugin installs are allowed (`strictKnownMarketplaces`)
- [ ] Confirm `~/.copilot` is clean (no old agents, skills, hooks)

## 2. General harness skeleton (M, then install on W)

- [ ] Structure the repo as a Copilot plugin marketplace with one plugin `work-harness`
- [ ] Guard hook (`preToolUse`, PowerShell): ask before git push/merge, `oc`/`kubectl` mutations, `argocd app sync/rollback`, Vault; deny commands that print secrets
- [ ] PowerShell profile wrapper for `copilot` with the `--deny-tool` list
- [ ] Personal `copilot-instructions.md` (short: stack, Windows/PS7, guardrails)
- [ ] Fallback install script (copy into `~/.copilot`)
- [ ] W: install with `copilot plugin marketplace add` + `copilot plugin install`; in VS Code via `chat.pluginLocations`

## 3. Test the guardrails (W)

- [ ] Ask Copilot to `git push`, `oc delete`, `oc -n x delete`, `vault read`, edit `overlays/prod/` and confirm each is asked or blocked
- [ ] Check that a hook timeout does not silently let calls through (keep hooks fast)

## 4. Workflow pieces (M)

- [ ] Orchestrator agent (plan -> implement -> review via subagents; no handoffs, they are Local-harness only)
- [ ] Read-only reviewer agent (correctness + security)
- [ ] PR-text skill (Testing / Risk / How to revert) for Bitbucket
- [ ] Pin models per agent: cheap for workers, strong for plan/review

## 5. SPFx repos (repo-level, shared with the team)

- [ ] Get from one repo: `package.json`, `.yo-rc.json`, `gulpfile.js`
- [ ] Ask: does the internal UI library support React 18?
- [ ] Add `.github/copilot-instructions.md`, `.github/instructions/*`, `verify` skill, reviewer, Microsoft SPFx skill, `REVIEW.md`, `incidents.md`
- [ ] `.git/hooks/pre-push` blocking main
- [ ] Open as a PR for teammates to review
- [ ] Upgrade step A: 1.20.1 -> 1.23.x, Heft, Node 22 (keep old `.sppkg` for rollback)
- [ ] Upgrade step B: 1.24.2, React 18
- [ ] Repeat for the second SPFx repo

## 6. GitOps repo (repo-level)

- [ ] Instructions: overlay structure, `kustomize edit set image` for tag changes
- [ ] `validate` skill: `kustomize build`, kubeconform, kube-linter, `argocd app diff`
- [ ] Hook: ask before any edit under `overlays/prod/**`
- [ ] T: Bitbucket `CODEOWNERS` for `overlays/prod/` and branch permissions

## 7. .NET API + React repo (repo-level)

- [ ] `copilot-instructions.md` with real build/test commands
- [ ] `applyTo` instructions for `**/*.cs`, frontend, `.teamcity/**`
- [ ] TeamCity DSL rules: keep IDs/uuid, secrets as `credentialsJSON:`, run `mvn teamcity-configs:generate`
- [ ] `verify` skill, hook blocking edits to secrets files

## 8. DevOps skills (general harness)

- [ ] W: TeamCity version (2026.1+ has MCP) and auth method (token or username/password)
- [ ] TeamCity failure-triage skill (read-only PowerShell)
- [ ] OpenShift/ArgoCD incident skill (read-only, separate view-only kubeconfig)
- [ ] Cluster health skill

## Open questions

- [ ] Bitbucket Cloud or Data Center (and version)
- [ ] What TUC and TUD stand for
- [ ] Separate non-admin `oc` account for the agent
- [ ] T: Vault admin setup + `vault kv put` for `secret/<app>/local`
- [ ] T: sign-off for Terraform apply on Azure PostgreSQL
