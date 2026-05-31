# Change Contract

## Goal

Normalize the names, definitions, and stage-specific wording of the highest-risk repeated rules across repository-local skills in place, without creating a shared glossary file or changing runtime engine behavior.

## Source Inputs

- Design: none
- Research: `.research/2026-05-31-skill-rule-convergence.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: PM decision recorded in this contract: synchronize wording, names, and definitions in existing skills like `Outcome-Proof Fit`; do not create a separate shared rule file or glossary for this normalization pass.

## Classification

Profile: `SOURCE_OF_TRUTH_DOCS`

Obligations: none

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| PM decision: synchronize wording, names, and definitions in existing skills like `Outcome-Proof Fit`; do not create a separate shared rule file or glossary. | `Source Inputs.Other`, `Boundaries.In Scope`, `Boundaries.Out of Scope`, Units 1-5 | Unit 5 status-scope check and the normal final committed-range review prove no new shared skill-rule glossary file or directory exists. |
| `Outcome-Proof Fit` is the existing model for a shared named rule used by multiple skills. | Unit 1 | Unit 1 completion check proves the canonical name is used consistently where proof/proxy wording is synchronized. |
| `Decision Chain Of Custody`, `Decision Closure`, and `Completion Evidence Boundary` are the first high-risk concepts to normalize. | Units 2-4 | Each unit completion check proves the canonical name, short definition, and stage-specific application appear in the intended skill owners and directly used template where applicable. |
| Stage-specific semantics must remain local to each skill. | `Boundaries.In Scope`, Units 1-4 | Completion checks require local stage wording and forbid replacing local rules with external references. |
| UI metadata cleanup and later lower-priority concepts are not part of this first pass. | `Boundaries.Out of Scope` | Unit 4 completion check proves only the four named concepts and necessary cross-references are changed. |
| Repository plan workflow requires completed plan steps to update `PLAN.md` and the linked step document in the same change. | Unit 5 | Unit 5 owns final status-marker updates and includes them in the committed range reviewed after all unit commits. |

## Evidence

- `.research/2026-05-31-skill-rule-convergence.md:13` / current state: the local skills already form a staged governance system with repeated invariants under different names -> the change should normalize behavior-affecting vocabulary across skills, not add generic cleanup.
- `.research/2026-05-31-skill-rule-convergence.md:15` / existing precedent: `Outcome-Proof Fit` is already explicitly shared across design, contract, and contract-check skills, while other important invariants are not named consistently -> use this pattern for the first normalization pass.
- `.research/2026-05-31-skill-rule-convergence.md:17` / risk: future agents may accept proxy proof, drop design handoff, patch symptoms, reuse stale reviewers, or mark work complete before proof exists -> the first pass should target the highest-risk rule clusters.
- `.research/2026-05-31-skill-rule-convergence.md:23` / rule table: `Stage Boundary` was identified but not selected for this first pass -> do not expand scope beyond the user's requested wording synchronization pass.
- `.research/2026-05-31-skill-rule-convergence.md:24` / rule table: `Decision Closure` is repeated across design disposition, review verdict, `Contract Blocker`, and contract-check `BLOCKED` wording -> normalize this name and definition in the affected skills.
- `.research/2026-05-31-skill-rule-convergence.md:25` / rule table: `Decision Chain Of Custody` spans design trace, source inputs, handoff constraints, and contract proof-surface mapping -> normalize this name and preserve local section/table requirements.
- `.research/2026-05-31-skill-rule-convergence.md:27` / rule table: `Outcome-Proof Fit` is already named in most stages, while code review refers indirectly to the anti-slop claim-vs-actual-work test -> finish name alignment without changing finding output semantics.
- `.research/2026-05-31-skill-rule-convergence.md:37` / rule table: `Completion Evidence Boundary` protects unchecked planning units, pre-implementation contract shape, and reviewed implementation proof -> normalize this name across planning, contract-check, code-review, and unit-by-unit wording.
- `.research/2026-05-31-skill-rule-convergence.md:215` / recommended order: the first four recommended normalization targets are `Outcome-Proof Fit`, `Decision Chain Of Custody`, `Decision Closure`, and `Completion Evidence Boundary` -> use those as the step's execution units.
- `.research/2026-05-31-skill-rule-convergence.md:228` / open question: the research left open whether some rules should live in a shared glossary or be repeated in affected skills -> the PM decision recorded in `Source Inputs.Other` settles this step in favor of in-place repetition, not a shared file.
- `.agents/skills/anti-slop-review/SKILL.md:24` / precedent owner: `anti-slop-review` already owns a short `Outcome-Proof Fit` definition and declares it a shared rule -> do not move that definition out to a new file.
- `.agents/skills/anti-slop-review/SKILL.md:39` / precedent shape: the shared rule uses a compact four-part frame instead of a long external document -> new normalized names should stay concise.
- `.agents/skills/change-contract/SKILL.md:133` / contract structure: full contracts require `Source Inputs`, `Classification`, and `Decision Trace` before `Evidence`, and map source decisions to units or proof surfaces -> the step must preserve this structure.
- `.agents/skills/change-contract-check/SKILL.md:22` / existing named rule: contract checking already names `Decision Closure Rule` and defines unresolved implementation-time decisions -> reuse this existing name where compatible instead of inventing a conflicting label.
- `AGENTS.md:18` / plan workflow: completed plan steps must update corresponding checkbox entries in `PLAN.md` and the linked step document in the same change -> the implementation needs a final unit that owns only status-marker updates after vocabulary units finish.
- `.agents/skills/unit-by-unit/SKILL.md:52` / final review workflow: after every unit has been committed, final review covers a committed range from first unit commit to latest commit containing all unit work -> final surface audit must check the committed range, not only the working tree.
- `PLAN.md:8` / roadmap structure: step entries use linked plan documents -> add a new linked Step 44 file.
- `PLAN.md:12` / roadmap order: step order defines intended implementation order -> append Step 44 after the completed Step 43 entry.

## Boundaries

Owner:

Repository-local skill instructions under `.agents/skills/**/SKILL.md` own this vocabulary normalization. `anti-slop-review` remains the owner of the canonical `Outcome-Proof Fit` definition. The contract/planning skills own how the normalized terms apply to contracts, validation, implementation review, and workflow completion.

In Scope:

Normalize only these four cross-cutting concepts in place across affected `SKILL.md` files: `Outcome-Proof Fit`, `Decision Chain Of Custody`, `Decision Closure`, and `Completion Evidence Boundary`. Preserve local stage-specific application in each skill instead of replacing it with an external reference. Update wording, names, nearby short definitions, and cross-references where needed so the same invariant uses the same canonical name and compatible severity/blocking semantics. Keep edits limited to repository-local skills and this plan step's completion status when the implementation is later finished.

Out of Scope:

Do not create `.agents/skills/shared/**`, a shared glossary file, or any other new source-of-truth vocabulary document. Do not normalize the lower-priority clusters from the research note in this step: `Stage Boundary`, `Evidence Consequence Link`, `Concrete Failure Mode Standard`, `Source-Of-Truth Singularity`, `Owner-Level Fix`, `Boundary-Owned Policy`, `Sequenced Migration And Retirement`, `Temporal Surface Closure`, `All-Or-Nothing Failure Boundary`, `Negative Proof And Fixture Quarantine`, `Fresh Reviewer After Mutation`, `Prompt Context Minimalism`, or `UI Metadata Separation`, except for incidental wording required to keep the four selected concepts coherent. Do not change UI metadata in `.agents/skills/*/agents/openai.yaml`. Do not change runtime code, tests, docs under `docs/`, architecture graph files, guardrail tooling, or public API behavior.

Source of Truth:

The current behavior is described by `.agents/skills/*/SKILL.md`, with `.agents/skills/anti-slop-review/SKILL.md` as the existing `Outcome-Proof Fit` precedent. The audit source input is `.research/2026-05-31-skill-rule-convergence.md`. The roadmap source of truth is `PLAN.md` plus this linked step contract.

Compatibility:

Existing skill trigger behavior, allowed edit scopes, review output formats, and exact prompt forms must remain compatible. The implementation may clarify names and definitions, but must not make a skill less strict, change required review prompt forms, alter verdict/output schemas, or require a new shared file to execute any skill.

Order Constraints:

Normalize `Outcome-Proof Fit` first because it is the existing canonical pattern. Then normalize `Decision Chain Of Custody`, followed by `Decision Closure`, and then `Completion Evidence Boundary`, because completion semantics depend on the earlier source-input and blocking vocabulary. After Units 1-4 are implemented, verified, reviewed, and committed, run the final status unit to update only `PLAN.md` and this step file's completion checkboxes. Include that status commit in the final committed-range review.

## Execution Units

### [x] Unit 1: Align Outcome-Proof Fit References

Owner:

`.agents/skills/anti-slop-review/SKILL.md`, `.agents/skills/code-review/SKILL.md`, `.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/change-contract/SKILL.md`, and `.agents/skills/change-contract-check/SKILL.md`.
`.agents/skills/architecture-design/assets/design-artifact-template.md` is included only for its existing `Outcome-Proof Fit` table wording and must remain a passive template.

Boundary:

Canonical name and short cross-reference only. Preserve the existing `Outcome-Proof Fit` definition in `anti-slop-review`; do not move it or broaden it into a new glossary. Do not change code-review's finding format or priority taxonomy.

Change:

Update indirect proof/proxy wording so affected review-stage rules refer to `Outcome-Proof Fit` by name when they are applying the same claim/direct-outcome/proxy-risk/required-proof invariant. Keep anti-slop's four-part frame as the local precedent. Preserve stage-specific output requirements: anti-slop verdicts remain anti-slop verdicts, and code-review findings remain code-review style actionable findings.

Completion Check:

`rg -n "Outcome-Proof Fit|claim-vs-actual-work|proxy signal|direct outcome" .agents/skills/anti-slop-review/SKILL.md .agents/skills/code-review/SKILL.md .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-review/SKILL.md .agents/skills/architecture-design/assets/design-artifact-template.md .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md` shows that broad proof/proxy rules use the canonical `Outcome-Proof Fit` name or are clearly local explanatory text under that rule. Manual review of `.agents/skills/code-review/SKILL.md` confirms the output format and `[P0]`-`[P3]` priority semantics are unchanged. Manual review of `.agents/skills/architecture-design/assets/design-artifact-template.md` confirms only passive template wording is aligned, not artifact shape.

Depends On:

None.

### [x] Unit 2: Normalize Decision Chain Of Custody

Owner:

`.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, and `.agents/skills/plan-step-contract/SKILL.md`.
`.agents/skills/architecture-design/assets/design-artifact-template.md` is included only for existing `Decision Trace` and `Change Contract Handoff` wording.

Boundary:

Name, short definition, and stage-specific application for preserving source decisions. Do not change the required contract sections, Decision Trace table columns, plan-step review prompt forms, or design artifact template shape unless a local phrase must be aligned to the canonical name.

Change:

Introduce and use the canonical name `Decision Chain Of Custody` for the invariant that source inputs, research/design/phase decisions, handoff constraints, lock-required facts, and repository-derived decisions must be preserved into the next stage's local fields, execution units, or proof surfaces. Keep each stage's local mechanics: design still records `Decision Trace`, contract still lists `Source Inputs`/`Classification`/`Decision Trace`, contract-check still validates loss/weakening, and plan-step still requires a contract shaped by `change-contract`.

Completion Check:

`rg -n "Decision Chain Of Custody|Decision Trace|Source Inputs|handoff|lock-required|source-input" .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-review/SKILL.md .agents/skills/architecture-design/assets/design-artifact-template.md .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md .agents/skills/plan-step-contract/SKILL.md` shows the canonical name in each affected stage and no contradictory alternate name for the same invariant. Manual review confirms source-input narrowing/exclusion rules and design-to-contract mapping requirements remain at least as strict as before, and the template remains passive output structure only.

Depends On:

Unit 1.

### [x] Unit 3: Normalize Decision Closure

Owner:

`.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/architecture-design-workflow/SKILL.md`, `.agents/skills/change-contract/SKILL.md`, and `.agents/skills/change-contract-check/SKILL.md`.

Boundary:

Canonical unresolved-decision vocabulary only. Preserve existing stage-specific labels: design dispositions, design-review `PASS`/`REVISE`/`BLOCKED` routes, `Contract Blocker`, and contract-check `PASS`/`REVISE`/`BLOCKED`.

Change:

Use `Decision Closure` consistently for the invariant that owner, boundary, source of truth, compatibility, execution order, proof seam/fixture strategy, mandatory source-of-truth update, temporal/reentrancy behavior, all-or-nothing boundary, migration/retirement strategy, and completion signal must be settled before implementation. Keep stage-specific routing intact: design records `NEEDS_RESEARCH` or `ARCHITECTURE_GATE`, design review blocks contract authoring, change-contract emits `Contract Blocker`, and change-contract-check blocks implementation.

Completion Check:

`rg -n "Decision Closure|Contract Blocker|BLOCKED|ARCHITECTURE_GATE|NEEDS_RESEARCH|completion signal|proof seam|source of truth" .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-review/SKILL.md .agents/skills/architecture-design-workflow/SKILL.md .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md` shows the canonical name attached to unresolved-decision rules without replacing local verdict/disposition names. Manual review confirms no skill now allows implementation-time selection of owner, boundary, source of truth, compatibility, order, proof seam, or completion signal.

Depends On:

Unit 2.

### [x] Unit 4: Normalize Completion Evidence Boundary

Owner:

`.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, `.agents/skills/code-review/SKILL.md`, `.agents/skills/plan-step-contract/SKILL.md`, `.agents/skills/unit-by-unit/SKILL.md`, `.agents/skills/anti-slop-review/SKILL.md`, and completion wording in `.agents/skills/architecture-design/SKILL.md` / `.agents/skills/architecture-design-workflow/SKILL.md` only where needed for consistent naming.

Boundary:

Completion-marker and proof-authority wording only. Do not change unit execution order, exact reviewer prompt forms, commit requirements, review output schemas, or plan-step primary/second reviewer requirements.

Change:

Introduce and use `Completion Evidence Boundary` for the invariant that completion markers and completion/readiness claims belong only to the stage that has the corresponding proof authority. Planning contracts keep execution unit checkboxes unchecked and contain no post-implementation proof. Contract checking rejects completed-unit status or proof blocks before implementation. Code review flags premature completion markers only when the reviewed range lacks implemented/proven work. Unit-by-unit remains the workflow that implements, verifies, reviews, commits, and final-range reviews units before completion is recorded. Anti-slop keeps completion/readiness claims under direct outcome proof instead of becoming a planning-completion authority.

Completion Check:

`rg -n "Completion Evidence Boundary|unchecked|pre-marked complete|post-implementation|premature completion|implemented, verified, reviewed|final committed-range|completion state|readiness state" .agents/skills/change-contract/SKILL.md .agents/skills/change-contract-check/SKILL.md .agents/skills/code-review/SKILL.md .agents/skills/plan-step-contract/SKILL.md .agents/skills/unit-by-unit/SKILL.md .agents/skills/anti-slop-review/SKILL.md .agents/skills/architecture-design/SKILL.md .agents/skills/architecture-design-workflow/SKILL.md` shows the canonical name in the relevant completion/proof-authority rules and shows anti-slop completion/readiness claims remain tied to direct outcome proof. Manual review confirms local completion semantics, reviewer prompt forms, commit requirements, review output schemas, and plan-step primary/second reviewer requirements are not weakened or rerouted by this unit.

Depends On:

Unit 3.

### [x] Unit 5: Final Plan Status And Range Surface Audit

Owner:

`PLAN.md` and `plan/step_44_skill_rule_vocabulary_normalization.md`.

Boundary:

Completion/status markers and final range-surface proof only. Do not change skill wording, UI metadata, runtime code, tests, docs under `docs/`, architecture graph files, guardrail tooling, or any source-of-truth surface outside `PLAN.md` and this step file in this unit.

Change:

After Units 1-4 have approved implementation commits, mark Step 44 complete in `PLAN.md` and mark Units 1-5 complete in `plan/step_44_skill_rule_vocabulary_normalization.md`. Before Unit 5 review, prove the status-only working tree contains only those marker changes and no pending or untracked forbidden files. After the approved Unit 5 status commit exists, the normal `unit-by-unit` final committed-range review must include this status commit and verify the range-level surface audit.

Completion Check:

Before Unit 5 review, `git diff --name-status` for the Unit 5 working tree shows only `PLAN.md` and `plan/step_44_skill_rule_vocabulary_normalization.md` status-marker changes. `git status --short --untracked-files=all` at the same point shows no pending or untracked glossary, shared rule-vocabulary, shared source-of-truth, `.agents/skills/shared/**`, UI metadata, runtime, test, docs, architecture, or guardrail files. `PLAN.md` marks Step 44 checked, and this step file marks Units 1-5 checked in the same status-only working tree. After the Unit 5 commit, the normal final committed-range review must verify `git diff --name-status START_COMMIT^..END_COMMIT` shows only the permitted implementation surfaces: `.agents/skills/anti-slop-review/SKILL.md`, `.agents/skills/architecture-design/SKILL.md`, `.agents/skills/architecture-design-review/SKILL.md`, `.agents/skills/architecture-design-workflow/SKILL.md`, `.agents/skills/architecture-design/assets/design-artifact-template.md`, `.agents/skills/change-contract/SKILL.md`, `.agents/skills/change-contract-check/SKILL.md`, `.agents/skills/code-review/SKILL.md`, `.agents/skills/plan-step-contract/SKILL.md`, `.agents/skills/unit-by-unit/SKILL.md`, `PLAN.md`, and `plan/step_44_skill_rule_vocabulary_normalization.md`, with no `.agents/skills/*/agents/openai.yaml` metadata changes, runtime/test/docs/architecture/guardrail changes, added glossary, shared rule-vocabulary, shared source-of-truth artifact, or `.agents/skills/shared/**` path. The same final committed-range review must also confirm the content changes are limited to the four selected concepts and necessary cross-reference wording, with no normalization of the out-of-scope lower-priority clusters listed in this contract.

Depends On:

Units 1, 2, 3, and 4.
