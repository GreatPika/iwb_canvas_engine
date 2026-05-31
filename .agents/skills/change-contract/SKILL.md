---
name: change-contract
description: Create a Change Contract before code implementation. Use when a coding task needs evidence-backed source inputs, contract classification, decision traceability, owner, boundary, execution order, execution units, and completion checks before changes are made. Do not implement code, run the implementation, or review an already written contract.
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

- which repository source inputs were used;
- the selected contract profile and obligations;
- which upstream design, research, phase, plan, or repository-derived decisions
  constrain the work;
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

- `Owner-Level Fix`: the owner or owning layer, the owning cause, or whether
  the proposed fix is only a one-off caller/symptom patch;
- `Boundary-Owned Policy`: the work boundary, boundary validation, policy, or
  compatibility placement;
- the source of truth;
- compatibility behavior;
- execution order;
- `Negative Proof And Fixture Quarantine`: the proof seam or fixture strategy
  for structural, bypass, or negative proof;
- mandatory source-of-truth updates when the change alters what a registry,
  contract, guardrail, generated output, or diagram means;
- temporal/reentrancy behavior for callback, listener, observer, delivery,
  transaction, rollback, no-op, atomicity, guard, or public-state publication
  windows;
- for all-or-nothing behavior: the irreversible point, the fallible work that
  must complete before it, and the later work that is infallible,
  failure-contained, or already part of the accepted result;
- migration, replacement, or retirement strategy;
- the completion signal for any execution unit.

Implementation details may remain open only when they are local tactics inside
an already fixed owner, boundary, order, and completion signal.

## Evidence

Before writing the contract, inspect the repository enough to identify the
relevant facts.

Include only evidence that the implementer needs to understand:

- the owner of the change;
- the work boundary;
- the execution order;
- exclusions from scope;
- the source of truth;
- compatibility constraints;
- proof seams, fixture strategy, and source-input decisions.

Do not include research logs, long code quotes, raw search output, or
intermediate reasoning.

Evidence format:

    - `path/to/file.ext:line` / `surface`: observed fact -> contract consequence.

This is the contract-stage `Evidence Consequence Link`: every cited fact must
connect exact observed evidence to the contract boundary, order, proof, source
of truth, or compatibility consequence it supports.

Use path-only evidence only for new files that do not exist yet, generated
outputs without stable line references, or repository-level commands/config
surfaces where line references are not meaningful.

## Repository Source Inputs

When the request names a source input, read it:

- `against phase PHASE_FILE`: read the concrete `docs/implementation/...` document.
- `against design DESIGN_FILE`: read the concrete `.design/...` document.
- any other explicit source input file: read that file.

Preserve mandatory decisions, scope, gates, sequencing, proof expectations,
selected form decisions when present, lock-required facts, source-of-truth
impacts, verification strategies, decision trace rows, and handoff constraints.

When using `against design DESIGN_FILE`:

- output `Contract Blocker` if the design uses `NEEDS_RESEARCH` or
  `ARCHITECTURE_GATE`, or if it otherwise records unresolved owner, boundary,
  source-of-truth, proof, or user decisions;
- do not replace the design's selected architecture form with a different owner,
  source of truth, proof strategy, or fixture strategy unless the user explicitly
  asks for redesign;
- list the design path in `Source Inputs`;
- preserve the selected profile and obligations in `Classification`;
- map every design handoff decision or `Decision Trace` row to a contract
  location and execution unit/proof surface in `Decision Trace`.

If a source input or design mentions temporal ordering, observers, listeners,
callbacks, post-commit delivery, rollback/no-op behavior, atomicity, public
state publication, or mutation guards, preserve the named synchronous callback
surfaces and reentrant/interleaving proof expectations.

If a source input or design relies on all-or-nothing behavior, preserve or
settle the failure-domain split: fallible work before the irreversible point,
the irreversible point itself, and later work that is infallible,
failure-contained, or included in the accepted result.

If the contract intentionally narrows or excludes anything from a source input,
state that exclusion in `Out of Scope`, map it in `Decision Trace`, and support
it with evidence or an explicit user requirement.

Inspect when relevant:

- `PLAN.md` for active roadmap scope and step-contract status;
- `docs/README.md` as the documentation entry point;
- repository instructions for plan workflow, DCM metrics exceptions, and
  verification commands.

## Source Inputs, Classification, And Decision Trace

Every full Change Contract must include `Source Inputs`, `Classification`, and
`Decision Trace` before `Evidence`.

`Decision Chain Of Custody` is the invariant that source inputs, design/research
decisions, phase decisions, user decisions, and repository-derived decisions are
preserved into contract fields, execution units, or proof surfaces instead of
being left as prose or re-decided during implementation:

- `Source Inputs`: list the concrete design, research, phase, plan, or explicit
  source files used. Write `none` only when no source input exists.
- `Classification`: record exactly one profile and any obligations inherited
  from the request or source input. Preserve the design-selected profile and
  obligations when using `against design DESIGN_FILE`, unless the user explicitly
  asks for redesign.
- `Decision Trace`: preserve `Decision Chain Of Custody` by mapping every
  lock-required source decision to the contract location that preserves it and
  to the execution unit or proof surface that will verify it.

Decision trace format:

    | Source decision | Contract location | Execution unit / proof surface |
    |---|---|---|

Use design decision ids such as `D1` when the source design provides them. When
no upstream decision artifact exists, include repository-derived decisions that
settle owner, boundary, source of truth, compatibility, ordering, proof seam, or
fixture strategy. Do not leave a design handoff decision only in prose.

## Contract Blocker

If the owner, boundary, work order, source of truth, compatibility constraint, or
completion check cannot be determined from repository evidence or explicit user
requirements, do not write a full contract.

Output:

    # Contract Blocker

    ## Goal

    [One short paragraph.]

    ## Source Inputs

    - Design: `.design/...` / none
    - Research: `.research/...` / none
    - Phase: `docs/implementation/...` / none
    - PLAN: `PLAN.md` / none
    - Other: `path/to/source` / none

    ## Blocking Questions

    - Question:
      Blocks because:
      Needed evidence or decision:

    ## Evidence

    - `path/to/file.ext:line` / `surface`: observed fact -> why it blocks the contract.

Do not include execution units or `Classification` in a blocker. Keep `Source Inputs` so the reviewer can see which source artifacts produced the blocker.

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
when creating the contract. This preserves `Completion Evidence Boundary`: a
planning contract may define completion signals, but completion markers belong
only to the later workflow that has implementation, verification, review, and
commit evidence.

Execution units should be small and roughly balanced when possible. Correct
boundaries, dependency order, and independent completion checks are more
important than equal size.

Do not split a unit if the resulting parts cannot be completed and checked
separately. Do not merge units that have different owners, different boundaries,
or different completion checks.

## Splitting Work

First choose the natural split axis for the task:

- behavior change: split by user flow, API call, command, event, or observable
  behavior;
- refactor: split by owner, module, seam, or dependency boundary;
- migration: split by adding the new path, migrating consumers, then removing
  the old path;
- rule, analyzer, or style check: split by rule, allowed case, forbidden case,
  fixture, or integration point;
- documentation: split by source-of-truth surface and dependent references;
- build, test, or CI change: split by affected verification surface.

Then construct execution units with this procedure:

1. List the main affected surfaces: files, modules, APIs, docs, schemas, tests,
   build steps, CI jobs, generated outputs, registries, or consumers.
2. Group those surfaces by the owner that should be responsible for the change.
3. Inside each owner group, identify concrete changes that can be completed
   separately.
4. For each candidate unit, define its completion check.
5. If a candidate has no separate completion check, do not keep it as a separate
   unit. Merge it into the nearest unit that owns the same outcome, or output
   `Contract Blocker` if no valid owner exists.
6. If a candidate has more than one owner, split it by owner.
7. If a candidate has multiple independent completion checks, consider splitting
   it by those checks.
8. If two adjacent candidates have the same owner, same boundary, same risk, and
   same completion check, merge them.
9. Order units so that owners and boundaries are established before consumers
   are changed.
10. Remove old paths only after replacement paths and consumers are in place.

A valid execution unit is not created from a file list alone. It is created from
this chain:

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

## All-Or-Nothing Behavior

When correctness relies on a change either fully taking effect or leaving prior
state unchanged, the contract must make the failure domain decision-complete.

Name:

- the irreversible point;
- the fallible work that must complete before that point;
- the later work that is allowed because it is infallible, failure-contained, or
  already part of the accepted result;
- the expected failure projection before and after the irreversible point;
- the proof surface that would fail if fallible work moved to the wrong side of
  that point.

Execution unit completion checks must prove this boundary when it is material to
the contract. Do not rely only on happy-path event order when the guarantee is
all-or-nothing behavior.

## Output Format

When enough evidence exists, output:

    # Change Contract

    ## Goal

    [One short paragraph describing the intended final state.]

    ## Source Inputs

    - Design: `.design/...` / none
    - Research: `.research/...` / none
    - Phase: `docs/implementation/...` / none
    - PLAN: `PLAN.md` / none
    - Other: `path/to/source` / none

    ## Classification

    Profile:

    Obligations:

    ## Decision Trace

    | Source decision | Contract location | Execution unit / proof surface |
    |---|---|---|
    | `D1` or direct requirement | `Boundaries.Owner` / `Unit N` / `Completion Check` | concrete unit or proof signal |

    ## Evidence

    - `path/to/file.ext:line` / `surface`: observed fact -> contract consequence.

    Preserve `Evidence Consequence Link`: keep exact stable evidence tied to the
    contract consequence, and name any new/generated/command-surface exception.

    ## Boundaries

    Owner:

    In Scope:

    Out of Scope:

    Source of Truth:

    Preserve `Source-Of-Truth Singularity`: name the owning source of truth,
    its real human or machine consumer, required dependent updates, and any
    cache/performance duplication invariant plus proof strategy.

    Compatibility:

    Order Constraints:

    ## Execution Units

    ### [ ] Unit 1: [short title]

    Owner:

    Boundary:

    Change:

    Completion Check:

    Depends On:


Add more units only when needed.

## Completion Check

Each `Completion Check` must tell the implementer how to know that the unit is
complete.

Each check must name an observable or executable signal and the bounded surface
where that signal applies.

Apply the shared `Outcome-Proof Fit` rule to every `Completion Check`:
`Claim -> Direct outcome -> Proxy risk -> Required proof`.

Each check must prove the direct outcome claimed by the unit. For every unit
claim about behavior, invariant, owner responsibility, source-of-truth update,
migration, guardrail, compatibility promise, or completion outcome, name the
owner-observable or external result that would be false if implementation were
fake or incomplete.

A proxy signal such as method calls, call order, revision increments, registry
entries, object construction, compile success, event firing, schema presence,
rebuild counts, cache key shape, or guardrail registration is not sufficient
unless the unit claim is explicitly scoped to that proxy or the proxy is itself
the claimed outcome.

A completion check may be:

- a test, command, or check with an expected signal;
- a specific behavior visible through a user flow, API, CLI, event, or output;
- removal of an old import, symbol, path, registry entry, or call site from a
  bounded surface;
- migration of named consumers to a new owner, seam, API, schema, or path;
- an updated source-of-truth document plus required dependent references;
- an analyzer rule, lint rule, fixture, or build integration that proves the
  rule is active;
- preservation of a public signature, format, schema, or compatibility promise.

Do not use vague checks such as "verify correctness", "add tests as needed",
"ensure it works", "update callers where necessary", or "clean up related
code". If the exact signal cannot be named, output `Contract Blocker`.

`Negative Proof And Fixture Quarantine`: for negative, bypass, fixture, or
structural-recognition proof, a completion check must name the production seam
or contract-named test seam, fixture mechanism, bounded surface, and expected
pass/fail signal. Fixture-only names, values, schemas, declarations, or data
must not be added to real production source-of-truth files, public API
registries, schemas, durable contracts, generated docs, or public surfaces.

For temporal/callback/guard work, a completion check is inadequate unless it
names the specific callback surface, the reentrant or interleaved action being
attempted, and the expected rejection/no-mutation signal.

For all-or-nothing behavior, a completion check is inadequate unless it names
the irreversible point or bounded seam, the fallible action being exercised or
structurally excluded, and the expected no-mutation, rollback, containment, or
publication signal.

Do not run the checks in this skill. Only specify them.

## Final Constraints

Before answering, ensure that:

- every decision is supported by repository evidence or an explicit user
  requirement;
- source inputs, classification, and decision trace preserve every relevant
  upstream design, research, phase, plan, or repository-derived decision;
- owner and boundary are clear;
- source of truth, compatibility, order, and completion signals are settled;
- every execution unit has a concrete change and completion check;
- for every completion check, `Outcome-Proof Fit` is satisfied: either it proves
  the direct outcome claimed by its unit, the unit claim is explicitly scoped to
  the checked proxy, or the checked proxy is itself the claimed outcome;
- dependencies between units are explicit;
- no execution unit is named like "update everything", "fix architecture", or
  "add tests where needed";
- the contract contains no implementation work or post-implementation status
  placeholders, preserving `Completion Evidence Boundary`;
- the answer contains no methodology explanation outside the required output
  format.
