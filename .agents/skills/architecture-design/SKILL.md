---
name: architecture-design
description: "Use when the requested outcome requires creating or editing an architecture design artifact. For read-only work, use only when the user's own message contains 'review' or 'ревью' and names the architecture design artifact as the review target."
---

# Architecture Design

Decide architecture for future Change Contract authoring. Do not implement, draft a
Change Contract, or claim implementation evidence.

## Mode Router

- Create or update: read `references/design-rules.md` and
  `references/authoring.md`, then follow the router's staged module loading.
- Checkpoint review: only when dispatched by the authoring workflow for one exact
  section; read `references/design-rules.md` and
  `references/checkpoint-reviewing.md`; load the cumulative modules required for the
  actual prefix at its semantic gate.
- Terminal review only: read `references/design-rules.md` and
  `references/reviewing.md`; load the full rule set at its semantic gate.
- Review and repair: only on explicit repair intent; read
  `references/design-rules.md`, `references/reviewing.md`, and
  `references/authoring.md`; load the full rule set at the terminal semantic gate.
- Skill or artifact-form maintenance: read `references/maintenance.md`.

## Runtime Boundary

Outside the artifact writes permitted by `references/authoring.md`, inspect repository
evidence with read-only source queries and run only `scripts/design_lint.py`. Do not run
implementation tests, builds, formatters, generators, migrations, package installation,
or completion checks.

Read `references/design-artifact-schema.json` directly only when diagnosing lint or
changing the artifact form.
