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
- Signals:
  - both streams stay `broadcast(sync: true)`
  - `ActionCommitted.actionId` format stays `a${counter++}`
- Selection:
  - `setSelection(...)` defaults to coalesced repaint (not immediate notify)
  - `clearSelection()` remains an immediate notify
- Commands:
  - structural mutations call `notifySceneChanged()` and return immediately

## High-level structure

```text
lib/
  basic.dart        // Minimal public API
  advanced.dart     // Full public API
  src/
    core/           // Scene model, math, selection, hit-test
    render/         // Canvas rendering for background, layers, nodes
    input/          // Pointer handling, tool state, gesture logic
    serialization/  // JSON v2 codec
```

## Data model

### Scene

- Ordered `layers` list
- Camera offset stored in `scene.camera.offset` (x, y)
- Background: color + grid (optional)
- Default palettes for drawing and background

### Layer

- Ordered `nodes` list
- The order defines z-order (last is top)

### Nodes

Common base properties:

- `id`, `type`, `transform` (2x3 affine: a,b,c,d,tx,ty)
- Convenience accessors (public API): `position`, `rotationDeg`, `scaleX`, `scaleY` are derived from `transform`
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
2. Draw layers in order; nodes in order.
   - Each node is rendered by applying `node.transform` (local -> scene/world) and then subtracting `cameraOffset` (scene/world -> view).
3. Draw selection overlay and selection marquee (if active).

Static layer cache invariants:

- The cache key includes view size, background color, grid settings, camera
  offset, and grid stroke width.
- The cached `Picture` is rebuilt only when the key changes.

### Images

- `ImageNode` uses `imageId`.
- The app provides a resolver: `imageId -> ui.Image`.
- Rendering should handle missing images gracefully (placeholder or skip).

## Input pipeline

### Pointer handling

- Raw pointer events are converted to scene coordinates.
- Double-tap is detected with time and distance thresholds.
- Pointer capture: if a drag starts on a node, it continues until pointer up.

### Tool state machine

- **Move mode**: selection, drag move, marquee selection.
- **Draw mode**: pen, highlighter, line, eraser.
- Line tool supports two flows: drag or two-tap with 10s timeout.

### Action boundaries

Action boundaries are required for undo/redo integration.
Emit `ActionCommitted` on:

- drag end (transform)
- stroke end
- line end
- transform/delete/clear
- marquee end
- erase end

## Hit-testing and math

- Rect/Image/Text nodes hit-test in local coordinates by transforming the
  pointer via `inverse(transform)` and checking `localBounds` (inflated by
  `hitPadding + kHitSlop`). When the inverse is unavailable (degenerate
  transforms), the engine falls back to the world-space AABB inflated by
  `hitPadding + kHitSlop` (coarse selection).
- Lines/strokes use distance-to-segment with thickness tolerance. `LineNode` and
  `StrokeNode` hit-testing also applies `hitPadding + kHitSlop` in scene units
  (scale-aware). When the inverse is unavailable, they fall back to the inflated
  world-space AABB (coarse selection).
- Path nodes hit-test as the union of:
  - **Fill**: geometry hit-test via `Path.contains` with inverse transforms.
  - **Stroke**: coarse AABB hit-test (stage A) using `strokeWidth/2 + hitPadding + kHitSlop`
    in scene units. This keeps selection usable without expensive geometry distance checks.
- `PathNode` geometry may be open and/or degenerate in bounds (e.g. linear
  paths); validity is not determined by `Rect.isEmpty`.
- Group transforms use center of union AABB of selected nodes.

## Serialization (JSON v2)

- `schemaVersionWrite = 2`, and the decoder accepts only `schemaVersionsRead = {2}`.
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

## Events

- `ActionCommitted` (required)
- `EditTextRequested` for `TextNode` double-tap
- A change notification for repaint (stream/listener)

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
