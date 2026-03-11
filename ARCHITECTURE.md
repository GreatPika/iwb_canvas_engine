# Architecture Overview

This document describes the current mainline architecture of
`iwb_canvas_engine`. It focuses on system shape, data flow, invariants, and the
constraints that keep the public API stable.

## Goals

- Keep scene state in one place.
- Expose stable public contracts around immutable snapshots and safe writes.
- Separate product UI concerns from engine/runtime concerns.

## System boundary

- Public entrypoint: `package:iwb_canvas_engine/iwb_canvas_engine.dart`
- Supported public surface: exactly the exports declared by
  `lib/iwb_canvas_engine.dart`
- Current serialization contract: write `schemaVersion = 5`, read `{5}`
- Public runtime aliases: `SceneController`, `SceneView`
- Public write boundary: `SceneWriteTxn`

The package is an engine. It does not own app UI, persistence, collaboration, or
undo/redo policy.

## Module layout

Current repository layout:

```text
lib/
  iwb_canvas_engine.dart
  src/
    contract/       // stable API contracts and contract-facing value types
      validated/    // boundary value objects and id/revision parsing rules
    core/           // primitives, defaults, math, event types
    controller/     // committed store, command execution, transactional writes
    interactive/    // public controller facade and gesture orchestration
    model/          // conversions between internal document and public snapshot
    render/         // painter and render-cache implementations
    serialization/  // JSON codec and validation boundary
    view/           // Flutter widget that wires input + painting
```

## Layer ownership note (ADR)

- Public API is defined only by exports from
  `lib/iwb_canvas_engine.dart`.
- `src/**` remains internal package structure rather than a supported external
  import contract.
- `src/contract/validated.dart` is part of the supported public API because it
  is exported by the package barrel; no separate compat or advanced entrypoint
  exists for it.
- `contract/` is the low-level layer for stable API contracts and
  shared contract-facing value types.
- `contract/validated/**` is the single contract-facing home for boundary value
  parsing/generation rules; `model/` and `serialization/` consume it rather
  than re-owning those rules independently.
- The `lib/src` dependency graph is explicit and acyclic.

Current dependency DAG:

- `contract -> none`
- `core -> contract`
- `model -> core + contract`
- `serialization -> model + core + contract`
- `controller -> model + core + contract`
- `interactive -> controller + model + core + contract`
- `render -> model + core + contract`
- `view -> interactive + controller + render + model + core + contract`

Ownership decisions for the target state:

- `SceneBuilder` is not part of `contract/`; it belongs to `model/`.
- Parsed-map normalization for `SceneBuilder.buildFromJson(...)` stays in the
  `model/` layer via a model-local guard; `model/` must not import
  `serialization/` to reuse transport wrappers.
- `Transform2D` is part of the supported contract language and lives in
  `contract/` as a contract-facing value type; its file move does not change
  the public symbol name.
- `PathFillRule` is part of the supported contract language and lives in
  `contract/path_fill_rule.dart`; `core/nodes.dart` is a consumer rather than
  the long-term owner of that enum.
- `contract/transform_tolerance.dart` is the single internal source of truth
  for the near-singular 2x2 criterion used by `contract/transform2d.dart` and
  downstream `core/` consumers; `contract/` must not import
  `core/numeric_tolerance.dart`.
- Runtime orchestration and owner-specific facades do not move into
  `contract/`.
- `contract/` is low-level but not pure Dart: contract types intentionally use
  `dart:ui`, and `SceneRenderState` depends on Flutter `Listenable`.

## Runtime data flow

1. `SceneView` receives Flutter pointer input and normalizes it into public
   `CanvasPointerInput`, while its view-local pointer router owns raw Flutter
   pointer lifetimes, routed runtime `pointerId` allocation, and apply-on-idle
   adoption of `PointerInputSettings`.
2. `SceneControllerInteractive` validates input, maintains interactive state,
   and delegates committed mutations to `SceneControllerCore`.
3. `SceneControllerCore` performs transactional writes and finalizes a canonical
   immutable `SceneSnapshot`.
4. `ScenePainter` renders the committed snapshot plus any ephemeral preview
   state owned by the interactive controller.
5. `actions` and `editTextRequests` expose asynchronous integration boundaries
   back to the host app.

## State ownership model

- The committed `SceneSnapshot` is the single source of truth.
- Preview state for move/draw gestures is intentionally ephemeral and does not
  mutate committed scene data until commit on `up`.
- All committed mutations go through `write(...)` or higher-level controller
  methods that delegate to the same write path.
- Public API never exposes mutable internal scene objects.
- Runtime revision allocation is store-owned. The store keeps one composite
  invalidation identity from `controllerEpoch` plus node `instanceRevision`;
  commits never derive the next revision by scanning scene data.
- When the runtime revision counter reaches the safe-int ceiling, allocation
  resets the next revision to `1` and the commit must bump `controllerEpoch`.
  If the epoch cannot be bumped safely, the commit fails fast.

## Core invariants

Canonical invariant definitions live in `tool/invariant_registry.dart`. The
most important architectural rules are:

- `write(...)` is synchronous-only; returning a `Future` is a contract error.
- `SceneWriteTxn` is valid only inside the active write callback.
- Snapshot/JSON boundaries keep `backgroundLayer` distinct from ordered content
  `layers`; mutable runtime `Scene.backgroundLayer` may remain `null` until a
  write path materializes it.
- Content layers are addressed by stable `LayerId`; z-order is defined only by
  list order.
- `TextNode.size` is derived from text layout inputs and is not a writable
  public field; `TextNodeSnapshot.size` is canonical output metadata and is
  non-authoritative on import.
- Boundary validation has one source of truth per rule: limits come from
  `core/scene_limits.dart`, boundary value parsing/generation lives in
  `contract/validated/**`, and model/serialization layers reuse those rules.
- Public snapshot/spec/patch constructors enforce those primitive boundary
  rules eagerly; `contract/owned_collections.dart` is the single structural
  owner for immutable collection payload ownership; internal decode/runtime
  producers use contract-local fast paths so already validated data does not
  pay the same constructor boundary twice or fork collection semantics.
- Transactional write/model paths consume those already validated contract
  objects and own only runtime/stateful semantics such as target existence,
  type compatibility, live-scene duplicate checks, index/range checks,
  canonicalization, and derived-value recomputation.
- Generated-id policy is internal runtime ownership in
  `src/core/id_generator.dart`; public boundary code validates only explicit
  ids and must not depend on a generated-id string format.
- Selection normalization drops only missing, background, or invisible ids;
  explicit non-selectable ids remain stable.
- Listener notifications are microtask-deferred and coalesced.
- `actions` and `editTextRequests` are asynchronous; their relative ordering
  against repaint notifications is intentionally not a public contract.
- `PointerInputSettings` is a value object. `SceneView` owns the
  applied-versus-pending transition state and may rebuild its
  `PointerInputTracker` only after the raw-pointer router becomes idle; pending
  updates are last-write-wins and do not move into the interactive controller.
- After `dispose()`, mutating or effectful public entrypoints fail fast with
  `StateError`.

## Transaction and signal model

- High-level methods such as `addNode`, `patchNode`, `clearScene`, and
  transform commands all route through the same transactional core.
- Scene-mutating runtime intents are modeled as internal `MutationOp` values
  and executed by `MutationExecutor`; `SceneWriteTxn` stays the public write
  seam, while `SceneControllerCore` remains the owner of commit/store/signal
  lifecycle.
- `SceneWriter` is the internal owner for selection-only transitions, exact
  command-facing mutation results, and the buffered signal enqueue boundary;
  internal commands consume that writer-local seam directly instead of
  expanding the public `SceneWriteTxn` contract.
- Successful commits finalize store state before publishing signals or repaint
  notifications.
- Committed signals are emitted before repaint listener notification for the
  same successful commit.
- Buffered effects are discarded if a transaction fails.
- Runtime invariant enforcement is two-tiered:
  - critical commit checks run in all build modes;
  - the full committed-store sweep remains enabled in `debug` and `profile`.

## Serialization boundary

- Public JSON APIs accept `Map<String, dynamic>` or JSON strings.
- `decodeSceneFromJson(...)` rejects raw JSON strings longer than `33554432`
  characters before parser allocation.
- Decode/import canonicalizes missing `backgroundLayer` to an empty dedicated
  layer before returning a `SceneSnapshot`.
- Mutable runtime `Scene` keeps `backgroundLayer` nullable as an internal
  shape; local write paths materialize it on demand instead of maintaining a
  second canonical runtime model.
- Decode/import and runtime replacement paths validate structure and numeric
  constraints and throw `SceneDataException` on malformed input.
- `ScenePolicy` is the single owner for scene-level traversal semantics across
  import, decode, and runtime scene canonicalization:
  duplicate node ids, duplicate content-layer ids, scene-wide node/layer
  limits, and scene-level numeric range enforcement must not be re-owned by
  parallel validation paths.
- `imageId` follows the same validated boundary-owner policy on decode/import,
  snapshot/spec/patch validation, and runtime scene validation.
- Encode/decode/build boundaries sanitize oversized `SceneDataException.source`
  payloads into compact previews and snapshot small structured payloads into
  immutable containers while preserving stable `code`, `path`, and immutable
  `details`; `message` is a derived user-facing rendering owned by
  `scene_data_exception.dart`.
- `scene_codec.dart` is a thin boundary adapter: string decode uses
  serialization-local guards, parsed-map decode delegates to the model-owned
  parsed-map guard, and snapshot/runtime encode entrypoints reuse the shared
  codec error factory instead of owning parallel transport mappings.
- JSON payload limits are enforced to keep import cost bounded.
- Guardrails cover both collection sizes (layers, nodes, points, palette item
  lists) and string lengths (for example node ids, layer ids, text/image ids,
  and path payloads).

## Performance model

- Transactions use copy-on-write: only touched scene parts are cloned.
- Hot-path node lookup uses committed indexes instead of repeated linear scans.
- Spatial queries use a bounded spatial index with a bounded fallback path for
  oversized queries.
- Render caches are owned by `SceneView` and reset on controller
  epoch/document changes.
- Stroke and path rendering use revision-based cache keys to avoid stale reuse
  after node-id reuse or geometry changes.
- Input and hit-testing guardrails cap worst-case work for long strokes and
  large queries.

## Non-goals

- Product-specific UI and workflows outside the canvas engine.
- Network synchronization or backend protocols.
- App-owned persistence and undo/redo history.
