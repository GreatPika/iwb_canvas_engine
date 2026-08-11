# Layer 1 — Implementation Review

Use this layer for implementation diffs, committed ranges, unit reviews, and artifacts that change runtime, public, build, persistence, state, event, callback, validation, migration, ownership, or integration behavior.

## Primary Review Frame

Check for actionable defects in accuracy, performance, security, reliability, maintainability, plan alignment, contract alignment, and verification confidence. Ignore trivial style unless it obscures meaning or violates documented standards.

Candidate findings must remain eligible for the Layer 4 finding threshold: they should be introduced by the reviewed diff or commit range, identify an evidence-backed affected consumer or scenario, avoid unstated assumptions, avoid intentional-change-only objections, and not demand a level of rigor absent from the rest of the codebase.

Use one finding per distinct issue. Do not include replacement patches, suggestion blocks, or implementation diffs. Keep each location as narrow as possible by naming the most useful diff line.

## Plan, Contract, And Architecture Alignment

Check the direct-child active plan under `docs/planning/plans/` when one exists.
Use that contract, linked designs, source inputs, and repository-local
instructions as review evidence when relevant to the diff.

The accepted contract `Decision Trace`, outcomes, owners, boundaries, evidence
constraints, pre-implementation completion boundary, and `Verification Profile`
obligations are authoritative. Resolve outcome keys through the `Verification
Matrix` to evidence, durable impact, artifact target, and semantic admission
keys. Exact regexes, fixture spelling, visitor implementation, private hooks,
and test paths do not define semantic scope. When a prescribed verification
mechanism would create false confidence or enforce private shape, report a
contract-mechanism defect instead of treating that mechanism as binding.

Flag plan mismatches only when the mismatch is visible and actionable from the reviewed change.

Flag visible drift from:

- active plan;
- active plan contract;
- linked design;
- source inputs;
- classification;
- selected owner;
- source of truth;
- acceptance oracle;
- evidence constraints;
- architecture-required verification seam when applicable;
- Decision Trace mapping;
- required source-of-truth update;
- sequencing constraint, including `Sequenced Migration And Retirement` drift.

A nonarchitectural fixture strategy does not define review scope and cannot
justify a permanent-artifact request.

Flag any durable verification artifact or independent coverage concern outside
the applicable resolved Matrix row. Verify that a bounded amendment changes
only an affected outcome that must be split, its corresponding Matrix row or new
row, and the corresponding central admission entry for `ADD` or
`EXTEND_COVERAGE`. Flag it when it also changes accepted scope, product
behavior, ownership, boundaries, compatibility, source of truth, or
implementation scope.

## Work-Budget And Lifecycle-Phase Audit

For every contract-scoped unit or final review whose contract selects
`WORK_BUDGET_CLOSURE` or otherwise constrains scans, copies, rebuilds,
materialization, publication, allocation, amortized work, or cost displacement,
audit actual owner behavior against every applicable phase. Do this even when
the diff does not change tests or instrumentation.

Trace the production owner and its invoked helpers, not only result assertions,
test names, counters, or the declared implementation intent. For each phase,
compare actual work with the accepted bound, allowed whole-owner pass, and
forbidden cost displacement:

- construction/import/reset;
- mutation/update/replay;
- freeze/publication/install;
- query/read; and
- cleanup/rollback.

Treat a phase as non-applicable only when the contract supplies its specific
source- and owner-grounded reason. An unchanged helper, an absent test change,
or a green suite does not make an applicable phase non-applicable.

Flag an owner route that moves a prohibited full scan, rebuild,
materialization, allocation, or publication into another phase. A correct
observable result does not close a work budget when prohibited work is
displaced, duplicated, or amplified in another phase. When the current
contract's adversarial case requires direct observation of constrained work, a
missing real owner-seam signal is a blocking candidate. Derive that work and
signal from the current contract and its accepted sources; never substitute a
built-in domain example or a failure family from another contract. Name the
applicable outcome and Matrix evidence key, phase, actual route, and the
required signal that stays green; do not infer closure from a test-controlled
counter or a counter outside the owner seam. Layer 2 classifies any surviving
escape at the contract level.

## Source-Of-Truth Singularity

Flag source-of-truth drift, duplicated truth without a cache or performance
invariant and evidence constraints, or durable source-of-truth artifacts with no
real consumer.

Durable meaning should have one owner. Duplicate truth requires an explicit
cache or performance invariant and evidence constraints. A source-of-truth
artifact must have a real human or machine consumer.

## Pre-Implementation Completion Boundary

Flag premature completion markers when the reviewed diff marks execution units
complete or closes an active plan without implementing and proving that work in
the reviewed range.

For unit-by-unit implementation, do not require extra evidence blocks or trace
commits. During unit review, keep the review scoped to the current unit and flag
violations of the pre-implementation completion boundary for premature
completion markers for future work. During final committed-range review, verify
required execution-unit checkbox updates and active-plan closure are backed by
implemented, verified, reviewed commits in the reviewed range.

## Temporal Surface Closure

Flag gaps when observer, listener, callback delivery, public-state publication, transaction, rollback, no-op ordering, post-commit notification, or mutation guards are changed without covering every synchronous callback surface, guard or boundary owner, public observation order, and rejection or no-mutation signal that can reenter before the next sequence step.

Verify guard placement covers the full synchronous execution window. Require
every relevant temporal outcome—including happy-path delivery and reentrant or
interleaved mutation attempts from every callback surface with the expected
rejection or no-mutation signal—to be covered by the resolved Matrix evidence
that satisfies the accepted acceptance oracle and evidence constraints. Do not
require focused tests unconditionally. A new or expanded permanent artifact is
allowed only when the resolved durable impact authorizes it and the finding
supplies the applicable semantic `Admission basis`.

## All-Or-Nothing Failure Boundary

Flag gaps when fallible work happens after an irreversible mutation without
containment, accepted-result scoping, failure projection, or admissible resolved
Matrix evidence.

Identify the irreversible point and verify that fallible work happens before it,
or is explicitly infallible, failure-contained, or already part of the accepted
result with admissible resolved Matrix evidence and failure projection.

## Fragility, Ownership, And Boundary Policy

Flag hacks, fragile shortcuts, future-risk smells, hardcoded special cases, duplicated state, sync glue, silent fallbacks, swallowed failures, inefficient repeated work, bypassed local utilities, or opaque abstractions introduced by the diff.

Apply `Owner-Level Fix`: flag one-off call-site patches when the invariant belongs to a shared owner.

Apply `Boundary-Owned Policy`: flag policy or validation pushed into callers when the boundary owner should enforce it.

For guardrails and analyzers, derive semantic scope from the stable invariant,
invalid state, owner, consumer, acceptance oracle, and evidence constraints.
Do not treat exact regexes, fixture spelling, visitor implementation, or test
paths as the semantic boundary.

## Implementation Candidate Format

Record candidate findings for Layer 4 synthesis as:

```text
Layer: 1 — Implementation correctness and contract alignment
Priority: [P0/P1/P2/P3]
Location: path:line
Concrete failure mode:
Affected consumer or scenario:
Expected fix direction:
```
