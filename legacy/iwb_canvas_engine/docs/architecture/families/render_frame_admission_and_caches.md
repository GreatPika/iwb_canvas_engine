# Render Frame Admission And Caches

## Purpose

This family owns render frame admission, paint candidate planning, selection
rendering, and render caches.

## Target Rules

- A frame paints from one frozen frame authority.
- Candidate admission and selection overlays must not introduce unbounded work
  or draw-order drift.
- Selection rendering owns halo-only visuals; base selected-node geometry stays
  in the content pass and reusable stroke paths are borrowed from
  frame-resolved paint data.

## Owners

- `lib/src/render/**`
- `test/render/**`

## Forbidden Shapes

- Do not mix multiple live read authorities inside one frame.
- Do not describe KI-8 as target architecture.

## Mechanical Evidence

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `flutter test --no-pub test/render test/view`

## Proof Links

- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Invariant: `INV-ENG-EPOCH-INVALIDATION`
- Invariant: `INV-ENG-PERFORMANCE-PROOF-CONTOUR`
- Invariant: `INV-ENG-RENDER-HIT-BOUNDS-PARITY`
- Invariant: `INV-ENG-RENDER-GEOMETRY-KEY-STABLE`
- Invariant: `INV-ENG-RENDER-CACHE-SCAN-RESISTANT`
- Invariant: `INV-ENG-SELECTION-BOUNDED-COMPOSITING`
- Invariant: `INV-ENG-GRID-BOUNDED-ITERATION`
- Invariant: `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`
- Invariant: `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE`
- Invariant: `INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY`

## Status

- `locked`
- Selection overlay redraw drift is closed; frame admission, halo-only
  selection rendering, and render-cache ownership now match the target rules.

## Update Triggers

- Refresh when frame reads, paint admission, selection rendering, or render
  caches change.
