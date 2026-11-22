# Work tech stack

Shared profile for the Copilot harness. Company-internal values (hosts, URLs,
registry paths, Vault paths, project keys) stay placeholders.

| Area | Technology | What we know | Still to confirm |
|---|---|---|---|
| Workstation | Windows laptop, PowerShell 7 | User-level installs only, no admin rights. New workstation coming. | — |
| AI: coding | GitHub Copilot CLI (main), VS Code + Copilot agent mode | Premium requests, $50/month budget. Claude and GPT models. | Copilot plan (Business/Enterprise), org policies |
| AI: Office | Microsoft 365 Copilot | Used for Microsoft-product questions and tasks, to save the Copilot budget. | Which agents/features the tenant enables |
| SPFx (developer role) | SharePoint Framework, React web parts, PnPjs, SPHttpClient/REST, internal UI component library | 2 solutions, deployed manually to the App Catalog outside CI/CD. Upgrade to SPFx 1.24/1.25 (React 18, SPFx CLI) planned. | Current SPFx and Node versions |
| App stack (DevOps role) | ASP.NET Core (.NET 8+), React + Vite | — | — |
| Database | Azure Database for PostgreSQL (Flexible Server) | Migrations run manually by the DBA. Terraform import/management drafted. | Apply sign-off (team + subscription owner) |
| Source control | Bitbucket Data Center | PRs into GitOps env branches merged manually. | Version (MCP plugin needs 10.5+) |
| CI | TeamCity Enterprise | 3 projects configured manually in the UI. One subproject per env branch. Sonar + Sonatype report-only. Login: username/password. New project to use configuration as code (Kotlin DSL). | Version (2026.1+ has built-in MCP), AI licence |
| Containers | Podman / Buildah | Images tagged with the build number, not the commit SHA. | — |
| Registries | Quay, DASY -> OpenShift ImageStream | Images pushed to both. | — |
| Platform | OpenShift, `oc` CLI | — | Whether OpenShift Lightspeed is installed |
| GitOps / CD | ArgoCD + Kustomize overlays | One ArgoCD app per env, tracking branch `<env>` + `overlays/<env>`. No post-deploy checks, notifications or rollback. | — |
| Secrets | HashiCorp Vault | Moving dev secrets from `secrets.Local.json` to KV v2 `secret/<app>/local` via VaultSharp. OIDC/LDAP login recommended. | Admin setup + `vault kv put` pending |
| Code quality | SonarQube, Sonatype | Report-only today. Plan: Sonatype blocking on TUD/PROD. | — |
| Environments | DEV -> TUC -> TUD -> PROD | TUC and TUD are both pre-prod test stages. | — |

## Guardrails (explicit confirmation required)

- Cluster mutations: `oc`/`kubectl` apply/delete/patch/scale/rollout, `argocd app sync/rollback`
- Any Vault read or write; secret values never appear in output
- `git push`/merge or Bitbucket PR merge
- Edits to PROD overlays

Read-only diagnostics run freely.
