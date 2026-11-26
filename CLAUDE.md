# work-harness

Source repo for an agent harness for **GitHub Copilot on my work laptop**: instructions, custom agents, prompt files, workflow graphs and guardrails. Authored here (personal Mac, Claude Code), later pushed to a private GitHub repo and cloned onto the work laptop.

Work discuss-first: settle each piece in conversation, then generate files. Layout and install method are still open.

## Target runtime

- GitHub Copilot in VS Code (agent mode) and GitHub Copilot CLI. Every artifact is a Copilot format; nothing here targets Claude Code.
- Windows + PowerShell 7. Scripts are `.ps1`, paths are Windows-style.
- Copilot formats (custom agents and handoffs, `*.instructions.md` with `applyTo`, `*.prompt.md`, `AGENTS.md`, Copilot CLI config, MCP config, terminal auto-approve rules) change often. Check current docs before writing each artifact type.
- Placeholders for anything company-internal: hostnames, cluster URLs, registry paths, Vault paths, project keys. The real values get filled in on the work laptop.

## Work context

Two domains with different roles; the harness covers both.

### SPFx (developer role)

- 2 SharePoint SPFx solutions: React web parts, PnPjs and SPHttpClient/REST for SharePoint data, an internal company UI component library.
- Deployed manually to the App Catalog. They stay outside CI/CD.

### .NET API + React frontend (DevOps role)

- ASP.NET Core (.NET 8+) API, React + Vite frontend, Azure Database for PostgreSQL.
- Code in Bitbucket. CI in TeamCity Enterprise, configured through the UI (no Kotlin DSL yet; moving to Versioned Settings is under discussion).
- Environments in promotion order: DEV -> TUC -> TUD -> PROD. Ask what TUC/TUD stand for before relying on it.
- Secrets in HashiCorp Vault. Cluster CLI is `oc`.

Current CI/CD flow (as-is, not the target):

1. Source repos have branches `dev`, `tuc`, `tud`, `main`. A push triggers the matching TeamCity subproject (DEV/TUC/TUD/PROD). Every subproject rebuilds from scratch.
2. Steps: restore/install, build, unit tests, Sonar + Sonatype (report only, nothing blocks), Podman/Buildah image build.
3. Image tagged with the TeamCity build number, pushed to Quay and DASY. DASY syncs into an OpenShift ImageStream.
4. Last step clones the GitOps repo and sets `overlays/<env>` tag on GitOps branch `dev`. DEV is pushed directly; TUC/TUD/PROD go through a manually merged PR into the GitOps env branch.
5. GitOps repo: branch per env AND overlay per env; ArgoCD app `<env>` tracks branch `<env>` + `overlays/<env>`.
6. DB migrations on Azure PostgreSQL are manual / DBA. No post-deploy checks, notifications, or documented rollback.

Known weak points: different image per env, build-number tags may collide and don't map to commits, `dev` -> `<env>` merges carry unrelated changes, gates don't block. Target direction: SHA-based tags, build once and promote the tag, single-branch GitOps, blocking Sonatype on TUD/PROD, ArgoCD Notifications + smoke test.

## Guardrails

Every harness artifact enforces these. Read-only diagnostics run freely (`oc get/describe/logs`, `argocd app get/diff`, `kustomize build`). These need explicit confirmation from me first:

- Cluster mutations: `oc`/`kubectl` apply, delete, patch, scale, rollout; `argocd app sync/rollback`.
- Any Vault read or write. Secret values never appear in output.
- Git push, merge, or PR merge in Bitbucket.
- Edits to PROD overlays.

State them in instructions and back them with whatever hard enforcement Copilot offers (deny lists in terminal auto-approve, CLI tool deny flags).

## Agent workflow graphs

"Graph engineering" here means workflow graphs: chained custom agents with handoffs (plan -> implement -> review), each node with scoped tools. Which graphs to build is undecided. Candidates: TeamCity failure triage, OpenShift/ArgoCD incident, feature -> Bitbucket PR, GitOps overlay change with validation. Propose and agree before building.
