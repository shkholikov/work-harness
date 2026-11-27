# work-harness

Private harness for GitHub Copilot and Microsoft 365 Copilot on the work laptop
(Windows, PowerShell 7, user-level installs, no admin rights).

- Copilot CLI: global instructions, custom agents, skills, MCP config
- VS Code + Copilot: user instructions, prompt files, custom agents
- Microsoft 365 Copilot: custom instructions, saved prompts, agents

Company-internal values (hosts, URLs, paths, keys) stay placeholders in this repo.

## v1: general Copilot setup + SPFx

Setup on the work laptop: [`docs/work-laptop-setup.md`](docs/work-laptop-setup.md).

| Folder | What | Installed by |
|---|---|---|
| [`user/`](user/) | Global instructions, agents (planner, reviewer, reviewer-high, deep-reviewer), skills (grill, ship), guard hook, settings, deny list, VS Code keys | `install/install.ps1` into `~/.copilot` |
| [`templates/spfx/`](templates/spfx/) | Repo setup for SPFx: instructions, skills (verify, dev, upgrade-spfx), repo guard, `REVIEW.md`, dev/verify scripts, Playwright smoke test, pre-push hook | `install/new-spfx-setup.ps1 -RepoPath <repo>` |
| [`install/`](install/) | `install.ps1`, `uninstall.ps1`, `new-spfx-setup.ps1` | |

DevOps parts (GitOps repo, TeamCity/Dockerfile layer, triage) come in v2; see [`TODO.md`](TODO.md).

## Contents

- [`docs/work-laptop-setup.md`](docs/work-laptop-setup.md): install and guardrail tests on the work laptop
- [`docs/history.md`](docs/history.md): discussion history and open items
- [`docs/tech-stack.md`](docs/tech-stack.md): work tech stack and guardrails
- [`docs/copilot-cli-cheatsheet.md`](docs/copilot-cli-cheatsheet.md): Copilot CLI cheat sheet (costs, commands, modes, permissions)
- [`reference/claude-setup.md`](reference/claude-setup.md): personal Claude Code setup used as the template
- [`TODO.md`](TODO.md): build plan for the harness
- [`CLAUDE.md`](CLAUDE.md): instructions for authoring this repo on the Mac with Claude Code
- [`docs/cicd/cicd-flow.html`](docs/cicd/cicd-flow.html): CI/CD today vs target, with diagrams
- [`reports/`](reports/): agentic CI/CD research report
- [`research_notes/`](research_notes/): research notes behind the report
