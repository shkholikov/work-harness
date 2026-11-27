---
name: grill
description: Interview the user about a feature, change or decision until nothing is assumed, then write a one-page spec with testable acceptance criteria. Use when the user says "grill me", asks to stress-test a plan, or starts a feature or risky change.
---

Interview the user until you share an understanding, then write it down.

## Before the first question
Read the code and docs the task touches (and `REVIEW.md`, repo instructions). Facts you find yourself; never ask the user for something you could look up. State findings as assumptions: "I'll assume X unless you object."

## Rounds
Map the task as a decision tree: each decision leads to the decisions that depend on it.
Each round, ask only the questions whose prerequisites are already settled. At most 5 per round. Number them and give your recommended answer:

```
Q1 - <title>: <question, with options if useful>
   Recommended: <your answer and one-line reason>
```

Wait for answers, recompute what can be asked now, repeat. A question that depends on an open question waits for a later round.
Cover: goal and who it is for, what is out of scope, data and permissions, UI states (loading, empty, error), edge cases, how we will check it, risk tier.
Stop when every branch is settled. If it runs past 4 rounds, the task is probably too big: propose splitting it.

## Output
Do not implement. When the user confirms the understanding, write the spec to `docs/specs/<yyyy-mm-dd>-<slug>.md` (use `docs/specs/SPEC.template.md` if present):

```
# <task> - spec
Goal: <one sentence, for whom>
Non-goals: ...
Decisions: Q -> answer (why, one line)
Acceptance criteria:
1. Given ... when ... then ...   (each one testable)
Edge cases: ...
Verify: <exact commands; screenshot for UI>
Boundaries: Always ... / Ask first ... / Never ...
Risk tier: Low | Medium | High (files: ...)
Open questions: ...
```

Keep it to one page. Tell the user the path.
