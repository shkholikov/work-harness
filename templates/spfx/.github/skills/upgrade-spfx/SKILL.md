---
name: upgrade-spfx
description: Plan an SPFx and/or LSG version upgrade before changing anything - reads current versions, runs the CLI for Microsoft 365 upgrade report, reads the LSG changelog, and writes docs/upgrade-<version>.md with steps, breaking changes, risks and rollback. Read-only on code. Use when the user wants to upgrade SPFx, React, Node or LSG.
---

This skill only plans. It does not change `package.json`, code or config.

## Facts (Microsoft compatibility table, checked 2026-11-27)
| SPFx | Node | TypeScript | React | Toolchain |
|---|---|---|---|---|
| 1.20.x | 18 | 4.5 / 4.7 | 17.0.1 | gulp |
| 1.21.x | 22 | 5.3 | 17.0.1 | gulp |
| 1.22.x, 1.23.x | 22 | 2.9 - 5.8 | 17.0.1 | Heft |
| 1.24.0 - 1.24.2 | 22.14+ / 24 / 26 | 2.9 - 5.8 | 18.3.1 | Heft only (gulp unsupported) |
- 1.24.2 (2026-11-20) fixes React 18 peer-dependency conflicts of 1.24.0/1.24.1: target 1.24.2, not 1.24.0/1.
- Microsoft: editing package.json versions alone breaks the build. Follow the release-notes steps (generator, all `@microsoft/sp-*` to the exact version, `npm install`, `npm run build`, commit the lock file).
- `m365 spfx project upgrade` does not support 1.24.2 yet (CLI 12.0.0): report against 1.24.1, then apply the 1.24.2 release-note steps.
- 1.25 (Dec 2026 / Jan 2027) replaces Yeoman with the SPFx CLI for new projects; not needed for upgrading.

## Steps
1. Record current state: SPFx (`@microsoft/sp-core-library`), React, TypeScript, Node, toolchain (gulpfile.js or Heft), LSG version, Fluent UI and PnPjs versions, custom `gulpfile.js` tasks.
2. Ask the user for the LSG target version and where its changelog / migration guide is (path or pasted text). Do not guess LSG breaking changes.
3. Run the report (read-only):
   `npx -p @pnp/cli-microsoft365@latest m365 spfx project upgrade --toVersion <1.23.2 or 1.24.1> --output md > .spfx-dev/upgrade-report.md`
   If the command is blocked (proxy, policy), tell the user and continue from the release notes they paste.
4. Write `docs/upgrade-<target>.md`:
   - Current -> target table (SPFx, Node, React, TS, toolchain, LSG, Fluent UI, PnPjs).
   - Steps, one PR each, in this order unless LSG forces otherwise:
     A. SPFx 1.20.1 -> 1.23.x, gulp -> Heft, Node 18 -> 22 (React 17, LSG unchanged). Move gulpfile customisations to Heft config/plugins.
     B. SPFx 1.24.2 + React 18.3.1 (+ LSG if the new LSG needs React 18).
     C. LSG upgrade + breaking-change fixes (before B if new LSG still supports React 17).
   - For each step: exact commands, files touched, breaking changes and how each is handled, checks (verify.ps1, smoke test vs baseline screenshots), rollback (previous `.sppkg` version).
   - Baseline to capture before step A: current `.sppkg` kept, Playwright screenshots of every web part, key tests passing.
   - Open questions for the user.
5. Tell the user the path and ask them to approve the plan before step A starts. Each step then runs as its own task (branch, verify, ship).
