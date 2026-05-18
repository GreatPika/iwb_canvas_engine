# Contract Rules

This file extends `SKILL.md` after a template has been selected. Use it to fill the selected template with detailed Change Contract rules: evidence, information ownership, slice-local file ownership, profile proof obligations, seam-retirement details, analyzer-specific details, and update behavior. Do not use this file to change routing, redefine core terms, add profiles, add obligations, or select a different template.

## Header rule

Every contract must start with the three header fields from the selected template.

- `Contract Mode` must be `FULL` or `ARCHITECTURE_GATE`.
- `Contract Profile` must be exactly one of `BEHAVIOR_CHANGE`, `REFACTOR`, `SOURCE_OF_TRUTH_DOCS`, or `ANALYZER_RULE`.
- `Contract Obligations` must be `none` or a comma-separated list in this order: `BUG_FIX`, `SEAM_MIGRATION`, `PUBLIC_API_CHANGE`.

For `ARCHITECTURE_GATE`, choose the profile and obligations using the gate rules in `SKILL.md`.

## Evidence rule

Inspect and record at least:

- entrypoint, trigger path, or document family;
- current owner module, layer, document owner, analyzer owner, or seam;
- existing checks in the area, or a confirmed absence after targeted inspection;
- one analogous valid implementation or documentation path elsewhere in the repository, or a confirmed absence after targeted inspection;
- repository rules that govern the area, or a confirmed absence after targeted inspection;
- nearby patterns that look relevant but are the wrong owner, wrong level, stale, or misleading.

`Evidence Map` describes the repository state before execution. In `Baseline Evidence`, state that these facts are evidence for the change, not target-state requirements. Do not reuse baseline facts as target-state requirements. Put target ownership, selected form, rejected alternatives, and future state in `Architecture Decision`.

Choose the owner that solves the problem once without leaking policy into the wrong layer or duplicating it across callers. Prefer the dominant local form already present in the repository.

## Architecture decision rule

For `FULL` contracts, section 3 must lock one evidence-backed architectural form. State the evidence-backed values for:

- selected form;
- ownership;
- seam;
- architectural dependency/import direction;
- state and data ownership;
- entry and exit boundaries;
- rejected alternatives;
- verification strategy.

Do not leave owner, boundaries, seam, architectural dependency/import direction, file placement, execution order, seam retirement timing, or verification strategy to be chosen during implementation.

Put full declaration blocks, schemas, signatures, or API snippets in `Architecture Decision` only when that exact public shape is itself part of the locked contract. Otherwise summarize the selected form in section 3 and put exact snippets in slice-local `Change` or proof expectations.

For `FULL` contracts, record durable decisions in `Decision Ledger` only when later slices or the final gate need stable decision IDs. Each durable decision gets a stable ID such as `D1`. The ledger is not a summary table: do not restate `Selected Form`, `Ownership`, or `Seam` unless that decision ID is needed later. If no separate durable decision IDs are needed, write one concrete sentence in `Decision Ledger` stating that slices and the final gate rely on the locked architecture directly.

For `ARCHITECTURE_GATE` contracts, section 3 must state the blocking gap, what is already known, the recommended form supported by evidence, supporting evidence, alternatives considered, and the exact user decision required. Do not include any sections after section 3 in a gate contract.

## Profile proof rules

Every slice must have executable proof appropriate to the selected `Contract Profile`. Write proof as intent plus command: first state what the command proves, then give the command. Avoid naked shell snippets whose failure mode is not self-explanatory.

### BEHAVIOR_CHANGE

Use this profile for production/runtime/API/data behavior, persistence, rendering, public semantics, and user-visible behavior changes.

Required proof:

- behavioral verification at the selected owner or public seam;
- structural verification when the slice introduces or depends on the locked architecture;
- final broad checks that are relevant to the changed behavior and supported by repository evidence.

### REFACTOR

Use this profile when observable behavior must remain unchanged.

Required proof:

- existing locking tests named before edits, or the minimum characterization tests needed before structural edits;
- 1 to 3 neighboring guard tests when adjacent branches are not already protected;
- structural verification for the moved, renamed, split, merged, or dependency-sensitive form;
- final proof that the locked behavior remains green.

If the work intentionally changes observable behavior, reclassify it as `BEHAVIOR_CHANGE`.

### SOURCE_OF_TRUTH_DOCS

Use this profile for normative repository documents such as architecture docs, contracts, diagrams, registries, guardrails, indexes, and roadmap step contracts when production/runtime implementation is out of scope.

Required proof:

- targeted semantic search proving selected terminology, ownership, and contract meaning;
- documentation structural checks for generated navigation, registries, indexes, diagrams catalogs, or context capsules when those artifacts exist;
- negative proof for retired terminology, stale guardrail IDs, stale registry entries, and rejected future-state proposals.

Negative proof must be targeted and bounded to named retired terms, stale IDs, rejected proposals, or active source-of-truth surfaces. Do not use broad repository-wide searches without a stated retired concept and bounded search surface.

Do not invent production tests or runtime behavioral verification for documentation-only contracts.

### ANALYZER_RULE

Use this profile when the owned behavior is structural recognition or enforcement.

Required proof:

- recognition forms the analyzer or rule must support;
- allowed non-violations that must not be flagged;
- resolution rules for ownership, imports, symbols, generated files, indirection, framework conventions, and repository-specific exceptions when relevant;
- positive and negative fixtures, or equivalent analyzer checks;
- false-positive, false-negative, bypass, or structural-drift coverage when repairing a defect.

Forbidden shortcuts:

- do not whitelist a single observed path when the invariant is structural;
- do not patch generated output when the source rule or generator owns the behavior;
- do not move policy into callers when the analyzer owner can enforce it once;
- do not retire old recognition paths until replacement coverage and consumer migration are proven.

## Obligation rules

Use obligations as structural requirements, not labels. Every obligation listed in the header must add concrete sequencing, proof, or closure content in the owning sections and must be covered by at least one slice only where that slice actually closes part of the obligation.

For `FULL` contracts, the obligation rules below add proof and sequencing requirements. For `ARCHITECTURE_GATE` contracts, listed obligations are classification metadata for facts already known from the request or repository evidence; detailed obligation proof is deferred until the gate is resolved.

### BUG_FIX

When `BUG_FIX` is present, the contract must require:

- one failing reproducer before the fix;
- 1 to 3 neighboring guard tests for the same contract;
- the minimum owner-side fix;
- no broadened change surface before the reproducer and guard tests are green.

For `ANALYZER_RULE`, the reproducer may be a failing structural fixture or analyzer check. For `SOURCE_OF_TRUTH_DOCS`, the reproducer may be targeted semantic or structural proof that the accepted source of truth currently contradicts the intended contract.

### SEAM_MIGRATION

When `SEAM_MIGRATION` is present, the contract must state:

- retired, renamed, changed, or successor seam;
- consumer migration order;
- registry, inventory, workflow, CI, index, or documentation references that must move before retirement;
- retirement gate;
- negative proof that the retired seam no longer remains in active source-of-truth surfaces.

Use the `Seam Migration` subsection in section 4 for this mapping. If several seams or consumer groups are involved, use a compact table there.

### PUBLIC_API_CHANGE

When `PUBLIC_API_CHANGE` is present, the contract must state:

- public contract owner;
- compatibility decision;
- breaking or non-breaking classification;
- migration or versioning note;
- export registry update, generated public index update, or explicit proof that no such registry or index exists;
- public contract proof;
- tests or documentation checks that protect the public surface.

## Slice rule

One slice closes one new verifiable result. Preparatory edits alone never close a slice.

Every slice must contain:

- `Implements`: only decision IDs such as `D1`, or one sentence that the slice relies on the locked architecture without separate decision IDs;
- `Obligations Covered`: only obligation labels from the header, and only when the slice directly closes part of `BUG_FIX`, `SEAM_MIGRATION`, or `PUBLIC_API_CHANGE`;
- `Files`: every file, test, fixture, inventory, workflow, generated artifact, verify-only evidence file, or explicit exclusion the slice relies on, with its file role and slice-local responsibility;
- `Change`: the slice-local result, without restating durable decisions;
- `Proof`: executable proof with intent plus command, using proof IDs from section 5 when reused;
- `Closure`: the condition that makes the slice complete.

Do not mix categories in one field. `Implements` must not contain obligation labels or proof IDs. `Obligations Covered` must not contain decision IDs or proof IDs. `Proof` is the only slice subsection that may reference proof IDs such as `P1`. Do not list every header obligation in every slice. Omit `Obligations Covered` when the slice does not directly close obligation work.

Each file expected to be edited must appear in exactly one slice as a primary edit, alignment, registry/index/workflow, verification, or cleanup/finalization file. A file may appear in multiple slices only when each slice names a different purpose; one slice must be named as the final owner for shared cleanup or finalization. Files listed only in `Evidence Map` are evidence, not change targets.

For each slice, distinguish file groups only when the categories are relevant. Give each file or group a concrete role plus the exact slice-local responsibility it closes, such as primary contract edit, public registry sync, diagram alignment, analyzer fixture coverage, verify-only evidence, finalization, or explicit exclusion. A bare action such as `Update`, `Refresh`, `Edit`, `Remove`, or `Verify` plus a path is insufficient unless the same bullet also states what responsibility that file has in the slice. Mark new files as proposed only when repository evidence supports placement and naming.

Duplicate the slice block as needed and number slices sequentially. Preserve checkbox syntax and give every slice a concrete title derived from the slice result. Use `Closure` for planned draft slices. Use completion evidence only when updating an existing executed contract and the slice already has concrete completion evidence.

## Template fill rules

The selected template is the document shape, not a source of new requirements.

Retain and fill the main numbered sections from the selected template: sections 1 through 3 for gate contracts, and sections 1 through 7 for locked contracts. Do not silently omit a main numbered section.

Use subsection headings only when they can be filled with concrete content. If a subsection is required to explain the lock but cannot be filled from repository evidence, use the architecture decision gate instead of emitting an empty heading.

Section 5 is the only owner for reusable proof commands, reusable proof groups, and every proof command referenced by the final gate. Each proof ID must be self-contained: purpose, command or check, and expected signal. Do not define a proof ID as `Defined in Slice` or as a vague description whose executable command lives elsewhere. If a command is used once and is not part of the final gate, keep it in the owning slice without assigning a proof ID. If a command is used by a slice and the final gate, give it a proof ID such as `P1` and reference the ID instead of repeating the command. If there are no reusable proof groups and no final-gate proof commands, write one concrete sentence that all proof is slice-local and keep commands in the slices.

Optional categories that are commonly omitted when not relevant include seam migration details, deferred broad verification, slice file subcategories, analyzer fixtures, positive scenarios, and negative scenarios. Do not emit placeholder text, guessed details, unexplained ellipses, or `None` filler.

## Updating an existing contract

When updating an existing Change Contract:

- Re-select the current mode, profile, obligations, and template through `SKILL.md`.
- Convert the output to the current selected template shape.
- Preserve completed slice evidence and stable decisions that are still supported by repository evidence by placing them in the current owning sections.
- Patch only content affected by new evidence, changed user direction, or required migration into the current template shape.
- Do not rewrite stable architecture decisions unless repository evidence contradicts them.
- If a previous assumption is invalidated, add a correction note in the owning section and update affected slices, slice-local file ownership, gates, and proof obligations.
- Do not preserve obsolete numbering, standalone file inventories, or deprecated proof headings.

Existing historical roadmap step files do not need migration unless the user explicitly asks to update that contract.

## Information Ownership

Each fact must have exactly one owning location.

- Mode, profile, and obligations live only in the header.
- Mandate, scope, and exclusions live only in section 1.
- Repository evidence lives only in section 2.
- Architecture, seam, state ownership, dependency direction, selected design, rejected alternatives, verification strategy, and durable decisions live only in section 3.
- Cross-slice order, seam migration, forbidden moves, and deferred verification live only in section 4.
- Reusable proof commands and final-gate proof commands live only in section 5.
- File lists live inside the slice that edits, verifies, excludes, or finalizes those files.
- Slice-local work lives only in section 6.
- Completion conditions live only in section 7.

Later sections must reference decision IDs and proof IDs instead of restating the same facts.

## Section guidance

### 1. Mandate and Boundary

State the required result in one short mandate. Separate included work from exclusions. Use exclusions to prevent scope creep, not to hide unresolved architecture decisions.

### 2. Evidence Map

Record inspected evidence, not assumptions. Separate baseline evidence from target architecture. Do not present future target owners or entrypoints as current repository facts.

### 3. Architecture Decision

For `FULL`, record the locked architecture selected through `SKILL.md` workflow and use the `Decision Ledger` for durable decisions and stable proof references. For `ARCHITECTURE_GATE`, use only the `Architecture Gate` subsection from the gate template and do not add a `Decision Ledger`.

### 4. Execution Guardrails

State cross-slice order, constraints, seam migration details, forbidden moves, and broad verification deferred to the final gate. Do not use this section as a complete file inventory.

### 5. Proof Plan

Name reusable proof groups with IDs such as `P1`. A proof ID must include the executable command or check and expected signal. A one-off command belongs in the owning slice when it is not reused and not part of the final gate. Do not duplicate proof commands across slices and final gate; reference proof IDs when the same command is reused.

### 6. Vertical Slices

One slice closes one new verifiable result. Use the slice `Files` block as the only complete owner for files to edit, refresh, verify, exclude, or finalize in that slice.

### 7. Final Gate

State the final proof set and completion conditions by referencing proof IDs, the Decision Ledger, and Contract Obligations. The final gate must not restate durable decision content from section 3 or introduce new scope.
