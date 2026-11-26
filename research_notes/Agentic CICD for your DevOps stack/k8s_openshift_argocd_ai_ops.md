# AI-assisted operations tooling for Kubernetes / OpenShift / ArgoCD / GitOps manifests (state as of Oct 2026)

Scope: tools a DevOps engineer can wire into GitHub Copilot (VS Code agent mode / Copilot CLI via MCP) or run standalone to diagnose and change workloads on OpenShift, deployed by ArgoCD (likely the OpenShift GitOps operator) from a Kustomize base/overlays GitOps repo. Emphasis on read-only vs write and how to restrict.

Research method note: findings come from primary READMEs and docs (GitHub, docs.redhat.com, developers.redhat.com, developer.hashicorp.com, akuity.io) fetched on 2026-10-06. Several fetches went through a summarizing fetch tool, so exact flag spellings should be checked against the installed version before writing config. Two Red Hat blog URLs returned 404 and are cited from search snippets only (marked).

## 1. Kubernetes MCP servers (containers/kubernetes-mcp-server, Red Hat OpenShift MCP server, Azure aks-mcp)

### Takeaway
`containers/kubernetes-mcp-server` (Go, Red Hat-backed, the upstream of Red Hat's "MCP server for Red Hat OpenShift", which is in Technology Preview) is the best fit: native OpenShift support, works from a kubeconfig created by `oc login`, Windows binary available, and has a real `read_only` switch (only tools annotated `readOnlyHint=true` are exposed) plus `disable_destructive`, tool allow/deny lists and `denied_resources` (e.g. block Secrets). Azure's `aks-mcp` also works on any cluster through `call_kubectl`, but it is a thin wrapper around raw kubectl/az and its own docs say its access levels are guardrails, not security boundaries.

### Cited Findings
**containers/kubernetes-mcp-server**
- Repo is in the `containers` GitHub org (the Red Hat-led org behind Podman/Buildah); Go-native implementation: "This IS NOT just a wrapper around kubectl or helm command-line tools. It is a Go-based native implementation." Distributed "as a single native binary for Linux, macOS, and Windows". — [GitHub README](https://github.com/containers/kubernetes-mcp-server)
- Install options: `npx kubernetes-mcp-server@latest`, `uvx kubernetes-mcp-server@latest`, native binaries from GitHub releases, one-click VS Code/Cursor install, Helm chart for in-cluster deployment. — [GitHub README](https://github.com/containers/kubernetes-mcp-server)
- Auth: kubeconfig by default (watches it for changes), in-cluster config, or OAuth/OIDC in HTTP mode (Keycloak and Microsoft Entra ID documented). — [GitHub README](https://github.com/containers/kubernetes-mcp-server)
- Toolsets: `core` (pods, generic resources, events; default), `config` (kubeconfig; default), `helm`, `kubevirt`, `tekton`, `kiali`, `netobserv`, `kcp`. Default `toolsets = ["core", "config"]`. — [configuration.md](https://github.com/containers/kubernetes-mcp-server/blob/main/docs/configuration.md)
- OpenShift support: `projects_list` tool; `route.openshift.io/v1 Route` and other OpenShift kinds via generic `resources_*` tools. — [README](https://raw.githubusercontent.com/containers/kubernetes-mcp-server/main/README.md)
- Core tools (as summarized from README). Read: `pods_list`, `pods_list_in_namespace`, `pods_get`, `pods_log`, `pods_top`, `nodes_log`, `nodes_stats_summary`, `nodes_top`, `events_list`, `namespaces_list`, `projects_list`, `resources_list`, `resources_get`. Write/destructive: `pods_delete`, `pods_run`, `resources_create_or_update` (server-side apply), `resources_delete`, `resources_scale`. Also `pods_exec` (runs commands in containers; listed alongside read tools in the summary, but its annotation was not confirmed). Config toolset: `configuration_contexts_list`, `configuration_view`, `targets_list`. — [README](https://raw.githubusercontent.com/containers/kubernetes-mcp-server/main/README.md)
- Access-control keys (TOML): `read_only` (default false): "When `true`, only exposes tools annotated with `readOnlyHint=true`. Prevents any write operations on the cluster." `disable_destructive` (default false): "When `true`, disables tools annotated with `destructiveHint=true` (delete, update operations)." Plus `enabled_tools` (allowlist), `disabled_tools` (denylist), `denied_resources` (list of GroupVersionKind to block), `cluster_provider_strategy` (`kubeconfig`, `in-cluster`, `kcp`, `disabled`), `require_oauth`, `stateless`, `kubeconfig`, `port`, `bind_address`, `list_output`, `tool_overrides`, `server_instructions`. — [configuration.md](https://github.com/containers/kubernetes-mcp-server/blob/main/docs/configuration.md)
- CLI: current docs list only `--version`, `--config <path>` (overrides `$MCP_CONFIG_PATH`) and `--config-dir <path>` (drop-in `.toml` directory), with settings in TOML. — [configuration.md](https://github.com/containers/kubernetes-mcp-server/blob/main/docs/configuration.md). CONFLICT/older info: 2025-era versions took the same settings as CLI flags (`--read-only`, `--disable-destructive`, `--toolsets`, `--kubeconfig`, `--port`, `--list-output`). This comes from prior knowledge and was not re-verified this session. Check `kubernetes-mcp-server --help` on the pinned version.
- OpenTelemetry tracing endpoint (`telemetry.endpoint`) is configurable. — [README](https://raw.githubusercontent.com/containers/kubernetes-mcp-server/main/README.md)

**Red Hat productization ("MCP server for Red Hat OpenShift")** (from search snippets only; the blog URLs returned 404 on fetch)
- Red Hat announced "the technology preview of the MCP server for Red Hat OpenShift", positioned as giving "AI agents controlled access to their clusters". — [Red Hat blog (zh-cn, search snippet)](https://www.redhat.com/zh-cn/blog/model-context-protocol-server-red-hat-openshift-now-available-technology-preview)
- Security posture claimed: toolset architecture "defaults to read-only operations, with write capabilities that must be explicitly enabled"; admins "can entirely disable destructive operations via configuration flags"; respects Kubernetes RBAC; can "explicitly block the server from interacting with sensitive resources, such as Secrets or ConfigMaps"; injects a specific user-agent into API calls so audit logs separate AI-agent actions from human ones. Reference deployment: Helm, bound to a read-only ClusterRole, bearer token required on the MCP HTTP endpoint, read-only mode with destructive operations disabled. — [Red Hat blog, MCP lifecycle operator (search snippet)](https://www.redhat.com/en/blog/manage-mcp-servers-red-hat-openshift-mcp-lifecycle-operator)
- "MCP lifecycle operator" is a developer preview (v0.1.0) with a declarative API to deploy and roll out MCP servers on OpenShift/Kubernetes. — [Red Hat blog (search snippet)](https://www.redhat.com/en/blog/manage-mcp-servers-red-hat-openshift-mcp-lifecycle-operator)
- Red Hat Cloud Experts publish an ARO guide for running the MCP server. — [cloud.redhat.com/experts](https://cloud.redhat.com/experts/aro/mcp-server-on-aro/)
- OpenShift Lightspeed uses the Kubernetes MCP server internally for cluster interaction (see section 3). — [Red Hat Developer](https://developers.redhat.com/articles/2026/02/04/how-connect-openshift-lightspeed-mcp-your-ide)

**Azure/aks-mcp**
- Maintained by Microsoft (Azure org), MIT. `--access-level` = `readonly` | `readwrite` | `admin`. Main tools are unified `call_kubectl` ("run any `kubectl` command with full argument support") and `call_az`, plus AKS-specific monitoring, detector, fleet, network and VMSS tools. `--allowed-namespaces` restricts kubectl to listed namespaces; `--enabled-components` limits tool groups; `--timeout` default 600s. Auth is Azure CLI identity (SP, workload identity, managed identity, existing login). — [GitHub Azure/aks-mcp](https://github.com/Azure/aks-mcp)
- The project's own warning: "Anyone who can invoke AKS-MCP tools effectively has the full Azure and Kubernetes privileges of the identity AKS-MCP is running under." Access levels are guardrails against accidents, not security boundaries. — [GitHub Azure/aks-mcp](https://github.com/Azure/aks-mcp)

### Inferences
- For an OpenShift + Windows workstation: run the `kubernetes-mcp-server` Windows binary over stdio, pin a version, point it at a TOML file containing `read_only = true`, `toolsets = ["core","config"]`, `denied_resources` covering core/v1 Secret (and Vault-injected ConfigMaps if relevant), and `disabled_tools = ["pods_exec","pods_run"]`. Defense in depth: give the kubeconfig context a token for a service account or user bound to the `view` ClusterRole. The `view` role excludes Secrets. Use a separate kubeconfig file just for the agent so an admin `oc login` session is never shared with it.
- `oc login` writes the token into kubeconfig. The MCP server reads the same kubeconfig, so the agent inherits whatever identity the engineer last logged in as unless a dedicated `KUBECONFIG` path is set in the MCP server's env. This is the main practical risk.
- RBAC is the real boundary. `read_only` and `disable_destructive` depend on MCP tool annotations, so they protect against model mistakes but not against a misbehaving server build.
- `aks-mcp`'s `call_kubectl` passes arbitrary kubectl argument strings. That is harder to constrain than typed tools and less suitable as the primary OpenShift server. It also has no `oc`-specific features.

### Gaps
- Exact Tech Preview date, supported OCP versions and the Red Hat product docs URL for "MCP server for Red Hat OpenShift" could not be fetched (404s). The relationship to `containers/kubernetes-mcp-server` is very likely the same codebase but is not confirmed by a fetched page.
- Whether `pods_exec` is annotated `readOnlyHint` or `destructiveHint` (i.e. whether `read_only = true` hides it) was not confirmed. Disable it explicitly.
- Latest version number of kubernetes-mcp-server not captured.
- Whether there is an OpenShift-specific toolset beyond `projects_list` (e.g. builds, imagestreams) was not confirmed.

## 2. ArgoCD MCP server, Argo CD AI features, Akuity Intelligence

### Takeaway
The de facto ArgoCD MCP server is `argoproj-labs/mcp-for-argocd` (npm `argocd-mcp`, created and maintained by Akuity engineers). It authenticates with an Argo CD API token, and `MCP_READ_ONLY=true` removes create/update/delete/sync/resource-action tools. Akuity Intelligence (AI incident triage, runbooks, remediation with approvals) exists only on the commercial Akuity Platform SaaS. No source shows it working with a self-managed OpenShift GitOps instance. No official in-core Argo CD AI feature was found.

### Cited Findings
- `argoproj-labs/mcp-for-argocd`: created by Akuity developers (@jiachengxu, @imwithye, @hwwn, @alexmt). Installed with `npx argocd-mcp@latest` (stdio or HTTP stream). — [GitHub](https://github.com/argoproj-labs/mcp-for-argocd); [search summary](https://glama.ai/mcp/servers/argoproj-labs/mcp-for-argocd)
- Tools: list/get/create/update/delete applications, sync application, get resource tree, managed resources, workload logs, resource events, resource actions (list/run); cluster and project listing. — [GitHub](https://github.com/argoproj-labs/mcp-for-argocd)
- Auth: env `ARGOCD_BASE_URL` and `ARGOCD_API_TOKEN`; tokens go in env or headers only, never in tool arguments. — [GitHub](https://github.com/argoproj-labs/mcp-for-argocd)
- Read-only: `"MCP_READ_ONLY": "true"` disables `create_application`, `update_application`, `delete_application`, `sync_application`, `run_resource_action`. — [GitHub](https://github.com/argoproj-labs/mcp-for-argocd)
- TLS: self-signed certs are handled with `NODE_TLS_REJECT_UNAUTHORIZED=0`, with the warning "Disabling SSL verification reduces security. Use this setting only in development environments". — [GitHub](https://github.com/argoproj-labs/mcp-for-argocd)
- VS Code config example: `{"servers":{"argocd-mcp-stdio":{"type":"stdio","command":"npx","args":["argocd-mcp@latest","stdio"],"env":{"ARGOCD_BASE_URL":"<argocd_url>","ARGOCD_API_TOKEN":"<argocd_token>"}}}}`. — [GitHub](https://github.com/argoproj-labs/mcp-for-argocd)
- Akuity Intelligence = Insights Dashboards + Akuity Agents, built into Argo CD and Kargo on the Akuity Platform. The On-Call Agent detects degraded Argo CD apps or namespaces, opens incidents with context, and can "execute or recommend runbooks". — [Akuity blog](https://akuity.io/blog/akuity-ai-software-delivery); [Help Net Security, 2025-10-01](https://www.helpnetsecurity.com/2025/10/01/akuity-platform-ai-capabilities)
- Runbooks are human-written natural-language symptom/solution patterns, used to keep outcomes deterministic. Closed loop: detect, diagnose, remediate, verify. — [TFiR](https://tfir.io/ai-autonomous-incident-response-human-runbooks-akuity/); [Cloud Native Now](https://cloudnativenow.com/features/akuity-applies-ai-to-both-management-of-argocd-and-kubernetes-clusters/)
- Sep 2025 to Feb 2026 updates: Slack incident management; automated triage executes "predefined runbooks when applications enter a degraded state" and "defined remediation or follow-up actions with approval requirements applied where configured"; certificate-expiry summaries (21/7 days); new EU region (AWS Frankfurt); SOC 2, ISO 27001, PCI DSS v4.0.1, HIPAA-aligned. — [Akuity product updates](https://akuity.io/blog/akuity-product-updates-sep-2025-feb-2026)
- HolmesGPT ships an ArgoCD toolset: "Get status, history and manifests and more of apps, projects and clusters." — [HolmesGPT GitHub](https://github.com/HolmesGPT/holmesgpt)

### Inferences
- On OpenShift GitOps, create a dedicated Argo CD local account (e.g. `ai-readonly`) with `apiKey` capability and an RBAC policy in `argocd-rbac-cm` (the `ArgoCD` CR `.spec.rbac` on OpenShift GitOps) granting only `get` on applications/projects/clusters/logs. Generate its token and set `MCP_READ_ONLY=true`. This gives two layers: tool removal plus server-side RBAC. Server-side RBAC is the one that matters. Argo CD RBAC mechanics are standard, but this exact setup was not re-verified this session.
- Do not use `NODE_TLS_REJECT_UNAUTHORIZED=0` on the work laptop. Point Node at the corporate CA with `NODE_EXTRA_CA_CERTS`. This is a standard Node.js variable, not documented by this repo.
- `argocd app diff` and `argocd app get` through the CLI are still useful deterministic read-only diagnostics alongside or instead of the MCP server.
- Akuity Intelligence requires the Akuity Platform (managed Argo CD), which is a different deployment model from OpenShift GitOps. It is likely irrelevant unless the organization changes platform.

### Gaps
- No official Argo CD (argoproj core) AI or MCP feature in Argo CD 3.x was found. Only the argoproj-labs project exists.
- Latest version/release cadence of `argocd-mcp` not captured. Whether it works with OpenShift GitOps SSO-only setups (Dex/OpenShift OAuth) beyond static API tokens was not confirmed.
- Akuity's LLM provider, BYO-LLM options and any Akuity-hosted MCP endpoint: none found.

## 3. Red Hat OpenShift Lightspeed

### Takeaway
OpenShift Lightspeed is a GA (1.0 onward; latest documented 1.1.4) operator-installed AI assistant in the OpenShift web console. It is grounded in Red Hat docs (RAG) and supports BYO knowledge. Its LLM can be external (OpenAI, Azure OpenAI, watsonx, Vertex AI, Bedrock) or self-hosted (OpenShift AI with vLLM, RHEL AI). Cluster interaction runs through the Kubernetes MCP server, and since 1.1 it supports writes with human-in-the-loop approval. Lightspeed can consume external MCP servers (`spec.mcpServers` with the `MCPServer` feature gate). Exposing Lightspeed itself as an MCP server for IDEs (VS Code/Copilot) is only an unsupported proof of concept.

### Cited Findings
- Version history: 1.0 GA (OCP 4.15+; cluster interaction, PostgreSQL persistence, token quotas); 1.1 GA (OCP 4.16+; "Kubernetes MCP server supports both read and write operations"; Google Vertex AI provider; `introspectionEnabled` defaults to true; Prometheus alert attachment); 1.1.2 (AWS Bedrock; Red Hat Offline Knowledge Portal (RHOKP) replaces custom RAG; OCP 4.16 to 4.22); 1.1.4 latest documented (security updates, OpenTelemetry collector for logging). MCP server with "human-in-the-loop approval for non-read operations". — [Lightspeed release notes](https://docs.redhat.com/en/documentation/red_hat_openshift_lightspeed/1.0/html-single/release_notes/index)
- Cluster interaction, earlier a Technology Preview, moved to MCP in 1.0.4. — [Lightspeed release notes (search snippet)](https://docs.redhat.com/en/documentation/red_hat_openshift_lightspeed/1.0/html/release_notes/ols-release-notes)
- LLM providers: SaaS (OpenAI, Azure OpenAI, IBM watsonx) or self-hosted with Red Hat OpenShift AI (vLLM single-model serving) or RHEL AI. — [About OpenShift Lightspeed](https://docs.redhat.com/en/documentation/red_hat_openshift_lightspeed/1.0/html/about/ols-about-openshift-lightspeed)
- Disconnected/air-gapped installs supported. — [Red Hat blog (search snippet)](https://www.redhat.com/en/blog/red-hat-openshift-lightspeed-now-available-technology-preview). Note: this source is the Tech Preview-era blog; the release notes summary did not mention disconnected support.
- External MCP servers: `OLSConfig.spec.mcpServers[]` with `name`, `url`, `timeout`, `headers` (`valueFrom.secretRef.name`). Requires `spec.featureGates: [MCPServer]`. Example: Satellite MCP server via an in-cluster proxy. BYO Knowledge: Markdown packaged into an image with `lightspeed-rag-tool-rhel9`, referenced at `spec.ols.rag[].image`. — [Red Hat Developer, 2026-09-22](https://developers.redhat.com/articles/2026/09/22/integrate-red-hat-satellite-mcp-openshift-lightspeed)
- OLSConfig API: `.spec.mcpServers[].streamableHTTP` (url, enableSSE, headers, sseReadTimeout default 10s, timeout default 5s). — [OLSConfig API reference](https://docs.redhat.com/en/documentation/red_hat_openshift_lightspeed/1.0/html/configure/olsconfig-api). The two sources show slightly different field shapes (nested `streamableHTTP` vs flat `url/headers`), which suggests a schema change between versions. Verify against the installed operator's CRD.
- Lightspeed as an MCP server for IDEs: `github.com/thoraxe/ols-mcp` (Python, `uv`). Env vars `OLS_API_URL` (route to the Lightspeed service) and `OLS_API_TOKEN` (`oc whoami -t`). The article calls it "a proof of concept", "not currently supported", and community-maintained. It works with any MCP client (VS Code + Copilot mentioned, Cursor shown). Cluster queries go through Lightspeed's cluster interaction; no mutation was shown. — [Red Hat Developer, 2026-02-04](https://developers.redhat.com/articles/2026/02/04/how-connect-openshift-lightspeed-mcp-your-ide)

### Inferences
- If the org already runs Lightspeed with an approved LLM (e.g. Azure OpenAI or in-house vLLM), it provides an enterprise-sanctioned AI path to the cluster in the console that uses the user's own OpenShift identity. That makes it a useful complement or fallback when Copilot is not approved to see cluster data.
- Bridging Lightspeed into Copilot via `ols-mcp` is unsupported. Treat it as experimental and not for the core harness.

### Gaps
- Release dates per Lightspeed version were not in the fetched notes.
- Whether Lightspeed itself is installed or licensed in the user's clusters is unknown. Ask on the work laptop.
- Support status (GA vs TP) of external `mcpServers` in Lightspeed was not explicitly stated (it is feature-gated).

## 4. k8sgpt, HolmesGPT, Komodor Klaudia and other AI SRE tools (LLM backends, self-hosting)

### Takeaway
HolmesGPT (CNCF Sandbox; Robusta with major Microsoft contributions; it powers the AKS agentic CLI) is the most capable open-source read-only investigator. It has OpenShift and ArgoCD toolsets, 30+ data-source toolsets, uses MCP servers as data sources, and supports Azure OpenAI and other providers. k8sgpt (analyzer-first, 0.4.x) is simpler and more deterministic. Its analyzers run locally and only explanations go to the LLM, with an anonymize option, and it supports local backends (Ollama, LocalAI) and Azure OpenAI. It also has `k8sgpt serve --mcp`. Komodor Klaudia is SaaS on Anthropic Claude via AWS Bedrock, so it is a poor fit if data must not leave the enterprise.

### Cited Findings
**HolmesGPT**
- "Originally created by Robusta.Dev with major contributions from Microsoft"; a "CNCF Sandbox Project". Investigates incidents by querying observability data to find root cause. — [GitHub HolmesGPT/holmesgpt](https://github.com/HolmesGPT/holmesgpt)
- "By design, HolmesGPT has read-only access and respects RBAC permissions. It is safe to run in production environments." — [GitHub](https://github.com/HolmesGPT/holmesgpt)
- Exception: an optional "Kubernetes Remediation (MCP)" toolset can "Apply fixes like scaling, rollbacks, and resource edits". — [GitHub](https://github.com/HolmesGPT/holmesgpt)
- Toolsets include OpenShift (projects, routes, builds, deployment configs) and ArgoCD. Integrations marked "(MCP)" include GitHub, AWS, Azure, GitLab, Jenkins. 30+ toolsets (K8s, Prometheus, Grafana) plus custom toolsets. — [GitHub](https://github.com/HolmesGPT/holmesgpt); [Robusta docs](https://docs.robusta.dev/improve_holmes_docs/configuration/holmesgpt/index.html)
- LLM providers: OpenAI, Anthropic, Azure OpenAI (`AZURE_API_KEY`, e.g. GPT-4.1), AWS Bedrock, Gemini, "and more". — [GitHub](https://github.com/HolmesGPT/holmesgpt); [skill doc summary](https://skills.cat/skills/julianobarbosa/claude-code-skills/holmesgpt-skill)
- Install: CLI via pip or brew, Helm chart, Docker, operator mode. — [GitHub](https://github.com/HolmesGPT/holmesgpt)
- The AKS agentic CLI is built on HolmesGPT. — [Microsoft Tech Community](https://techcommunity.microsoft.com/blog/appsonazureblog/-/4468166)

**k8sgpt**
- k8sgpt-ai org, ~8.2k stars, OpenSSF Best Practices badge; version 0.4.39 referenced in install docs. "a tool for scanning your Kubernetes clusters, diagnosing, and triaging issues in simple English" with "SRE experience codified into its analyzers". — [GitHub k8sgpt-ai/k8sgpt](https://github.com/k8sgpt-ai/k8sgpt)
- Default analyzers: pod, pvc, rs, service, event, ingress, statefulSet, deployment, job, cronJob, node, mutating/validating webhook, configMap. Optional: hpa, pdb, networkPolicy, log, storage, security, others. — [GitHub](https://github.com/k8sgpt-ai/k8sgpt)
- Backends: OpenAI, Azure OpenAI, LocalAI, Ollama, Amazon Bedrock, Cohere, Gemini, HuggingFace, CustomREST, LiteLLM, IBM watsonx. — [GitHub](https://github.com/k8sgpt-ai/k8sgpt)
- Anonymization: "The data is anonymized before being sent to the AI Backend... masked when sent to the AI backend and replaced by a key." — [GitHub](https://github.com/k8sgpt-ai/k8sgpt)
- MCP: `k8sgpt serve --mcp`. Operator (`k8sgpt-operator`) for continuous in-cluster scanning. Windows binaries on the Releases page. — [GitHub](https://github.com/k8sgpt-ai/k8sgpt)

**Komodor Klaudia**
- Klaudia is Komodor's GenAI troubleshooting agent, "based on the Claude 3.5 Sonnet large language model ... hosted on the Amazon Bedrock service" (2024 announcement; the model has likely changed since). Komodor positions itself as an "autonomous AI SRE platform for Kubernetes". — [BusinessWire 2024-09-18](https://www.businesswire.com/news/home/20240918213235/en); [Komodor help center](https://help.komodor.com/hc/en-us/articles/22447540595218)

### Inferences
- For an enterprise that restricts external LLMs: k8sgpt with `--anonymize` and an Azure OpenAI or local Ollama/vLLM backend, or HolmesGPT with Azure OpenAI (via LiteLLM-style config), are the realistic self-hostable options. Klaudia and Akuity Intelligence send data to vendor SaaS.
- k8sgpt `analyze` output is deterministic (analyzers) and only the explanation uses the LLM. That makes it a good read-only pre-step an agent can call (CLI or MCP) before free-form investigation.
- HolmesGPT overlaps with what Copilot plus the kubernetes-mcp-server already do. Its added value is the prebuilt investigation toolsets (Prometheus/Grafana/ArgoCD/OpenShift). Run it without the Remediation (MCP) toolset to keep it read-only.

### Gaps
- Tools exposed by `k8sgpt serve --mcp` and their read/write nature were not captured.
- Whether k8sgpt has an auto-remediation feature: the README did not mention it; not verified elsewhere.
- HolmesGPT latest version and whether it can itself run as an MCP server for Copilot were not confirmed (it consumes MCP servers).
- Komodor self-hosted/on-prem LLM options and OpenShift support: no reliable source found.
- Other AI SRE tools (e.g. kagent from Solo.io/CNCF, Datadog Bits, Dynatrace) were not researched for time.

## 5. AI review/validation of GitOps manifests: deterministic tools plus an LLM reviewer

### Takeaway
The consensus pattern is to keep rendering, schema validation, policy and diffing deterministic: `kustomize build` per overlay, kubeconform, kube-linter, conftest/OPA or Kyverno CLI, and `argocd app diff` or argocd-diff-preview. Tools like kubechecks post these results on PRs. The LLM then reads the rendered output, the diffs and the tool results to explain risk and intent. New research (Aug 2026 preprint) shows LLMs should not author YAML or diffs directly. The model should emit a structured field-change intent and deterministic code should apply the minimal edit, followed by human PR review.

### Cited Findings
- kubechecks (Zapier) integrates with GitHub/GitLab and ArgoCD and posts results on PRs/MRs. It runs linting and validation with kubepug, kubeconform and conftest. — [kubechecks docs index](https://docsearch.algolia.com/mcp/docs/repo/zapier/kubechecks)
- Argo CD Diff Preview (dag-andersen/argocd-diff-preview) renders accurate manifest diffs for PRs using Argo CD's own rendering engine (Helm/Kustomize). — [argocd-diff-preview docs index](https://docsearch.algolia.com/mcp/docs/repo/dag-andersen/argocd-diff-preview)
- Davineni, "Don't Let the Model Write the YAML: Deterministic, Minimal-Diff GitOps Remediation from LLM-Proposed Field Changes" (preprint, 2026-08-31, independent researcher, not peer-reviewed). Results: unified diffs under strict patching were 1.2 to 3.6% correct; GNU patch applied 96% but "silently misapply 14–20% of the applied diffs"; full-file rewrite was 2.4% correct for small models and 97.6% for frontier models, with silent corruption on 6/83 tasks (7.2%). The deterministic span-edit (model emits `FieldChange{kind,name,fieldPath,newValue}`, code edits the exact YAML scalar span) was 100% correct with 0% collateral change across 415 runs. It costs about 50 to 150 output tokens vs about 9,300 to rewrite a 9.3K-token manifest. Recommended flow: structured intent, then deterministic edit, then human PR review (no auto-merge), with fail-closed refusal on ambiguous targets. — [alphaXiv 2609.00227](https://www.alphaxiv.org/abs/2609.00227.md)
- Community MCP wrappers for linting exist (e.g. kube-lint-mcp) so agents can call validators as tools. — [Glama listing](https://glama.ai/mcp/servers/sophotechlabs/kube-lint-mcp)
- Guidance on PR reviews for Argo CD deployment changes (2026-02). — [OneUptime blog](https://oneuptime.com/blog/post/2026-02-26-argocd-pull-request-reviews-deployment-changes/markdown) (secondary/vendor blog)

### Inferences
- Recommended split for this stack:
  - Deterministic gates (block merge): `kustomize build overlays/<env>` succeeds for every env; kubeconform with OpenShift CRD schemas (Route, DeploymentConfig, etc. need a CRD schema catalog); kube-linter; conftest/OPA or Kyverno CLI policies (no `:latest`, resource limits, no privileged pods, image registry allowlist for OpenShift internal registry/Quay, PROD overlay change requires specific reviewers); `argocd app diff --local` or argocd-diff-preview to show the live-vs-desired delta.
  - AI (advisory only): summarize the rendered diff per environment, flag surprising cross-env drift (e.g. a base change that unintentionally hits PROD), check that image tags and promotions follow DEV -> TUC -> TUD -> PROD order, and explain policy failures. Never let the AI be the only gate.
  - For agent-authored overlay changes (e.g. image tag bumps), prefer `kustomize edit set image` or a structured edit script over free-form YAML generation. This matches the preprint's finding.
- These deterministic tools all run on Windows/PowerShell as standalone binaries (kustomize, kubeconform, kube-linter, conftest, kyverno, argocd). This is general knowledge, not re-verified.

### Gaps
- No primary source found for a vendor-neutral "official" best-practice document on deterministic-vs-AI split. The split above is inference plus the preprint.
- Availability of OpenShift CRD JSON schemas for kubeconform (e.g. community datreeio CRDs-catalog) not verified this session.
- kubechecks support for Bitbucket (the user's SCM) not verified. The source mentions only GitHub/GitLab.

## 6. HashiCorp Vault MCP server and agents near secrets

### Takeaway
HashiCorp ships an official `vault-mcp-server` (Beta). It exposes KV read/write/list/delete, mount create/delete and PKI issuance. HashiCorp warns that it "may expose ... Vault secrets, to MCP clients and LLMs", says it is "intended for local use only", and discourages production use. For a harness whose rule is "any Vault read or write needs confirmation; secret values never appear in output", the safe default is to not install it. Keep Vault out of the agent's tool surface and let agents reference Vault paths and placeholders only.

### Cited Findings
- Status: Beta. "Beta functionality is stable but possibly incomplete and subject to change. We strongly discourage using beta features in production deployments." — [HashiCorp Vault MCP docs](https://developer.hashicorp.com/vault/docs/mcp-server/overview)
- Tools: mounts (list/create/delete KV v1/v2), secrets (list/read/write/delete), PKI enable/issuers/roles/issue certificate. — [HashiCorp docs](https://developer.hashicorp.com/vault/docs/mcp-server/overview); [GitHub hashicorp/vault-mcp-server](https://github.com/hashicorp/vault-mcp-server)
- Warnings: "the MCP server may expose certain Vault data, including Vault secrets, to MCP clients and LLMs interacting with the server." "Do not use the MCP server with untrusted MCP clients or LLMs." HashiCorp disclaims liability for third-party clients/LLMs. — [HashiCorp docs](https://developer.hashicorp.com/vault/docs/mcp-server/overview)
- "At this stage, the MCP server is intended for local use only." Auth: `VAULT_ADDR` (default `http://127.0.0.1:8200`), `VAULT_TOKEN` (required), `VAULT_NAMESPACE` (optional). Transports: stdio (default) or HTTP (`TRANSPORT_MODE`, `TRANSPORT_HOST` default 127.0.0.1, `TRANSPORT_PORT` default 8080). Docker image `hashicorp/vault-mcp-server`. — [GitHub hashicorp/vault-mcp-server](https://github.com/hashicorp/vault-mcp-server)
- No tool-filtering or read-only flag was documented on the fetched pages. — [HashiCorp docs](https://developer.hashicorp.com/vault/docs/mcp-server/overview)

### Inferences
- Best practice for agents near secrets: (1) do not register the Vault MCP server in Copilot. (2) If it is ever needed, use a short-TTL token with a Vault policy limited to `list` on metadata paths (no `read` on secret data), so the server cannot return values whatever the tool exposes. (3) Block `vault` CLI subcommands and `oc get secret -o yaml` / `oc extract secret` in terminal auto-approve deny rules. (4) Use `denied_resources` for Secrets in kubernetes-mcp-server and the `view` ClusterRole (no Secrets). (5) In GitOps, reference secrets only via Vault paths (e.g. Vault Agent injector annotations, External Secrets, or argocd-vault-plugin placeholders) so manifests the agent reads never contain values.
- Even read-only K8s tools can leak secrets via `pods_log`, env vars in `resources_get` of Deployments/Pods, or `configuration_view` (kubeconfig with token). `configuration_view` minified may still include credentials. Consider disabling the `config` toolset or that tool. The kubeconfig-token risk is inferred, not confirmed from docs.

### Gaps
- Whether HCP Vault / Vault Enterprise has native "AI" features beyond the MCP server was not researched.
- Vault MCP server version and any newer tool-filtering options not captured.
