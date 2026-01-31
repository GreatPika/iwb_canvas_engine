# Architecture Overview

This document describes the intended architecture for `iwb_canvas_engine` v1.0.

## Goals

- Provide a scene engine for Flutter: model, rendering, input, and JSON serialization.
- Keep a single source of truth in `SceneController`.
- Maintain clear action boundaries for undo/redo integration at the app layer.

## Non-goals

- App UI (menus, panels, asset pickers).
- Built-in undo/redo implementation.
- Persistence beyond JSON export/import.

## High-level structure

```text
lib/
  core/            // Scene model, math, selection, hit-test
  render/          // Canvas rendering for background, layers, nodes
  input/           // Pointer handling, tool state, gesture logic
  serialization/   // JSON v1 codecs
```

## Data model

### Scene

- Ordered `layers` list
- `cameraOffset` (x, y)
- Background: color + grid (optional)
- Default palettes for drawing and background

### Layer

- Ordered `nodes` list
- The order defines z-order (last is top)

### Nodes

Common base properties:

- `id`, `type`, `position`, `rotationDeg`, `scaleX`, `scaleY`
- `opacity`, `isVisible`, `isSelectable`, `isLocked`, `isDeletable`, `isTransformable`

Position semantics:

- For box-based nodes (image/text/rect), `position` is the **center** of the node.
- For stroke/line, points are stored in **scene coordinates**; `position` is derived as the bounding box center, and setting it translates all points.

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

- **Scene coordinates**: stored in model and JSON.
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

- drag end (move)
- stroke end
- line end
- rotate/flip/delete/clear
- marquee end
- erase end

## Hit-testing and math

- Rotated rectangles use AABB of transformed corners.
- Lines/strokes use distance-to-segment with thickness tolerance.
- Path nodes use geometry hit-test via `Path.contains` with inverse transforms.
- Group rotate/flip uses center of union AABB of selected nodes.

## Serialization (JSON v1)

- `schemaVersion = 1`.
- `ImageNode` stores only `imageId` and sizes.
- `TextNode` stores minimal style fields.
- `PathNode` stores `svgPathData`, fill/stroke colors, stroke width, and fill rule.
- Export/import must validate and produce clear errors on invalid input.

## Events

- `ActionCommitted` (required)
- `EditTextRequested` for `TextNode` double-tap
- A change notification for repaint (stream/listener)

`ActionCommitted.payload` uses minimal metadata for undo/redo:
- rotate: `{clockwise: bool}`
- flip: `{axis: 'vertical' | 'horizontal'}`

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
