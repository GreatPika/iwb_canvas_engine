# Architecture Overview

This document describes the architecture as of `iwb_canvas_engine` v0.1.0 and
the intended direction for v1.0.

## Goals

- Provide a scene engine for Flutter: model, rendering, input, and JSON serialization.
- Keep a single source of truth in `SceneController`.
- Maintain clear action boundaries for undo/redo integration at the app layer.

## Non-goals

- App UI (menus, panels, asset pickers).
- Built-in undo/redo implementation.
- Persistence beyond JSON export/import.

## Invariants

This section documents project invariants in a form that is intended to be
checkable (by tests, tooling, or simple grep-able rules).

Canonical invariant IDs live in `tool/invariant_registry.dart`.

### Global invariants

- `lib/src/core/**` must not import `input/`, `render/`, `view/`, or
  `serialization/`.
- Layer boundaries are enforced by `tool/check_import_boundaries.dart`:
  - `lib/src/serialization/**` may import only `core/**` and `serialization/**`
  - `lib/src/input/**` may import only `core/**` and `input/**`
  - `lib/src/render/**` may import only `core/**`, `input/**`, and `render/**`
  - `lib/src/view/**` may import only `core/**`, `input/**`, `render/**`, and `view/**`
- Public entrypoints must remain source-compatible:
  - `package:iwb_canvas_engine/basic.dart`
  - `package:iwb_canvas_engine/advanced.dart`
  - `CanvasMode` and `DrawTool` stay available via those same entrypoints.
- Input notifications preserve the current "bit-for-bit" semantics:
  - **Immediate notification** (synchronous): mode/tool/color/background/grid
    setters, `notifySceneChanged()`, and most scene mutation commands
    (rotate/flip/delete/clear/moveNode/removeNode/addNode).
  - **Coalesced notification (once per frame)**: stroke thickness/opacity
    setters, camera offset, selection/selection-rect updates, and hot paths
    during pointer gestures.

### v2 transaction-first guardrails

The v2 migration adds explicit guardrails enforced by `tool/` checks. They are
designed to keep v2 architecture constraints machine-checkable while the v1 and
v2 code paths temporarily coexist.

- `INV-V2-NO-EXTERNAL-MUTATION`:
  v2 public API modules must not depend on mutable internals from
  `input/**`, `render/**`, `view/**`, or `serialization/**`.
- `INV-V2-WRITE-ONLY-MUTATION`:
  v2 controller mutation entrypoints are restricted to transaction-style
  `write*`/`txn*` symbols.
- `INV-V2-TXN-ATOMIC-COMMIT`:
  v2 mutation flow must preserve a single transaction boundary per write
  (guarded by transaction entrypoint rules and transaction-focused tests).
- `INV-V2-EPOCH-INVALIDATION`:
  v2 controller lifecycle must preserve epoch-based invalidation contracts
  (`controllerEpoch`) for replace-scene/cache/index safety.

### Boundary invariants (Input slices)

The input layer is being refactored into vertical slices under
`lib/src/input/slices/**`. These rules are enforced by `tool/` checks (see
`DEVELOPMENT_PLAN.md`).

- `lib/src/input/slices/**`:
  - must not use `part` / `part of`
  - must not import `scene_controller.dart`
  - must not import other slices outside of its own slice subtree
- `lib/src/input/internal/**`:
  - must not import `scene_controller.dart`
  - must not import `slices/**`
- Shared reusable input code (used by multiple slices) lives in
  `lib/src/input/internal/**` (or in `lib/src/core/**` if it is pure math).

### Slice invariants

These invariants are requirements for future extraction work. They are kept
here as a checklist to prevent subtle behavioral regressions during refactors.

- Repaint:
  - repeated `requestRepaintOncePerFrame()` calls schedule at most one frame
  - cancellation tokening prevents stale scheduled callbacks from firing
  - `notifyNow()` clears the "needs notify" flag and cancels scheduled repaint
  - `notifyNow()` is a safe no-op after `dispose()`
- Signals:
  - both streams stay `broadcast(sync: true)`
  - `ActionCommitted.actionId` format stays `a${counter++}`
  - events emitted after dispatcher `dispose()` are dropped safely
  - double-tap correlation is keyed by `pointerId` (not device kind)
  - while a gesture is active, signal candidates are accepted only from the
    active pointer id
  - pending-tap flush uses a single timer window (no timer recreation per move)
- Selection:
  - `setSelection(...)` defaults to coalesced repaint (not immediate notify)
  - `clearSelection()` remains an immediate notify
- Commands:
  - structural mutations go through `mutateStructural(...)`/commands that call
    `notifySceneChanged()` and return immediately
  - `SceneController` maintains an internal `allNodeIds` membership index
    (derived from scene structure) used by `newNodeId()` and
    `notifySceneChanged()` normalization paths for O(1) id checks

## High-level structure

```text
lib/
  basic.dart        // Primary v2 public API
  advanced.dart     // Advanced alias of basic.dart
  basic_v2.dart     // Deprecated compatibility alias to basic.dart
  advanced_v2.dart  // Deprecated compatibility alias to advanced.dart
  src/
    core/           // Scene model, math, selection, hit-test
    render/         // Canvas rendering for background, layers, nodes
    input/          // Pointer handling, tool state, gesture logic
    serialization/  // Legacy JSON v2 codec (mutable Scene API)
    v2/public/      // Immutable snapshot/spec/patch contracts (transaction-first migration)
    v2/serialization/ // JSON v2 codec (SceneSnapshot API)
```

## v2 public surface

`basic.dart` / `advanced.dart` expose immutable v2 contracts:

- immutable read models (`SceneSnapshot`, `LayerSnapshot`, `NodeSnapshot`)
- immutable write intents (`NodeSpec`, `NodePatch`)
- tri-state patch field semantics (`PatchField.absent/value/nullValue`)
- JSON helpers with v2 snapshot types (`encodeScene*` / `decodeScene*`)

The compatibility aliases `basic_v2.dart` / `advanced_v2.dart` re-export the
same symbols for migration convenience.

## Data model

### Scene

- Ordered `layers` list
- Camera offset stored in `scene.camera.offset` (x, y)
- Background: color + grid (optional)
- Default palettes for drawing and background

### Layer

- Ordered `nodes` list
- The order defines z-order (last is top)
- For scenes managed by `SceneController`, constructor canonicalization keeps a
  single background layer at index `0` (missing/misordered background is fixed;
  multiple background layers are rejected).
- `clearScene()` canonicalizes runtime layer structure to that same invariant:
  exactly one background layer at index `0` and no non-background layers.

### Nodes

Common base properties:

- `id`, `type`, `transform` (2x3 affine: a,b,c,d,tx,ty)
- Convenience accessors (public API): `position`, `rotationDeg`, `scaleX`, `scaleY` are derived from `transform`
- For flips (`det < 0`), convenience accessors use a canonical TRS(+flip) decomposition: `scaleX` is a non-negative magnitude and reflection is encoded via the sign of `scaleY` together with `rotationDeg`. If you need to preserve the original reflection axis, use `transform` directly.
- `opacity`, `isVisible`, `isSelectable`, `isLocked`, `isDeletable`, `isTransformable`

Position semantics:

- `position` is the translation component of `transform` (center-based for box nodes).
- For stroke/line, geometry is stored in **local coordinates** around (0,0). During interactive drawing, the controller may temporarily keep points in world coordinates with `transform == identity`, then normalizes on gesture end.

Node types:

- `ImageNode`: references `imageId` and size
- `TextNode`: text + minimal style (font size, color, alignment, bold/italic/underline, optional fontFamily/maxWidth/lineHeight)
- `StrokeNode`: polyline + style
- `LineNode`: start/end + style
- `RectNode`: basic rectangle (selection + example)
- `PathNode`: SVG path data + fill/stroke + fill rule (nonZero/evenOdd)

### Selection

- Selection is a set of `nodeIds`.
- Selection storage is unordered; iteration order is not part of the contract.
- `setSelection(...)` / `toggleSelection(...)` normalize input to interactive
  node ids only: existing ids in non-background layers where
  `isVisible == true` and `isSelectable == true`.
- Selection operations treat background-layer nodes as non-interactive and
  non-deletable (even if ids are injected manually).
- Group is not stored; group operations compute a union AABB and apply transforms per node.

## Coordinate systems

- **Scene/world coordinates**: stored in node `transform` translation and used for hit-test and selection.
- **Local coordinates**: per-node geometry around (0,0) (stroke points, line endpoints, path data).
- **View/screen coordinates**: pointer and canvas space.
- Conversion applies `cameraOffset`:
  - Render: `scenePoint - cameraOffset`.
  - Input: `pointerPoint + cameraOffset`.

## Rendering pipeline

### `SceneView` (Widget)

- Hosts `CustomPaint` for drawing.
- Wraps with `Listener` to capture raw pointer events.
- Depends on `SceneController` and `ImageResolver` callback.

### `ScenePainter`

1. Draw static layer (background + grid) using a cached `Picture` when available.
   - Grid over-density is degraded by drawing every `N`th line per axis so
     painted line count stays within safety cap; the grid is not silently
     disabled for this case.
2. Draw layers in order; nodes in order.
   - Each node is rendered by applying `node.transform` (local -> scene/world) and then subtracting `cameraOffset` (scene/world -> view).
3. Draw selection overlay and selection marquee (if active).

Static layer cache invariants:

- The cache key includes view size, background color, grid settings, and grid
  stroke width.
- The cached `Picture` is rebuilt only when the key changes.

### Images

- `ImageNode` uses `imageId`.
- The app provides a resolver: `imageId -> ui.Image`.
- Rendering should handle missing images gracefully (placeholder or skip).

## Input pipeline

### Pointer handling

- Raw pointer events are converted to scene coordinates.
- Inbound timestamps are treated as hints and normalized into an internal
  monotonic timeline (`max(hint, cursor + 1)`).
- Double-tap is detected with time and distance thresholds and is correlated by
  `pointerId` (not by `PointerDeviceKind`).
- Pointer capture: if a drag starts on a node, it continues until pointer up.
- While a gesture is active, `SceneView` forwards tap/double-tap candidates
  only from the active pointer id.
- `SceneView` keeps at most one pending-tap flush timer and only while pending
  taps exist.

### Tool state machine

- **Move mode**: selection, drag move, marquee selection.
- **Draw mode**: pen, highlighter, line, eraser.
- Move drag is transactional: cancel and mode switch during active drag
  rollback all drag-applied transforms and emit no transform action.
- Eraser normalizes selection before publishing changes: deleted node ids are
  removed from `selectedNodeIds` before action emission.
- Eraser commits only on pointer up (move is preview-only); cancel and mode
  switch do not mutate scene and emit no erase action.
- Stroke/line commit is fail-safe: if local-normalization preconditions are
  violated at commit time, the pending preview node is discarded and no action
  is emitted (the input loop must not crash).
- Line tool supports two flows: drag or two-tap with 10s timeout driven by an
  internal timer (not by arrival of new pointer events).

### Action boundaries

Action boundaries are required for undo/redo integration.
Emit `ActionCommitted` on:

- drag end (transform)
- stroke end (successful commit only)
- line end (successful commit only)
- transform/delete/clear
- marquee end (only when normalized selection changes)
- erase end

## Hit-testing and math

- `hitTestTopNode` ignores layers with `isBackground == true`; background layers
  are render-only at top-level selection/hit-test.
- Rect/Image/Text nodes hit-test in local coordinates by transforming the
  pointer via `inverse(transform)` and checking `localBounds` (inflated by
  `hitPadding + kHitSlop`). When the inverse is unavailable (degenerate
  transforms), the engine falls back to the world-space AABB inflated by
  `hitPadding + kHitSlop` (coarse selection).
- Lines/strokes use distance-to-segment with thickness tolerance. `LineNode` and
  `StrokeNode` hit-testing also applies `hitPadding + kHitSlop` in strict
  scene/world units (no anisotropic max-axis inflation). When the inverse is
  unavailable, they fall back to the inflated world-space AABB (coarse
  selection).
- Path nodes hit-test as the union of:
  - **Fill**: geometry hit-test via `Path.contains` with inverse transforms.
    If inverse transform is unavailable (degenerate), fill is non-interactive
    (no coarse AABB fallback).
  - **Stroke**: coarse AABB hit-test (stage A) using
    `boundsWorld.inflate(hitPadding + kHitSlop)` in scene units. Note that
    `boundsWorld` already includes stroke thickness via `PathNode.localBounds`.
    This keeps selection usable without expensive geometry distance checks.
  - Invalid/unbuildable SVG path data is non-interactive in hit-testing.
- `PathNode` geometry may be open and/or degenerate in bounds (e.g. linear
  paths); validity is not determined by `Rect.isEmpty`.
- Group transforms use center of union AABB of selected nodes.

## Serialization (JSON v2)

- `schemaVersionWrite = 2`, and the decoder accepts only `schemaVersionsRead = {2}`.
- Integer JSON fields use integer-valued finite numeric validation:
  values like `2` and `2.0` are accepted; `2.5`, non-finite numbers, and
  non-numeric values are rejected.
- Every node stores:
  - `transform` as an affine 2×3 matrix: `{a,b,c,d,tx,ty}`
  - `hitPadding`
  - local geometry by type
- Local geometry:
  - `StrokeNode`: `localPoints` (around (0,0))
  - `LineNode`: `localA`, `localB` (around (0,0))
  - `PathNode`: `svgPathData` (source of truth; rendered centered around (0,0))
  - `RectNode` / `ImageNode` / `TextNode`: `size {w,h}` (always centered on (0,0))
- Export/import validates input and throws a clear `SceneJsonFormatException` on invalid data.
- JSON contracts also enforce non-empty palettes and conditional grid rules:
  `background.grid.cellSize` must be finite and `> 0` when grid is enabled,
  and only finite when grid is disabled.
- Decoder canonicalizes background-layer invariants: exactly one background
  layer at index `0` (missing/misordered is fixed, multiple backgrounds throw
  `SceneJsonFormatException`).
- Runtime bounds/hit-testing/rendering use soft numeric normalization to avoid
  NaN/Infinity propagation; strict validation is enforced at the JSON boundary.
  - Width-like values (`thickness`, `strokeWidth`, `hitPadding`) normalize to
    finite non-negative values.
  - `opacity` normalizes in the core model (`!finite -> 1`, clamp to `[0,1]`).

## Events

- `ActionCommitted` (required)
- `EditTextRequested` for `TextNode` double-tap
- A change notification for repaint (stream/listener)
- `ActionCommitted.timestampMs` and `EditTextRequested.timestampMs` are emitted
  on the same internal monotonic timeline (not UNIX wall-clock time).

`ActionCommitted.payload` uses minimal metadata for undo/redo:
- transform: `{delta: {a,b,c,d,tx,ty}}`

## Example app responsibilities

- Provide UI for tools/modes, palettes, background.
- Provide `ImageResolver` and text editing UI.
- Demonstrate selection, transform, draw, erase, and camera scroll.

## Extensibility notes

To add a node type:

1. Extend core model and serialization.
2. Add renderer in `render/`.
3. Add hit-test in `core/`.
4. Add unit tests for math/serialization.
