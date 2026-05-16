# Contract Rules

This file extends `SKILL.md` after a template has been selected. Use it to fill the selected template with detailed Change Contract rules: evidence, section ownership, slice-local file ownership, proof obligations, seam-retirement details, analyzer-specific details, and update behavior. Do not use this file to change routing, redefine core terms, add new architecture-lock requirements, or select a different template.

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

When filling 4B, state the blocking gap, what is already known, any recommended form supported by evidence, supporting evidence, alternatives considered, and the exact user decision required. Do not include any sections after section 4 in a decision-gate contract.

## Shared seam and retirement rule

When the change creates a successor seam, migrates consumers, or retires a shared support file, the contract must state:

- the successor seam;
- the consumer migration order;
- the retirement gate;
- the registry, inventory, workflow, or CI references that must move before retirement;
- which broad verification runs are reserved for the final gate.

When shared-seam creation, migration, or retirement coordinates more than one retired or changed seam, successor seam, consumer group, registry, inventory, workflow, CI reference, or retirement proof, add a `Seam Migration Matrix` in section 7. Each row should connect the retired or changed seam to its successor, affected consumers or documents, migration slice, and retirement proof. Do not scatter this mapping only across boundary notes, order gates, and slices.

## Slice rule

One slice closes one new verifiable result. Preparatory edits alone never close a slice.

Every slice must have executable semantic proof. Every slice that introduces or depends on the locked architectural form must also have executable structural proof.

Semantic proof demonstrates the behavior, API contract, documentation meaning, or user-visible state that the slice changes. Structural proof demonstrates architecture, import direction, owner boundaries, registries, indexes, generated navigation, analyzer recognition, or other mechanically checkable structure.

Write proof as intent plus command: first state what the command proves, then give the command. Avoid naked shell snippets whose failure mode is not self-explanatory.

Structural verification must make later architectural drift mechanically visible through architectural dependency rules, import rules, architecture tests, custom lints, structure tests, registry/index checks, generated-documentation checks, or negative structural scenarios. Existing structural checks may be reused only when the contract names them explicitly and they already guard the locked form for that slice.

Before writing a slice, identify and inspect the current owner or support seam, intended successor seam when any, in-scope consumers, slice-local verification units, and any registry, inventory, or CI references that would block retirement of a shared seam.

Every slice must contain a `Files` block. Put files there, not in a separate global list. Each file expected to be edited must appear in exactly one slice as a primary edit, alignment, registry/index/workflow, verification, or cleanup/finalization file. A file may appear in multiple slices only when each slice names a different purpose; one slice must be named as the final owner for cross-slice cleanup or finalization. Files listed only in section 3 are evidence, not change targets. Files named in `Change Surface Summary` are broad surfaces only, not ownership assignments. When updating a contract that previously used a standalone file list, move those files into the owning slice `Files` blocks in the current template shape.

For each slice, distinguish file groups only when the categories are relevant: primary edit files, alignment files, registry/index/workflow files, verification files, verify-only evidence files, and excluded files. Give each file or group an action such as create, update, remove, refresh, verify-only, or excluded. Mark new files as proposed only when repository evidence supports placement and naming.

In section 9, duplicate the slice block as needed and number slices sequentially. Preserve checkbox syntax and give every slice a concrete title derived from the slice contract. Use `Closure Gate` for planned draft slices. Use `Closure Evidence` only when updating an existing executed contract and the slice already has concrete completion evidence.

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

- list analyzer or rule owner files in the owning slice `Files` block;
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

Retain and fill the main numbered sections from the selected template: sections 1 through 4 for the gate template, and sections 1 through 11 for locked templates. Do not silently omit a main numbered section in a locked contract.

Use subsection headings only when they can be filled with concrete content. If a subsection is required to explain the lock but cannot be filled from repository evidence, do not leave it empty; use the architecture decision gate instead.

Use concrete slice titles. Preserve the checkbox syntax from the template, but replace the empty slice heading with a real slice title and add more slices only when each one closes a distinct verifiable result.

Optional categories that are commonly omitted when not relevant include `Change Surface Summary`, successor-seam retirement gates, `Seam Migration Matrix`, `Cross-Slice Finalization`, deferred broad verification, slice file subcategories, fixtures, and positive or negative scenarios. Analyzer-only recognition categories belong only in the analyzer template and are required there. Do not emit `None` for optional categories; omit the category instead.

## Updating an existing contract

When updating an existing Change Contract:

- Re-select the current template through `SKILL.md` and convert the output to that template shape.
- Preserve completed slice evidence and stable decisions that are still supported by repository evidence by placing them in the current owning sections.
- Patch only content affected by new evidence, changed user direction, or required migration into the current template shape.
- Do not rewrite stable architecture decisions unless repository evidence contradicts them.
- If a previous assumption is invalidated, add a correction note in the owning section and update affected slices, slice-local file ownership, gates, and proof obligations.
- Do not preserve obsolete section numbering, standalone file-list sections, or deprecated proof headings. Move old file-list content into slice `Files` blocks, and express old behavioral or structural verification content under the current `Slice Verification` proof headings.

## Section ownership

Place each fact in the first section that owns it. Later sections may rely on that fact without restating it.

- Section 1 owns the change result.
- Section 2 owns the compact change-surface summary, included scope, and exclusions.
- Section 3 owns repository evidence, current owners, adjacent abstractions, tests, precedents, rules, and misleading local patterns.
- Section 4 owns architectural placement, architectural dependency/import direction, state ownership, entry and exit boundaries, extension seam, and architecture decision gates.
- Section 5 owns execution-closed decisions that remain after section 4 is fixed.
- Section 6 owns observable end-state properties.
- Section 7 owns preconditions, cross-slice order constraints, seam migration matrices, retirement gates, the `Cross-Slice Finalization` list, and final-gate timing.
- Section 8 owns implementation constraints and proof obligations.
- Section 9 owns slice-local files, changes, and verification.
- Sections 10 and 11 own final runs and acceptance conditions.

## Section guidance

### 1. Change Mandate

State the required result in one short, concrete statement. Do not include implementation mechanics, file lists, or verification details.

### 2. Change Boundary

Start with `Change Surface Summary` when it improves orientation. Keep it compact: mode, primary surfaces, production/test status, and broad change class. Do not list file ownership or per-slice file inventories there.

Separate included work from exclusions. Use exclusions to prevent scope creep, not to hide unresolved architecture decisions. Do not put preflight blockers, baseline state checks, or broad-verification deferrals here; put those in section 7.

### 3. Surrounding Code Review

Record inspected evidence, not assumptions. Include the evidence required above. Separate current evidence from target architecture; do not present future target owners or entrypoints as current repository facts. Put target ownership in section 4 unless the repository already defines it.

### 4. Architecture

Record the locked architecture or decision gate already selected through `SKILL.md` workflow. Do not select a different template from this section.

### 5. Locked Decisions

Include only decisions that remain after section 4 is fixed. Do not repeat architecture facts.

### 6. Result Requirements

State final observable truths. Avoid implementation mechanics.

### 7. Execution Order and Gates

State preconditions, cross-slice order constraints, successor-seam migration order, seam migration matrix when useful, retirement gates, `Cross-Slice Finalization`, and broad verification runs reserved for the final gate. Use `Cross-Slice Finalization` only for shared cleanup, registry/index refresh, backlog cleanup, derived navigation, or other files whose final owner matters across slices. Do not use this section as a complete file inventory; files that are edited or verified belong in slice `Files` blocks.

### 8. Implementation Rules

State protected invariants, required proof, allowed change surface, and forbidden moves. When the analyzer contract template was selected, also state recognition forms, allowed non-violations, and resolution rules.

### 9. Vertical Slices

One slice closes one new verifiable result. Each slice must state slice contract, files, change, semantic proof, structural proof when architecture-relevant, broad checks when relevant, and closure gate or evidence depending on whether the contract is planned or already executed.

Use the slice `Files` block as the only complete owner for files to edit, refresh, verify, or exclude in that slice. Keep files from section 3 as evidence unless the same file appears in a slice. Add fixtures, positive scenarios, and negative scenarios only when they materially constrain execution or proof; do not emit `None`.

### 10. Final Verification

Reserve broad or expensive runs for the final gate when earlier slices already carry local proof. Name exact commands, suites, or checks only when supported by repository evidence.

### 11. Acceptance Criteria

State the conditions that must be true for the Change Contract to be considered complete. Keep acceptance criteria tied to mandate, result requirements, gates, and verification.
