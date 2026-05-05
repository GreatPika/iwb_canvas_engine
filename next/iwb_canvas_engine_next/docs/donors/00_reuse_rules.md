<!-- CONTEXT:BEGIN -->
Registry id: `donors_00_reuse_rules`
Source: `docs/_registry/donors.yaml / Reuse rules`
Canonical source: `docs/_registry/donors.yaml`
Feeds registry: `docs/_registry/donors.yaml`
Feeds indexes:
- `docs/indexes/donor_to_phase.md`
Use rule: donor entries are phase-bound implementation inputs, not legacy architecture to copy.
<!-- CONTEXT:END -->

# `iwb_canvas_engine_next`: current-code donor inventory

This document lists reusable donors from the current `iwb_canvas_engine`
codebase for the greenfield `iwb_canvas_engine_next` implementation.

The current engine is a **functional oracle and implementation donor**, not a
legacy dependency. Donor use means copying or adapting proven algorithms,
contracts, tests, and guardrails into the next package shape. It does not allow
the next package to import the legacy runtime or preserve the legacy public API.

## Reuse rules

- No production import from the legacy package or legacy `lib/src/**` runtime
  paths is allowed in `iwb_canvas_engine_next`.
- Public names and API shapes in the next package remain governed by the v1 API
  plan, even when the implementation donor came from a legacy public type.
- `copy` is allowed only for small cohesive utilities with low legacy coupling
  and ported tests.
- `copy/adapt` means the core logic is portable, but names, owners, error
  types, or public boundaries must change.
- `adapt` means the behavior or algorithm is valuable, but the legacy shell is too
  coupled to legacy scene/controller/snapshot types.
- `adapt/rewrite` means preserve the behavior and tests, but rewrite the shell
  around next-owned models, owners, and public boundaries.
- `rewrite-reference` means use the legacy code and tests as behavioral evidence
  only; do not port the structure.
- Every reused donor must carry at least one ported or equivalent test before
  the implementation slice closes.
- If donor code conflicts with the next v1 API, package layout, or no-legacy
  rules, the next plan wins.
