---
name: change-contract-check
description: Validate a drafted or updated Change Contract before implementation begins. Use after a Change Contract or Contract Blocker exists. Check source inputs, classification, decision traceability, repository evidence, owner, boundary, scope, work order, execution units, completion checks, source-input consistency, and contradictions. Return a blocking validation report, not a rewritten contract, unless repair is explicitly requested.
---

# Validate Change Contract

Validate the contract, not the code change.

Use this skill only after a `Change Contract` or `Contract Blocker` already
exists. Default to audit-only. Do not rewrite the contract unless the user
explicitly asks for repair. Validate only the short contract shape defined here.
Do not require any fields not listed here.

Pre-implementation validation must not require post-implementation status,
commit hashes, or reviewer approvals. The `unit-by-unit` workflow proves
implemented units through unit commits and final committed-range review.

A contract fails if the implementer must make design decisions that the contract
was supposed to settle.

## Decision Closure Rule

A full contract is not implementable when the implementer must choose the owner,
boundary, source of truth, compatibility behavior, execution order, proof seam
or fixture strategy, mandatory source-of-truth updates, migration or retirement
strategy, or completion signal.

For contracts involving callback, listener, observer, delivery, transaction,
rollback/no-op, atomicity, public-state publication, or guard windows, the
temporal invariant and every synchronous reentry/interleaving proof surface are
also decisions that must be settled before implementation.

For contracts that rely on all-or-nothing behavior, the irreversible point, the
fallible work that must happen before it, the later infallible or
failure-contained work, and the proof of that boundary are also decisions that
must be settled before implementation.

Treat vague deferrals as unresolved decisions when they appear in required
fields or execution units. Examples include "as needed", "if applicable",
"where necessary", "choose the appropriate", "verify correctness", "ensure it
works", "add tests as needed", and "clean up related code".

These phrases are acceptable only when the contract also gives the exact
condition, bounded surface, and completion signal that make the optional work
non-ambiguous.

## Accepted Inputs

Accept exactly one of these shapes.

### Change Contract

Required sections:

- `# Change Contract`
- `## Goal`
- `## Source Inputs`
- `## Classification`
- `## Decision Trace`
- `## Evidence`
- `## Boundaries`
- `## Execution Units`

Required `Classification` fields:

- `Profile`
- `Obligations`

Required `Decision Trace` columns:

- `Source decision`
- `Contract location`
- `Execution unit / proof surface`

Required `Boundaries` fields:

- `Owner`
- `In Scope`
- `Out of Scope`
- `Source of Truth`
- `Compatibility`
- `Order Constraints`

Each execution unit must include:

- a heading that starts with `### [ ] Unit N:`;
- `Owner`
- `Boundary`
- `Change`
- `Completion Check`
- `Depends On`

Pre-implementation contracts must not include completed-unit status or
post-implementation proof blocks.

### Contract Blocker

Required sections:

- `# Contract Blocker`
- `## Goal`
- `## Source Inputs`
- `## Blocking Questions`
- `## Evidence`

Each blocking question must include:

- `Question`
- `Blocks because`
- `Needed evidence or decision`

A `Contract Blocker` must not include execution units.

## Verdicts

Return exactly one verdict:

- `PASS` - the contract is implementable as written; only minor wording issues
  may remain.
- `REVISE` - the contract is implementable, but has non-blocking weaknesses or
  small gaps.
- `BLOCKED` - implementation must not start because source inputs,
  classification, decision trace, owner, boundary, source of truth,
  compatibility, sequencing, proof, or completion checks are unresolved or
  contradicted.

Use `BLOCKED` whenever implementation-time design decisions remain.

## Repository Evidence Rule

Re-check the repository evidence behind the contract. Do not trust the
contract's evidence at face value.

Confirm, when relevant:

- named paths, modules, packages, layers, documents, analyzers, fixtures, tests,
  build steps, CI jobs, generated outputs, registries, and consumers exist or
  are justified as new artifacts;
- the claimed owner and work boundary match the repository;
- the claimed source of truth governs the work;
- compatibility constraints match public APIs, data formats, schemas, config,
  persistence, docs, generated outputs, or external consumers;
- completion checks are executable or observable enough to prove the unit is
  done;
- completion checks satisfy shared `Outcome-Proof Fit`: `Claim -> Direct outcome
  -> Proxy risk -> Required proof`, proving the direct outcome claimed by each
  unit and not only a proxy signal that could pass while the claimed outcome
  remains false, unless the unit claim is explicitly scoped to that proxy or the
  proxy is itself the claimed outcome;
- temporal/callback/guard obligations name every synchronous callback surface
  and the expected rejection or no-mutation signal;
- all-or-nothing obligations name the irreversible point or bounded seam, the
  fallible action being exercised or structurally excluded, and the expected
  rollback, no-mutation, containment, or publication signal.

Evidence must connect observed facts to contract consequences. Repository
evidence should use exact `path:line` references whenever the cited fact exists
in a stable text file. Path-only evidence is acceptable only for new files,
generated outputs without stable lines, or repository-level commands/config
surfaces where line references are not meaningful.

## Repository Source Inputs

When the review request names a source input, read it and verify that the
contract lists it in `## Source Inputs` and preserves mandatory decisions,
scope, gates, sequencing, selected form decisions when present, lock-required
facts, source-of-truth impacts, verification strategies, decision trace rows,
handoff constraints, and proof expectations:

- `against phase PHASE_FILE`: read the concrete `docs/implementation/...` document.
- `against design DESIGN_FILE`: read the concrete `.design/...` document.
- any other explicit source input file: read that file.

If the contract intentionally narrows or excludes source-input content, the
narrowing must appear in `Out of Scope`, be mapped in `Decision Trace`, and be
supported by evidence or an explicit user requirement.

For `against design DESIGN_FILE`, block the contract if it omits the design path
from `Source Inputs`, drops the selected profile or obligations from
`Classification`, replaces the selected architecture form, makes a required
source-of-truth update optional, drops a required proof seam or fixture strategy,
loses a handoff constraint, or fails to map a design `Decision Trace` row to a
contract boundary, execution unit, or proof surface without explicit redesign
authority.

Check when relevant:

- `PLAN.md` for active roadmap scope and step-contract status;
- `docs/README.md` as the documentation entry point;
- repository instructions for plan workflow, DCM metrics exceptions, and
  verification commands.

## Blocking Criteria

Mark the contract `BLOCKED` when any category applies:

1. Shape is invalid: wrong top-level output, missing required sections, missing
   required fields, empty headings, placeholders, filler, or guessed facts.
2. Evidence is insufficient: repository inspection is not real, cited facts
   cannot be verified, available `path:line` evidence is replaced by broad file
   references without justification, source inputs were not read, or evidence
   does not support the contract consequence.
3. Source-input traceability is missing: the contract was authored against a
   design, research note, phase document, PLAN step, or explicit source input
   but omits that source from `Source Inputs`, drops its classification, or
   fails to map lock-required source decisions to a contract location and
   execution unit/proof surface.
4. Decision trace is missing or lossy: a full contract lacks `Decision Trace`,
   uses vague targets, drops a source-input or repository-derived decision, or
   fails to map a design handoff decision to a boundary, execution unit, or proof
   surface.
5. Owner or boundary is unresolved: ownership is wrong, vague, split across
   unrelated owners, pushed into callers instead of the owning layer, or left
   for implementation.
6. Scope is unsafe: in-scope and out-of-scope work are missing, contradictory,
   silently expanded, or inconsistent with source inputs.
7. Source of truth or compatibility is wrong: the contract misses or contradicts
   governing docs, public APIs, data formats, schemas, config, persistence,
   generated outputs, registries, or external consumers.
8. Order is unsafe: required sequencing is missing, dependencies are circular or
   vague, consumers move before owners exist, migration or retirement strategy is
   deferred, or old paths are retired before replacement and migration checks are
   in place.
9. Execution units are invalid: a pre-implementation unit heading lacks the
   unchecked `[ ]` checkbox, a unit is pre-marked complete, a unit includes
   post-implementation proof/status, a unit lacks owner, boundary, concrete
   change, completion check, or dependency, a unit is only preparatory, or units
   are split or merged against owner, boundary, or completion-check logic.
10. Completion checks are inadequate: checks are vague, non-observable, lack an
   expected signal, omit the bounded surface being checked, or fail to prove the
   unit's change.
11. Shared `Outcome-Proof Fit` is missing: a completion check can pass while a
    unit claim about behavior, invariant, owner responsibility, source-of-truth
    update, migration, guardrail, compatibility promise, or completion outcome
    remains false. The contract must narrow the unit claim to the checked proxy,
    show that the proxy is itself the claimed outcome, or add a direct outcome
    proof.
12. Cross-section consistency fails: goal, source inputs, classification,
    decision trace, evidence, boundaries, units, dependencies, and completion
    checks contradict each other.
13. A `Contract Blocker` is invalid: it includes execution units, asks for
    decisions the repository already determines, or does not identify the exact
    missing evidence or decision.
14. Temporal/callback proof is missing: the contract includes or inherits call
    ordering, observer/listener/callback delivery, transaction, rollback, no-op
    boundaries, public-state publication, atomicity, or mutation guard
    obligations, but completion checks do not prove every synchronous callback
    surface that can run user or runtime code before the next sequence step.
15. Proof or fixture strategy is unresolved: a structural, bypass, negative, or
    fixture proof is required, but the contract omits the proof seam, fixture
    mechanism, bounded surface, or expected pass/fail signal.
16. Fixture-only data contaminates a real source of truth: the contract requires
    test-only names, values, schemas, or fixtures to be added to production
    registries, public APIs, durable contracts, real schemas, generated docs, or
    public surfaces.
17. Source-input obligations are weakened: a source-of-truth update, registry
    change, verification strategy, decision trace row, handoff constraint, or
    sequencing fact required by a design or phase source is made optional,
    conditional, or left for implementation to rediscover.
18. All-or-nothing proof is missing: the contract relies on all-or-nothing
    behavior, but does not identify the irreversible point, the fallible work
    that must happen before it, the later work that is infallible or
    failure-contained, and a proof that fails if fallible work is placed on the
    wrong side of that point.

## Non-Blocking Criteria

Use `REVISE` instead of `PASS` when the contract is implementable but weaker
than it should be:

- evidence is valid but thinner than nearby repository context would allow;
- the precedent is valid but not the closest one;
- an execution unit is slightly oversized but still has one owner and one
  completion check;
- a completion check is executable but its expected signal could be clearer;
- `Depends On` is understandable but should name a specific unit;
- wording is redundant but does not change scope, ownership, order, or
  verification.

## Required Output Format

Output this format only:

```md
# Change Contract Validation

Verdict: `PASS | REVISE | BLOCKED`

## Required Fixes

- `<short issue title>`
  Severity: `blocking`
  Location: `<section, field, execution unit, or file>`
  Issue: `<what is wrong>`
  Evidence: `<contract or repository evidence>`
  Minimal Repair: `<smallest acceptable repair>`

## Optional Improvements

- `<short improvement>`
  Severity: `non-blocking`
  Location: `<section, field, execution unit, or file>`
  Issue: `<what is weak>`
  Minimal Repair: `<small improvement>`

## Summary

`<one short paragraph>`
```

Omit empty `Required Fixes` or `Optional Improvements` sections. Do not list
passed sections unless the user explicitly asks for a full audit.

## Repair Rule

Do not rewrite the contract unless the user explicitly asks for repair. When
repair is requested, make the smallest change that resolves the findings and
preserves evidence-backed scope.
