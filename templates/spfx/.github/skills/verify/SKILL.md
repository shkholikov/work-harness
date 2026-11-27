---
name: verify
description: Final check of a finished SPFx task before commit - runs scripts/verify.ps1 (Node, lint, typecheck, tests, ship build, risk tier), the Playwright smoke test, and the review agents the risk tier needs, then fixes what they find. Use when a task is done, or when the user says "verify", "/verify" or "check everything".
---

1. **Checks.** Run `pwsh -NoProfile -File scripts/verify.ps1` (add `-Base <branch>` if the PR will not target `main`).
   - On FAIL: read only the log tail it prints, fix, run again. After 3 failed rounds on the same step, stop and explain to the user.
2. **Smoke test (UI changes).** If `src/` changed and `tests/e2e` exists:
   - `pwsh -NoProfile -File scripts/stack.ps1 up` (says so if already running),
   - `pwsh -NoProfile -File scripts/verify.ps1 -E2E -Only e2e`,
   - report the screenshot names in `.spfx-dev/screenshots/`. Ask the user to look at them if the change is visual.
3. **Review by tier** (the script prints `TIER:`):
   - `Low`: no review agent.
   - `Medium`: run the `reviewer` agent with the base branch and the spec path (if `docs/specs/` has one for this task).
   - `High`: run `reviewer-high` and `deep-reviewer` (they can run in parallel), pass the `HIGH FILES` list. Tell the user to read every High file's diff themselves.
4. **Fix** every high/medium finding, or explain why it is not a problem. Re-run step 1 after fixes, then re-review only the new diff. Stop after 3 review rounds and rethink with the user.
5. **Last run must be a full PASS** of step 1 on the final code (this records the fingerprint that the `ship` skill checks).
6. Report in this shape:
```
Verify: PASS | FAIL
Checks: node, lint, typecheck, test, build, sppkg (each PASS/SKIP/FAIL)
Smoke test: PASS/FAIL/SKIP (+ screenshots)
Tier: <tier>; High files: <list>
Review: <agent>: PASS | n findings fixed | open: ...
```
