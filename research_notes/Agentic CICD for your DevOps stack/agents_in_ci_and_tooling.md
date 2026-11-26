# AI coding agents in CI/CD and AI features of CI/source-hosting tools (Bitbucket + TeamCity focus, as of Oct 2026)

Research date: 2026-10-06. "Verified" below means seen in a fetched page this session. Items from prior knowledge that I could not re-check are listed under Gaps and marked as unverified.

## GitHub Copilot CLI: can it run headless in a CI job (TeamCity), with what flags, auth, plan and terms?

### Takeaway
Yes. Copilot CLI has an official programmatic mode (`copilot -p "<prompt>"`) with tool allow/deny flags, and it authenticates in CI through an environment variable holding a fine-grained PAT with the "Copilot Requests" permission. Nothing in it is tied to GitHub Actions: it runs on any machine with the binary and the token, so a TeamCity agent works. GitHub's official CI docs and examples cover only GitHub Actions, and I found no GitHub statement that allows or forbids running it on non-GitHub CI.

### Cited Findings
- Official "automate with Actions" doc shows programmatic mode: `copilot -p "Review the git log..." --allow-tool='shell(git:*)' --allow-tool=write --no-ask-user`. `-p` runs non-interactively and exits when done. `--no-ask-user` stops the agent asking clarifying questions, which an unattended run needs. — [GitHub Docs: automate Copilot CLI with Actions](https://docs.github.com/en/copilot/how-tos/copilot-cli/automate-with-actions)
- That doc's auth: `COPILOT_GITHUB_TOKEN` set to a personal access token with the "Copilot Requests" permission, recommended. For org-owned repos inside Actions, the built-in `GITHUB_TOKEN` is an alternative. The doc mentions no CI system other than GitHub Actions. — [GitHub Docs: automate with Actions](https://docs.github.com/en/copilot/how-tos/copilot-cli/automate-with-actions)
- Supported token types: OAuth `gho_` (the default, via `copilot login`), fine-grained PAT `github_pat_` ("must be owned by your personal account (not an organization)", with the Copilot Requests permission), and GitHub App user-to-server `ghu_` (environment variable only). Classic PATs `ghp_` are "Not supported by Copilot CLI". — [GitHub Docs: Authenticate Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/authenticate-copilot-cli)
- Credential precedence: `COPILOT_GITHUB_TOKEN` > `GH_TOKEN` > `GITHUB_TOKEN` > OAuth token in the keychain > GitHub CLI fallback. "An environment variable silently overrides a stored OAuth token." The environment-variable route is "Recommended for CI/CD pipelines, containers, and non-interactive environments." — [GitHub Docs: Authenticate Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/authenticate-copilot-cli)
- Flags for headless runs, from a community write-up dated 2026-07-27 against CLI 1.0.69-2:

  | Flag | Effect |
  |------|--------|
  | `-p/--prompt` | Run one prompt non-interactively |
  | `-s` | Plain output, no stats or decoration |
  | `--no-ask-user` | Do not block on clarification requests |
  | `--model=` | Pin the model, e.g. `claude-sonnet-4.6` |
  | `--allow-tool='shell(git:*)'` | Allow one tool family |
  | `--deny-tool='shell(git push)'` | Block a command; denials win over allows |
  | `--allow-all-tools` | Allow every tool |
  | `--allow-all` / `--yolo` | Allow all tools, paths and URLs |
  | `--agent=<name>` | Run a custom agent |
  | `--secret-env-vars=VAR1,VAR2` | Redact those values from output |
  | `--max-ai-credits <n>` | Spending cap |
  | `--max-autopilot-continues <n>` | Cap on autopilot continuations |
  | `--cloud` | Cloud execution, public preview |

  Each prompt uses premium requests / AI credits. Its only examples are GitHub Actions, cron and Windows Task Scheduler; there are none for TeamCity, Jenkins or Azure DevOps. Community source, not GitHub docs. — [devleader.ca, 2026-07-27](https://www.devleader.ca/2026/07/27/running-github-copilot-cli-in-scripts-and-cicd-pipelines-headless-mode)
- Copilot Business ($19/user/month) and Enterprise ($39/user/month) include Copilot CLI. An organization or enterprise policy controls whether users can use it, and enterprise-level settings override org settings. Business/Enterprise source is a secondary knowledge-base page; the policy statement is from GitHub Docs. — [GitHub Docs: Copilot policies](https://docs.github.com/en/copilot/concepts/enterprise/policies); [inventivehq KB](https://inventivehq.com/knowledge-base/copilot/how-to-set-up-enterprise)
- gh-aw pins Copilot CLI versions per workflow (example `"0.0.422"`), so the CLI is versioned and pinnable for reproducible CI. — [gh-aw engines reference](https://github.github.com/gh-aw/reference/engines)

### Inferences
- In TeamCity: install the CLI on the agent image (npm package, or the Windows/Linux binary), store a fine-grained PAT as a TeamCity password parameter, expose it as `env.COPILOT_GITHUB_TOKEN`, and run `copilot -p ... --no-ask-user --allow-tool=... --deny-tool=...` in a command-line or PowerShell step. The repo can stay in Bitbucket; Copilot CLI only needs a local working directory.
- The PAT must belong to a person, not an organization, and draws on that person's Copilot seat and premium-request quota. A shared bot user would need its own Copilot seat. Check that against corporate policy and GitHub's terms.
- `--deny-tool` gives hard enforcement of the harness guardrails in CI, for example `--deny-tool='shell(git push)'`, `--deny-tool='shell(oc apply)'` and `--deny-tool='shell(vault)'`, together with a narrow `--allow-tool` list rather than `--allow-all`.

### Gaps
- No GitHub terms-of-service or product-specific-terms text was found that addresses running Copilot CLI with a personal PAT on non-GitHub CI (TeamCity), or using one person's seat for automation. Treat this as unresolved; it needs the user's GitHub admin or legal team.
- The flag list (`-s`, `--secret-env-vars`, `--max-ai-credits`, `--cloud`) came from a community article, not the official CLI reference page, which I did not fetch. Run `copilot --help` on the installed version before relying on it.
- Whether Copilot Free/Pro plans allow programmatic/CI use, and whether a GitHub App installation token (rather than user-to-server) works, was not confirmed.

## GitHub Agentic Workflows (gh-aw) and the Copilot coding agent: what they are, and are they GitHub-only?

### Takeaway
Both are GitHub-only. The Copilot coding agent (now called "Copilot cloud agent" in the docs) works only on GitHub-hosted repositories. gh-aw compiles Markdown workflows into GitHub Actions and is documented only for GitHub repos. Neither is usable directly with Bitbucket + TeamCity, but gh-aw's pattern (Markdown-defined agent tasks with scoped tools and permissions) can be copied by hand.

### Cited Findings
- "Copilot cloud agent only works with repositories hosted on GitHub." It runs in an ephemeral cloud environment, one repo, one branch and one PR per task, with a maximum session of "59 minutes. This limit cannot be extended or bypassed." Tasks come from the Agents panel, Copilot Chat, issues/PRs, security campaigns, Teams and Slack. — [GitHub Docs: About Copilot coding/cloud agent](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent)
- The Azure Boards integration sends work items to Copilot's coding agent, but the code still has to live in a GitHub repository, not Azure Repos. — [GitHub Docs: integrate coding agent with Azure Boards](https://docs.github.com/ko/copilot/how-tos/use-copilot-agents/coding-agent/integrate-coding-agent-with-azure-boards); [Azure DevOps blog, 2025-09-16](https://devblogs.microsoft.com/devops/azure-boards-integration-with-github-copilot-private-preview/)
- gh-aw: repository automation defined in Markdown with YAML frontmatter (triggers, permissions, tools, engine), run through GitHub Actions. Technical preview shipped 2026-02-13. Go module versions around v0.87.x. — [GitHub Docs: develop agentic workflows](https://docs.github.com/en/actions/tutorials/develop-agentic-workflows-in-github-actions); [pkg.go.dev gh-aw v0.87.2](https://pkg.go.dev/github.com/github/gh-aw@v0.87.2); [Daniel Vaughan, 2026-03-28](https://codex.danielvaughan.com/2026/03/28/github-agentic-workflows-codex-integration/)
- gh-aw engines and their auth:

  | Engine | Auth | Status |
  |--------|------|--------|
  | Copilot CLI | `copilot-requests: write` or `COPILOT_GITHUB_TOKEN` | Default |
  | Claude Code | `ANTHROPIC_API_KEY` or Anthropic WIF | Supported |
  | Codex | `CODEX_API_KEY` or `OPENAI_API_KEY` | Supported |
  | Gemini CLI | `GEMINI_API_KEY` or Google WIF | Supported |
  | Pi | Copilot auth by default | Supported |

  OpenCode, Aider, Crush, Cursor, Goose, Kiro and others are "samples only" with no support commitment. The reference covers only GitHub Actions and GitHub repos. — [gh-aw engines reference](https://github.github.com/gh-aw/reference/engines)

### Inferences
- With Bitbucket + TeamCity, the useful parts of gh-aw are its design ideas, not its code. The ideas: a Markdown task file per workflow, frontmatter declaring allowed tools, a read-only default with explicit write outputs, and pinned engine versions. Each of these maps to a TeamCity build configuration that runs `copilot -p` or `claude -p` with a prompt file from the repo.
- Mirroring the Bitbucket repo to GitHub just to use the coding agent or gh-aw is technically possible but adds a second source of truth. It is probably out of scope for a Bitbucket-standard company.

### Gaps
- I found no statement on gh-aw roadmap support for non-GitHub hosts. GHES support status for gh-aw was not checked.

## Claude Code headless / Agent SDK, OpenAI Codex exec and similar: mechanism, and do they run in any CI (e.g. a TeamCity agent)?

### Takeaway
Both are plain CLIs with documented non-interactive modes, structured JSON output and API-key auth, so they run on any CI agent, TeamCity included. Their vendor docs ship first-party integrations only for GitHub Actions (both) and GitLab CI (Claude). Neither has an official TeamCity or Bitbucket integration, so on TeamCity you call the CLI from a build step.

### Cited Findings
- **Claude Code basics.** `claude -p "<prompt>"` (alias `--print`) runs non-interactively. It exits 0 on success and non-zero on failure. It reads stdin (capped at 10 MB), so `cat build-error.txt | claude -p '...'` works. — [Claude Code docs: Run programmatically](https://code.claude.com/docs/en/headless)
- **`--bare` mode.** It skips auto-discovery of hooks, skills, plugins, MCP servers, memory and CLAUDE.md, and is "recommended mode for scripted and SDK calls, and will become the default for `-p` in a future release." In bare mode, auth comes from `ANTHROPIC_API_KEY` or an `apiKeyHelper`; Bedrock, Google Cloud and Microsoft Foundry read their own credentials. Context is loaded explicitly with `--append-system-prompt[-file]`, `--settings`, `--mcp-config`, `--agents` and `--plugin-dir`. — [Claude Code docs: headless](https://code.claude.com/docs/en/headless)
- **Untrusted-repo risk.** Without `--bare`, a `-p` session runs the hooks in the project's `.claude/settings.json` and connects the servers in its `.mcp.json` "even in a folder you've never trusted", with no trust dialog. This matters when CI runs on PR branches. — [Claude Code docs: headless](https://code.claude.com/docs/en/headless)
- **Permissions.**
  - `--allowedTools` uses rule syntax such as `"Bash(git diff *),Read"`.
  - `--permission-mode` takes `dontAsk`, `acceptEdits` or `auto`. `dontAsk` denies anything that would prompt and is described as useful "for locked-down CI runs".
  - `--permission-prompts none` (v2.1.259+) is for unattended runs.
  - Denials are reported in `permission_denials` in stream-json output.

  — [Claude Code docs: headless](https://code.claude.com/docs/en/headless)
- **Structured output.** `--output-format json` returns `result`, `session_id` and `total_cost_usd`. `--json-schema` returns `structured_output`. `stream-json` emits `system/init`, which includes `mcp_server_errors` and `plugin_errors` so CI can fail when an MCP server doesn't load. — [Claude Code docs: headless](https://code.claude.com/docs/en/headless)
- **SIGTERM.** A CI timeout that sends SIGTERM makes the run exit with code 143. — [Claude Code docs: headless](https://code.claude.com/docs/en/headless)
- **Agent SDK.** It exposes the same agent loop as the CLI (`claude -p`, for scripts and CI/CD) and as Python/TypeScript packages. The docs have first-party guides for GitHub Actions and GitLab CI/CD only. — [Claude Code docs: headless](https://code.claude.com/docs/en/headless)
- **Codex.** `codex exec` is the non-interactive mode.
  - Flags: `--sandbox workspace-write | danger-full-access`, `--skip-git-repo-check`, `--json` (JSONL event stream), `-o/--output-last-message <path>`, `--output-schema <path>`, `--ephemeral`, `--ignore-user-config`, `--ignore-rules`, and `codex exec resume --last`.
  - CI auth: `CODEX_API_KEY=<key> codex exec --json "task"`, or a seeded `~/.codex/auth.json` for ChatGPT-managed auth.
  - The official GitHub Action `openai/codex-action` is recommended for Actions.
  - Pattern: `npm test 2>&1 | codex exec "summarize failures"`.

  — [OpenAI Codex docs: Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)
- **Rovo Dev CLI** (Atlassian's agent) runs inside Bitbucket Pipelines. The build container needs `USER_API_TOKEN` (secret), `USER_EMAIL` and `BILLING_SITE_URL`, and Rovo Dev plus Rovo Dev CLI access must be enabled for the account. — [Atlassian Support: Work with Rovo Dev in Bitbucket Pipelines](https://support.atlassian.com/rovo/docs/work-with-rovo-dev-in-bitbucket-pipelines/)

### Inferences
- On a Windows TeamCity agent, all three CLIs (Copilot, Claude Code, Codex) can be called from a PowerShell step. The common shape:
  1. Fetch context through the TeamCity REST API or MCP.
  2. Pipe it into `-p`/`exec`.
  3. Request JSON or schema output.
  4. Post the result back to Bitbucket with REST.
- For a Copilot-only harness, Copilot CLI is the natural engine because the same custom agents and instructions work in VS Code, the CLI and CI. Claude Code and Codex are alternatives only if the company provides API keys.
- Rovo Dev CLI's Pipelines integration depends on Atlassian Cloud credentials. Whether it can run on TeamCity against Bitbucket DC is unverified (see Gaps).

### Gaps
- No vendor documentation for TeamCity specifically was found for Claude Code, Codex or Copilot CLI.
- Whether Rovo Dev CLI can run outside Bitbucket Pipelines (for example on a TeamCity agent) or against Bitbucket Data Center was not verified.
- Licensing for using Claude Code with a Claude subscription in CI versus API keys was not examined. The docs say bare mode does not use subscription login.

## TeamCity: built-in AI features, MCP server, REST API for agents, Kotlin DSL + AI

### Takeaway
TeamCity has three official AI pieces as of 2026:
- A built-in MCP endpoint at `<server>/app/mcp`, safe by default.
- An open-source `teamcity` CLI with an installable agent skill.
- An AI Assistant and AI Build Analyzer that explain failed builds. These are Enterprise-licensed on-prem; Cloud got them first.

A mature third-party MCP server (Daghis/teamcity-mcp) covers older versions and write operations. This is the strongest non-GitHub agent story in the user's stack.

### Cited Findings
- **TeamCity 2026.1** (May 2026) shipped:
  - A free open-source TeamCity CLI with 60+ commands, installable via Homebrew, bash, winget, PowerShell or npm, including an agent skill so AI coding agents can "check build status, analyze failures, and interact with your Pipeline".
  - MCP support for external AI tools such as JetBrains IDEs and Cursor.
  - AI Assistant now included in Enterprise trial licenses; before that it was Enterprise-only.
  - Kotlin DSL support in the new Pipelines alongside YAML.

  — [JetBrains blog: TeamCity 2026.1](https://blog.jetbrains.com/teamcity/2026/05/teamcity-20261/); [daily.dev summary](https://daily.dev/posts/teamcity-2026-1-cli-mcp-for-ai-agents-pipelines-enhancements-and-more-0dxq69rd4)
- **MCP endpoint.** `<server-url>/app/mcp`. Auth is a Bearer access token in the `Authorization` header, or OAuth/PKCE via `<server>/pkce/authorize.html`. Example: `claude mcp add --transport http buildserver <TeamCity-server-URL>/app/mcp --header "Authorization: Bearer $TC_AUTH_TOKEN"`. — [TeamCity 2026.2 Help: AI agent integration](https://www.jetbrains.com/help/teamcity/2026.2/ai-agent-integration.html)
- **MCP tools:**

  | Tool | Behaviour |
  |------|-----------|
  | `teamcity_build_log` | Full log, paginated, filterable by message type |
  | `teamcity_rest_get` | Any REST GET, within the token's scope |
  | `teamcity_rest_post` | In safe mode, limited to `/app/rest/buildQueue` and forced to `personal=true` builds |
  | `teamcity_pipeline_get` | Read pipelines |
  | `teamcity_pipeline_post` | Create or update pipelines; unavailable in safe mode |
  | `teamcity_pipeline_delete` | Delete pipelines/projects; unavailable in safe mode |

  "Brave mode" is opt-in through the server property `teamcity.ai.mcp.braveMode.enabled=true` and defaults to false. — [TeamCity 2026.2 Help](https://www.jetbrains.com/help/teamcity/2026.2/ai-agent-integration.html)
- **TeamCity CLI.** Binary `teamcity`. Install with `brew install jetbrains/utils/teamcity`, `curl -fsSL https://jb.gg/tc/install | bash`, `winget install JetBrains.TeamCityCLI`, or `irm https://jb.gg/tc/install.ps1 | iex`. Agent skill: `teamcity skill install [--project] [--agent]`. Read-only mode: `export TEAMCITY_RO=1`. — [TeamCity 2026.2 Help](https://www.jetbrains.com/help/teamcity/2026.2/ai-agent-integration.html)
- **AI Assistant and AI Build Analyzer.** Powered by the JetBrains AI platform, with early access in TeamCity 2025.11. The AI Build Analyzer "reads the logs and tells you why, complete with a summary, root cause, and possible fixes". It reached TeamCity Cloud in early 2026, "with on-prem support following soon after". — [JetBrains blog livestream recap, Oct 2025](https://blog.jetbrains.com/teamcity/2025/10/livestream-recording-maximizing-teamcity/); [TeamCity Roadmap](https://www.jetbrains.com/teamcity/roadmap/)
- **2026 roadmap focus.** "agentic interfaces and scenarios" (CLI, MCP and agent-skills compatibility for configuration, migration, observability, build running, failure analysis and fix options). — [TeamCity Roadmap](https://www.jetbrains.com/pages/teamcity-roadmap)
- **Community MCP: Daghis/teamcity-mcp.**
  - 87 tools.
  - Dev mode (default): 31 safe tools, including TriggerBuild, GetBuildStatus, FetchBuildLog, ListTestFailures and AnalyzeBuildProblems.
  - Full mode: queue management, agent operations and `create_build_config`.
  - Status as of June 2026: "stable with low-key maintenance and is no longer under active development". The project itself points to JetBrains' official MCP and CLI.
  - Comparison in the same source: the built-in endpoint is the default for "read-and-rerun", and teamcity-mcp suits workflows needing writes, multi-server support or pre-2026.1 servers.

  — [GitHub: Daghis/teamcity-mcp](https://github.com/Daghis/teamcity-mcp); [mcpservers.org listing](https://mcpservers.org/servers/daghis/teamcity-mcp)

### Inferences
- Version check comes first. If the work TeamCity is older than 2026.1, there is no built-in `/app/mcp`. The options are then the `teamcity` CLI (which talks REST and may work against older servers, unverified), Daghis/teamcity-mcp, or raw REST.
- Safe mode lines up with the harness guardrails: reads are free and triggers are personal builds only. Leave brave mode off. Use a TeamCity access token scoped to a read-mostly role.
- The AI Assistant and Build Analyzer are UI features for humans. For agent workflows, MCP/CLI/REST is the integration surface.
- A Copilot "TeamCity failure triage" graph can use the built-in MCP from VS Code agent mode (an HTTP MCP entry in `mcp.json` with a Bearer header) with no CI-side agent at all.

### Gaps
- Exact on-prem availability and licence of the AI Build Analyzer as of Oct 2026 were not confirmed. The 2026.1 notes say the AI Assistant needs Enterprise (now also trial). Whether it requires a JetBrains AI subscription or sends logs to JetBrains' cloud LLM was not verified, and this matters for data-residency approval.
- **REST endpoints useful to agents.** These are from prior knowledge and were not re-verified this session:
  - Build log: `GET /downloadBuildLog.html?buildId=<id>` or `/app/rest/builds/id:<id>/log`.
  - Failed tests: `GET /app/rest/testOccurrences?locator=build:(id:<id>),status:FAILURE`.
  - Problems: `GET /app/rest/problemOccurrences?locator=build:(id:<id>)`.
  - Changes: `GET /app/rest/changes?locator=build:(id:<id>)`.
  - Trigger: `POST /app/rest/buildQueue`.

  The MCP doc confirms only `/app/rest/buildQueue`.
- Outbound webhooks on build failure: I believe TeamCity has no native generic webhooks (the tcWebHooks plugin is the usual answer), but this was not verified this session. Notifier and plugin options need checking.
- The "Kotlin DSL + AI" story: nothing found beyond the agent-facing pipeline tools (`teamcity_pipeline_*`) and Kotlin DSL in Pipelines. No JetBrains feature that generates Kotlin DSL with AI was found. Not relevant if the user keeps UI-configured builds.

## Bitbucket (Cloud and Data Center): Rovo AI code review, MCP servers, Pipelines vs DC, APIs for an AI reviewer

### Takeaway
The answer depends on whether the company's Bitbucket is Cloud or Data Center; the CLAUDE.md does not say.

| Capability | Bitbucket Cloud | Bitbucket Data Center |
|------------|-----------------|-----------------------|
| Native AI code review | Rovo Dev Code Reviewer, GA Oct 2025 | None documented as of Sept 2026 |
| Agentic pipelines / autofix | Rovo Dev Agentic Pipelines | No |
| MCP | Atlassian Rovo MCP Server with Bitbucket tools | Bundled MCP plugin (Bitbucket 10.5+, Marketplace for 9.x/10.x), released 2026-09-29 |

A self-built AI reviewer on DC posts through the PR comment REST API and/or Code Insights reports and annotations.

### Cited Findings
- **Rovo Dev Code Reviewer.** Reviews PRs for quality, security and performance. Rovo Dev went GA in Oct 2025. Atlassian claims, in an ICSE 2026 paper over ~1,900 repos, a 30.8% cut in PR cycle time and 35.6% fewer human review comments. That claim is vendor-sourced. One Atlassian source says the reviewer is built on Claude 3.5 Sonnet, which is likely outdated. — [Atlassian blog: developer productivity with Rovo Dev](https://www.atlassian.com/blog/ai-at-work/developer-productivity-improved-with-rovo-dev); [Atlassian Rovo Dev code review](https://www.atlassian.com/ko/software/rovo-dev/code-review)
- **Cloud-only.** Native AI-assisted review exists only on Bitbucket Cloud (Standard, Premium or Enterprise plans). "If your team is on Data Center, the vendor documents no native option as of 2026-09-17." The suggested DC integration points are repository hooks, pre-receive hooks and branch permissions as merge gates. — [DEV Community, Emil Reiter, 2026-09-17](https://dev.to/emilreiter/ai-code-review-on-bitbucket-data-center-whats-native-what-isnt-2b7j)
- **Rovo Dev in Bitbucket Pipelines (Cloud).** It summarises changes, explains failed build steps and suggests fixes. "Agentic pipelines" let Rovo Dev autonomously fix issues and push changes back to the branch. Container env: `USER_API_TOKEN`, `USER_EMAIL`, `BILLING_SITE_URL`. — [Atlassian Support: Rovo Dev in Bitbucket Pipelines](https://support.atlassian.com/rovo/docs/work-with-rovo-dev-in-bitbucket-pipelines/); [Atlassian blog: AI-powered workflows with Rovo Dev](https://www.atlassian.com/blog/bitbucket/ai-powered-workflows-rovodev); [Bitbucket Cloud: Agentic Pipelines guide](https://support.atlassian.com/ja/bitbucket-cloud/docs/agentic-pipelines/)
- **Atlassian Rovo MCP Server (remote, Cloud) Bitbucket tools:**
  - bitbucketWorkspace list/get
  - bitbucketRepository list/get
  - bitbucketPullRequest create/get/list/merge/approve/comment/comments/diff
  - bitbucketRepoContent branch/commit/files
  - bitbucketPipelines list/run/get/steps/step.log
  - bitbucketDeployments
  - bitbucketEnvironments (including create/delete/update)

  Setup: an org admin enables API-token auth under Admin Hub > Rovo > Rovo MCP Server, and the Bitbucket Cloud workspace must be org-linked. — [Atlassian blog: Rovo MCP Server now supports Bitbucket Cloud](https://www.atlassian.com/blog/bitbucket/the-atlassian-rovo-mcp-server-now-supports-bitbucket-cloud)
- Rovo MCP v2 reached GA on 2026-09-08, adding Bitbucket, Loom, Goals and others. — [Atlassian: Rovo MCP Server GA](https://www.atlassian.com/blog/announcements/atlassian-rovo-mcp-ga); [Rovo MCP changelog](https://developer.atlassian.com/cloud/rovo-mcp/changelog/)
- **MCP for Bitbucket Data Center.** Released 2026-09-29. Bundled plugin in Bitbucket 10.5, and on the Marketplace for 9.x/10.x. HTTP endpoint `https://<bitbucket>/rest/mcp/1.0/` with `Authorization: Bearer <token>`. Tools cover projects, repositories, pull requests and code. Admins whitelist which REST endpoints are exposed as tools in `BITBUCKET_HOME/shared/mcp-tools.json`, and rate limiting is recommended. — [Atlassian Developer Community: MCP for Bitbucket DC released](https://community.developer.atlassian.com/t/mcp-for-bitbucket-dc-has-been-released/102963)
- **Code Insights (Bitbucket Server/DC).** A CI tool or bot PUTs a report per commit and POSTs annotations. Reports show on the PR overview with title, pass/fail and up to 6 data fields. Annotations attach to changed lines with a severity, and "only annotations that are on lines that have been changed in a pull request are displayed". The token needs only "repository read" permission. "Posting a failed report will not stop a pull request from being merged." — [Atlassian Developer: Bitbucket Code Insights how-to](https://developer.atlassian.com/server/bitbucket/how-tos/code-insights/)
- **Community/third-party Bitbucket MCP servers.** Examples include gemyago/atlacp and many listings on MCP directories. Not evaluated. — [glama.ai: atlacp](https://glama.ai/mcp/servers/@gemyago/atlacp); [mcp.directory guide](https://mcp.directory/blog/bitbucket-mcp-complete-guide-2026)

### Inferences
- If the company runs Bitbucket DC with TeamCity Enterprise (likely, since both are self-managed), then:
  - Rovo Dev review, Agentic Pipelines and the Rovo MCP server are unavailable.
  - The usable official pieces are the DC MCP plugin (if Bitbucket is 10.5+ or the plugin is installed) plus REST.
- The DC `mcp-tools.json` whitelist lets the Bitbucket admin enforce "no merge, no push" at the server, which backs the harness guardrail on PR merges with a hard control.
- **AI reviewer for GitOps/Kustomize PRs on DC.** A TeamCity build triggered on the PR branch runs `kustomize build` plus the agent CLI with a review prompt. It writes a Code Insights report (pass/fail plus line annotations) and optionally a summary PR comment. Because a failed Insights report doesn't block merges, gating requires a separate build-status merge check or required-builds setting.

### Gaps
- Whether the company is on Bitbucket Cloud or DC (and which version) is unknown and decides most of this section. Ask the user.
- **PR comment REST endpoints.** From prior knowledge, not re-verified this session:
  - DC: `POST /rest/api/1.0/projects/{projectKey}/repos/{repositorySlug}/pull-requests/{pullRequestId}/comments`. Inline comments go in an `anchor` object with path/line/lineType/fileType.
  - Cloud: `POST /2.0/repositories/{workspace}/{repo_slug}/pullrequests/{id}/comments`.
- **Code Insights path prefix.** The fetched summary gave `/rest/projects/{projectKey}/repos/{slug}/commits/{commitId}/reports/{key}`. My prior knowledge is that the real prefix is `/rest/insights/1.0/` (or `/rest/insights/latest/`). Verify against the instance's REST docs.
- The full DC MCP tool list and whether it exposes write operations (create PR, comment, merge) by default were not listed in the announcement.
- Rovo Dev pricing/credits for code review and Agentic Pipelines were not gathered.

## Real-world patterns: AI build-failure triage bots, AI PR reviewers for infra/manifests, auto-fix PRs on non-GitHub CI

### Takeaway
The documented, vendor-supported patterns are mostly inside a single ecosystem: GitHub (gh-aw, coding agent, codex-action, claude-code-action), Bitbucket Cloud (Rovo Dev Agentic Pipelines) and TeamCity (Build Analyzer, MCP). For Bitbucket DC + TeamCity there is no turnkey product. The working pattern is DIY glue: TeamCity build step → agent CLI in headless mode → TeamCity REST/MCP for context → Bitbucket REST/Code Insights for output. Specific engineering write-ups for exactly this combination were not found.

### Cited Findings
- **Vendor pattern 1, build-failure triage.** TeamCity's AI Build Analyzer gives a summary, root cause and possible fixes from logs. TeamCity's 2026 roadmap targets agentic "failure analysis and fix options" through CLI, MCP and skills. — [JetBrains blog Oct 2025](https://blog.jetbrains.com/teamcity/2025/10/livestream-recording-maximizing-teamcity/); [TeamCity Roadmap](https://www.jetbrains.com/pages/teamcity-roadmap)
- **Vendor pattern 2, explain and auto-fix a failed step.** Rovo Dev in Bitbucket Pipelines explains failed steps in plain language and, with Agentic Pipelines, "autonomously fix issues, apply suggestions, and push changes back to your branch". This is Bitbucket Cloud only. — [Atlassian Support](https://support.atlassian.com/rovo/docs/work-with-rovo-dev-in-bitbucket-pipelines/)
- **Generic CLI patterns** from the vendor docs: `cat build-error.txt | claude -p 'concisely explain the root cause...'`, `npm test 2>&1 | codex exec "summarize failures"`, and the diff-to-reviewer pattern `gh pr diff | claude -p --append-system-prompt "You are a security engineer..." --output-format json` (the diff source can be swapped for `git diff` or Bitbucket's diff endpoint). — [Claude Code headless docs](https://code.claude.com/docs/en/headless); [Codex non-interactive docs](https://learn.chatgpt.com/docs/non-interactive-mode)
- **Safety guidance from the community write-up:** "Start headless Copilot CLI from read-only diagnostics, then widen permissions only when you can explain why the workflow needs them." — [devleader.ca 2026-07-27](https://www.devleader.ca/2026/07/27/running-github-copilot-cli-in-scripts-and-cicd-pipelines-headless-mode)
- **Merge gates on Bitbucket DC.** Repository hooks, pre-receive hooks and branch permissions. — [DEV Community 2026-09-17](https://dev.to/emilreiter/ai-code-review-on-bitbucket-data-center-whats-native-what-isnt-2b7j)

### Inferences
These are proposed wirings for Bitbucket + TeamCity + OpenShift/ArgoCD. They are not sourced case studies.

1. **TeamCity failure triage.** A follow-up build configuration (finish-build trigger on failure, or a snapshot dependency with "run even if dependency failed"):
   1. Pulls the failed build's log, failed tests and changes through REST or `teamcity_build_log`/`teamcity_rest_get`.
   2. Runs `copilot -p` (or `claude -p --bare --permission-mode dontAsk`) with a triage prompt and JSON output.
   3. Posts the summary as a Bitbucket PR comment or Code Insights report, and/or as a TeamCity build tag or comment.

   Read-only throughout. Alternatively, run it interactively from VS Code with the TeamCity MCP, with no CI-side agent.
2. **GitOps overlay PR review.** On a PR to the GitOps repo, TeamCity runs `kustomize build` for each changed overlay and diffs the rendered manifests against the target branch. An agent reviews the rendered diff (image tag, resources, probes, PROD overlay touched?) and posts a Code Insights report with line annotations. A deterministic check, not the AI, fails the build when a PROD overlay changed without an approval label, and branch permissions or required builds make that the merge gate.
3. **Auto-fix PRs.** The agent proposes a patch on a new branch. Pushing and opening a PR uses a bot token whose Bitbucket permissions allow branch creation but not merge. Per the guardrails, any push still needs human confirmation, so for this harness auto-fix should stop at "patch as artifact plus suggested diff in a PR comment" unless the user relaxes that rule.
4. **Deny-list layering.** Copilot CLI `--deny-tool` and a narrow `--allow-tool` set in the TeamCity step, TeamCity MCP safe mode, the Bitbucket DC MCP `mcp-tools.json` whitelist, and least-privilege tokens (TeamCity read role, Bitbucket repo-read token for Code Insights). The agent never gets `oc`, `argocd` or Vault credentials in CI.

### Gaps
- No credible engineering-blog case study was found of AI triage or review wired specifically into TeamCity + Bitbucket DC. Patterns above are inferred from the components.
- Not researched: commercial third-party AI reviewers that support Bitbucket DC (e.g. CodeRabbit, Qodo/PR-Agent, Sourcery, CodeAnt), or AI features in ArgoCD/OpenShift (e.g. OpenShift Lightspeed). Worth a separate pass if the report needs vendor options.
