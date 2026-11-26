# Security risks and guardrails for AI agents in CI/CD and infrastructure operations (as of Oct 2026)

Scope: Copilot agent mode / Copilot CLI / Claude Code / MCP servers reading build logs, reviewing PRs, running cluster diagnostics and proposing GitOps changes, in a Bitbucket + TeamCity + OpenShift + ArgoCD + Vault shop. Research done 2026-10-06. Roughly 20 searches/fetches; a few claims rest on secondary reporting and are marked as such.

## 1. Prompt injection through untrusted CI/CD inputs: incidents and disclosures, 2025-2026

### Takeaway
Since mid-2025 there has been a steady run of real exploits. All follow one pattern: untrusted text (issue or PR title, PR body, hidden HTML/markdown comment, poisoned package) reaches an agent that holds credentials and can run shell commands, write repos, post comments or render images. The attacker then takes secrets out through the platform's own channels. Vendors mostly patch the specific exfiltration path. GitHub calls the underlying issue a "known architectural limitation", so the fix has to be architectural: least privilege, no untrusted text in prompts of privileged agents, and no exfiltration channel.

### Cited Findings
**Invariant Labs: GitHub MCP "toxic agent flow" (May 2025)**
- A malicious issue in a public repo hijacks a user's agent when the user asks something harmless like "look at the open issues". The agent pulls private-repo data into context and leaks it through an autonomously created PR in the public repo. The MCP server was unmodified and its tool descriptions were clean. Invariant said there is "no easy and complete fix." — [Invariant Labs](https://invariantlabs.ai/blog/mcp-github-vulnerability); [DevClass, 2025-05-27](https://www.devclass.com/ai-ml/2025/05/27/researchers-warn-of-prompt-injection-vulnerability-in-github-mcp-with-no-obvious-fix/1623458)

**CVE-2025-53773: GitHub Copilot / Visual Studio (disclosed 2025-08-12, CVSS 7.8)**
- Prompt injection planted in source files, web pages or issues gets Copilot to write `"chat.tools.autoApprove": true` into `.vscode/settings.json`. That disables all confirmations and allows shell execution, i.e. RCE. The researchers described wormable "ZombAI" scenarios. — [Wiz CVE DB](https://www.wiz.io/vulnerability-database/cve/cve-2025-53773); [CyberSecurityNews](https://cybersecuritynews.com/github-copilot-rce-vulnerability)

**CamoLeak: CVE-2025-59145, Copilot Chat (CVSS 9.6)**
- Hidden markdown comments in PRs, which the web UI doesn't show, carried instructions to Copilot Chat. Copilot then leaked private-repo code and secrets (e.g. AWS keys) by encoding them into image URLs proxied through GitHub's own Camo service, which bypassed CSP.
- Timeline: reported via HackerOne in June 2025. GitHub disabled image rendering in Copilot Chat on 2025-08-14. Public disclosure was in October 2025 (researcher Omer Mayraz, Legit Security). — [The Register, 2025-10-09](https://assets.theregister.com/2025/10/09/github_copilot_chat_vulnerability/); [Dark Reading](https://www.darkreading.com/application-security/github-copilot-camoleak-ai-attack-exfils-data)
- The CVE number comes from secondary reporting; not checked against NVD.

**Nx "s1ngularity" npm supply-chain attack (2025-08-26)**
- Eight malicious Nx versions ran a `telemetry.js` postinstall hook. It detected local AI CLIs and ran them with safety off: Claude with `--dangerously-skip-permissions`, Gemini with `--yolo`, Amazon Q with `--trust-all-tools`. The prompt told them to recursively scan the filesystem for secrets (GitHub/npm tokens, SSH keys, `.env`, wallets) and write paths to `/tmp/inventory.txt`. Data went to public GitHub repos named `s1ngularity-repository`. — [StepSecurity](https://www.stepsecurity.io/blog/supply-chain-security-alert-popular-nx-build-system-package-compromised-with-data-stealing-malware); [Okta threat intel](https://www.okta.com/blog/threat-intelligence/the-s1ngularity-attack--when-attackers-prompt-your-ai-agents-to/)
- One aftermath report put the total at 2,180 affected GitHub accounts (secondary source). — [Hackmag](https://hackmag.com/news/s1ngularitys-aftermath)
- CSA notes the campaign also went after AI-tool credential files: Claude Code, Gemini CLI and Amazon Q. — [CSA Research Note](https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-github-actions-security-20260503-csa-st/)

**postmark-mcp: first known malicious MCP server (2025-09-17, v1.0.16)**
- An npm package impersonating Postmark's MCP server added one line that BCC'd every email to an attacker address. It had about 1,643 downloads before removal (found by Koi Security). — [The Hacker News](https://thehackernews.com/2025/09/first-malicious-mcp-server-found.html?m=1); [Dark Reading](https://www.darkreading.com/application-security/malicious-mcp-server-exfiltrates-secrets-bcc)
- Other 2025 MCP-layer CVEs named in that coverage (not individually verified): CVE-2025-6514 (mcp-remote RCE), CVE-2025-49596 (MCP Inspector), CVE-2025-54136 (Cursor "MCPoison"), CVE-2025-54994 (create-mcp-server-stdio). — [PolicyLayer summary](https://policylayer.com/attacks/compromised-mcp-package)

**PromptPwnd (Aikido Security, early December 2025)**
- Aikido called it "the first confirmed real-world demonstration that AI prompt injection can compromise CI/CD pipelines."
- It needs two things together:
  - an AI agent in a GitHub Actions or GitLab CI job that holds powerful tokens (GITHUB_TOKEN, cloud keys);
  - a prompt that embeds user-controlled fields (issue title, PR body).
- Affected setups used Gemini CLI, Claude Code and OpenAI Codex. At least five Fortune 500 companies were exposed, plus Google's own Gemini CLI repo, which was patched quickly.
- Mitigations Aikido recommended: restrict the agent's toolset (no issue edits, no shell), sanitise untrusted input, treat AI output as untrusted code, limit token scopes. — [eSecurity Planet](https://www.esecurityplanet.com/threats/ai-agents-create-critical-supply-chain-risk-in-github-actions/); [CSO Online](https://csoonline.com/article/4101751/ai-in-ci-cd-pipelines-can-be-tricked-into-behaving-badly-2.html)
- I didn't fetch Aikido's original post. The details above are as reported by trade press.

**"Clinejection" (reported 2026-01-01, published 2026-02-09, exploited 2026-02-17)**
- Cline's issue-triage workflow ran `anthropics/claude-code-action@v1` with two problems:
  - `allowed_non_write_users: "*"`, so any GitHub user could trigger it;
  - `--allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch"`, with the issue title interpolated straight into the prompt.
- The attack chain:
  1. A crafted issue title made Claude run `npm install` from an attacker fork, whose preinstall script executed.
  2. The "Cacheract" tool flooded the Actions cache with more than 10 GB, evicting legitimate entries and poisoning the nightly-release cache keys.
  3. The nightly workflow restored the poisoned cache, which exposed `VSCE_PAT`, `OVSX_PAT` and `NPM_RELEASE_TOKEN`.
- Cline fixed the workflow within 30 minutes of publication but did not fully revoke the npm token. On 2026-02-17 an unknown actor used it to publish `cline@2.3.0`, which installed the OpenClaw agent globally. It was live for about 8 hours.
- Root cause per Snyk: nightly and production credentials were not scoped separately. — [Snyk](https://snyk.io/blog/cline-supply-chain-attack-prompt-injection-github-actions/); [Simon Willison, 2026-03-06](https://simonwillison.net/2026/Mar/6/clinejection/); researcher Adnan Khan
- Reported impact ranges from "~4,000 developer machines" ([grith.ai](https://grith.ai/blog/clinejection-when-your-ai-tool-installs-another)) to a potential "5+ million users with auto-update" ([Snyk](https://snyk.io/blog/cline-supply-chain-attack-prompt-injection-github-actions/)). These measure different things: actual installs vs exposed population.

**"Comment and Control" (published 2026-04-16, updated 2026-04-21)**
- Researcher Aonan Guan, with Johns Hopkins researchers, hijacked three tools through PR titles, issue bodies and comments, including hidden HTML comments:
  - Anthropic's Claude Code Security Review action: PR title interpolated unsanitised; CVSS 9.4 per reports; secrets showed up as "findings" or in Actions logs.
  - Google's Gemini CLI Action: a fake "Trusted Content Section" got it to post `GEMINI_API_KEY` in a public comment.
  - GitHub Copilot Agent: HTML-comment payloads bypassed its environment filtering, secret scanning and network firewall.
- Vendor responses:

  | Vendor | Classification | Bounty | Fix |
  |---|---|---|---|
  | Anthropic | Critical | $100 | Disallowed the `ps` tool; underlying issue persists per the researcher |
  | Google | Confirmed | $1,337 | Added guardrail prompts; patched within about 4 days |
  | GitHub | Confirmed | $500 | Called it a "known architectural limitation" |

  — [SecurityWeek](https://www.securityweek.com/claude-code-gemini-cli-github-copilot-agents-vulnerable-to-prompt-injection-via-comments/); [CSA Research Note](https://labs.cloudsecurityalliance.org/research/csa-research-note-comment-control-github-prompt-injection-20/)
- No CVE is mentioned in SecurityWeek. One commentator stresses that these were "no-CVE" disclosures. — [Waxell](https://waxell.ai/blog/github-ai-agent-prompt-injection-no-cve-disclosure)

**Adjacent CI supply-chain events that matter for AI tooling (CSA timeline)**

| Date | Event |
|---|---|
| Mar 2025 | tj-actions/changed-files, CVE-2025-30066: about 23,000 repos affected. reviewdog/action-setup, CVE-2025-30154: secrets base64-encoded to evade log masking. Both added to CISA KEV. |
| Sep 2025 | GhostAction: 327 accounts, 817 repos. |
| 2026-03-19 | "TeamPCP" force-pushed malicious payloads to 76 of 77 tags of `aquasecurity/trivy-action` and all 7 tags of `setup-trivy`. |

— [CSA Research Note](https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-github-actions-security-20260503-csa-st/)

**Mitigations that recur across all of the above**
- Pin actions and dependencies by SHA.
- Declare explicit minimum `permissions:`.
- Treat all repo content as untrusted and delimit it in prompts.
- Keep the agent's toolset minimal.
- Monitor at the runner level, e.g. StepSecurity Harden-Runner.
- Use short-lived, environment-scoped credentials instead of personal keys.
- Keep agent decision-making apart from the execution layer that holds credentials.
- Red-team AI workflows. — [CSA](https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-github-actions-security-20260503-csa-st/)

### Inferences
- **Every vector maps to this stack.**
  - Bitbucket PR titles, descriptions and comments: hidden HTML/markdown comments render invisibly in Bitbucket too.
  - Commit messages and branch names.
  - TeamCity build logs: test output and dependency install scripts can print attacker text.
  - Container and pod logs from `oc logs`: application logs often contain user-supplied strings.
  - Dependency READMEs and npm/NuGet packages.
- **Log masking is not a complete defence.** Base64 evasion (reviewdog) and Camo image URLs (CamoLeak) both got around it. Assume an agent that sees a secret can leak it.
- **CVE-2025-53773 and Clinejection show the agent attacking its own guardrails.** It edited the auto-approve setting in one case and poisoned the cache in the other. Harness config files (`.vscode/settings.json`, `.github/agents`, `*.instructions.md`, Copilot CLI permission files) need write protection from the agent itself.
- **s1ngularity means installed AI CLIs are themselves an attack surface.** Any malicious postinstall can run `copilot --yolo` (or `--allow-all`) on the work laptop. Org policy that blocks `--yolo`/`--allow-all`, if available, and keeping long-lived tokens off disk both matter.

### Gaps
- I found no public incident involving Bitbucket Pipelines, TeamCity, ArgoCD or OpenShift specifically. All public cases are GitHub Actions/GitLab or local IDE/CLI. The patterns transfer, but there's no direct evidence.
- I didn't verify the CVE numbers for CamoLeak or the MCP CVE list against NVD.
- "PromptPwnd": I didn't fetch Aikido's original post, so the exact date and vendor list rest on secondary reporting.
- Copilot-specific CVEs after April 2026 weren't found in this pass and may exist.

## 2. Frameworks: OWASP LLM/Agentic Top 10, NIST, lethal trifecta, Rule of Two

### Takeaway
The most useful design rule for CI/CD agents is the lethal trifecta (Willison), formalised as Meta's Agents Rule of Two. In any one session an agent may have at most two of: untrusted input, sensitive data/systems, and external communication or state change. When all three are needed, a human approves. OWASP's Agentic Top 10 (Dec 2025) and NIST CAISI's work (Jan 2026 RFI) supply the vocabulary and the "least privilege + zero trust" baseline.

### Cited Findings
**Lethal trifecta (Simon Willison, 2025-06-16)**
- The three ingredients: private data, exposure to untrusted content, and the ability to communicate externally. With all three, attackers can easily steal data.
- Willison rejects guardrails that claim 95% detection as "a failing grade". The only reliable mitigation is to remove at least one leg.
- MCP is singled out because a single server (e.g. GitHub's) can supply all three legs at once. — [simonwillison.net](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)

**Meta's "Agents Rule of Two" (late Oct/Nov 2025)**
- Until injections can be reliably detected, an agent should satisfy at most two of three properties per session: [A] processes untrustworthy inputs; [B] has access to sensitive systems or private data; [C] can change state or communicate externally.
- If all three are required, the agent "should not be permitted to operate autonomously" and needs human-in-the-loop approval or another reliable validation, or a fresh session/context. — [Simon Willison's summary](https://simonw.substack.com/p/new-prompt-injection-papers-agents); [Databricks](https://www.databricks.com/blog/mitigating-risk-prompt-injection-ai-agents-databricks)
- Critics note that the Rule of Two doesn't cover every agentic risk, e.g. cascading failures and rogue agents. — [Ken Huang](https://kenhuangus.substack.com/p/the-rule-of-two-vs-reality-why-metas)

**OWASP Top 10 for Agentic Applications 2026 (published 2025-12-09 by the OWASP GenAI Security Project, 100+ contributors)**

| ID | Risk |
|---|---|
| ASI01 | Agent Goal Hijack |
| ASI02 | Tool Misuse and Exploitation |
| ASI03 | Agent Identity and Privilege Abuse |
| ASI04 | Agentic Supply Chain Compromise |
| ASI05 | Unexpected Code Execution |
| ASI06 | Memory and Context Poisoning |
| ASI07 | Insecure Inter-Agent Communication |
| ASI08 | Cascading Agent Failures |
| ASI09 | Human-Agent Trust Exploitation |
| ASI10 | Rogue Agents |

— [Giskard](https://www.giskard.ai/knowledge/owasp-top-10-for-agentic-application-2026); [Cycode](https://cycode.com/blog/owasp-top-10-agentic-applications/)

- CSA recommends using it as the evaluation framework for AI in CI. — [CSA](https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-github-actions-security-20260503-csa-st/)

**NIST / CAISI**
- CAISI published an RFI on "Security Considerations for AI Agents" in the Federal Register on 2026-01-08 (docket NIST-2025-0035, 43 questions, comments closed 2026-03-09). Its framing:
  - A hijacked agent "leverages the tools and authorizations already granted" to act for the attacker.
  - Three risk classes: adversarial inputs, backdoored models, misaligned objectives.
  - Mitigations: least privilege, zero-trust architecture, plus newer methods such as instruction hierarchy and design patterns that use trusted models. — [Federal Register](https://www.govinfo.gov/content/pkg/FR-2026-01-08/html/2026-00206.htm); [ExecutiveGov](https://www.executivegov.com/articles/nist-rfi-agentic-ai-risks-security)

### Inferences
**Mapping to this harness**

| Agent | Untrusted input | Sensitive access | State change / egress | Implication |
|---|---|---|---|---|
| TeamCity failure triage | Yes (logs) | Yes (build config, maybe secrets in env) | Should be none | Output stays in the chat to the human only; no posting comments, no web fetch, no push |
| OpenShift incident diagnostics | Yes (pod logs, events) | Yes (cluster) | Must be read-only | `view` role, no `oc` mutations, no egress |
| GitOps change proposer | Lower (repo it owns) | Gets write | Yes | Must not also read untrusted logs or PR comments in the same session. Use a fresh session / handoff boundary between "diagnose" and "write" |

- **Copilot custom-agent handoffs act as the Rule of Two "fresh session" boundary**, provided the handoff passes a human-reviewed summary rather than raw log text.
- **OWASP labels for the documentation**: Vault reads map to ASI03; MCP server pinning to ASI04; protecting harness config files from agent edits to ASI05/ASI06.

### Gaps
- I didn't fetch the OWASP Top 10 for LLM Applications 2025 list (LLM01 Prompt Injection, LLM06 Excessive Agency, etc.) from genai.owasp.org in this pass. It's widely known but not cited here.
- I found no final NIST guidance document yet (only the RFI). It's unclear whether CAISI published a profile or overlay after March 2026.
- I found no Red Hat or CNCF guidance specific to AI agents on OpenShift/ArgoCD.

## 3. Concrete controls

### Takeaway
Hard enforcement exists, and it should carry the policy rather than instructions alone:
- **Copilot CLI**: `--deny-tool` / `--excluded-tools`. Deny beats every allow, including `--allow-all` and saved approvals.
- **VS Code**: terminal auto-approve rules, `chat.tools.edits.autoApprove` for sensitive files, terminal sandbox, enterprise policy keys.
- **Platform side**: read-only identities (OpenShift `view`, Argo CD `role:readonly` without `exec`), short-lived scoped credentials, and pinned, vetted MCP servers.

### Cited Findings
**Copilot CLI permission model**
- `--allow-tool` / `--deny-tool` take tool kinds with patterns:
  - shell: `shell(git push)`, `shell(git:*)`;
  - MCP tools: `ServerName(tool_name)`;
  - file writes: `write(path)`; `read` covers all reads.
- "Deny rules always take precedence", even over `--allow-all` and over approvals saved in `~/.copilot/permissions-config.json`. Documented example: `--allow-tool='shell(git:*)' --deny-tool='shell(git push)'`.
- `--available-tools` (allowlist) and `--excluded-tools` (denylist) remove tools from the agent entirely. If both are used, `--available-tools` wins.
- `--allow-all` / `--yolo` turns on everything.
- URL approvals are stored in `~/.copilot/settings.json` `allowedUrls`. `/reset-allowed-tools` clears saved approvals. — [GitHub Docs: allowing tools](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/allowing-tools); [GitHub Docs: configure CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/configure-copilot-cli)
- GitHub warns that approving a command like `rm` for the session lets it delete anything in the directory tree without asking. `/add-dir` trusts a directory persistently. — [GitHub Docs: use Copilot CLI](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli)

**VS Code agent mode**
- `chat.tools.terminal.autoApprove` supports per-command rules, including regex. VS Code documents "known limitations with shell aliases, quote concatenation, and complex shell syntax".
- `chat.tools.edits.autoApprove` takes globs, so sensitive files can require manual approval (example: `"**/.env": false`).
- `chat.tools.global.autoApprove` disables all approvals; VS Code warns against it.
- Restricted Mode (untrusted workspace) disables agents.
- The fetch tool uses two-step approval: trust the domain, then review the content.
- `chat.tools.terminal.sandbox` adds OS-level isolation for agent terminal commands. It's Preview on macOS/Linux and **Experimental on Windows**. Stdio MCP servers can also be sandboxed on macOS/Linux. — [VS Code: Copilot security](https://code.visualstudio.com/docs/copilot/security)
- VS Code enterprise policies:

  | Policy | Effect |
  |---|---|
  | `ChatAgentMode` | Disable agents |
  | `ChatAgentExtensionTools` | Block extension-contributed tools |
  | `ChatToolsAutoApprove` | Block global auto-approve; hides Allow all / Autopilot |
  | `ChatToolsEligibleForAutoApproval` | Force manual approval for specific tools |
  | `ChatToolsTerminalEnableAutoApprove` | Turn off rule-based terminal auto-approve |
  | `ChatMCP` (`registryOnly` / `off`) | Restrict or turn off MCP |
  | `McpGalleryServiceUrl` | Point to a private MCP registry |

  — [VS Code: Copilot security](https://code.visualstudio.com/docs/copilot/security)

**Least privilege on the platform**
- **Kubernetes/OpenShift `view` ClusterRole**: read access to most namespaced objects but *not* Secrets. `edit` can modify Secrets and ServiceAccounts and so can escalate. — [Kubernetes RBAC docs](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- **Argo CD RBAC**:
  - Built-in roles: `role:readonly` and `role:admin`.
  - Application actions: get, create, update, delete, sync, action, override.
  - `logs` (get) and `exec` (create) are separate grants.
  - Local users bind like `g, my-local-user, role:readonly`.
  - Caveat: every authenticated user gets at least `policy.default`, and "This access cannot be blocked by a 'deny' rule." — [Argo CD RBAC docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)

**Credentials, isolation and sandboxing**
- **Credential scoping**:
  - Clinejection's root cause was nightly and prod release tokens sharing an identity, plus a token that wasn't revoked after the fix.
  - Separate identities per environment.
  - Prefer short-lived/OIDC credentials.
  - Confirm revocation after an incident.
  - Don't let release jobs consume shared caches. — [Snyk](https://snyk.io/blog/cline-supply-chain-attack-prompt-injection-github-actions/)
- **Separation**: decision-making (the LLM) should be separate from the execution layer that holds credentials. Use runner-level egress/process monitoring. — [CSA](https://labs.cloudsecurityalliance.org/research/csa-research-note-ai-github-actions-security-20260503-csa-st/)
- **Exfiltration channels found so far**:
  - PR creation (Invariant);
  - image URLs via Camo (CamoLeak);
  - public comments and logs (Comment and Control);
  - public GitHub repos (s1ngularity);
  - email BCC (postmark-mcp).

  Sources: as cited in section 1.
- **Sandboxed runners alone don't stop it.** Copilot coding agent's built-in firewall and secret scanning were bypassed in Comment and Control. — [SecurityWeek](https://www.securityweek.com/claude-code-gemini-cli-github-copilot-agents-vulnerable-to-prompt-injection-via-comments/)

### Inferences
**Copilot CLI baseline invocation for this harness**
- Use `--deny-tool` for:
  - `shell(git push)`, `shell(git merge)`;
  - `shell(oc apply)`, `shell(oc delete)`, `shell(oc patch)`, `shell(oc scale)`, `shell(oc rollout)`, `shell(oc edit)`, `shell(oc exec)`, `shell(oc rsh)`, `shell(oc set)`, `shell(oc create)`;
  - the same verbs for `kubectl`;
  - `shell(argocd app sync)`, `shell(argocd app rollback)`, `shell(argocd app delete)`, `shell(argocd app set)`, `shell(argocd app patch)`;
  - `shell(vault:*)`;
  - `write(**/overlays/prod/**)`;
  - `write` for the harness config files.
- Add `--excluded-tools=web_fetch,web_search` for triage agents. Never `--yolo`.
- **Prefix-matching risk.** Denying `oc delete` might not catch `oc --namespace x delete`, or a shell script the agent writes and then runs. Back the deny list with server-side RBAC.

**VS Code**
- Put the same regex deny rules in `chat.tools.terminal.autoApprove`.
- Mark `.vscode/settings.json`, `.github/**`, `*.instructions.md`, `*.agent.md` and the prod overlays as `false` in `chat.tools.edits.autoApprove`. This closes the CVE-2025-53773 class.
- On Windows the terminal sandbox is only Experimental, so don't rely on it.

**Cluster and Argo CD identities**
- Give the agent its own ServiceAccount or token bound to `view`, scoped to the app namespaces, and nothing on PROD beyond `view`.
- `view` still allows pod logs and ConfigMaps. Both may hold sensitive data and are injection sources.
- Use a dedicated Argo CD local account with `role:readonly` and no `exec`. Check that `policy.default` isn't broader than readonly.

**Vault**
- The agent should have no Vault token at all. Vault reads stay a human step, which matches the CLAUDE.md rule.
- Make sure `VAULT_TOKEN` and `~/.vault-token` aren't present in the shell the agent uses. s1ngularity specifically hunted for token files.

### Gaps
- I didn't confirm the exact semantics of Copilot CLI pattern matching (prefix vs exact, handling of flags placed before the subcommand, chained `&&`/`;`/pipes). Test this on the work laptop with `copilot help permissions`.
- I couldn't confirm whether Copilot CLI has a deny-by-URL flag (`--deny-url`) or org-level enforcement of CLI flags.
- I found no source on Bitbucket Data Center/Cloud token scopes for read-only agent access, or on TeamCity read-only REST tokens. Check the vendor docs directly.
- Not researched: Vault agent/AI-specific guidance (HashiCorp's own MCP server and its scopes), and OpenShift Lightspeed's security model.
- Audit logging: I found no source on what Copilot CLI/agent-mode actions appear in GitHub enterprise audit logs.

## 4. GitHub Copilot enterprise/org policies

### Takeaway
The main org-level levers:
- the "MCP servers in Copilot" policy plus an allowlist, preferably through `managed-settings.json`, which is generally available and matches on name, URL or stdio command (the registry approach is weaker);
- VS Code device policies (above);
- content exclusion, which **does not apply to agent or edit mode in VS Code**, so it is no control for agent workflows.

### Cited Findings
**MCP**
- The "MCP servers in Copilot" policy decides whether MCP can run at all.
- Recommended allowlist method: a managed settings file hosted on GitHub. It's generally available, enforced enterprise-wide (overridable for teams), and does "secure matching based on name, URL, or stdio commands."
- The alternative, a custom MCP registry with the "Registry only" policy, is "public preview, not prioritized for development". It matches on name/ID only, and "Users can bypass the restriction by editing configuration files." — [GitHub Docs: MCP management](https://docs.github.com/en/copilot/concepts/enterprise/mcp-management)
- Registry/allowlist controls reached VS Code Stable in public preview on 2025-11-18 (Insiders on 2025-09-12). — [GitHub changelog 2025-11-18](https://github.blog/changelog/2025-11-18-internal-mcp-registry-and-allowlist-controls-for-vs-code-stable-in-public-preview/); [changelog 2025-09-12](https://github.blog/changelog/2025-09-12-internal-mcp-registry-and-allowlist-controls-for-vs-code-insiders/)

**Content exclusion**
- In VS Code Copilot Chat, Edit and Agent modes are "not supported".
- Copilot may still use semantic information from excluded files that the IDE supplies.
- Symlinks and remote filesystems aren't covered.
- Repo admins, org owners and enterprise owners can configure it. — [GitHub Docs: content exclusion](https://docs.github.com/en/copilot/concepts/context/content-exclusion)

### Inferences
- **Whether these levers are available depends on the work org's Copilot plan and admin settings**, which the user may not control. Ask the GitHub/Copilot admin:
  - Is MCP enabled?
  - Is there a managed-settings allowlist?
  - Is `ChatToolsAutoApprove` enforced?
  - Which models are allowed?
  - What data-retention terms apply?
- **Content exclusion can't keep secrets away from agent mode.** Secrets must not be in the workspace at all: no `.env` with real values, kubeconfig outside the repo, no Vault token files.
- **MCP vetting**:
  - Pin servers by exact version or digest.
  - Prefer first-party servers.
  - Review tool descriptions.
  - Use read-only toolsets where a server offers them.
  - Remember postmark-mcp: one line in a minor version.

### Gaps
- I didn't fetch GitHub docs on Copilot model policies, Copilot audit-log events, or prompt/suggestion data retention for Business/Enterprise. Some 2025 knowledge exists, but it isn't verified for Oct 2026.
- It's unclear whether `managed-settings.json` enforcement applies to Copilot CLI, VS Code, or both; the docs page didn't list surfaces.

## 5. Agents writing to GitOps repos

### Takeaway
I found no primary source specifically on "AI agents + GitOps". The incidents point to one rule: an agent can only *propose* changes by branch/PR. Merge, sync and PROD overlay changes stay behind human approval and server-side protections the agent's credentials can't bypass.

### Cited Findings
- Invariant's GitHub MCP exploit used PR creation as the exfiltration channel. Even "PR-only" write access is an egress path if the agent has also read untrusted content and private data in the same session. — [Invariant Labs](https://invariantlabs.ai/blog/mcp-github-vulnerability)
- Clinejection reached prod because a lower-trust workflow (nightly) shared cache and credentials with release. Separate the identities and paths for low- and high-trust changes. — [Snyk](https://snyk.io/blog/cline-supply-chain-attack-prompt-injection-github-actions/)
- Argo CD separates `applications` sync/override from get, and that permission can be withheld from the agent's identity. — [Argo CD RBAC docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
- Rule of Two: an agent that changes state should not also process untrusted input in the same session without human approval. — [Willison on Rule of Two](https://simonw.substack.com/p/new-prompt-injection-papers-agents)

### Inferences
**Recommended pattern for the DEV -> TUC -> TUD -> PROD GitOps repo**
1. The agent's Bitbucket credential can push only to `agent/*` branches. Branch permissions block pushes to main, release and prod paths. Merge needs one or more human approvals and passing builds; PROD overlays need a CODEOWNERS-style required reviewer, if Bitbucket supports it on the user's edition.
2. Run `kustomize build` on every overlay plus a policy-as-code check in CI before merge, e.g. conftest/OPA, kyverno CLI or kubeconform. Check:
   - no `:latest` tags;
   - image registry allowlist (OpenShift internal / Quay only);
   - no privileged or SCC-escalating fields;
   - no inline Secrets;
   - no changes under `overlays/prod` unless labelled.
3. Argo CD keeps auto-sync only where it already exists (DEV). For higher environments, the agent's Argo CD account has no `sync` permission.
4. Split the diagnose step (reads logs, untrusted) from the propose-change step (writes a branch) into separate agents/sessions with a human-approved handoff.
5. Defence in depth: a client-side deny `write(**/overlays/prod/**)` plus server-side branch/path restrictions.

### Gaps
- I didn't research Bitbucket-specific capabilities: path-based merge checks, CODEOWNERS support in Data Center vs Cloud, and scoped repo access tokens.
- I found no published reference architecture from Red Hat, CNCF or Argo for AI agents proposing GitOps changes. Any examples in the final report would be recommendations, not cited best practice.
- I didn't compare policy-as-code tool options (conftest vs kyverno vs OpenShift-native admission) in this pass.
