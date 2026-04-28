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
- `flutter test --no-pub test/model`

## Proof Links

- Proof family: [invariant registry and proof reachability](../../proof_architecture/families/invariant_registry_and_proof_reachability.md)
- Invariant: `INV-G-NODEID-UNIQUE`
- Invariant: `INV-G-LAYERID-UNIQUE`
- Invariant: `INV-G-SELECTION-NORMALIZED`
- Invariant: `INV-G-GRID-ENABLE-CELL-SIZE-RELATION`
- Invariant: `INV-ENG-ID-INDEX-FROM-SCENE`
- Invariant: `INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER`
- Invariant: `INV-ENG-COMMITTED-STORE-METADATA-CONTRACT`
- Invariant: `INV-ENG-RUNTIME-SCENE-VALIDITY-BACKSTOP`
- Invariant: `INV-ENG-PALETTE-RUNTIME-VALUE-OWNER`
- Invariant: `INV-ENG-RUNTIME-NODE-VALUE-OWNERS`
- Invariant: `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`

## Status

- `locked`
- Model topology insertion admission uses scene topology as the source of
  truth for node uniqueness, node budget, and content-layer uniqueness.
  Derived `nodeLocator` and `layerIndexById` maps are companion indexes and
  are refreshed from scene topology after successful semantic insertion.

## Update Triggers

- Refresh when document topology, locators, or model mutation helpers change.
