# Model Document Mutation And Topology

## Purpose

This family owns model-level document topology and mutation helpers.

## Target Rules

- Topology invariants are validated by the owner that has the complete scene
  topology.
- Derived indexes are not treated as independent truth unless freshness is
  explicit and enforced.

## Owners

- `lib/src/model/**`
- `test/model/**`

## Forbidden Shapes

- Do not rely on stale caller-provided locator or layer indexes as the sole
  uniqueness source.
- Do not describe KI-5 as target architecture.

## Mechanical Evidence

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`

## Proof Links

- Proof family: [invariant registry and proof reachability](../../proof_architecture/families/invariant_registry_and_proof_reachability.md)
- Invariant: `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`

## Status

- `docs stale`
- This slice creates the atlas route; the family is completed in the engine
  family atlas slice.

## Update Triggers

- Refresh when document topology, locators, or model mutation helpers change.
