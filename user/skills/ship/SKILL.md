---
name: ship
description: Commit verified work on a branch, push it after the user confirms, and print the pull request text (Testing, Risk, How to revert) for Bitbucket. Use when the user says "ship it", "/ship", "commit and push" or "make the PR".
---

1. **Verified?** If the repo has `scripts/verify.ps1`, run `pwsh -NoProfile -File scripts/verify.ps1 -CheckFresh`.
   - Exit 0: the code is exactly what the last verify checked. Continue.
   - Otherwise: stop and run the `verify` skill first.
   Without a verify script, run the repo's lint, typecheck, test and build and keep the output.
2. **Branch.** If on `main`/`master`, create `feat/<slug>` or `fix/<slug>` first (`git switch -c`). Never commit to main.
3. **Commit.** Show `git status --short`. Stage only files that belong to the task (never `.spfx-dev/`, logs, screenshots, profiles). One commit, one short line saying what changed in plain language. Add a body only if the why would otherwise be lost.
4. **Push.** Tell the user the branch name and ask before `git push -u origin <branch>` (the guard hook will also ask). Never push to main, never force.
5. **PR text.** Write `.spfx-dev/pr.md` (or `pr.md` in the temp folder if there is no `.spfx-dev`) and print it:

```
## What
<2-3 lines; link the spec in docs/specs/ if any>

## Testing
<verify summary: each check PASS/FAIL; Playwright result and screenshot names; reviewer verdicts>

## Risk
Tier: <Low|Medium|High>. High-risk files: <list or none>.
<what could break and who would notice>

## How to revert
<revert the merge commit; for SPFx: upload the previous .sppkg <version> to the App Catalog>
```

6. Tell the user to open the PR in Bitbucket from `<branch>` into `main` and paste the text. Do not merge anything.
