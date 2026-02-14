# Architecture Overview

This document describes the architecture of `iwb_canvas_engine` on the current mainline.

## Goals

- Provide a reusable Flutter canvas engine package (no app UI).
- Keep a single source of truth for scene/runtime state.
- Expose stable public contracts for runtime and JSON persistence.

## Public surface

Entrypoints:

- `package:iwb_canvas_engine/iwb_canvas_engine.dart`

Primary public abstractions:

- Runtime: `SceneController`, `SceneView`
- Immutable read model: `SceneSnapshot`, `BackgroundLayerSnapshot`, `ContentLayerSnapshot`, `NodeSnapshot`
- Safe transactional write model: `SceneWriteTxn`
- Write intents: `NodeSpec`
- Partial mutation: `NodePatch` + `PatchField<T>`
- Serialization: `encodeScene*`, `decodeScene*`, `SceneDataException`

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
    serialization/  // JSON codec (schema v4)
    view/           // interactive Flutter widget
```

## Data flow

1. `SceneView` receives pointer events from Flutter.
2. `SceneController` processes events and performs transactional writes.
3. Controller updates the immutable `SceneSnapshot`.
4. `ScenePainterV2` renders snapshot state via `CustomPaint`.
5. `actions` / `editTextRequests` streams expose asynchronous boundaries to the host app.

## Invariants

Canonical invariant registry:

- `tool/invariant_registry.dart`

Key invariants:

- Single entrypoint: `iwb_canvas_engine.dart` only.
- Single source of truth: runtime state is owned by controller snapshot.
- Public API does not expose mutable core scene structures.
- All state mutations flow through `write` transactions and safe txn operations.
- Committed signals are delivered only after store commit finalization.
- For each successful commit, signal delivery happens before repaint listener notification.
- Repaint/listener notifications are scheduled after commit via microtask and coalesced per event-loop tick.
- Interactive `actions` / `editTextRequests` streams are delivered asynchronously (never in the same call stack as mutation methods).
- Relative ordering between interactive stream delivery and repaint listener notification is intentionally not a public contract.
- Buffered signal/repaint effects are discarded when `write(...)` rolls back.
- Node-id index state keeps `allNodeIds` and `nodeLocator` equal to committed scene ids/locations, while `nodeIdSeed` is a monotonic generator lower-bounded by committed scene ids.
- Node instance identity keeps `instanceRevision >= 1` for all committed nodes, and `nextInstanceRevision` is a monotonic generator lower-bounded by committed scene instance revisions.
- Selection normalization preserves explicit non-selectable ids and drops only missing/background/invisible ids.
- Runtime snapshot boundary (`initialSnapshot` / `replaceScene`) validates input strictly and fails fast with `SceneDataException` for malformed snapshots.
- Text node box size is derived from text layout inputs and is not writable via public spec/patch APIs.
- Runtime typed-layer rule: snapshot/model uses dedicated `backgroundLayer` plus content-only `layers`; input may omit background layer, but import boundaries canonicalize it to an empty dedicated layer.
- JSON decoder rule: accepts `backgroundLayer` (optional) and `layers` (content-only); missing `backgroundLayer` is canonicalized on decode/encode boundaries; legacy `isBackground` layer flag is unsupported.
- Unique node ids across all layers.
- Input and render subsystems must not bypass controller transaction boundaries.
- Import boundaries are enforced by `tool/check_import_boundaries.dart`.

## Serialization contract

- Current write schema: `schemaVersion = 4`.
- Accepted read schemas: `{4}`.
- Encoder/decoder validate numeric and structural constraints and fail fast with `SceneDataException`.

## Performance model

- Mutating transactions use copy-on-write: first mutation creates a shallow scene clone, then only touched layers/nodes are cloned on demand; no-op patches do not trigger layer/node cloning.
- Hot-path node lookup (`NodeId -> layer/node index`) uses committed `nodeLocator` instead of linear scene scans.
- Viewport culling for offscreen nodes.
- Bounded caches for text layout, stroke paths, and selected path metrics.
- `ScenePainterV2` keeps an internal per-node `RenderGeometryCache` with bounded LRU memory (`maxEntries = 512`) that reuses path parsing and local/world bounds calculations across culling, selection, and drawing.
- Stroke-path cache freshness is validated in O(1) by
  `(node.id, node.instanceRevision, pointsRevision)` instead of
  hashing/iterating point lists on every lookup.
- Spatial index supports incremental commit updates (`added/removed/hitGeometryChangedIds`) for hit-testing hot paths; full rebuild is a fallback path only.
- Spatial query guardrail: oversized query rectangles (`> 50_000` index cells) bypass cell loops and use bounded all-candidate scan with exact intersection filtering.
- Hit-test guardrail: path-stroke precise hit-testing caps per-metric sampling to `2_048` points by increasing sampling step for long metrics.
- Interactive draw guardrail: stroke commit caps points to `20_000` using deterministic index-uniform downsampling (endpoints preserved).
- Interactive move drag uses preview translation (single source in interactive controller) and commits translation once on pointer up; preview hit-testing merges spatial candidates for `point` and `point - delta`.

## Non-goals

- App-level state management, storage, or collaboration backend.
- App UI widgets outside canvas runtime/view.
- Built-in undo/redo history storage.
