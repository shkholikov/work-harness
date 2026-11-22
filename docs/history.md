# work-harness: discussion history (2026-10-04 to 2026-10-23)

Handoff summary for a new session. Built from the project's memory notes and the files in this repo. The original chat transcripts no longer exist, so code drafted in chat (the TeamCity PowerShell script, the Terraform example, the VaultSharp snippet) is not preserved verbatim.

## Project

Source repo for an agent harness for **GitHub Copilot on the work laptop** (VS Code agent mode + Copilot CLI, Windows + PowerShell 7). Authored on the personal Mac, later pushed to a private GitHub repo and cloned at work. Work discuss-first: settle each piece, then generate files. Nothing targets Claude Code. Company-internal values (hosts, cluster URLs, registry paths, Vault paths, project keys) stay placeholders.

Work context:
- **SPFx (developer role):** 2 SharePoint SPFx solutions, React web parts, PnPjs and SPHttpClient/REST, an internal UI component library. Deployed manually to the App Catalog, outside CI/CD.
- **.NET API + React (DevOps role):** ASP.NET Core (.NET 8+), React + Vite, Azure Database for PostgreSQL. Code in Bitbucket, CI in TeamCity Enterprise (UI-configured), images via Podman/Buildah to Quay and DASY -> OpenShift ImageStream, ArgoCD + Kustomize overlays, secrets in HashiCorp Vault, cluster CLI `oc`. Environments DEV -> TUC -> TUD -> PROD (meaning of TUC/TUD still to be confirmed).

Guardrails every artifact enforces (need explicit confirmation): cluster mutations (`oc`/`kubectl` apply/delete/patch/scale/rollout, `argocd app sync/rollback`), any Vault read or write (secret values never in output), git push/merge or Bitbucket PR merge, edits to PROD overlays. Read-only diagnostics run freely.

## 1. Environment, CI/CD analysis, diagrams (Oct 4)

- Wrote `CLAUDE.md` describing the work setup above. Covered Copilot usage patterns and TeamCity Versioned Settings (Kotlin DSL).
- **Current pipeline:** push to `dev`/`tuc`/`tud`/`main` triggers the matching TeamCity subproject, which rebuilds from scratch (restore, build, tests, Sonar + Sonatype report-only, Podman image tagged with the build number), pushes to Quay + DASY, then bumps `overlays/<env>` on GitOps branch `dev`. DEV pushes directly; TUC/TUD/PROD go through a manually merged PR into the GitOps env branch. ArgoCD app `<env>` tracks branch `<env>` + `overlays/<env>`. DB migrations manual/DBA. No post-deploy checks, notifications or rollback.
- **Risks found:** different image per env (PROD image never tested in TUD); build-number tags can collide and don't map to commits; whole-branch `dev` -> `<env>` merges carry unrelated changes; gates never block; no post-deploy verification; manual DB migrations.
- **4-phase roadmap:** (1) SHA-based image tags, (2) build once and promote the same tag, (3) single-branch GitOps repo with an overlay per env, PROD protected, (4) trunk-based development (`main` + short-lived feature branches).
- **Target flow:** merge to main -> one TeamCity build per commit (Kotlin DSL; blocking Sonatype on TUD/PROD) -> `app:<git-sha>` pushed once -> `kustomize edit set image` on `overlays/dev` -> promotion = one-line PR copying the tag to the next overlay -> ArgoCD sync -> PostSync smoke test (`/health/ready` + key APIs) -> ArgoCD Notifications (Teams/email). Failed smoke test reverts the tag. EF migrations shipped as an idempotent SQL artifact for the DBA. Secrets from Vault per env path.
- Diagrams (local Mac repo): `docs/cicd/as-is.svg`, `docs/cicd/target.svg`, side-by-side page `docs/cicd/cicd-flow.html` with a "what changes" table.

## 2. Spec Kit for SPFx (Oct 4)

Gave a 6-step Spec Kit workflow for SPFx, rules for when to use it, folder structure and git policy. The later research (section 3) refined this: Spec Kit is overkill for routine web-part work; use Microsoft's SPFx agent skill (`.github/skills/spfx/`) plus a short repo `*.instructions.md` (exact SPFx and Node versions, React pinned `--save-exact`, internal UI library conventions, ban on App Catalog deploy commands). VS Code's Plan agent for medium changes. Keep Spec Kit for the SPFx 1.24/1.25 upgrade (React 18, Yeoman -> SPFx CLI).

## 3. Agentic CI/CD research (Oct 6-7)

Four parallel research tracks (agents in CI, K8s/OpenShift/ArgoCD AI ops, guardrails, Spec Kit for SPFx). Report on the Mac: `reports/Agentic CICD for your DevOps stack.md`; notes in `research_notes/Agentic CICD for your DevOps stack/`.

Conclusions:
- Agents sit beside the pipeline, read-only first. Deterministic tools gate, AI advises.
- GitHub-native agents (Copilot coding agent, gh-aw) need GitHub-hosted repos; don't mirror Bitbucket. Copy gh-aw's design instead (one Markdown task file per workflow, declared tools, read-only default, pinned engine).
- Copilot CLI is the headless engine (`copilot -p --no-ask-user`, narrow `--allow-tool`, full `--deny-tool`, pinned version). CI auth via fine-grained PAT with "Copilot Requests" (personal account or bot seat).
- Agent surfaces: TeamCity 2026.1+ built-in MCP (`/app/mcp`, safe mode) or `teamcity` CLI with `TEAMCITY_RO=1`; kubernetes-mcp-server `read_only = true`; argocd-mcp `MCP_READ_ONLY=true`; Bitbucket Data Center MCP plugin (10.5+) vs Cloud Rovo; **do not install the Vault MCP server**. OpenShift Lightspeed as a possible sanctioned fallback.
- Security: Agents Rule of Two (untrusted input, sensitive access, state change: at most two per session). Client-side deny lists plus server-side boundaries (view-only kubeconfig, Argo CD `role:readonly`, Bitbucket branch permissions, no Vault token in agent shells). Protect `.vscode/settings.json`, `.github/**`, `*.instructions.md`, `*.agent.md` from agent edits. Never `--yolo`/`--allow-all`.
- Roadmap: 0 verify facts -> 1 read-only VS Code agents (TeamCity triage, OpenShift/ArgoCD incident) -> 2 deterministic GitOps gates (kustomize build, kubeconform, kube-linter, conftest/Kyverno, `argocd app diff`) as required checks -> 3 headless Copilot CLI in TeamCity (failure triage, GitOps PR reviewer -> Code Insights via a separate posting step) -> 4 agent-proposed GitOps changes on `agent/*` branches, human merge.
- Facts to check at work: Bitbucket Cloud vs Data Center + version; TeamCity version and AI licence; Copilot plan/org policies; terms for Copilot CLI in TeamCity; deny-pattern semantics; SPFx versions; whether OpenShift Lightspeed is installed.
- "AI-first DevOps" search (Oct 9): online versions lean full autonomy; Microsoft's "Agentic DevOps" assumes GitHub/Azure. The guardrail-first roadmap stands.

## 4. Read-only CI/CD agent/skill (Oct 9)

Idea: a custom read-only agent wrapping API scripts (TeamCity failure triage, cluster health) so it uses fewer tokens than pasting logs or a generic MCP server. Agreed the design, recommended packaging it as a skill, drafted a PowerShell TeamCity failure script. **Paused:** waiting on how the user authenticates to TeamCity (token or username/password).

## 5. IaC (Oct 15)

Explained IaC and its fit: TeamCity Kotlin DSL, ArgoCD Applications as code, Vault config, Azure PostgreSQL via Terraform. Gave a Terraform example for Azure Database for PostgreSQL Flexible Server, including `import` of the existing server. **Apply pending** confirmation from the team and the Azure subscription owner.

## 6. Review workflow mapped to the work stack (Oct 19)

Mapped the personal Claude + GitHub review workflow onto Copilot, Bitbucket, TeamCity, ArgoCD, SPFx. Phases 1 (task), 2 (branch), 3 (code + check), 5 (ship) and the incidents log carry over. Phase 4's PR review layers need replacements on Bitbucket/TeamCity. **Open:** Bitbucket Cloud vs Data Center.

## 7. Dev secrets to Vault (Oct 21-23)

Goal: replace the .NET API's local `secrets.Local.json` with HashiCorp Vault as a shared dev secret store.
- Login: recommended OIDC (Entra ID) or LDAP over AppRole for developers.
- Storage: KV v2 at `secret/<app>/local`.
- API change: `VaultSharp.Extensions.Configuration` added as a configuration source in `Program.cs`, Vault address/role via `launchSettings.json`.
- Drafted the config-loading code and Vault admin setup steps.
- **Not live:** someone with write access must run `vault kv put` to load the secret; Vault admin setup pending.

## Open items

1. TeamCity auth method (token or username/password) -> unblocks the triage skill/script.
2. Bitbucket Cloud or Data Center (and version) -> decides MCP/review options.
3. Meaning of TUC and TUD.
4. Vault: admin setup + `vault kv put` for `secret/<app>/local`.
5. Terraform apply for Azure PostgreSQL: team + subscription owner sign-off.
6. Which Copilot workflow graphs to build first. Candidates: TeamCity failure triage, OpenShift/ArgoCD incident, feature -> Bitbucket PR, GitOps overlay change with validation.
7. Harness repo layout and install method on the work laptop.

## Files on the Mac (not yet in any remote repo)

- `CLAUDE.md` - project instructions
- `docs/cicd/` - as-is/target diagrams (`.svg`, `.json`) and `cicd-flow.html`
- `reports/Agentic CICD for your DevOps stack.md` - research report
- `research_notes/Agentic CICD for your DevOps stack/` - 4 research notes
- `docs/history.md` - this file
