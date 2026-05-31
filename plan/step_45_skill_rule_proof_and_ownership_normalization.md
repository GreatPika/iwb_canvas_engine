# Change Contract

## Goal

Normalize the second and third waves of repeated repository-local skill rules in place: proof/evidence artifact quality first, then architecture ownership and sequencing rules, without creating a new shared glossary or changing runtime engine behavior.

## Source Inputs

- Design: none
- Research: `.research/2026-05-31-skill-rule-convergence.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `plan/step_44_skill_rule_vocabulary_normalization.md` as the completed first-wave precedent; PM decision recorded in this contract/request context: first wave is closed, and this second contract covers Wave 2 (`Evidence Consequence Link`, `Concrete Failure Mode Standard`, `Negative Proof And Fixture Quarantine`, `Source-Of-Truth Singularity`) plus Wave 3 (`Owner-Level Fix`, `Boundary-Owned Policy`, `Sequenced Migration And Retirement`, `Temporal Surface Closure`, `All-Or-Nothing Failure Boundary`).

## Classification

Profile: `SOURCE_OF_TRUTH_DOCS`

Obligations: none

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| Step 44 normalized the first-wave vocabulary in existing skill files without creating a shared glossary. | `Boundaries.In Scope`, `Boundaries.Out of Scope`, Units 1-8 | Unit 8 range audit proves this step follows the same in-place pattern and does not add `.agents/skills/shared/**`, a glossary, or UI metadata changes. |
| Wave 2 must cover proof/evidence artifact quality: `Evidence Consequence Link`, `Concrete Failure Mode Standard`, `Negative Proof And Fixture Quarantine`, and `Source-Of-Truth Singularity`. | Units 1-4 | Each Wave 2 unit completion check proves the canonical name, short definition, and stage-specific application appear in the intended skill owners without changing output schemas. |
| Wave 3 must cover architecture ownership and sequencing: `Owner-Level Fix`, `Boundary-Owned Policy`, `Sequenced Migration And Retirement`, `Temporal Surface Closure`, and `All-Or-Nothing Failure Boundary`. | Units 5-7 | Each Wave 3 unit completion check proves the canonical name, short definition, and stage-specific application appear in the intended skill owners without weakening existing blocking/review semantics. |
| Wave 2 must run before Wave 3 so proof/evidence vocabulary is stable before owner, boundary, migration, temporal, and failure-boundary wording depends on it. | `Boundaries.Order Constraints`, Units 1-7 | Unit dependency order requires Units 1-4 before Units 5-7. |
| Existing first-wave concepts remain source inputs and compatibility constraints, not work to re-normalize in this step. | `Boundaries.Out of Scope`, Units 1-7 | Completion checks forbid broad edits to `Outcome-Proof Fit`, `Decision Chain Of Custody`, `Decision Closure`, and `Completion Evidence Boundary` except incidental cross-reference wording needed by the new concepts. |
| Repository plan workflow requires completed plan steps to update `PLAN.md` and the linked step document in the same change. | Unit 8 | Unit 8 owns only final status-marker updates after Units 1-7 are implemented, verified, reviewed, and committed. |

## Evidence

- `.research/2026-05-31-skill-rule-convergence.md:26` / rule table: `Evidence Consequence Link` is repeated across design, contract, contract-check, research, and forensics with slightly different evidence exceptions -> normalize exact-evidence and consequence wording before later proof/ownership rules depend on it.
- `.research/2026-05-31-skill-rule-convergence.md:28` / rule table: `Concrete Failure Mode Standard` spans anti-slop and code-review finding eligibility while preserving different verdict/priority systems -> normalize the shared finding threshold without changing output formats.
- `.research/2026-05-31-skill-rule-convergence.md:35` / rule table: `Negative Proof And Fixture Quarantine` repeats across contract, contract-check, code-review, design-review, anti-slop, and naming-cohesion under different labels -> normalize proof seam and fixture contamination vocabulary.
- `.research/2026-05-31-skill-rule-convergence.md:29` / rule table: `Source-Of-Truth Singularity` repeats across design, template, design-review, contract-check, anti-slop, code-review, and naming-cohesion, but cache/performance and consumer exceptions are uneven -> normalize the single-owner rule and allowed duplication exception.
- `.research/2026-05-31-skill-rule-convergence.md:30` / rule table: `Owner-Level Fix` repeats across design, contract-check, code-review, unit-by-unit, naming, and forensics, while repeated-finding escalation is only explicit in unit-by-unit -> normalize the shared name while preserving implementation-specific escalation.
- `.research/2026-05-31-skill-rule-convergence.md:31` / rule table: `Boundary-Owned Policy` repeats across design validation, design review, contracts, contract-check, and naming public API ownership -> normalize boundary ownership without collapsing compatibility/migration details.
- `.research/2026-05-31-skill-rule-convergence.md:32` / rule table: `Sequenced Migration And Retirement` repeats across design seam gates, contract splitting/order, contract-check blocking, and design-review seam checks -> normalize migration/retirement vocabulary after owner/boundary terms are stable.
- `.research/2026-05-31-skill-rule-convergence.md:33` / rule table: `Temporal Surface Closure` repeats across design, contract, contract-check, code-review, and design-review using temporal/reentrancy/callback/guard vocabulary -> normalize a shared field list for synchronous callback surfaces and expected signals.
- `.research/2026-05-31-skill-rule-convergence.md:34` / rule table: `All-Or-Nothing Failure Boundary` repeats across design, contract, contract-check, code-review, and design-review with different accepted-result/publication/containment wording -> normalize the irreversible-point and failure-domain vocabulary.
- `.research/2026-05-31-skill-rule-convergence.md:219` / recommended order: after the first four concepts, the research identifies `Source-Of-Truth Singularity`, `Negative Proof And Fixture Quarantine`, `Temporal Surface Closure`, `All-Or-Nothing Failure Boundary`, `Owner-Level Fix`, and `Boundary-Owned Policy` as next normalization targets -> this supports the later Wave 2/3 targets, while `Evidence Consequence Link` and `Concrete Failure Mode Standard` are supported by their rule-table evidence and by the PM wave grouping recorded below.
- User request for this step / order decision: plan Wave 2 proof/evidence quality before Wave 3 architecture ownership and sequencing, with Wave 3 ordered owner/boundary before migration and temporal/failure-boundary rules -> this PM wave grouping intentionally supersedes the research note's advisory ordering for these targets.
- `plan/step_44_skill_rule_vocabulary_normalization.md:61` / first-wave boundary: Step 44 normalized selected concepts in place across affected `SKILL.md` files and preserved local stage-specific application -> follow that pattern for Waves 2-3.
- `plan/step_44_skill_rule_vocabulary_normalization.md:65` / first-wave out-of-scope: Step 44 intentionally deferred Wave 2 and Wave 3 concepts, shared glossary creation, UI metadata cleanup, runtime, tests, docs, architecture graph, and guardrail tooling -> this step should pick up only the requested Wave 2 and Wave 3 concepts while preserving the other exclusions.
- `.agents/skills/change-contract/SKILL.md:138` / current contract structure: `Decision Chain Of Custody` requires source inputs and decisions to be preserved into contract fields, execution units, or proof surfaces -> this contract maps every requested wave concept into a unit and completion proof.
- `.agents/skills/change-contract/SKILL.md:376` / completion check rule: completion checks must satisfy `Outcome-Proof Fit` -> each unit's completion check names an observable search/manual review signal that would fail if the canonical rule name or stage-specific application is missing.
- `PLAN.md:8` / roadmap structure: step entries use linked plan documents -> add a linked Step 45 file.
- `PLAN.md:12` / roadmap order: step order defines intended implementation order -> append Step 45 after completed Step 44.

## Boundaries

Owner:

Repository-local skill instructions under `.agents/skills/**/SKILL.md` own this vocabulary normalization. `anti-slop-review` remains the owner for proof-quality review concepts that judge claim/value/failure-mode fit. Design and contract skills own architecture and planning concepts. Code-review and naming-cohesion skills own how normalized terms become actionable review findings. `repo-forensics` and `research-codebase` own evidence-gathering wording only where the normalized evidence concepts already apply.

In Scope:

Normalize these nine cross-cutting concepts in place across affected `SKILL.md` files and the directly used design template where required: `Evidence Consequence Link`, `Concrete Failure Mode Standard`, `Negative Proof And Fixture Quarantine`, `Source-Of-Truth Singularity`, `Owner-Level Fix`, `Boundary-Owned Policy`, `Sequenced Migration And Retirement`, `Temporal Surface Closure`, and `All-Or-Nothing Failure Boundary`. Preserve local stage-specific application in each skill instead of replacing local rules with an external reference. Update wording, names, nearby short definitions, and cross-references where needed so the same invariant uses the same canonical name and compatible severity/blocking semantics.

Out of Scope:

Do not create `.agents/skills/shared/**`, a shared glossary file, or any other new source-of-truth vocabulary document. Do not re-normalize the completed first-wave concepts except for incidental cross-reference wording required by this step: `Outcome-Proof Fit`, `Decision Chain Of Custody`, `Decision Closure`, and `Completion Evidence Boundary`. Do not normalize Wave 4 concepts in this step: `Stage Boundary`, `Fresh Reviewer After Mutation`, `Prompt Context Minimalism`, or `UI Metadata Separation`. Do not change UI metadata in `.agents/skills/*/agents/openai.yaml`. Do not change runtime code, tests, docs under `docs/`, architecture graph files, guardrail tooling, public API behavior, or generated outputs.

Source of Truth:

The current behavior is described by `.agents/skills/*/SKILL.md`, with `.agents/skills/architecture-design/assets/design-artifact-template.md` included only where the design skill directly uses it. The audit source input is `.research/2026-05-31-skill-rule-convergence.md`. The completed first-wave precedent is `plan/step_44_skill_rule_vocabulary_normalization.md`. The roadmap source of truth is `PLAN.md` plus this linked step contract.

Compatibility:

Existing skill trigger behavior, allowed edit scopes, review output formats, verdict schemas, exact reviewer prompt forms, and first-wave canonical names must remain compatible. The implementation may clarify names and definitions, but must not make a skill less strict, change required review prompt forms, alter verdict/output schemas, require a new shared file, or turn stage-specific details into a generic external reference.

Order Constraints:

Implement Wave 2 before Wave 3: normalize `Evidence Consequence Link`, then `Concrete Failure Mode Standard`, then `Negative Proof And Fixture Quarantine`, then `Source-Of-Truth Singularity`. This user-requested wave grouping intentionally overrides the research note's advisory ordering for the remaining concepts. After proof/evidence vocabulary is stable, normalize Wave 3 in owner-to-order sequence: `Owner-Level Fix` and `Boundary-Owned Policy`, then `Sequenced Migration And Retirement`, then `Temporal Surface Closure` and `All-Or-Nothing Failure Boundary`. After Units 1-7 are implemented, verified, reviewed, and committed, run the final status unit to update only `PLAN.md` and this step file's completion checkboxes. Include that status commit in the final committed-range review.

## Execution Units

### [ ] Unit 1: Normalize Evidence Consequence Link

Owner:

`.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, `.agents/skills/research-codebase/SKILL.md`, and `.agents/skills/repo-forensics/SKILL.md`.
`.agents/skills/architecture-design/assets/design-artifact-template.md` is included only for existing repository evidence wording.

Boundary:

Evidence naming and exception vocabulary only. Do not change research output shape, contract evidence table shape, repository evidence verification duties, or forensics probe lists.

Change:

Introduce and use `Evidence Consequence Link` for the invariant that repository evidence must be exact when stable, exceptions must be named for new/generated/command surfaces, and every cited fact must state the decision, contract, proof, or review consequence it supports. Preserve local mechanics: research still records search coverage, design still cites architecture claims, contracts still use observed fact -> contract consequence, contract-check still re-checks evidence, and forensics still treats tool output as evidence rather than decision.

Completion Check:

`rg -n "Evidence Consequence Link|path:line|observed fact|contract consequence|tool output as evidence|search coverage|re-check|generated outputs|stable text" .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-review/SKILL.md .agents/skills/architecture-design/assets/design-artifact-template.md .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md .agents/skills/research-codebase/SKILL.md .agents/skills/repo-forensics/SKILL.md` shows the canonical name attached to the shared evidence rule and no contradictory alternate exception vocabulary. Manual review confirms research note structure, contract evidence format, design evidence policy, contract-check evidence verification, and forensics probe/reporting behavior are not weakened.

Depends On:

None.

### [ ] Unit 2: Normalize Concrete Failure Mode Standard

Owner:

`.agents/skills/anti-slop-review/SKILL.md` and `.agents/skills/code-review/SKILL.md`.

Boundary:

Finding eligibility and review threshold wording only. Do not change anti-slop verdict names, code-review priority names, code-review output format, or the rule that slop signals are investigation prompts rather than automatic findings.

Change:

Introduce and use `Concrete Failure Mode Standard` for the invariant that a review concern must identify the concrete missed failure mode, consumer, scenario, or behavior affected before it becomes a finding. Preserve local stage semantics: anti-slop may return `Useful`, `Weak but valid`, `Misnamed`, `Slop`, or `Harmful slop`; code-review reports only actionable findings with `[P0]`-`[P3]` priorities after inspecting the full relevant diff.

Completion Check:

`rg -n "Concrete Failure Mode Standard|concrete failure mode|consumer|scenario|actionable|introduced by the reviewed|slop signals|investigation prompts|full relevant diff|No findings" .agents/skills/anti-slop-review/SKILL.md .agents/skills/code-review/SKILL.md` shows the canonical name in both review skills and shows anti-slop/code-review output vocabularies remain present. Manual review confirms anti-slop verdicts, code-review priorities, JSON prohibition, and code-review finding format are unchanged.

Depends On:

Unit 1.

### [ ] Unit 3: Normalize Negative Proof And Fixture Quarantine

Owner:

`.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, `.agents/skills/code-review/SKILL.md`, `.agents/skills/anti-slop-review/SKILL.md`, and `.agents/skills/naming-cohesion-review/SKILL.md`.

Boundary:

Negative, bypass, fixture, structural-recognition, and self-referential proof wording only. Do not change analyzer/guardrail behavior, code-review output schemas, fixture directory policy, or production source-of-truth definitions beyond naming the shared quarantine invariant.

Change:

Introduce and use `Negative Proof And Fixture Quarantine` for the invariant that negative/bypass/structural proof must exercise a real production seam or contract-named test seam and fixture-only names, values, schemas, declarations, or data must not contaminate production source-of-truth files, public API registries, schemas, durable contracts, generated docs, or public surfaces. Preserve stage-specific application: design checks feasibility, contracts specify proof seam/fixture mechanism, contract-check blocks unresolved or contaminating fixture strategy, code-review reports actionable seam/fixture findings, anti-slop detects self-referential proof, and naming-cohesion keeps reusable fixture placement review.

Completion Check:

`rg -n "Negative Proof And Fixture Quarantine|negative proof|bypass proof|negative-fixture|structural-recognition|fixture-only|production seam|contract-named test seam|self-referential proof|approved fixture location" .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-review/SKILL.md .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md .agents/skills/code-review/SKILL.md .agents/skills/anti-slop-review/SKILL.md .agents/skills/naming-cohesion-review/SKILL.md` shows the canonical name in every affected stage and retains local seam/fixture examples. Manual review confirms the rule does not authorize fixture-only production data and does not remove anti-slop's proxy/self-referential proof checks.

Depends On:

Units 1 and 2.

### [ ] Unit 4: Normalize Source-Of-Truth Singularity

Owner:

`.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, `.agents/skills/anti-slop-review/SKILL.md`, `.agents/skills/code-review/SKILL.md`, and `.agents/skills/naming-cohesion-review/SKILL.md`.
`.agents/skills/architecture-design/assets/design-artifact-template.md` is included only for `Source-Of-Truth Impact` wording.

Boundary:

Source-of-truth ownership, consumer/value, mandatory update, and cache/performance duplication exception wording only. Do not change actual plan source files, docs under `docs/`, registries, generated outputs, or UI metadata.

Change:

Introduce and use `Source-Of-Truth Singularity` for the invariant that durable meaning has one owning source of truth; duplicated truth is allowed only when explicitly scoped as cache/performance duplication with an invariant and proof strategy; and a source-of-truth artifact must have a real human or machine consumer. Preserve local stage semantics: design identifies source-of-truth impact, contracts name source-of-truth fields and required dependent references, contract-check blocks wrong/optional/weakened source-of-truth obligations, anti-slop checks consumer/value, code-review flags source-of-truth drift, and naming-cohesion applies the governing local source of truth.

Completion Check:

`rg -n "Source-Of-Truth Singularity|Source of Truth|Source-Of-Truth Impact|duplicate truth|duplicated truth|second source of truth|cache/performance duplication|consumer|mandatory source-of-truth|source-of-truth drift" .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-review/SKILL.md .agents/skills/architecture-design/assets/design-artifact-template.md .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md .agents/skills/anti-slop-review/SKILL.md .agents/skills/code-review/SKILL.md .agents/skills/naming-cohesion-review/SKILL.md` shows the canonical name across affected stages, retains the cache/performance duplication exception, and keeps anti-slop's consumer/value condition. Manual review confirms no new source-of-truth document or generated output was added.

Depends On:

Unit 3.

### [ ] Unit 5: Normalize Owner-Level Fix And Boundary-Owned Policy

Owner:

`.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, `.agents/skills/code-review/SKILL.md`, `.agents/skills/unit-by-unit/SKILL.md`, `.agents/skills/naming-cohesion-review/SKILL.md`, and `.agents/skills/repo-forensics/SKILL.md`.

Boundary:

Owner/root-cause/boundary/policy placement vocabulary only. Do not change execution unit shape, reviewer prompt forms, public API compatibility rules, or naming-cohesion output format.

Change:

Introduce and use `Owner-Level Fix` for the invariant that repeated defects or shared invariant breaks must be fixed at the owning cause, not through one-off caller or symptom patches. Introduce and use `Boundary-Owned Policy` for the invariant that validation, normalization, compatibility, public API placement, and policy decisions belong at the owning boundary. Preserve stage-specific application: design selects owner and boundary, contract/check settle owner and boundary before implementation, code-review flags call-site patches and boundary bypasses, unit-by-unit keeps its repeated-finding escalation trigger, naming-cohesion reviews file/directory/public API ownership, and repo-forensics remains evidence-gathering rather than decision authority.

Completion Check:

`rg -n "Owner-Level Fix|Boundary-Owned Policy|root cause|owning cause|one-off call-site|pushed into callers|single reason to change|stable owner|public API symbol|boundary validation|validation at the boundary|owner placement|boundary questions" .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-review/SKILL.md .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md .agents/skills/code-review/SKILL.md .agents/skills/unit-by-unit/SKILL.md .agents/skills/naming-cohesion-review/SKILL.md .agents/skills/repo-forensics/SKILL.md` shows both canonical names in the affected owner/boundary rules. Manual review confirms unit-by-unit still escalates repeated findings to one owner-level fix, naming-cohesion still reports code-review style findings, and repo-forensics still treats probe output as evidence rather than design decision.

Depends On:

Unit 4.

### [ ] Unit 6: Normalize Sequenced Migration And Retirement

Owner:

`.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, and `.agents/skills/code-review/SKILL.md`.
`.agents/skills/architecture-design/assets/design-artifact-template.md` is included only for migration/seam diagram trigger wording.

Boundary:

Migration, replacement, retirement, successor seam, consumer order, and removal-order vocabulary only. Do not change classification profiles, obligations, execution unit checkbox rules, or architecture graph/docs.

Change:

Introduce and use `Sequenced Migration And Retirement` for the invariant that owners and replacement paths must exist before consumers move, and old paths may be retired only after replacement paths, migrated consumers, retirement gates, and migration checks exist. Preserve stage-specific application: design names seam successor/retirement and consumer order, contracts split migration into add/migrate/remove units, contract-check blocks unsafe order, and code-review flags actionable sequencing drift.

Completion Check:

`rg -n "Sequenced Migration And Retirement|successor|retired seam|consumer order|retirement gate|migration order|replacement paths|consumers are in place|old paths|unsafe order|sequencing constraint" .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-review/SKILL.md .agents/skills/architecture-design/assets/design-artifact-template.md .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md .agents/skills/code-review/SKILL.md` shows the canonical name in relevant migration/retirement rules and no weakening of existing order constraints. Manual review confirms the change does not alter profile routing, obligations, or execution unit shape.

Depends On:

Unit 5.

### [ ] Unit 7: Normalize Temporal Surface Closure And All-Or-Nothing Failure Boundary

Owner:

`.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, and `.agents/skills/code-review/SKILL.md`.
`.agents/skills/architecture-design/assets/design-artifact-template.md` is included only for temporal/all-or-nothing hard-gate and lock-required-fact wording.

Boundary:

Temporal/reentrancy and failure-domain vocabulary only. Do not change runtime behavior, tests, callback APIs, reviewer prompt forms, or general all-or-nothing implementation rules beyond normalized names and stage-specific field lists.

Change:

Introduce and use `Temporal Surface Closure` for the invariant that call ordering, observer/listener/callback delivery, transaction, rollback/no-op, public-state publication, atomicity, or mutation guard changes must name the temporal invariant, every synchronous callback surface, guard/boundary owner, allowed public observation order, and expected rejection/no-mutation signal. Introduce and use `All-Or-Nothing Failure Boundary` for the invariant that a change requiring full effect or prior state unchanged must name the irreversible point, fallible work before it, later infallible/failure-contained/accepted work, failure projection, and proof surface. Preserve stage-specific application: design decides and records, contracts specify completion checks, contract-check blocks unresolved proof, and code-review reports actionable implementation gaps.

Completion Check:

`rg -n "Temporal Surface Closure|All-Or-Nothing Failure Boundary|temporal invariant|synchronous callback surface|reentrant|interleaved|public observation order|rejection/no-mutation|irreversible point|fallible work|failure-contained|accepted result|rollback|containment|publication signal" .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-review/SKILL.md .agents/skills/architecture-design/assets/design-artifact-template.md .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md .agents/skills/code-review/SKILL.md` shows both canonical names in the relevant temporal and failure-boundary rules and retains expected signal wording. Manual review confirms no runtime/test/API behavior was changed and no completion check relies only on happy-path event order.

Depends On:

Unit 6.

### [ ] Unit 8: Final Plan Status And Range Surface Audit

Owner:

`PLAN.md` and `plan/step_45_skill_rule_proof_and_ownership_normalization.md`.

Boundary:

Completion/status markers and final range-surface proof only. Do not change skill wording, UI metadata, runtime code, tests, docs under `docs/`, architecture graph files, guardrail tooling, generated outputs, or any source-of-truth surface outside `PLAN.md` and this step file in this unit.

Change:

After Units 1-7 have approved implementation commits, mark Step 45 complete in `PLAN.md` and mark Units 1-8 complete in `plan/step_45_skill_rule_proof_and_ownership_normalization.md`. Before Unit 8 review, prove the status-only working tree contains only those marker changes and no pending or untracked forbidden files. After the approved Unit 8 status commit exists, the normal `unit-by-unit` final committed-range review must include this status commit and verify the range-level surface audit.

Completion Check:

Before Unit 8 review, `git diff --name-status` for the Unit 8 working tree shows only `PLAN.md` and `plan/step_45_skill_rule_proof_and_ownership_normalization.md` status-marker changes. `git status --short --untracked-files=all` at the same point shows no pending or untracked glossary, shared rule-vocabulary, shared source-of-truth, `.agents/skills/shared/**`, UI metadata, runtime, test, docs, architecture, generated output, or guardrail files. `PLAN.md` marks Step 45 checked, and this step file marks Units 1-8 checked in the same status-only working tree. After the Unit 8 commit, the normal final committed-range review must verify `git diff --name-status START_COMMIT^..END_COMMIT` shows only permitted implementation surfaces: `.agents/skills/anti-slop-review/SKILL.md`, `.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/architecture-design/assets/design-artifact-template.md`, `.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, `.agents/skills/code-review/SKILL.md`, `.agents/skills/naming-cohesion-review/SKILL.md`, `.agents/skills/repo-forensics/SKILL.md`, `.agents/skills/research-codebase/SKILL.md`, `.agents/skills/unit-by-unit/SKILL.md`, `PLAN.md`, and `plan/step_45_skill_rule_proof_and_ownership_normalization.md`, with no `.agents/skills/*/agents/openai.yaml` metadata changes, runtime/test/docs/architecture/guardrail/generated-output changes, added glossary, shared rule-vocabulary, shared source-of-truth artifact, or `.agents/skills/shared/**` path. The same final committed-range review must confirm content changes are limited to the nine selected Wave 2 and Wave 3 concepts plus necessary cross-reference wording, with no normalization of Wave 4 concepts.

Depends On:

Units 1, 2, 3, 4, 5, 6, and 7.
