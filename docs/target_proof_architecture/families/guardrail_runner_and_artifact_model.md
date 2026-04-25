# Guardrail Runner And Artifact Model

## Purpose

This family fixes the target shape for the guardrail runner: rule order,
invariant ownership, and shared runner artifacts must remain explicit so proof
surfaces do not silently change meaning.

## Target Rules

- Keep guardrail rule order explicit in one checked-in inventory.
- Keep every shared runner artifact owned by a named writer rule and consumed
  only by declared reader rules.
- Use artifact names for one proof universe only; if two proof universes differ
  materially, they must not share one ambiguous artifact.
- Keep invariant ownership visible at the rule level so rule drift is
  mechanically explainable.

## Owners

- `tool/check_guardrails.dart`
- `tool/src/guardrails/guardrails_runner.dart`
- `tool/src/guardrails/guardrail_rule_inventory.dart`
- `tool/src/guardrails/core/guardrail_run_state.dart`

## Forbidden Shapes

- A shared runner artifact stands in for two different proof universes.
- Rule order or artifact edges are implicit instead of coming from one checked-in
  inventory.
- Invariant ids and rule ownership drift apart without an executable inventory
  trace.

## Mechanical Evidence

- `dart run tool/trace_proof_inventory.dart --json-out=docs/target_proof_architecture/evidence/proof_inventory.json --md-out=docs/target_proof_architecture/evidence/proof_inventory.md`
- `dart run tool/check_guardrails.dart`

## Status

- `locked`
- Current mechanical evidence shows separate public-proof artifacts:
  `exportedSurfaces` for direct barrel-layout policy and
  `effectivePublicExportNamespace` for effective namespace signature coverage.
