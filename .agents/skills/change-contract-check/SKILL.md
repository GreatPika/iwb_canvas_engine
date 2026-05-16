---
name: change-contract-check
description: Validate a drafted or updated Change Contract before implementation begins. Use immediately after writing or revising a Change Contract for a feature, bug fix, refactor, migration, analyzer/rule change, or seam retirement. Check template compliance, repository evidence, architecture lock, section ownership, cross-section consistency, slice proof, test-first obligations, retirement gates, and contradictions. Return a blocking validation report, not a rewritten contract, unless repair is explicitly requested.
---

# Validate Change Contract

Validate the contract, not the code change.

Use this skill only after a Change Contract already exists.
Do not start implementation from a contract that fails blocking checks.
Default to audit-only. Do not rewrite the contract unless the user explicitly asks for repair.
When the paired authoring skill is available, read its `SKILL.md`, `references/contract-rules.md`, and the one template from the paired authoring skill's `assets/` directory that should apply to the contract.
Read `assets/change-contract-validation-report-template.md` and use it as the output format.

Treat the contract as acceptable only when it is specific enough that implementation choices are no longer floating at the wrong level.
Reject vague approval language such as “looks good overall” when any blocking rule is still open.

## Verdicts

Return exactly one verdict:

- `PASS` — the contract is implementable as written; only minor wording issues may remain.
- `REVISE` — the contract has non-blocking weaknesses or small gaps, but the architecture and proof strategy are mostly locked.
- `BLOCKED` — implementation must not start because the contract leaves architecture, ownership, verification, sequencing, or retirement conditions unresolved.

Use `BLOCKED` whenever the contract would force implementation-time design decisions or cannot be verified slice by slice.

## What to inspect

Inspect the contract itself and re-check the repository evidence behind it.
Do not trust section 3 at face value.
Confirm, when relevant:

- named paths, modules, packages, layers, and tests actually exist or are justified as new artifacts;
- the claimed current owner and entry path match the repository;
- the analogous implementation path is actually analogous;
- the cited repository rules govern the area;
- the rejected misleading patterns are real and are actually the wrong owner, wrong level, or wrong seam.

When the repository does not contain a formal rule file for the area, accept an explicit statement that no formal local rule was found only if the contract names the dominant local pattern that will govern the change.

## Expected template selection

Validate the contract against exactly one paired authoring template. Use the paired `change-contract` skill routing rules as the source of truth for selection, and read the selected template from that skill's `assets/` directory:

- `assets/architecture-gate-template.md` when repository evidence shows architecture cannot be locked, or when the contract uses `4B. Architecture Decision Gate`; no sections after section 4 may contain substantive plan content.
- `assets/analyzer-contract-template.md` when the architecture is locked and the contract subject is an analyzer, rule engine, bypass detector, static-analysis check, contract-enforcement mechanism, or structural-recognition rule.
- `assets/full-contract-template.md` for all other locked contracts.

Do not validate a normal feature against the analyzer template merely because it has structural proof. Do not treat analyzer-only headings as optional full-contract headings.
For every drafted or updated contract, require the current paired template shape: sections 1 through 4 for gate contracts, and sections 1 through 11 for locked contracts, with section 8 as `Implementation Rules` and section 9 as `Vertical Slices`.
Do not accept preserved older numbering, standalone file maps, or deprecated proof headings as a separate valid contract shape. Optional or triggered headings from the template may be omitted when they have no confirmed content; common examples include `Change Surface Summary`, `Successor Seam and Retirement Gates`, `Seam Migration Matrix`, `Cross-Slice Finalization`, `Deferred Broad Verification`, and `Broad Checks`.

## Blocking checks

Mark the contract `BLOCKED` when any of the following is true:

1. The main numbered structure or required non-optional headings do not follow the expected paired authoring template.
2. Template placeholders, filler text, guessed facts, or unexplained `...` remain.
3. Section 3 does not prove real inspection of the surrounding code.
4. Section 4 does not lock one architectural form and does not stop cleanly at `4B. Architecture Decision Gate`.
5. Section 4 leaves owner, boundaries, seam, dependency direction, state ownership, file placement, execution order, or verification strategy to implementation-time choice.
6. `4B. Architecture Decision Gate` is filled but later sections still contain substantive plan content.
7. Section 5 contains architecture choices that should have been locked in section 4.
8. Section 6 describes implementation mechanics instead of end-state truths.
9. Section 7 misses required migration order, successor seam, retirement gate, or deferred broad verification when a shared seam is introduced, migrated, or retired.
10. Section 8 omits proof obligations, protected invariants, or forbidden moves needed to keep execution safe.
11. Any slice omits the `Files` block or fails to list the files, tests, fixtures, inventories, workflows, checks, verify-only evidence, or explicit exclusions that the slice relies on.
12. Any slice is only preparatory, horizontal, or non-verifiable.
13. Any slice lacks executable semantic proof with a stated proof intent and command.
14. A slice that introduces or depends on the locked architecture lacks structural verification that would make drift visible later.
15. A bug-fix, regression, false-positive, false-negative, or invariant-enforcement contract does not start with one failing reproducer plus 1 to 3 neighboring guard tests before the minimal owner-side fix.
16. A refactor contract does not name locking tests or add minimum characterization tests before structural edits.
17. The contract contradicts itself across sections.
18. Named files, tests, fixtures, inventories, workflows, or checks appear only as section 3 evidence while later sections treat them as change targets.
19. A locked contract uses a standalone global file-map section instead of slice-local file ownership.
20. Section 2's `Change Surface Summary` assigns file ownership, lists per-slice file inventories, or carries proof obligations instead of compact orientation.
21. Section 7 omits `Seam Migration Matrix` when shared-seam creation, migration, or retirement must coordinate multiple retired or changed seams, successor seams, consumer groups, registry, inventory, workflow, or CI references, or retirement proofs.
22. Section 7 omits `Cross-Slice Finalization` when shared cleanup, registry/index refresh, backlog cleanup, derived navigation, or another cross-slice final owner exists.

## Non-blocking weaknesses

Use `REVISE` instead of `PASS` when the contract is implementable but weaker than it should be, for example:

- precedent is valid but not the closest one;
- repository rule citation is thin but directionally correct;
- a result requirement is too broad but still testable;
- a slice is slightly oversized but still closes one verifiable result;
- acceptance criteria are incomplete but redundant with stronger earlier sections.

## Section-by-section review rules

### Section 1. Change Mandate

Verify that it states one concrete result, not an execution plan.
Reject multiple bundled outcomes.

### Section 2. Change Boundary

Verify that included scope and exclusions are explicit.
Reject boundaries that silently expand architecture or rollout scope.
When `Change Surface Summary` is present, require compact orientation only: mode, primary surfaces, production/test status, and broad change class. Reject file ownership, per-slice file inventories, proof obligations, or implementation ordering in the summary.

### Section 3. Surrounding Code Review

Require inspected artifacts with specific revelations.
Require current entry path, current owner, adjacent abstractions, existing tests, analogous valid path, governing rules, and rejected misleading local patterns.
Reject generic claims such as “reviewed relevant files” without named evidence.

### Section 4. Architecture

Accept either:
- one fully locked `4A. Locked Architectural Form`; or
- one real `4B. Architecture Decision Gate` followed by no substantive sections after section 4.

In `4A`, require: ownership level, selected form, owner, dependency direction, data ownership, boundaries, seam, rejected alternatives, why this level is correct, and verification strategy.
Reject unresolved alternatives or wording that defers the core design choice.

### Section 5. Locked Decisions

Require only execution-closed decisions that remain after section 4 is fixed.
Reject architectural choices, vague intentions, and duplicate result requirements.

### Section 6. Result Requirements

Require observable end-state truths.
Reject file-by-file mechanics, step ordering, and implementation tactics.

### Section 7. Execution Order and Gates

Require preconditions, cross-slice sequencing, migration order when relevant, seam migration matrix when shared-seam creation, migration, or retirement coordinates multiple seams, consumer groups, registry, inventory, workflow, or CI references, or retirement proofs, retirement gate when relevant, cross-slice finalization owners when relevant, and final-gate timing for broad verification.
Reject “run everything after each slice” unless the contract proves that is required and affordable.

### Section 8. Implementation Rules

Require protected invariants, required proof, allowed change surface, and forbidden moves.
When the expected template is `assets/analyzer-contract-template.md`, require recognition forms, allowed non-violations, and resolution rules.
For non-analyzer locked contracts, reject analyzer-only recognition, allowed-form, or resolution headings unless the contract subject actually requires the analyzer template.
Reject generic safety language that does not constrain execution.

### Section 9. Vertical Slices

Require atomic vertical slices.
Reject slice headings that preserve the template's empty title form, such as `### Slice 1. [ ]`, instead of naming a concrete verifiable result.
Each slice must close one new verifiable result.
Preparatory work alone does not count as a closed slice.
Require every slice to contain a `Files` block. Cross-check that files, tests, fixtures, inventories, workflows, checks, verify-only evidence, and explicit exclusions used by the slice are listed there with a purpose or action.
Reject a standalone global file map as the owner of implementation files. Files listed only in section 3 are evidence, not change targets.
Require executable semantic proof for every slice, written as proof intent plus command.
Require executable structural verification for every slice that introduces or depends on the locked form.
For analyzer contracts, require a reproducer proof for the exact false positive, false negative, bypass, or structural drift being fixed.
Require `Closure Gate` for planned draft slices. Accept `Closure Evidence` only when reviewing an updated already-executed contract with concrete completion evidence.
Reject slices that mix multiple user-visible results, multiple retirement events, or multiple proof obligations without necessity.

### Sections 10 and 11. Final Verification and Acceptance Criteria

Require final runs and acceptance criteria to reflect the earlier contract rather than introduce new scope.
Reject broad final checks that should have been slice-local proof.

## Cross-section consistency checks

Perform these checks explicitly:

1. Every file edited, refreshed, verified, or excluded by a slice must appear in that slice's `Files` block with a purpose or action.
2. Every slice file must be supported by section 4 placement, section 7 ordering or finalization gates, section 3 repository evidence, or an explicit proposed-new-file placement rationale.
3. Every named invariant or proof obligation in section 9 must be traceable to section 8.
4. Every sequencing dependency in section 9 must be justified by section 7.
5. Every result in section 9 must support section 6.
6. Files listed only in section 3 must not be treated as change targets unless the owning slice also lists them in `Files`.
7. Locked contracts must not use a standalone global file map.
8. `Change Surface Summary` must not be used as a source of file ownership, proof obligations, or implementation ordering.
9. `Seam Migration Matrix` and `Cross-Slice Finalization` must be present only when their triggering cross-slice coordination exists, and must not become duplicate file inventories.
10. Section 5 must not silently redefine section 4.
11. Section 10 must not compensate for missing slice-local verification.
12. Section 11 must not expand scope beyond sections 1 and 2.
13. If 4B is used, no sections after section 4 may contain substantive plan content.

## Change-type rules

Infer the change type from the contract and enforce the matching proof rule.

### Bug fix / regression / false positive / false negative / invariant gap

Require:

- one failing reproducer first;
- 1 to 3 neighboring guard tests;
- the minimum owner-side fix;
- no broadened change surface before the tests are green.

### Refactor

Require:

- existing locking tests or minimum characterization tests first;
- 1 to 3 neighboring guard tests when adjacent branches are not already protected;
- only the minimum structural change needed to preserve the locked behavior.

### Behavior change / migration

Reject classification as “pure refactor” when observable behavior intentionally changes.
Require explicit result requirements, migration order when relevant, and acceptance criteria that match the new behavior.

## How to report findings

For every finding, provide:

- severity: `blocking` or `non-blocking`;
- location: section number and subsection;
- rule violated or satisfied;
- concrete evidence from the contract and, when relevant, from the repository;
- minimal repair instruction.

Prefer the smallest repair that makes the contract acceptable.
When multiple issues stem from one upstream defect, identify the root issue first.

## Self-check before returning

Do not return the report until all answers are yes:

1. Did you verify the contract against both the template shape and the writer-skill rules when available?
2. Did you re-inspect repository evidence instead of trusting the contract summary?
3. Did you distinguish blocking defects from non-blocking weaknesses?
4. Did you check section ownership and cross-section consistency, not just local section quality?
5. Did you enforce bug-fix or refactor proof rules when applicable?
6. Did you avoid rewriting the contract unless repair was explicitly requested?
7. Did your verdict match the strongest defect you found?
