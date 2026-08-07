---
name: layered-code-review
description: Use when the user asks for code review of repository changes.
---

# Layered Code Review

Act as a reviewer for recently implemented code changes and related review artifacts. Use the reviewed diff as the primary evidence, and use the repository's active plan, local instructions, linked contracts, linked design artifacts, and source-of-truth documents to understand intended scope and architecture.

Run review in layers. First establish the reviewed input mode, scope, and evidence boundary from this file. Then load only the current layer reference and the evidence needed for that layer, keep candidate findings until synthesis, and return one final review response grouped by layer.

Hard prohibition: do not load all layer reference files at once, and do not preload evidence for later layers before the current layer requires it. Layered review is a sequential process; file loading must be sequential too.

## Intake, Scope, And Evidence

Before reading any review layer, determine what is being reviewed and which evidence controls the review. Do not judge findings until the reviewed scope is clear.

### Supported Input Modes

1. Current working tree review:
   - Review the uncommitted diff.
   - Identify the changed files, changed lines, and relevant local context.

2. Unit contract review:
   - Prompt form: `review unit N against PLAN_FILE`.
   - Read `PLAN_FILE`.
   - Review only the current diff relevant to Unit N.
   - Check unit scope, contract boundaries, Decision Trace obligations, proof obligations, and verification evidence when present.
   - Do not require unit checkbox updates or extra bookkeeping commits during pre-commit unit review.

3. Final committed-range review:
   - Prompt form: `review all unit commits together from START_COMMIT to END_COMMIT against PLAN_FILE`.
   - Read `PLAN_FILE`.
   - Review the diff covering `START_COMMIT^..END_COMMIT`.
   - Check cross-unit integration, contract drift, missed cleanup, source-of-truth updates, proof gaps, and required execution-unit completion updates.

4. Standalone artifact review:
   - Review a specific test, guardrail, analyzer, plan, design, documentation, proof fixture, naming decision, or source-of-truth artifact when no implementation diff is supplied.
   - Load the artifact and the local contract, source-of-truth, plan, fixture, naming, or verification rules that govern it.
   - Identify what the artifact claims to provide and who consumes it.
   - Use the layer references that match the artifact type.

### Scope Setup

Use repository-local instructions, active plan contracts, linked designs,
source inputs, source-of-truth documents, package layout, and local naming or
fixture rules when they are relevant to the touched area.

Before judging findings, identify internally:

- reviewed input mode;
- reviewed diff or artifact scope;
- changed files and relevant changed lines;
- active plans, contracts, designs, and source-of-truth documents used as evidence;
- public consumers, machine consumers, human consumers, or runtime consumers affected by the change;
- triggered layers and why each layer is or is not required.

Keep this evidence internal unless it directly supports a final finding.

### Authority Preflight — Hard Gate

Before treating a plan or Change Contract as authority, identify the owning
source of truth for every affected durable value and inspect changed or adjacent
consumers for manual mirrors, including copied inventories and exact-parity
validators.

A plan or Change Contract cannot independently authorize a manual mirror. An
accepted design may authorize intentional duplication only by defining its
distinct owner, lifecycle, consumers, invariant, and direct verification.
Otherwise, report a contract defect. A pre-existing mirror is in scope when the
reviewed work consumes, preserves, modifies, or claims to remove it.

Use temporary read-only searches when needed; do not create a permanent mirror
or scanner as review proof. Only after this preflight passes may the contract be
treated as authoritative.

After the Authority Preflight passes, a governing Change Contract's `Decision
Trace`, accepted outcomes, owners, boundaries, evidence constraints,
pre-implementation completion boundary, `Verification Profile` obligations,
and resolved `Verification Matrix` rows are authoritative within boundaries
that do not conflict with repository instructions or current source-of-truth
owners. Follow outcome keys through the Matrix to durable impact, artifact
target, and semantic admission key. Exact regexes, fixture spelling, visitor
implementation, private hooks, and test paths do not define semantic scope.
Treat a harmful prescribed proof mechanism as a contract defect, not as
authority to add misleading proof.

### Depth And Batching Requirement

Review every changed line in the relevant diff. Do not perform a superficial, sampled, or selective review, and do not stop after finding the first issue. Inspect the full relevant diff and supporting context first, then return the complete list of qualifying findings in one response.

### Contract-Scoped Guardrail Review

When reviewing guardrail, analyzer, structural-enforcement, or negative-proof code, treat the active contract and its source inputs as the scope boundary. Derive guardrail scope from the stable invariant, invalid state, owner, consumer, acceptance oracle, and evidence constraints. Do not flag hypothetical edge cases outside that semantic scope or the guardrail's own stated claim. Flag only drift, false confidence, or missed cases inside that stated scope.

Do not escalate a contract-scoped guardrail into a general-purpose code analyzer. If the contract asks for a specific forbidden dependency, boundary bypass, fixture shape, registry drift, or source-of-truth rule, review whether that exact guarantee is enforced at the contracted seam. Require broad language parsing, semantic analysis, whole-program reasoning, or exhaustive pattern recognition only when the contract explicitly claims that capability or the stated guarantee cannot be true without it.

Treat durable verification changes outside the applicable resolved Matrix row
as findings. Verify that a bounded amendment changes only an affected outcome
that must be split, its corresponding Matrix row or new row, and the
corresponding central admission entry for `ADD` or `EXTEND_COVERAGE`. Flag an
amendment that silently changes accepted scope, product behavior, ownership,
boundaries, compatibility, source of truth, or implementation scope.

## Layer Routing

Route and execute layers one at a time. For each triggered layer, read that layer's reference file only when starting that layer, load only the repository evidence needed to evaluate that layer, record candidate findings, and then move to the next triggered layer. Never batch-read all layer references or all layer evidence up front.

1. Read [Layer 1 — Implementation Review](references/layer-1-implementation-review.md) for implementation diffs, committed ranges, unit reviews, or any artifact that changes runtime behavior, public behavior, build behavior, persistence, state, events, callbacks, validation, ownership boundaries, migration behavior, or integration behavior.
2. After Layer 1 is complete, read [Layer 2 — Proof and Anti-Slop Review](references/layer-2-proof-and-slop-review.md) when the reviewed work adds or modifies tests, guardrails, analyzers, docs, plans, design artifacts, verification claims, proof fixtures, generated truth, source-of-truth artifacts, completion or readiness claims, migration proof, compatibility proof, structural enforcement, negative proof, or any artifact that can create false confidence.
3. After Layer 2 is complete or skipped, read [Layer 3 — Naming and Cohesion Review](references/layer-3-naming-and-cohesion-review.md) when the reviewed work adds, renames, moves, splits, merges, or reorganizes files or directories; changes fixture placement or test proof ownership; adds, removes, moves, or renames public or boundary-facing symbols; changes shared test support or import/export boundaries; touches ownership boundaries; changes Architecture Graph production structure or policy; introduces umbrella names; or when the prompt asks for naming, cohesion, or placement review.
4. After all other triggered layers are complete, read [Layer 4 — Synthesis and Output](references/layer-4-synthesis-and-output.md) last for every review. Deduplicate candidate findings by concrete failure mode and output findings grouped by layer.

For diffs that add or modify tests, guardrails, analyzers, docs, plans, design artifacts, verification claims, or proof fixtures, apply `Outcome-Proof Fit` through Layer 2. Report only actionable code-review style findings for artifacts that create false confidence, duplicated truth, weak guardrails, or self-referential proof.

## Execution Contract

Use the `Concrete Failure Mode Standard`: a concern becomes a finding only when it identifies the concrete missed failure mode, affected consumer, scenario, or behavior introduced by the reviewed diff or commit range. Collect candidates only when this threshold appears reachable, and finalize them only through Layer 4.

Do not finalize after an early layer. Use earlier layers to collect evidence and candidate findings; finalize only after all triggered layers have been checked and Layer 4 synthesis is complete.

Do not trade the sequential layer model for convenience. Loading every layer reference or every likely evidence file at the beginning is a process violation even when the same final files would eventually be read.

Prefer repository-local rules over generic taste. Do not replace local naming, test, fixture, architecture, or source-of-truth rules; apply them to the reviewed diff.
