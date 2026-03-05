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
- `contract/` is the low-level layer for stable API contracts and
  shared contract-facing value types.
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
   `CanvasPointerInput`.
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

## Core invariants

Canonical invariant definitions live in `tool/invariant_registry.dart`. The
most important architectural rules are:

- `write(...)` is synchronous-only; returning a `Future` is a contract error.
- `SceneWriteTxn` is valid only inside the active write callback.
- `backgroundLayer` is always distinct from ordered content `layers`.
- Content layers are addressed by stable `LayerId`; z-order is defined only by
  list order.
- `TextNode.size` is derived from text layout inputs and is not a writable
  public field; `TextNodeSnapshot.size` is canonical output metadata and is
  non-authoritative on import.
- Selection normalization drops only missing, background, or invisible ids;
  explicit non-selectable ids remain stable.
- Listener notifications are microtask-deferred and coalesced.
- `actions` and `editTextRequests` are asynchronous; their relative ordering
  against repaint notifications is intentionally not a public contract.
- After `dispose()`, mutating or effectful public entrypoints fail fast with
  `StateError`.

## Transaction and signal model

- High-level methods such as `addNode`, `patchNode`, `clearScene`, and
  transform commands all route through the same transactional core.
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
- Decode/import canonicalizes missing `backgroundLayer` to an empty dedicated
  layer before returning a `SceneSnapshot`.
- Decode/import and runtime replacement paths validate structure and numeric
  constraints and throw `SceneDataException` on malformed input.
- JSON payload limits are enforced to keep import cost bounded.

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
