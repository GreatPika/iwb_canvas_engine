---
name: change-contract
description: Draft or update a Change Contract as a normative execution plan before implementation. Use when a feature, fix, refactor, migration, rule/analyzer change, source-of-truth documentation change, or shared-seam retirement needs repository-evidence-backed architecture, execution order, gates, slice-local file ownership, vertical slices, and proof obligations; stop at an architecture decision gate when the owner, seam, architectural dependency/import direction, state ownership, boundary, or verification strategy cannot be locked.
---

# Change Contract

Draft a Change Contract, not an overview.

Use only confirmed facts from the request and inspected repository artifacts. Make the final contract executable in a later run without relying on conversation memory.

## Internal file contract

- This `SKILL.md` is the only source for routing, core terms, architecture-lock requirements, decision-gate conditions, profile selection, obligation selection, and active template priority.
- After reading this file and inspecting repository evidence, you must already know the contract mode, profile, obligations, whether the architecture is locked, and which active template to select.
- `references/contract-rules.md` explains how to fill the selected template: evidence, information ownership, slice construction, proof obligations, seam-retirement details, analyzer-specific details, and update behavior. It must not change routing, redefine core terms, add new profiles, add new obligations, or select a different template.
- Files in `assets/` are passive output shapes only. They must not be used to infer routing rules, architecture-lock requirements, profile classification, or obligation classification.

## Core terms

- **Owner**: the module, layer, document family, analyzer, rule, or support seam that should own the behavior, invariant, policy, or migration once. Do not push ownership into callers when a shared owner can solve it once.
- **Seam**: the boundary where consumers interact with an owner or replacement mechanism. A shared seam has multiple consumers or repository references and cannot be retired without a successor, migration order, and retirement gate.
- **Lock-required facts**: owner, owning layer or module, seam, architectural dependency/import direction, state/data ownership, entry and exit boundaries, file placement basis, execution order, rejected alternatives, and verification strategy. For shared-seam creation, migration, or retirement, also lock successor seam, consumer migration order, retirement gate, and final broad-verification timing.
- **Architecture decision gate**: the stop condition when any lock-required fact is missing, contradicted by repository evidence, or cannot be chosen without a user decision. In this case use `Contract Mode: ARCHITECTURE_GATE`, select the gate template, and stop at section 3.
- **Proof**: executable repository verification that demonstrates the slice or final contract is correct. Semantic proof checks behavior, wording, API shape, documentation meaning, or user-visible contract. Structural proof checks architecture, imports, ownership, layer boundaries, registries, indexes, generated navigation, analyzer recognition, or other mechanically checkable structure.

## Contract modes

Select exactly one mode before selecting a profile.

- `FULL`: all lock-required facts are evidence-backed and the contract can define slices and proof.
- `ARCHITECTURE_GATE`: at least one lock-required fact is missing, contradicted, or requires a user decision. The contract must stop at section 3 and must not include proof plans, slices, or final gates.

## Contract profiles

Every contract must write exactly one `Contract Profile`.

For `FULL` contracts, select the profile that owns the locked proof mode.
For `ARCHITECTURE_GATE` contracts, select the profile that would govern the requested work if the gate were resolved, using the known request and repository evidence. If the blocking gap prevents confident classification, use `BEHAVIOR_CHANGE` as the conservative default and state the profile uncertainty in `Architecture Gate`.

Use this priority order:

1. `ANALYZER_RULE`: the owned behavior is an analyzer, rule engine, bypass detector, static-analysis check, contract-enforcement mechanism, structural-recognition rule, or its fixtures.
2. `SOURCE_OF_TRUTH_DOCS`: the owned change updates normative repository source-of-truth documents such as architecture docs, contracts, diagrams, registries, guardrails, indexes, or roadmap step contracts, without production/runtime implementation in scope.
3. `REFACTOR`: the owned change alters implementation form, placement, naming, decomposition, dependency direction, or ownership while preserving observable behavior.
4. `BEHAVIOR_CHANGE`: the owned change alters observable production/runtime/API/data behavior, persistence, rendering, public semantics, or user-visible behavior. This is the default locked profile when no earlier profile applies.

Do not choose a profile by file extension. Markdown can be source-of-truth docs, analyzer fixtures, or historical evidence. Dart can be behavior, refactor, or analyzer work. The owner and proof mode decide.

## Contract obligations

List obligations in this stable order: `BUG_FIX`, `SEAM_MIGRATION`, `PUBLIC_API_CHANGE`. If none apply, write `Contract Obligations: none`.

For `ARCHITECTURE_GATE` contracts, list only obligations already proven by the request or repository evidence. If an obligation depends entirely on the unresolved user decision, omit it until the gate is resolved.

- `BUG_FIX`: add when the change repairs existing wrong behavior, a regression, false positive, false negative, invariant gap, or contradiction with an accepted contract.
- `SEAM_MIGRATION`: add when the change creates, renames, replaces, migrates, or retires a shared seam with multiple consumers or repository references.
- `PUBLIC_API_CHANGE`: add when the change modifies exported API, public contract, data format, config schema, persistence format, or compatibility promise.

## Active templates

Select exactly one active template.

- `assets/architecture-gate-template.md` for `Contract Mode: ARCHITECTURE_GATE`.
- `assets/full-contract-template.md` for every `Contract Mode: FULL` contract, including `ANALYZER_RULE`.

There is no separate analyzer template. Analyzer-specific requirements are profile rules inside the unified locked template.

## Source-of-truth rules

- Apply naming rules from the active user-level `AGENTS.md` when those rules are present in your active instruction context.
- Do not mention user-level configuration file paths in the Change Contract; the contract should name repository artifacts only.
- If user-level naming rules are not present, infer names from adjacent repository artifacts and state that naming was inferred from repository-local precedent.
- Repository-local rules still govern architecture, architectural dependency/import direction, layer boundaries, test commands, fixtures, and placement when they are present.

## Workflow

1. Inspect active instructions, repository-local rules, surrounding code/docs/tests, lock-required facts, and existing verification.
2. Normalize the request into mandate, included scope, and exclusions.
3. Select `Contract Mode`. Use `FULL` only when all lock-required facts are evidence-backed; otherwise use `ARCHITECTURE_GATE`, select the gate template, and stop at section 3.
4. Select exactly one `Contract Profile`, then select applicable `Contract Obligations` or `none`.
5. Open the active template for the selected mode, then read `references/contract-rules.md` to fill it. Do not let the reference file change mode, profile, obligations, or template choice.
6. When updating an existing contract, convert it to the current template and preserve stable content only in current owning sections.
7. Return only the Change Contract.
