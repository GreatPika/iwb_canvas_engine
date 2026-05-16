---
name: change-contract
description: Draft or update a Change Contract as a normative execution plan before implementation. Use when a feature, fix, refactor, migration, rule/analyzer change, or shared-seam retirement needs repository-evidence-backed architecture, execution order, gates, file mapping, vertical slices, and proof obligations; stop at an architecture decision gate when the owner, seam, or architectural dependency/import direction cannot be locked.
---

# Change Contract

Draft a Change Contract, not an overview.

Use only confirmed facts from the request and inspected repository artifacts. The final contract must be executable by another Codex run without relying on conversation memory.

## Internal file contract

- This `SKILL.md` is the only source for routing, core terms, architecture-lock requirements, decision-gate conditions, and template priority.
- After reading this file and inspecting repository evidence, Codex must already know what a locked architecture is, when to gate, and which single template to select.
- `references/contract-rules.md` explains how to fill the selected template: evidence, section ownership, slice construction, proof obligations, seam-retirement details, analyzer-specific details, and update behavior. It must not change routing, redefine core terms, or select a different template.
- Files in `assets/` are passive output shapes only. They must not be used to infer routing rules, architecture-lock requirements, or analyzer classification.

## Core terms

- **Owner**: the module, layer, or support seam that should own the behavior, invariant, policy, or migration once. Do not push ownership into callers when a shared owner can solve it once.
- **Seam**: the boundary where consumers interact with an owner or replacement mechanism. A shared seam has multiple consumers or repository references and cannot be retired without a successor, migration order, and retirement gate.
- **Locked architecture**: one evidence-backed architectural form selected before implementation. It fixes every lock-required fact below.
- **Lock-required facts**: owner, owning layer or module, seam, architectural dependency/import direction, state/data ownership, entry and exit boundaries, file placement basis, execution order, rejected alternatives, and verification strategy. For shared-seam creation, migration, or retirement, also lock successor seam, consumer migration order, retirement gate, and final broad-verification timing.
- **Architecture decision gate**: the stop condition when any lock-required fact is missing, contradicted by repository evidence, or cannot be chosen without a user decision. In this case use the gate template and stop after section 4.
- **Vertical slice**: the smallest implementation step that closes one new verifiable result. Preparatory edits alone do not close a slice.
- **Proof**: executable repository verification that demonstrates the slice or final contract is correct. Behavioral proof checks runtime/user-visible behavior. Structural proof checks architecture, imports, ownership, layer boundaries, or analyzer recognition.
- **Analyzer change**: a change whose subject is an analyzer, rule engine, bypass detector, static-analysis check, contract-enforcement mechanism, or structural-recognition rule. A normal feature does not become an analyzer change merely because it needs structural proof.

## Source-of-truth rules

- Apply naming rules from the active user-level `AGENTS.md` when those rules are present in Codex context.
- Do not mention user-level configuration file paths in the Change Contract; the contract should name repository artifacts only.
- If user-level naming rules are not present, infer names from adjacent repository artifacts and state that naming was inferred from repository-local precedent.
- Repository-local rules still govern architecture, architectural dependency/import direction, layer boundaries, test commands, fixtures, and placement when they are present.

## Workflow

1. Inspect active instructions already in context, repository-local rules, surrounding code, tests, owner boundaries, architectural dependency/import direction, layer boundaries, and existing verification before drafting.
2. Normalize the request into mandate, included scope, and exclusions.
3. Decide whether all lock-required facts are evidence-backed. If any lock-required fact is missing or contradicted, choose the architecture decision gate.
4. Select exactly one template, in this priority order:
   - `assets/architecture-gate-template.md` when architecture cannot be locked; stop after section 4.
   - `assets/analyzer-contract-template.md` when architecture is locked and the change itself is an analyzer change.
   - `assets/full-contract-template.md` for all other locked changes.
5. Read `references/contract-rules.md` to fill the selected template. Do not let the reference file change the selected template or routing decision.
6. Preserve main section numbering and slice checkboxes from the selected template. Use concrete slice titles. Omit only optional subsections, bullets, or categories that have no confirmed content. Never emit placeholders, filler, guessed details, or empty optional headings.
7. Return only the Change Contract. Do not append review, validation, or audit commentary.
