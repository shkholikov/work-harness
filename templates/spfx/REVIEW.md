# Review rules

How much review a change gets depends on the files it touches. `scripts/verify.ps1` sets the tier
from the globs in `.github/spfx-harness.json` (keep them in sync with this file).

## Risk tiers

| Tier | Files | Review | Merge |
|---|---|---|---|
| High | `config/package-solution.json`, `config/serve.json`, `package.json`, `package-lock.json`, `*.manifest.json`, services (`**/services/**`, `*Service.ts`): permissions, versions, data writes, Graph/AadHttpClient calls | `reviewer-high` + `deep-reviewer` agents | Read every High file's diff yourself |
| Medium | Web part and component code, PnPjs reads, everything not listed elsewhere | `reviewer` agent | Read the findings, then merge |
| Low | `*.scss`, `loc/*`, docs, assets | None | Merge when checks pass |

## Always check
- LSG components used the way the `lsg` skill describes; no custom copies of LSG components.
- PnPjs list queries have `select` and `top`; errors shown to the user, never swallowed.
- No `dangerouslySetInnerHTML` with SharePoint data.
- No tenant URLs, list GUIDs, secrets or tokens in code or config.
- No new API permission requests unless the spec asks for them.
- React and `@microsoft/sp-*` versions pinned exactly and matching the compatibility table.
- Web part manifest `id` unchanged.
- Release PRs: `version` bumped in `config/package-solution.json`.

## Before a release (manual deploy)
1. Full `scripts/verify.ps1` PASS on `main`.
2. Keep the current production `.sppkg` (rollback).
3. Upload the new `.sppkg` to the App Catalog, check the web parts on the dev site, then production.
4. Production bug: add an entry to `incidents.md` and a rule above.
