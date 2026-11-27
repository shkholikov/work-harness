# <Solution name> (SPFx)

SharePoint Framework solution with React web parts. Deployed manually to the App Catalog.

## Versions (keep in sync with package.json)
- SPFx <1.20.1>, Node <18>, React <17.0.1>, TypeScript <4.7>, toolchain <gulp>. LSG <version>.
- Compatibility (Microsoft, Nov 2026): 1.20 = Node 18, gulp, React 17. 1.21 = Node 22, gulp. 1.22-1.23 = Node 22, Heft, React 17. 1.24.x = Node 22.14+/24/26, Heft only, React 18.3.1.
- Pin React exactly: `npm install react@<v> react-dom@<v> --save-exact`. All `@microsoft/sp-*` packages on the same exact version.

## Dev
- Dev stack: `pwsh -File scripts/stack.ps1 up|down|restart|status|ports|logs|url` (port <4321>, live reload 35729). `up` prints the hosted workbench URL. Use the `stack` skill.
- Dev site for testing: see `devSiteUrl` in `.github/spfx-harness.json`. Never test against production pages.
- First time on a machine: `npm ci`, then `pwsh -File scripts/stack.ps1 trust` (dev certificate).

## Checks
- `pwsh -File scripts/verify.ps1` runs Node check, lint, typecheck, tests, ship build and prints the risk tier. Add `-E2E` with the dev server running for the Playwright smoke test.
- Use the `verify` skill before every commit and the `ship` skill to commit and push.

## Rules
- LSG (internal UI library) components: follow the `lsg` skill. Prefer LSG over custom UI or raw Fluent UI.
- PnPjs: always `select` and `top` on list queries; handle throttling and errors visibly (no empty catch).
- No `dangerouslySetInnerHTML` with SharePoint data. No tenant URLs, list GUIDs or secrets in code: use web part properties or config.
- Never run App Catalog deploy commands (`m365 spo app add/deploy`, `*-PnPApp`). Deploys are manual.
- Bump `version` in `config/package-solution.json` only in a release task.
- Review rules and risk tiers: `REVIEW.md`. Specs for features live in `docs/specs/`.
