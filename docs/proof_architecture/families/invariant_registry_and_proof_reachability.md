# Invariant Registry And Proof Reachability

## Purpose

This family fixes the target shape for invariant bookkeeping: invariant ids,
architecture-family ownership, required proof paths, regression surfaces, and
required-code-change reachability must stay explicit and mechanically checked.

## Target Rules

- Keep invariant ids, scopes, titles, and proof paths in one checked-in
  registry.
- Keep architecture-family invariant expectations registry-owned so atlas docs
  and atlas checker fixtures cannot drift through parallel maps.
- Require every invariant to name at least one executable required proof
  surface.
- Require required proofs to stay reachable from the `required_code_change`
  preset.
- Keep regression surfaces explicit so proof coverage can stay executable as the
  repository changes.

## Owners

- `tool/invariant_registry.dart`
- `tool/check_invariant_coverage.dart`
- `tool/src/verification_contract/verification_contract_registry.dart`

## Forbidden Shapes

- Invariants without executable required proofs.
- Architecture-family invariant expectations owned by checker-local maps.
- Required proof paths that are unreachable from `required_code_change`.
- Regression surfaces that drift without matching invariant markers.

## Mechanical Evidence

- `dart run tool/trace_proof_inventory.dart --json-out=docs/proof_architecture/evidence/proof_inventory.json --md-out=docs/proof_architecture/evidence/proof_inventory.md`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart test/tool/trace_proof_inventory_tool_test.dart`

## Status

- `locked`
- Current mechanical coverage is green, and proof reachability plus
  architecture-family invariant ownership remain explicit in the invariant
  registry plus verification-contract registry.

## Update Triggers

- Refresh this family when its listed proof tools, evidence artifacts, or registry-backed invariants change.
