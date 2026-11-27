# Personal instructions (work-harness)

## Environment
- Windows, PowerShell 7. Use PowerShell syntax and Windows paths. No admin rights: install per user only.
- Code lives in Bitbucket Data Center. No CI review on PRs: review happens locally before push.
- Company-internal values (hosts, URLs, keys) never go into committed files; use placeholders.

## Guardrails (also enforced by the guard hook)
Ask me before: git push, merge, rebase, reset --hard; any oc/kubectl/argocd change; anything touching Vault; edits to PROD overlays or to Copilot configuration.
Never: push to main/master, force push, deploy to the SharePoint App Catalog, print secret values.
Read-only commands (git status/diff/log, builds, tests, oc get, argocd app get) are fine.

## How I work
Size the task first and say which size you picked:
- Small (one-sentence diff: fix, copy, style): implement directly, then run the repo's checks.
- Feature: use the `grill` skill, write the spec, then plan, then implement in small steps.
- Risky (upgrade, dependency or config change): read-only exploration first, then `grill`.
After each step run the repo's typecheck and affected tests. Never say done without check output.
Before commit: the repo's `verify` skill. To ship: the `ship` skill. One task = one branch.

## Style
- Short, direct answers. No emojis. Show code when relevant.
- Commit messages: one short line saying what changed, plain language.
- Read code before asking me about it; ask me only for decisions.
