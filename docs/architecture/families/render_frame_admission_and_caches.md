# Render Frame Admission And Caches

## Purpose

This family owns render frame admission, paint candidate planning, selection
rendering, and render caches.

## Target Rules

- A frame paints from one frozen frame authority.
- Candidate admission and selection overlays must not introduce unbounded work
  or draw-order drift.

## Owners

- `lib/src/render/**`
- `test/render/**`

## Forbidden Shapes

- Do not mix multiple live read authorities inside one frame.
- Do not describe KI-8 as target architecture.

## Mechanical Evidence

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`

## Proof Links

- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Invariant: `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`

## Status

- `docs stale`
- This slice creates the atlas route; the family is completed in the engine
  family atlas slice.

## Update Triggers

- Refresh when frame reads, paint admission, selection rendering, or render
  caches change.
