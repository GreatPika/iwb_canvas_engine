---
name: change-contract
description: Draft or update a Change Contract as a normative execution plan for a feature, fix, refactor, migration, or rule change. Use before implementation when the work needs a locked, verifiable contract with explicit architecture, execution order, seam-retirement gates, and slice-by-slice proof.
---

# Write Change Contract

Draft a Change Contract, not an overview.

Use only confirmed facts from the request and inspected repository artifacts.
Read the global `File naming` before naming paths, tests, fixtures, checks, or new artifacts.
Read `assets/change-contract-template.md` and use it as the output template.
Preserve section numbering and slice checkboxes.
Fill only sections and subsections that own facts for this change.
Do not use placeholders, filler, or guessed details.

If an essential fact is not locked by the request or repository evidence, surface the gap explicitly.
If the gap blocks architecture selection, fill `4B. Architecture Decision Gate` and stop after section 4.

For analyzers, rule engines, bypass detection, or structural-analysis changes, use the optional analysis-specific subsections in section 9 of the template only when they materially apply.

## Section ownership

Place each fact in the first section that owns it. Later sections may rely on that fact without restating it.

- Section 1 owns the change result.
- Section 2 owns scope and exclusions.
- Section 3 owns repository evidence, current owners, adjacent abstractions, tests, precedents, rules, and misleading local patterns.
- Section 4 owns architectural placement, dependency direction, state ownership, entry and exit boundaries, and extension seam.
- Section 5 owns execution-closed decisions that remain after section 4 is fixed.
- Section 6 owns observable end-state properties.
- Section 7 owns cross-slice order constraints, retirement gates, and final-gate timing.
- Section 8 owns concrete files implied by sections 4 through 7.
- Section 9 owns implementation constraints and proof obligations.
- Section 10 owns slice-local changes and slice-local verification.
- Sections 11 and 12 own final runs and acceptance conditions.

## Workflow

1. Inspect the surrounding code and collect repository evidence.
2. Normalize the request into mandate, included scope, and exclusions.
3. Lock one architectural form at the correct level, or stop at the decision gate.
4. Close the remaining execution decisions implied by the locked architecture.
5. State the required end state without implementation mechanics.
6. State cross-slice order constraints and retirement gates.
7. Map concrete files from the locked architecture and closed decisions.
8. Write only the implementation constraints still needed for safe execution.
9. Expand the work into atomic vertical slices with proof attached.
10. Run the self-check before returning the contract.

## Required inspection before locking architecture

Inspect and record at least:

- entrypoint or trigger path;
- current owner module or layer;
- adjacent abstractions in the same layer;
- existing tests in the area;
- one analogous valid implementation path elsewhere in the repository;
- repository rules that govern the area;
- nearby patterns that look relevant but are the wrong owner, wrong level, or wrong seam.

Choose the owner that solves the problem once without leaking policy into the wrong layer or duplicating it across callers.
Prefer the dominant local form already present in the repository.

## Required architectural lock

The contract must either lock one explicit architectural form or stop at the decision gate.

The locked form must state:

- problem ownership level;
- owning layer or module;
- dependency direction;
- state and data ownership;
- entry and exit boundaries;
- permitted extension seam;
- rejected alternatives;
- why this level is correct.

Do not leave owner, boundaries, seam, dependency direction, file placement, execution order, seam retirement timing, or verification strategy to be chosen during implementation.

## Shared seam and retirement rule

When the change creates a successor seam, migrates consumers, or retires a shared support file, the contract must state:

- the successor seam;
- the consumer migration order;
- the retirement gate;
- the registry, inventory, workflow, or CI references that must move before retirement;
- which broad verification runs are reserved for the final gate.

## Slice rule

One slice closes one new verifiable result.
Preparatory edits alone never close a slice.
Every slice must have executable behavioral verification.
Every slice that introduces or depends on the locked architectural form must also have executable structural verification.
Structural verification must make later architectural drift mechanically visible through dependency rules, import rules, architecture tests, custom lints, structure tests, or negative structural scenarios.
Existing structural checks may be reused only when the contract names them explicitly and they already guard the locked form for that slice.

## Test-first proof rule

Before changing implementation, lock the contract with tests at the owner that currently carries the behavior or invariant.

For bug fixes, regressions, false positives, false negatives, and invariant-enforcement gaps:

1. Reproduce the defect with one failing behavioral or structural test.
2. Add 1 to 3 guard tests for neighboring branches of the same contract.
3. Change only the owner of the invariant and only by the minimum edit set needed to make the tests pass.

For refactors:

1. Name the existing tests that already lock the current behavior and invariants, or add the minimum characterization tests needed to lock them first.
2. Add 1 to 3 guard tests for neighboring branches of the same contract when adjacent paths are not already protected.
3. Change only the owner, seam, or structure under refactor and only by the minimum edit set needed to keep the locked behavior green.

Do not broaden the change surface until the reproducer or characterization tests and the guard tests are green.

If the work intentionally changes observable behavior, do not treat it as a pure refactor.
Classify it as a bug fix, migration, or behavior change and prove it accordingly.

## Slice inspection minimum

Before writing a slice, identify and inspect:

- the current owner or support seam;
- the intended successor seam, if any;
- the in-scope consumers for that slice;
- the slice-local verification units;
- any registry, inventory, or CI references that would block retirement of a shared seam.

When a slice moves or retires shared support code, inventory declarations and consumers before editing the seam.

## Self-check before returning

Do not return the contract until all answers are yes:

1. Does section 3 prove that the surrounding code was actually inspected?
2. Does section 4 either lock one clear architectural form or stop at a decision gate?
3. Does section 5 contain only decisions that remain after section 4 is fixed?
4. Does section 6 describe final system truths rather than implementation mechanics?
5. Does section 7 capture the required execution order and retirement gates?
6. Does section 8 contain only files that are justified by sections 4 through 7?
7. Does section 9 contain only execution constraints and proof obligations?
8. Does every slice close one result with named verification?
9. Does every architecture-relevant slice include structural verification that would catch drift later?
10. Are all named files, tests, fixtures, and checks tied to a section that owns them?
11. If architecture is not locked, does the contract stop after section 4?
12. For bug-fix slices, does the contract name one failing reproducer first and 1 to 3 neighboring guard tests before the minimal owner-side fix?
13. For refactor slices, does the contract name the existing locking tests or add the minimum characterization tests before the minimal owner-side structural change?
