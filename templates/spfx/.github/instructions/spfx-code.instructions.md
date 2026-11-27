---
applyTo: "src/**/*.ts,src/**/*.tsx"
---

# SPFx component code

- Function components with hooks. Props and state typed; no `any` unless a library forces it (comment why).
- Data access goes through a service in `src/services/` (or the web part's existing service), not inside components.
- Every async call: loading, empty and error states in the UI. Errors are shown to the user and logged with context; never swallowed.
- PnPjs: `.select(...)` only the fields used, `.top(n)` on lists, batch where it saves round trips. Respect throttling (429) with the existing retry setup.
- Use LSG components through the `lsg` skill's patterns. Do not copy LSG source into the repo.
- Strings shown to users come from `loc/` files, not literals.
- Keep components small; split when a file passes about 250 lines.
- Tests (Jest + React Testing Library) for logic and components with branching: mock PnPjs/SPHttpClient, assert what the user sees.
