---
name: stack
description: Start, stop, restart or inspect the SPFx dev stack - the local dev server, its ports (serve 4321, live reload 35729) and the hosted workbench URL. Use when the user says "stack up/down/restart/status/ports", wants to run or see the web part, before the Playwright smoke test, or when the dev server or a port misbehaves.
---

Always go through `scripts/stack.ps1`; never start `gulp serve` or `heft start` yourself (they block the terminal), and never kill processes by port yourself.

| User says | Run (`pwsh -NoProfile -File scripts/stack.ps1 ...`) | Then |
|---|---|---|
| stack up / start the dev server | `up` | give the user the workbench URL it prints |
| stack down / stop | `down` | report what was stopped and that the ports are free |
| stack restart | `restart` | give the URL again |
| stack status / is it running | `status` | short summary: running or not, ports, Node warning |
| stack ports / port in use | `ports` | explain who holds each port |
| logs | `logs` (add `-Lines 100` only if 50 is not enough) | read only what explains the problem |

The script stops only processes it started or whose command line points into this repo. A port held by another program (`Owner = other`) is never touched: tell the user which program (name + PID) holds it and let them decide.

If `up` fails:
- Node version message: tell the user which Node version to switch to (fnm / nvm-windows); do not install Node yourself.
- Certificate errors in the browser: ask the user to run `pwsh -File scripts/stack.ps1 trust` once (it may show a Windows dialog).
- "old dev server of this repo still holds port": run `down`, then `up`.
- Build errors: read `logs`, fix the code, run `up` again.

When the task is done, run `down` unless the user wants to keep it running.
