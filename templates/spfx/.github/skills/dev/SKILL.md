---
name: dev
description: Start, stop or inspect the SPFx local dev server and get the hosted workbench URL. Use when the user wants to run or see the web part, before the Playwright smoke test, or when the dev server misbehaves.
---

Always go through the script; never start `gulp serve` or `heft start` yourself (they block the terminal).

- Start: `pwsh -NoProfile -File scripts/dev.ps1 start` - waits for the port and prints the workbench URL. Give the URL to the user.
- Status: `pwsh -NoProfile -File scripts/dev.ps1 status`
- Logs: `pwsh -NoProfile -File scripts/dev.ps1 logs` (last 50 lines; use `-Lines 100` only if needed)
- Stop: `pwsh -NoProfile -File scripts/dev.ps1 stop` - stop it when the task is done.

If start fails:
- Node version message: tell the user which Node version to switch to (fnm/nvm-windows); do not install Node yourself.
- Certificate errors in the browser: ask the user to run `pwsh -File scripts/dev.ps1 trust` (it may show a Windows dialog).
- Port in use: run `status`; if it is not ours, tell the user.
- Build errors: read `logs`, fix the code, start again.
