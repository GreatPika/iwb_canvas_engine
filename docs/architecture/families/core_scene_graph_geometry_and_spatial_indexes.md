# Core Scene Graph Geometry And Spatial Indexes

## Purpose

This family owns geometry calculations, hit testing, and spatial index query
semantics.

## Target Rules

- Geometry and spatial index helpers expose shared policies instead of
  duplicating candidate logic.
- Hit testing and candidate bounds stay aligned for each node family.

## Owners

- `lib/src/core/**`
- `test/core/**`

## Forbidden Shapes

- Do not encode a separate hit-test policy in each caller.
- Do not describe KI-6 or KI-7 as target architecture.

## Mechanical Evidence

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `flutter test --no-pub test/core test/controller`

## Proof Links

- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Invariant: `INV-G-NODEID-UNIQUE`
- Invariant: `INV-G-LAYERID-UNIQUE`
- Invariant: `INV-G-LAYER-Z-ORDER-BY-LIST`
- Invariant: `INV-ENG-STROKE-RUNTIME-GEOMETRY-OWNER`
- Invariant: `INV-ENG-PALETTE-RUNTIME-VALUE-OWNER`
- Invariant: `INV-ENG-RUNTIME-NODE-VALUE-OWNERS`
- Invariant: `INV-ENG-EVENTS-IMMUTABLE`
- Invariant: `INV-ENG-CORE-ARCHITECTURE-BOUNDARY`
- Invariant: `INV-ENG-POINTER-SETTINGS-VALIDATION`
- Invariant: `INV-ENG-RENDER-HIT-BOUNDS-PARITY`
- Invariant: `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE`
- Invariant: `INV-ENG-PATH-NODE-CACHE-INVALIDATION`

## Status

- `known issue`
- Hit-testing and paint candidate parity defects remain tracked by
  [KI-6](../../../KNOWN_ISSUES.md#ki-6) and
  [KI-7](../../../KNOWN_ISSUES.md#ki-7); the family keeps the shared geometry
  and spatial-index target rules visible.

## Update Triggers

- Refresh when geometry, hit testing, or spatial index admission changes.
