---
name: change-contract-check
description: Validate a drafted or updated Change Contract before implementation begins. Use immediately after writing or revising a Change Contract for a feature, bug fix, refactor, migration, source-of-truth documentation update, analyzer/rule change, or seam retirement. Check template compliance, repository evidence, architecture lock, information ownership, cross-section consistency, slice proof, profile proof obligations, retirement gates, and contradictions. Return a blocking validation report, not a rewritten contract, unless repair is explicitly requested.
---

# Validate Change Contract

Validate the contract, not the code change.

Use this skill only after a Change Contract already exists.
Do not start implementation from a contract that fails blocking checks.
Default to audit-only. Do not rewrite the contract unless the user explicitly asks for repair.
When the paired authoring skill is available, read its `SKILL.md`, `references/contract-rules.md`, and the one active template from the paired authoring skill's `assets/` directory that should apply to the contract.
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
Do not trust `Evidence Map` at face value.
Confirm, when relevant:

- named paths, modules, packages, layers, documents, analyzers, fixtures, and tests actually exist or are justified as new artifacts;
- the claimed current owner and entry path match the repository;
- the analogous implementation or documentation path is actually analogous;
- the cited repository rules govern the area;
- the rejected misleading patterns are real and are actually the wrong owner, wrong level, stale, or misleading.

When the repository does not contain a formal rule file for the area, accept an explicit statement that no formal local rule was found only if the contract names the dominant local pattern that will govern the change.

## Expected template selection

Validate the contract against exactly one paired authoring template. Use the paired `change-contract` skill routing rules as the source of truth for selection, and read the selected template from that skill's `assets/` directory:

- `assets/architecture-gate-template.md` when `Contract Mode: ARCHITECTURE_GATE`.
- `assets/full-contract-template.md` when `Contract Mode: FULL`.

Do not validate a locked analyzer contract against a separate shape. `ANALYZER_RULE` is a profile inside the unified locked template.

For every drafted or updated contract, require the current paired template shape:

- gate contracts contain header fields and sections 1 through 3 only;
- locked contracts contain header fields and sections 1 through 7.

Do not accept preserved older numbering, standalone file inventories, or deprecated proof headings as a separate valid contract shape.

## Blocking checks

Mark the contract `BLOCKED` when any of the following is true:

1. The header omits `Contract Mode`, `Contract Profile`, or `Contract Obligations`.
2. `Contract Mode`, `Contract Profile`, or `Contract Obligations` contains unsupported values or obligation ordering.
3. The main numbered structure does not follow the selected active template.
4. Template placeholders, filler text, guessed facts, unexplained ellipses, or empty required headings remain.
5. `Evidence Map` does not prove real inspection of the surrounding repository state.
6. `ARCHITECTURE_GATE` is selected but section 3 does not identify a real blocking gap and exact user decision.
7. `ARCHITECTURE_GATE` is selected but any substantive section after section 3 is present.
8. `FULL` is selected but section 3 does not lock one architectural form.
9. `FULL` is selected but section 3 leaves owner, boundaries, seam, dependency direction, state ownership, file placement, execution order, or verification strategy to implementation-time choice.
10. `FULL` is selected and `Decision Ledger` has malformed decision IDs or omits a decision ID referenced by a slice or final gate.
11. `FULL` is selected and the selected `Contract Profile` does not match the owner and required proof mode.
12. `ARCHITECTURE_GATE` is selected and the selected `Contract Profile` is neither supported by known request/repository evidence nor a documented `BEHAVIOR_CHANGE` fallback for unresolved profile uncertainty.
13. `FULL` is selected and required profile proof is missing.
14. `FULL` is selected and a required obligation is missing, or a listed obligation lacks its required proof and sequencing.
15. `FULL` is selected with `SEAM_MIGRATION`, but successor/retired seam, consumer migration order, retirement gate, or negative proof is missing.
16. `FULL` is selected with `PUBLIC_API_CHANGE`, but compatibility decision, migration/versioning note, or public contract proof is missing.
17. `FULL` is selected with `BUG_FIX`, but the contract does not require a reproducer first plus 1 to 3 neighboring guard tests before the minimal owner-side fix.
18. `FULL` is selected with `REFACTOR`, but the contract does not name locking tests or minimum characterization tests before structural edits.
19. Any slice omits the `Files` block or fails to list the files, tests, fixtures, inventories, workflows, checks, verify-only evidence, or explicit exclusions that the slice relies on.
20. Any slice is only preparatory, horizontal, or non-verifiable.
21. Any slice lacks executable proof with a stated proof intent and command.
22. A slice that introduces or depends on the locked architecture lacks structural verification that would make drift visible later.
23. A slice mixes decision IDs, obligation labels, and proof IDs in the same subsection instead of separating `Implements`, `Obligations Covered`, and `Proof`.
24. The contract contradicts itself across sections.
25. Named files, tests, fixtures, inventories, workflows, or checks appear only as evidence while later sections treat them as change targets.
26. A locked contract uses a standalone global file inventory instead of slice-local file ownership.
27. Final gate introduces new scope instead of proving earlier decisions, obligations, and slices.

## Non-blocking weaknesses

Use `REVISE` instead of `PASS` when the contract is implementable but weaker than it should be, for example:

- precedent is valid but not the closest one;
- repository rule citation is thin but directionally correct;
- a slice is slightly oversized but still closes one verifiable result;
- proof IDs are valid but named unclearly;
- `Decision Ledger` includes unreferenced summary rows that duplicate section 3 facts;
- `Proof Plan` contains one-off commands that should live in the owning slice;
- `SOURCE_OF_TRUTH_DOCS` negative proof is broader than needed but still bounded enough to execute;
- final completion conditions are redundant but do not expand scope.

## Section-by-section review rules

### Header

Verify the mode, profile, and obligations first. Reject profile selection by file extension. The selected profile must follow the paired authoring skill priority order: `ANALYZER_RULE`, `SOURCE_OF_TRUTH_DOCS`, `REFACTOR`, `BEHAVIOR_CHANGE`. For `ARCHITECTURE_GATE`, accept the conservative `BEHAVIOR_CHANGE` fallback only when section 3 documents that the blocking gap prevents confident profile classification.

### Section 1. Mandate and Boundary

Verify that the mandate states one concrete result, not an execution plan.
Verify that included scope and exclusions are explicit.
Reject boundaries that silently expand architecture or rollout scope.

### Section 2. Evidence Map

Require inspected artifacts with specific revelations.
Require baseline evidence, entry paths, current owners, existing checks, valid precedents, governing rules, and misleading patterns when relevant.
Reject generic claims such as “reviewed relevant files” without named evidence.
Reject target-state requirements presented as baseline evidence.

### Section 3. Architecture Decision

For `FULL`, require one locked form with selected form, ownership, seam, dependency direction, state/data ownership, entry/exit boundaries, verification strategy, decision ledger, and rejected alternatives. Accept a concrete no-ID statement in `Decision Ledger` when slices and final gate do not need separate durable decision IDs. Treat ledger rows that merely summarize nearby section 3 facts and are not referenced by slices or final gate as non-blocking duplication.
Reject unresolved alternatives or wording that defers the core design choice.

For `ARCHITECTURE_GATE`, require one real gate with blocking gap, known facts, recommended form, supporting evidence, alternatives considered, and exact user decision required.

### Section 4. Execution Guardrails

Require cross-slice order and constraints when sequencing matters.
Require seam migration details when `FULL` is selected with `SEAM_MIGRATION`.
Require forbidden moves that materially constrain execution.
Require deferred broad verification only when broad checks are intentionally held for the final gate.
Reject using this section as a complete file inventory.

### Section 5. Proof Plan

Require reusable proof IDs when commands or proof groups are referenced by more than one slice or by the final gate.
Accept a concrete statement that proof is slice-local when no reusable proof groups exist.
Reject duplicated reusable commands scattered across slices and final gate. Treat one-off commands placed in `Proof Plan` as non-blocking drift toward duplication.

### Section 6. Vertical Slices

Require atomic vertical slices.
Reject slice headings that preserve the template's empty title form instead of naming a concrete verifiable result.
Each slice must close one new verifiable result.
Preparatory work alone does not count as a closed slice.
Require every slice to contain `Implements`, `Files`, `Change`, `Proof`, and `Closure`. Require `Obligations Covered` when the slice closes part of `BUG_FIX`, `SEAM_MIGRATION`, or `PUBLIC_API_CHANGE`.
Reject obligation labels or proof IDs in `Implements`. Reject decision IDs or proof IDs in `Obligations Covered`. Reject decision IDs or obligation labels used as proof IDs.
Require executable proof for every slice, written as proof intent plus command.
Require executable structural verification for every slice that introduces or depends on the locked form.
For `ANALYZER_RULE`, require positive and negative fixtures or equivalent analyzer checks.
Reject slices that mix multiple user-visible results, multiple retirement events, or multiple proof obligations without necessity.

### Section 7. Final Gate

Require final proof set and completion conditions to reflect earlier decisions, obligations, and slices.
Reject broad final checks that should have been slice-local proof.
Reject new scope introduced only at the final gate.

## Cross-section consistency checks

Perform these checks explicitly:

1. Every file edited, refreshed, verified, excluded, or finalized by a slice must appear in that slice's `Files` block with a purpose or action.
2. Every slice file must be supported by section 3 placement, section 4 ordering or finalization gates, section 2 repository evidence, or an explicit proposed-new-file placement rationale.
3. Every decision ID referenced in a slice `Implements` or final gate must exist in `Decision Ledger`.
4. Every proof ID referenced in a slice or final gate must exist in `Proof Plan`.
5. Every obligation label referenced in `Obligations Covered` must be listed in `Contract Obligations`.
6. Every sequencing dependency in section 6 must be justified by section 4.
7. Every slice result must support a decision, obligation, or mandate.
8. Files listed only in evidence must not be treated as change targets unless the owning slice also lists them in `Files`.
9. Locked contracts must not use a standalone global file inventory.
10. Seam migration details must be present only when `SEAM_MIGRATION` is listed, and must not become a duplicate file inventory.
11. Final gate must not compensate for missing slice-local verification.
12. If `ARCHITECTURE_GATE` is used, no sections after section 3 may contain substantive plan content.

## Profile and obligation checks

Infer the profile and obligations from the contract and repository evidence, then compare them to the header. For `ARCHITECTURE_GATE`, validate only header classification and known facts; do not require profile proof, obligation proof, slices, proof plan, or final gate content.

### BEHAVIOR_CHANGE

For `FULL`, require behavioral verification at the owner or public seam. Require structural proof when the slice introduces or depends on locked architecture.

### REFACTOR

For `FULL`, require existing locking tests or minimum characterization tests first. Require proof that observable behavior remains unchanged.

### SOURCE_OF_TRUTH_DOCS

For `FULL`, require targeted semantic proof, documentation structural checks when applicable, and negative proof for retired terminology or stale references. Reject invented runtime tests for documentation-only contracts. Treat overly broad but bounded negative proof as a weakness; treat repository-wide negative proof without a named retired concept and bounded source-of-truth surface as missing targeted proof.

### ANALYZER_RULE

For `FULL`, require recognition forms, allowed non-violations, resolution rules when relevant, and positive/negative fixtures or equivalent analyzer checks.

### BUG_FIX

For `FULL`, require one reproducer first, 1 to 3 neighboring guard tests, and the minimum owner-side fix.

### SEAM_MIGRATION

For `FULL`, require successor or retired seam, consumer migration order, retirement gate, and negative proof.

### PUBLIC_API_CHANGE

For `FULL`, require compatibility decision, migration/versioning note, and public contract proof.

## How to report findings

For every finding, provide:

- severity: `blocking` or `non-blocking`;
- location: header, section number, subsection, or file;
- rule violated or satisfied;
- concrete evidence from the contract and, when relevant, from the repository;
- minimal repair instruction.

Prefer the smallest repair that makes the contract acceptable.
When multiple issues stem from one upstream defect, identify the root issue first.

## Self-check before returning

Do not return the report until all answers are yes:

1. Did you verify the contract against both the active template shape and the writer-skill rules when available?
2. Did you re-inspect repository evidence instead of trusting the contract summary?
3. Did you distinguish blocking defects from non-blocking weaknesses?
4. Did you check information ownership and cross-section consistency, not just local section quality?
5. Did you enforce profile and obligation proof rules when applicable?
6. Did you avoid rewriting the contract unless repair was explicitly requested?
7. Did your verdict match the strongest defect you found?
