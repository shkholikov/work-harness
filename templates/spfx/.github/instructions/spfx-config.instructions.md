---
applyTo: "config/**,package.json,package-lock.json,gulpfile.js,**/*.manifest.json"
---

# SPFx config and dependencies (High risk)

These files are High risk in `REVIEW.md`: the reviewer-high and deep-reviewer agents run, and the user reads every line.

- `config/package-solution.json`: do not add `webApiPermissionRequests`, change `skipFeatureDeployment`, `isDomainIsolated` or the solution id unless the spec asks for it. Say explicitly in your reply when you touch them.
- Versions: all `@microsoft/sp-*` and `@microsoft/eslint-*`/rig packages on one exact SPFx version; React and React DOM pinned exactly to the version the SPFx compatibility table names; LSG version as the spec says.
- After any dependency change: `npm install`, commit `package-lock.json` with `package.json`, run the full `scripts/verify.ps1`.
- Editing `package.json` versions by hand is not an SPFx upgrade: follow the upgrade plan in `docs/upgrade-*.md` (created by the `upgrade-spfx` skill).
- Web part manifests: do not change the component `id`; it breaks existing pages.
