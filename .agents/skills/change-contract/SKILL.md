---
name: change-contract
description: Use when the requested outcome requires creating or editing a Change Contract, or when the user explicitly requests a Change Contract review.
---

# Change Contract

## Authority Preflight — Hard Gate

Before authoring, repairing, or returning `PASS`, identify every affected
source of truth and inspect its direct consumers for manual mirrors, including
copied inventories, constants, registries, allowlists, snapshots, and
exact-parity validators.

A plan, contract, or existing implementation is not evidence that a manual
mirror is valid. An accepted design may authorize intentional duplication only
when it defines its distinct owner, lifecycle, consumers, invariant, and direct
verification.

A pre-existing mirror is a contract conflict when the contract consumes,
preserves, modifies, or claims singular ownership of that concern; it cannot be
dismissed as baseline or out of scope.

Return a Contract Blocker until the owning source, consumer behavior, and scope
are reconciled. Only after this preflight passes may a contract receive `PASS`.

Select one mode from the user's intent. Explicit audit feedback, validation
findings, or reviewer feedback selects `review-only` or `review-and-repair`; do
not silently return to authoring.

- `create-or-update`: read [contract-rules.md](references/contract-rules.md),
  [authoring.md](references/authoring.md), and the
  [template](assets/change-contract-template.md). Write at most one direct-child
  active contract at `docs/planning/plans/YYYY-MM-DD-topic.md`.
- `review-only`: read [contract-rules.md](references/contract-rules.md) and
  [reviewing.md](references/reviewing.md). Make no writes, do no brainstorming,
  create no subagents, and perform no implementation verification.
- `review-and-repair`: begin with the complete `review-only` audit; then read
  both procedures and repair only the supplied active contract.

All modes may inspect only the artifact, its declared sources, repository facts,
read-only source-query surfaces, git status, and the mechanical linter. Do not
run implementation tests, builds, formatters, generators, migrations,
dependency installation, or completion checks. The linter owns normal schema
consumption; inspect the schema directly only to diagnose lint or change form.
`references/contract-artifact-schema.json` owns the mechanical contract and
blocker form; contract-lint tests plus active/template lint verify it.

Only `create-or-update` and explicit `review-and-repair` may write, and then
only the active contract. Do not edit product requirements, architecture,
implementation, tests, source-of-truth documentation, roadmap state, or
historical artifacts while deciding implementability. If repair needs absent
product, architecture, API, error-taxonomy, verification, or other source
authority, leave the active contract byte-identical and return a `BLOCKED`
validation artifact; never invent that decision.

Terminal and output boundaries:

- `create-or-update` succeeds only after lint and one fresh `contract_reviewer`
  agent receives exactly the closed prompt owned by `authoring.md` and returns
  a complete `PASS` verdict against the artifact and its declared sources.
- A source conflict or missing material decision returns one Contract Blocker
  and no stored partial active plan.
- `review-only` returns exactly one validation artifact and stops.
- `review-and-repair` returns exactly one repaired full contract only after its
  lint and one new fresh review; unresolved authority returns the byte-stable
  `BLOCKED` validation artifact.
- Never expose working notes, private obligation ledgers, provisional units or
  matrices, review methodology, or lint reports as the user-visible artifact.
