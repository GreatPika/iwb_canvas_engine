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

## Proof Links

- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Invariant: `INV-ENG-CORE-ARCHITECTURE-BOUNDARY`

## Status

- `docs stale`
- This slice creates the atlas route; the family is completed in the engine
  family atlas slice.

## Update Triggers

- Refresh when geometry, hit testing, or spatial index admission changes.
