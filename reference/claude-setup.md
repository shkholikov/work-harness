# Personal Claude Code setup (Mac) - reference

Summary of `~/.claude` on the personal Mac, sent from the PLAYGROUND session.
Used as the template for the Copilot harness. The hooks, skills and agents
themselves live only on the Mac.

## Stack and preferences (global CLAUDE.md)

- TypeScript, Python. Next.js + Tailwind + shadcn/ui (Radix; existing Base UI apps keep Base UI). Node.js, REST, zod, pino, Jest, Prettier, ESLint, .env files.
- Telegram: grammY bot + Next.js Mini App + Next.js admin, pnpm + Turborepo monorepo.
- DB: PostgreSQL via Prisma, MongoDB via Mongoose. Queues: BullMQ + Redis. Docker always, Kubernetes for complex apps.
- Auth: JWT, Telegram Login, OAuth. Payments: Stripe, Telegram Stars/Payments, Payme, Click. i18n: next-intl, grammY i18n.
- Deploy: Vercel, Railway, AWS/VPS.
- UI: every app has DESIGN.md; search shadcn registries before custom UI; Magic UI animations on landing pages only.
- Style: short, direct, no emojis, no preamble. Ask questions as clickable options.
- Never push without confirmation, never force push. Commit messages: one short specific line.

## Dev workflow (repos with REVIEW.md)

1. Task: agree goal and scope (plan mode; /grilling for features). One task = one branch = one PR.
2. Branch feat/, fix/, chore/ from main. Never code on main.
3. Small steps; typecheck + affected tests after each; check UI in the running app. New code in High-risk paths comes with a test.
4. Task done: /verify (checks, verify-app agent, code-simplifier, /code-review, /security-review; High risk also silent-failure-hunter and pr-test-analyzer).
5. Ship with /commit-push-pr (PR with Testing / Risk / How to revert). Reruns /verify if code changed.
6. PR: CI + multi-agent PR review in GitHub Actions; merge by risk tier.

Risk tiers: Low = docs/copy/styles (merge after CI). Medium = everything else (merge after reading AI review). High = payments, auth, CI workflows, DB schema, env, deploy config (read every diff).
After a production bug: entry in incidents.md + proposed REVIEW.md rule.

## Hooks

- workflow-guard: blocks commits/pushes on main and PRs whose code was not verified.
- verify-stop / verify-track: no finishing a turn with unchecked code or unviewed UI changes.
- workflow-session: session-start note when a repo has not adopted the workflow.
- format-edit + prettier-config-check: format on Edit/Write.
- board-event / board-approve: local session/event board.
- Every repo: .git/hooks/pre-push blocking pushes to main.

## Skills, agents, commands

- Skills: verify, commit-push-pr, review-setup, grilling, writing-for-agents, impeccable, ithink-documents, system-diagram, topology-creator, codebase-design, diagnosing-bugs, click-path-audit, git-guardrails-claude-code, setup-pre-commit, standards-code-review, ecc-security-review; patterns: api-design, backend, frontend, frontend-a11y, react-performance, react-testing, e2e-testing, error-handling, docker, kubernetes, deployment, postgres, prisma, redis; threejs-* (11).
- Agents: verify-app, telegram-bot-reviewer, prisma-auditor, monorepo-auditor, impeccable-* (4).
- Commands: /audit, /changes, /dns, /ports, /predeploy, /spend, /stack.
- Plugins: github, context7, playwright, vercel, railway, remember, security-guidance, code-simplifier, pr-review-toolkit, claude-md-management, claude-security, theme-examples.
- MCP: shadcn, meta-ads, metapilot-native, Claude in Chrome.
- Other: custom statusline; ~/.claude is a git repo; scripts/doctor.sh checks the setup; backups via scripts/backup.sh.
