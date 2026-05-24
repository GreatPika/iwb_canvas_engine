---
name: change-contract
description: Create a Change Contract before code implementation. Use when a coding task needs an evidence-backed owner, work boundary, execution order, execution units, and completion checks before changes are made. Do not use to implement code, run the implementation, or review an already written contract.
---

# Change Contract

Create a short Change Contract for the implementer.

Do not edit code. Do not implement the change. Do not run the work.

Output only one of:

- `Change Contract`
- `Contract Blocker`

## Purpose

Convert the user's coding task into an executable change plan.

The contract must define:

- what must change;
- where the change is owned;
- what is in scope;
- what is out of scope;
- the required order of work;
- how each execution unit is considered complete.

## Decision Closure

A full contract must settle the decisions that belong before implementation.

Output `Contract Blocker` instead of a full contract when the implementer would
still need to choose:

- the owner or owning layer;
- the work boundary;
- the source of truth;
- compatibility behavior;
- execution order;
- temporal/reentrancy behavior for callback, listener, observer, delivery,
  transaction, rollback, no-op, atomicity, guard, or public-state publication
  windows;
- migration, replacement, or retirement strategy;
- the completion signal for any execution unit.

Implementation details may remain open only when they are local tactics inside
an already fixed owner, boundary, order, and completion signal.

## Evidence

Before writing the contract, inspect the repository enough to identify the relevant facts.

Include only evidence that the implementer needs to understand:

- the owner of the change;
- the work boundary;
- the execution order;
- exclusions from scope;
- the source of truth;
- compatibility constraints.

Do not include research logs, long code quotes, raw search output, or intermediate reasoning.

Evidence format:

    - `path/to/file` / `surface`: observed fact -> contract consequence.

## Repository Source Inputs

When the request names a source input, read it:

- `against phase PHASE_FILE`: read the concrete `docs/implementation/...` document.
- `against design DESIGN_FILE`: read the concrete `.design/...` document.
- any other explicit source input file: read that file.

Preserve mandatory decisions, scope, gates, sequencing, and proof expectations.
If a source input or design mentions temporal ordering, observers, listeners,
callbacks, post-commit delivery, rollback/no-op behavior, atomicity, public
state publication, or mutation guards, preserve the named synchronous callback
surfaces and reentrant/interleaving proof expectations.

If the contract intentionally narrows or excludes anything from a source input, state that exclusion in `Out of Scope` and support it with evidence or an explicit user requirement.

Inspect when relevant:

- `PLAN.md` for active roadmap scope and step-contract status;
- `docs/README.md` as the documentation entry point;
- repository instructions for plan workflow, DCM metrics exceptions, and verification commands.

## Contract Blocker

If the owner, boundary, work order, source of truth, compatibility constraint, or completion check cannot be determined from repository evidence or explicit user requirements, do not write a full contract.

Output:

    # Contract Blocker

    ## Goal

    [One short paragraph.]

    ## Blocking Questions

    - Question:
      Blocks because:
      Needed evidence or decision:

    ## Evidence

    - `path/to/file` / `surface`: observed fact -> why it blocks the contract.

Do not include execution units in a blocker.

## Execution Unit

An execution unit is a small bounded piece of work with:

- one owner;
- a clear boundary;
- a concrete change;
- a completion check;
- explicit dependencies, if any.

Each execution unit heading must start with an unchecked checkbox:
`### [ ] Unit N: [short title]`.

The checkbox is for later implementation tracking. Do not mark a unit complete
when creating the contract.

Execution units should be small and roughly balanced when possible.

Correct boundaries, dependency order, and independent completion checks are more important than equal size.

Do not split a unit if the resulting parts cannot be completed and checked separately.

Do not merge units that have different owners, different boundaries, or different completion checks.

## Splitting Work

First choose the natural split axis for the task:

- behavior change: split by user flow, API call, command, event, or observable behavior;
- refactor: split by owner, module, seam, or dependency boundary;
- migration: split by adding the new path, migrating consumers, then removing the old path;
- rule, analyzer, or style check: split by rule, allowed case, forbidden case, fixture, or integration point;
- documentation: split by source-of-truth surface and dependent references;
- build, test, or CI change: split by affected verification surface.

Then construct execution units with this procedure:

1. List the main affected surfaces: files, modules, APIs, docs, schemas, tests, build steps, CI jobs, generated outputs, registries, or consumers.
2. Group those surfaces by the owner that should be responsible for the change.
3. Inside each owner group, identify concrete changes that can be completed separately.
4. For each candidate unit, define its completion check.
5. If a candidate has no separate completion check, do not keep it as a separate unit. Merge it into the nearest unit that owns the same outcome, or output `Contract Blocker` if no valid owner exists.
6. If a candidate has more than one owner, split it by owner.
7. If a candidate has multiple independent completion checks, consider splitting it by those checks.
8. If two adjacent candidates have the same owner, same boundary, same risk, and same completion check, merge them.
9. Order units so that owners and boundaries are established before consumers are changed.
10. Remove old paths only after replacement paths and consumers are in place.

A valid execution unit is not created from a file list alone. It is created from this chain:

    owner -> boundary -> concrete change -> completion check

## Temporal And Callback Windows

When the change introduces or modifies call ordering, observer/listener/callback
delivery, post-commit notification, transaction, rollback, or no-op boundaries,
public-state publication, atomic install, or mutation guards, the contract must
make the synchronous execution window decision-complete.

Name:

- the temporal invariant;
- every synchronous callback surface that can run user or runtime code before
  the next sequence step;
- the guard or boundary owner;
- the allowed public observation order;
- the expected rejection or no-mutation behavior for reentrant/interleaved
  mutation attempts.

Execution unit completion checks must prove those surfaces explicitly. Do not
write vague checks such as "guard observer delivery" or "test reentrancy"; name
the callback surface and expected signal.

## Output Format

When enough evidence exists, output:

    # Change Contract

    ## Goal

    [One short paragraph describing the intended final state.]

    ## Evidence

    - `path/to/file` / `surface`: observed fact -> contract consequence.

    ## Boundaries

    Owner:

    In Scope:

    Out of Scope:

    Source of Truth:

    Compatibility:

    Order Constraints:

    ## Execution Units

    ### [ ] Unit 1: [short title]

    Owner:

    Boundary:

    Change:

    Completion Check:

    Depends On:

    ### [ ] Unit 2: [short title]

    Owner:

    Boundary:

    Change:

    Completion Check:

    Depends On:

Add more units only when needed.

## Completion Check

Each `Completion Check` must tell the implementer how to know that the unit is complete.

Each check must name an observable or executable signal and the bounded surface
where that signal applies.

A completion check may be:

- a test, command, or check with an expected signal;
- a specific behavior visible through a user flow, API, CLI, event, or output;
- removal of an old import, symbol, path, registry entry, or call site from a bounded surface;
- migration of named consumers to a new owner, seam, API, schema, or path;
- an updated source-of-truth document plus required dependent references;
- an analyzer rule, lint rule, fixture, or build integration that proves the rule is active;
- preservation of a public signature, format, schema, or compatibility promise.

Do not use vague checks such as "verify correctness", "add tests as needed",
"ensure it works", "update callers where necessary", or "clean up related code".
If the exact signal cannot be named, output `Contract Blocker`.

For temporal/callback/guard work, a completion check is inadequate unless it
names the specific callback surface, the reentrant or interleaved action being
attempted, and the expected rejection/no-mutation signal.

Do not run the checks in this skill. Only specify them.

## Final Constraints

Before answering, ensure that:

- every decision is supported by repository evidence or an explicit user requirement;
- owner and boundary are clear;
- source of truth, compatibility, order, and completion signals are settled;
- every execution unit has a concrete change and completion check;
- dependencies between units are explicit;
- no execution unit is named like “update everything”, “fix architecture”, or “add tests where needed”;
- the contract contains no implementation work;
- the answer contains no methodology explanation outside the required output format.
