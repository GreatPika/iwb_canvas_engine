# Architecture Overview

This document describes the architecture of `iwb_canvas_engine` for release `2.0.1`.

## Goals

- Provide a reusable Flutter canvas engine package (no app UI).
- Keep a single source of truth for scene/runtime state.
- Expose stable public contracts for runtime and JSON persistence.

## Public surface

Entrypoints:

- `package:iwb_canvas_engine/iwb_canvas_engine.dart`

Primary public abstractions:

- Runtime: `SceneController`, `SceneView`
- Immutable read model: `SceneSnapshot`, `LayerSnapshot`, `NodeSnapshot`
- Safe transactional write model: `SceneWriteTxn`
- Write intents: `NodeSpec`
- Partial mutation: `NodePatch` + `PatchField<T>`
- Serialization: `encodeScene*`, `decodeScene*`, `SceneJsonFormatException`

## Internal structure

```text
lib/
  iwb_canvas_engine.dart
  src/
    core/           // model primitives, math, hit testing, defaults
    controller/     // transactional writer/store internals
    input/          // input slices and gesture-state helpers
    interactive/    // public interactive controller facade
    model/          // scene <-> snapshot conversion helpers
    public/         // snapshot/spec/patch contracts
    render/         // painter and render caches
    serialization/  // JSON codec (schema v2)
    view/           // interactive Flutter widget
```

## Data flow

1. `SceneView` receives pointer events from Flutter.
2. `SceneController` processes events and performs transactional writes.
3. Controller updates the immutable `SceneSnapshot`.
4. `ScenePainterV2` renders snapshot state via `CustomPaint`.
5. `actions` / `editTextRequests` streams expose boundaries to the host app.

## Invariants

Canonical invariant registry:

- `tool/invariant_registry.dart`

Key invariants:

- Single entrypoint: `iwb_canvas_engine.dart` only.
- Single source of truth: runtime state is owned by controller snapshot.
- Public API does not expose mutable core scene structures.
- All state mutations flow through `write` transactions and safe txn operations.
- Committed signals are delivered only after store commit finalization.
- Repaint/listener notifications are scheduled after commit via microtask and coalesced per event-loop tick.
- Node-id index state (`allNodeIds`, `nodeIdSeed`) is derived from committed scene data.
- Selection normalization preserves explicit non-selectable ids and drops only missing/background/invisible ids.
- Background layer rule: at most one background layer; canonical index is `0`.
- Unique node ids across all layers.
- Input and render subsystems must not bypass controller transaction boundaries.
- Import boundaries are enforced by `tool/check_import_boundaries.dart`.

## Serialization contract

- Current write schema: `schemaVersion = 2`.
- Accepted read schemas: `{2}`.
- Decoder validates numeric and structural constraints and fails fast with `SceneJsonFormatException`.

## Performance model

- Mutating transactions use single clone-on-first-mutation; commit does not deep-clone scene again.
- Viewport culling for offscreen nodes.
- Bounded caches for text layout, stroke paths, and selected path metrics.
- Spatial index support for input hit-testing hot paths.
- Interactive move drag uses preview translation (single source in interactive controller) and commits translation once on pointer up; preview hit-testing merges spatial candidates for `point` and `point - delta`.

## Non-goals

- App-level state management, storage, or collaboration backend.
- App UI widgets outside canvas runtime/view.
- Built-in undo/redo history storage.
