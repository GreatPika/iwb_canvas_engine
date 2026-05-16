# Contract Rules

This file extends `SKILL.md` after a template has been selected. Use it to fill the selected template with detailed Change Contract rules: evidence, section ownership, slice construction, proof obligations, seam-retirement details, analyzer-specific details, and update behavior. Do not use this file to change routing, redefine core terms, add new architecture-lock requirements, or select a different template.

## Evidence rule

Inspect and record at least:

- entrypoint or trigger path;
- current owner module or layer;
- adjacent abstractions in the same layer;
- existing tests in the area, or a confirmed absence after targeted inspection;
- one analogous valid implementation path elsewhere in the repository, or a confirmed absence after targeted inspection;
- repository rules that govern the area, or a confirmed absence after targeted inspection;
- nearby patterns that look relevant but are the wrong owner, wrong level, or wrong seam.

Choose the owner that solves the problem once without leaking policy into the wrong layer or duplicating it across callers. Prefer the dominant local form already present in the repository.

## Architecture section rule

The selected template already determines whether section 4 is a locked architecture or a decision gate. Use the architecture terms and lock-required facts from `SKILL.md`.

When filling 4A, state the evidence-backed values for:

- problem ownership level;
- selected architectural form;
- owning layer or module;
- architectural dependency/import direction;
- state and data ownership;
- entry and exit boundaries;
- permitted extension seam;
- rejected alternatives;
- why this level is correct;
- verification strategy.

Do not leave owner, boundaries, seam, architectural dependency/import direction, file placement, execution order, seam retirement timing, or verification strategy to be chosen during implementation.

When filling 4B, state the blocking gap, what is already known, any recommended form supported by evidence, supporting evidence, alternatives considered, and the exact user decision required. Do not include sections 5 through 12 after a decision gate.

## Shared seam and retirement rule

When the change creates a successor seam, migrates consumers, or retires a shared support file, the contract must state:

- the successor seam;
- the consumer migration order;
- the retirement gate;
- the registry, inventory, workflow, or CI references that must move before retirement;
- which broad verification runs are reserved for the final gate.

## Slice rule

One slice closes one new verifiable result. Preparatory edits alone never close a slice.

Every slice must have executable behavioral verification. Every slice that introduces or depends on the locked architectural form must also have executable structural verification.

Structural verification must make later architectural drift mechanically visible through architectural dependency rules, import rules, architecture tests, custom lints, structure tests, or negative structural scenarios. Existing structural checks may be reused only when the contract names them explicitly and they already guard the locked form for that slice.

Before writing a slice, identify and inspect the current owner or support seam, intended successor seam when any, in-scope consumers, slice-local verification units, and any registry, inventory, or CI references that would block retirement of a shared seam.

In section 10, duplicate the slice block as needed and number slices sequentially. Preserve checkbox syntax and give every slice a concrete title derived from the slice contract.

## Test-first proof rule

Before changing implementation, lock existing behavior, defects, or invariants with tests at the owner that currently carries them. For new behavior, put the first executable behavior test at the selected owner or public seam before implementation.

For bug fixes, regressions, false positives, false negatives, and invariant-enforcement gaps:

1. Reproduce the defect with one failing behavioral or structural test.
2. Add 1 to 3 guard tests for neighboring branches of the same contract.
3. Change only the owner of the invariant and only by the minimum edit set needed to make the tests pass.

For refactors:

1. Name the existing tests that already lock the current behavior and invariants, or add the minimum characterization tests needed to lock them first.
2. Add 1 to 3 guard tests for neighboring branches of the same contract when adjacent paths are not already protected.
3. Change only the owner, seam, or structure under refactor and only by the minimum edit set needed to keep the locked behavior green.

Do not broaden the change surface until the reproducer or characterization tests and the guard tests are green. If the work intentionally changes observable behavior, do not treat it as a pure refactor; classify it as a bug fix, migration, or behavior change and prove it accordingly.

## Analyzer, rule-engine, and structural-analysis details

These details apply only after `SKILL.md` has selected the analyzer contract template. Do not apply them merely because an ordinary implementation has structural verification.

For analyzer changes:

- list the analyzer or rule owner files in section 8;
- list concrete recognition forms the rule must support;
- list allowed forms that must not be flagged, to protect against false positives;
- state how the rule resolves ownership, imports, symbols, generated files, indirection, framework conventions, or repository-specific exceptions;
- add a failing reproducer for the exact false positive, false negative, bypass, or structural drift;
- add guard tests for neighboring accepted and rejected forms;
- prove the fix at the analyzer or rule owner, not by patching each caller or each violating file.

Forbidden shortcuts for analyzer changes:

- do not whitelist a single observed path when the invariant is structural;
- do not patch generated output when the source rule or generator owns the behavior;
- do not move policy into callers when the analyzer owner can enforce it once;
- do not retire old recognition paths until replacement coverage and consumer migration are proven.

## Template fill rules

The selected template is the document shape, not a source of new requirements.

Retain and fill the main numbered sections from the selected template: sections 1 through 4 for the gate template, and sections 1 through 12 for locked templates. Do not silently omit a main numbered section in a locked contract.

Use subsection headings only when they can be filled with concrete content. If a subsection is required to explain the lock but cannot be filled from repository evidence, do not leave it empty; use the architecture decision gate instead.

Use concrete slice titles. Preserve the checkbox syntax from the template, but replace the empty slice heading with a real slice title and add more slices only when each one closes a distinct verifiable result.

Optional categories that are commonly omitted when not relevant include successor-seam retirement gates, deferred broad verification, fixtures, registry/inventory/workflow files, and positive or negative scenarios. Analyzer-only categories belong only in the analyzer template; when that template is selected, recognition forms, allowed non-violations, and resolution rules are required.

## Updating an existing contract

When updating an existing Change Contract:

- Preserve section numbering, completed slice evidence, and stable decisions that are still supported by repository evidence.
- Patch only sections affected by new evidence or changed user direction.
- Do not rewrite stable architecture decisions unless repository evidence contradicts them.
- If a previous assumption is invalidated, add a correction note in the owning section and update affected slices, file maps, gates, and proof obligations.

## Section ownership

Place each fact in the first section that owns it. Later sections may rely on that fact without restating it.

- Section 1 owns the change result.
- Section 2 owns scope and exclusions.
- Section 3 owns repository evidence, current owners, adjacent abstractions, tests, precedents, rules, and misleading local patterns.
- Section 4 owns architectural placement, architectural dependency/import direction, state ownership, entry and exit boundaries, extension seam, and architecture decision gates.
- Section 5 owns execution-closed decisions that remain after section 4 is fixed.
- Section 6 owns observable end-state properties.
- Section 7 owns cross-slice order constraints, retirement gates, and final-gate timing.
- Section 8 owns concrete files implied by sections 4 through 7.
- Section 9 owns implementation constraints and proof obligations.
- Section 10 owns slice-local changes and slice-local verification.
- Sections 11 and 12 own final runs and acceptance conditions.

## Section guidance

### 1. Change Mandate

State the required result in one short, concrete statement. Do not include implementation mechanics, file lists, or verification details.

### 2. Change Boundary

Separate included work from exclusions. Use exclusions to prevent scope creep, not to hide unresolved architecture decisions.

### 3. Surrounding Code Review

Record inspected evidence, not assumptions. Include the evidence required above.

### 4. Architecture

Record the locked architecture or decision gate already selected through `SKILL.md` workflow. Do not select a different template from this section.

### 5. Locked Decisions

Include only decisions that remain after section 4 is fixed. Do not repeat architecture facts.

### 6. Result Requirements

State final observable truths. Avoid implementation mechanics.

### 7. Execution Order and Gates

State cross-slice order constraints, successor-seam migration order, retirement gates, and broad verification runs reserved for the final gate.

### 8. File Map

List only files justified by sections 4 through 7. Use the categories in the selected template. Do not add analyzer-specific file-map categories to the ordinary full-contract template.

Mark new files as proposed only when repository evidence supports their placement and naming.

### 9. Implementation Rules

State protected invariants, required proof, allowed change surface, and forbidden moves. When the analyzer contract template was selected, also state recognition forms, allowed non-violations, and resolution rules.

### 10. Vertical Slices

One slice closes one new verifiable result. Each slice should state slice contract, change, behavioral verification, structural verification when architecture-relevant, fixtures when relevant, scenarios when relevant, and closure evidence.

### 11. Final Verification

Reserve broad or expensive runs for the final gate when earlier slices already carry local proof. Name exact commands, suites, or checks only when supported by repository evidence.

### 12. Acceptance Criteria

State the conditions that must be true for the Change Contract to be considered complete. Keep acceptance criteria tied to mandate, result requirements, gates, and verification.
