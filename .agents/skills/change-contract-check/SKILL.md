---
name: change-contract-check
description: Validate a drafted or updated Change Contract before implementation begins. Use after a Change Contract or Contract Blocker exists. Check repository evidence, owner, boundary, scope, work order, execution units, completion checks, repository source-input consistency, and contradictions. Return a blocking validation report, not a rewritten contract, unless repair is explicitly requested.
---

# Validate Change Contract

Validate the contract, not the code change.

Use this skill only after a `Change Contract` or `Contract Blocker` already exists.
Default to audit-only. Do not rewrite the contract unless the user explicitly asks for repair.
Validate only the short contract shape defined here. Do not require any fields not listed here.

A contract fails if the implementer must make design decisions that the contract was supposed to settle.

## Decision Closure Rule

A full contract is not implementable when the implementer must choose the owner,
boundary, source of truth, compatibility behavior, execution order, proof seam
or fixture strategy, mandatory source-of-truth updates, migration or retirement
strategy, or completion signal.
For contracts involving callback, listener, observer, delivery, transaction,
rollback/no-op, atomicity, public-state publication, or guard windows, the
temporal invariant and every synchronous reentry/interleaving proof surface are
also decisions that must be settled before implementation.

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
- `## Evidence`
- `## Boundaries`
- `## Execution Units`

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

### Contract Blocker

Required sections:

- `# Contract Blocker`
- `## Goal`
- `## Blocking Questions`
- `## Evidence`

Each blocking question must include:

- `Question`
- `Blocks because`
- `Needed evidence or decision`

A `Contract Blocker` must not include execution units.

## Verdicts

Return exactly one verdict:

- `PASS` - the contract is implementable as written; only minor wording issues may remain.
- `REVISE` - the contract is implementable, but has non-blocking weaknesses or small gaps.
- `BLOCKED` - implementation must not start because owner, boundary, source of truth, compatibility, sequencing, or completion checks are unresolved or contradicted.

Use `BLOCKED` whenever implementation-time design decisions remain.

## Repository Evidence Rule

Re-check the repository evidence behind the contract. Do not trust the contract's evidence at face value.

Confirm, when relevant:

- named paths, modules, packages, layers, documents, analyzers, fixtures, tests, build steps, CI jobs, generated outputs, registries, and consumers exist or are justified as new artifacts;
- the claimed owner and work boundary match the repository;
- the claimed source of truth governs the work;
- compatibility constraints match public APIs, data formats, schemas, config, persistence, docs, generated outputs, or external consumers;
- completion checks are executable or observable enough to prove the unit is done.
- when temporal/callback/guard obligations are present or inherited from a
  source input, completion checks name every synchronous callback surface and
  the expected rejection or no-mutation signal.

Evidence must connect observed facts to contract consequences.

## Repository Source Inputs

When the review request names a source input, read it and verify that the
contract preserves mandatory decisions, scope, gates, sequencing, selected form
decisions when present, lock-required facts, source-of-truth impacts,
verification strategies, handoff constraints, and proof expectations:

- `against phase PHASE_FILE`: read the concrete `docs/implementation/...` document.
- `against design DESIGN_FILE`: read the concrete `.design/...` document.
- any other explicit source input file: read that file.

If the contract intentionally narrows or excludes source-input content, the narrowing must appear in `Out of Scope` and be supported by evidence or an explicit user requirement.

For `against design DESIGN_FILE`, block the contract if it replaces the selected
architecture form, makes a required source-of-truth update optional, drops a
required proof seam or fixture strategy, or loses a handoff constraint without
explicit redesign authority.

Check when relevant:

- `PLAN.md` for active roadmap scope and step-contract status;
- `docs/README.md` as the documentation entry point;
- repository instructions for plan workflow, DCM metrics exceptions, and verification commands.

## Blocking Criteria

Mark the contract `BLOCKED` when any category applies:

1. Shape is invalid: wrong top-level output, missing required sections, missing required fields, empty headings, placeholders, filler, or guessed facts.
2. Evidence is insufficient: repository inspection is not real, cited facts cannot be verified, source inputs were not read, or evidence does not support the contract consequence.
3. Owner or boundary is unresolved: ownership is wrong, vague, split across unrelated owners, pushed into callers instead of the owning layer, or left for implementation.
4. Scope is unsafe: in-scope and out-of-scope work are missing, contradictory, silently expanded, or inconsistent with source inputs.
5. Source of truth or compatibility is wrong: the contract misses or contradicts governing docs, public APIs, data formats, schemas, config, persistence, generated outputs, registries, or external consumers.
6. Order is unsafe: required sequencing is missing, dependencies are circular or vague, consumers move before owners exist, migration or retirement strategy is deferred, or old paths are retired before replacement and migration checks are in place.
7. Execution units are invalid: a unit heading lacks the unchecked `[ ]` checkbox, a unit lacks owner, boundary, concrete change, completion check, or dependency; a unit is only preparatory; units are split or merged against owner, boundary, or completion-check logic.
8. Completion checks are inadequate: checks are vague, non-observable, lack an expected signal, omit the bounded surface being checked, or fail to prove the unit's change.
9. Cross-section consistency fails: goal, evidence, boundaries, units, dependencies, completion checks, and source inputs contradict each other.
10. A `Contract Blocker` is invalid: it includes execution units, asks for decisions the repository already determines, or does not identify the exact missing evidence or decision.
11. Temporal/callback proof is missing: the contract includes or inherits call
    ordering, observer/listener/callback delivery, transaction, rollback, or
    no-op boundaries, public-state publication, atomicity, or mutation guard
    obligations, but completion checks do not prove every synchronous callback
    surface that can run user or runtime code before the next sequence step.
    Vague wording such as "guard observer delivery" is insufficient when state
    listeners, diagnostics, action streams, repaint callbacks, or other
    synchronous surfaces can also run.
12. Proof or fixture strategy is unresolved: a structural, bypass, negative, or
    fixture proof is required, but the contract omits the proof seam, fixture
    mechanism, bounded surface, or expected pass/fail signal.
13. Fixture-only data contaminates a real source of truth: the contract requires
    test-only names, values, schemas, or fixtures to be added to production
    registries, public APIs, durable contracts, real schemas, generated docs, or
    public surfaces.
14. Source-input obligations are weakened: a source-of-truth update, registry
    change, verification strategy, handoff constraint, or sequencing fact
    required by a design or phase source is made optional, conditional, or left
    for implementation to rediscover.

## Non-Blocking Criteria

Use `REVISE` instead of `PASS` when the contract is implementable but weaker than it should be:

- evidence is valid but thinner than nearby repository context would allow;
- the precedent is valid but not the closest one;
- an execution unit is slightly oversized but still has one owner and one completion check;
- a completion check is executable but its expected signal could be clearer;
- `Depends On` is understandable but should name a specific unit;
- wording is redundant but does not change scope, ownership, order, or verification.

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

Omit empty `Required Fixes` or `Optional Improvements` sections.
Do not list passed sections unless the user explicitly asks for a full audit.

## Repair Rule

Do not rewrite the contract unless the user explicitly asks for repair.
When repair is requested, make the smallest change that resolves the findings and preserves evidence-backed scope.
