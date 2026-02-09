# iwb_canvas_engine

[![pub package](https://img.shields.io/pub/v/iwb_canvas_engine.svg)](https://pub.dev/packages/iwb_canvas_engine)
[![CI](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml/badge.svg)](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml)

Scene-based canvas engine for Flutter: model, rendering, input handling, and
JSON serialization for drawing tools and whiteboard-style apps.

Live demo and docs:

- Web demo: https://greatpika.github.io/iwb_canvas_engine/demo/
- API reference: https://greatpika.github.io/iwb_canvas_engine/api/
- API usage guide: `API_GUIDE.md`

## What it is / What it isn't

**What it is**

- A Flutter canvas engine with a mutable scene model (layers + nodes).
- Rendering via `CustomPaint` (`ScenePainter`) and a widget integration (`SceneView`).
- Input handling + tool logic (move/select, pen/highlighter/line/eraser).
- JSON v2 import/export for persistence and interoperability.

**What it isn't**

- A full whiteboard app (no menus/panels/toolbars/asset pickers).
- A built-in undo/redo stack (the engine emits action events; the app owns history).
- A storage backend (persistence is via JSON helpers).

## Features

- Scene model with layers and nodes (image, text, stroke, line, rect, path).
- Rendering via `ScenePainter` with background and grid.
- Built-in bounded render caches for text layout, stroke paths, and selected
  path metrics (`SceneView` owns them by default).
- Optional HiDPI-friendly pixel snapping for thin axis-aligned lines/strokes.
- Viewport culling for offscreen nodes.
- Hit-testing for selection and interaction.
- JSON v2 import/export with validation.

## Getting started

Add the dependency:

```sh
flutter pub add iwb_canvas_engine
```

## Entrypoints

Prefer importing the smallest API surface that fits your use case:

- `package:iwb_canvas_engine/basic.dart` — minimal “happy path” API (recommended).
- `package:iwb_canvas_engine/advanced.dart` — full export surface (low-level
  painting, hit-testing, pointer tracking, etc.).
- `package:iwb_canvas_engine/basic_v2.dart` — preview v2 immutable model
  (snapshot/spec/patch only; no v2 controller yet).
- `package:iwb_canvas_engine/advanced_v2.dart` — preview v2 alias of
  `basic_v2.dart` during migration stage B.

## v2 preview API (snapshot-only)

The preview v2 entrypoints expose immutable public contracts for transaction-
first migration:

- `SceneSnapshot`, `LayerSnapshot`, `NodeSnapshot` variants (read model).
- `NodeSpec` variants (node creation intent).
- `NodePatch` variants + `PatchField<T>` tri-state semantics:
  - `PatchField.absent()` => do not change field.
  - `PatchField.value(x)` => set field to `x`.
  - `PatchField.nullValue()` => explicitly set field to `null`.

No bridge to mutable v1 `Scene` is provided in this stage by design.

## Core concepts

- **Scene → Layer → Node**: layers are rendered in list order; nodes inside a
  layer are rendered in list order. The last node is top-most for hit-testing.
- **Path hit-testing**: `PathNode` selection uses fill ∪ stroke; fill is checked
  via `Path.contains` (requires an invertible transform; degenerate transforms
  are not clickable for fill), and stroke uses precise distance-to-path checks
  with tolerance `strokeWidth/2 + hitPadding + kHitSlop`.
  Invalid/unbuildable SVG path data is non-interactive in hit-testing.
- **Text direction and alignment**: `SceneView` forwards ambient
  `Directionality` to `ScenePainter`. `TextAlign.start`/`TextAlign.end`
  resolve according to that direction (`ltr`/`rtl`).
- **Background interaction policy**: background-layer nodes are render-only for
  selection/delete paths (`selectAll`, marquee, transform helpers, and
  `deleteSelection`).
- **Local geometry + `Transform2D`**: node geometry is stored in local
  coordinates around (0,0). `SceneNode.transform` (2×3 affine matrix) is the
  single source of truth for translation/rotation/scale.
- **View vs scene coordinates**: pointer samples come in view/screen
  coordinates (e.g. `PointerEvent.localPosition`). The controller converts them
  to scene coordinates using `scene.camera.offset`.
- **Camera offset**: rendering subtracts `scene.camera.offset` so that panning
  is implemented as camera movement, not by mutating node geometry.
  `SceneController.setCameraOffset(...)` accepts only finite offsets and throws
  `ArgumentError` for NaN/Infinity components.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/basic.dart';

final scene = Scene(
  layers: [
    Layer(nodes: [
      RectNode(
        id: 'rect-1',
        size: const Size(120, 80),
        fillColor: const Color(0xFF2196F3),
      )..position = const Offset(120, 120),
      PathNode(
        id: 'path-1',
        svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
        fillRule: PathFillRule.evenOdd,
        fillColor: const Color(0xFF4CAF50),
      )..position = const Offset(260, 120),
    ]),
  ],
);

final controller = SceneController(scene: scene);

SceneView(
  controller: controller,
  // Optional. Provide when you use ImageNode.
  imageResolver: (imageId) => null,
);
```

`SceneController(scene: ...)` is optional. When omitted, the controller creates
an empty `Scene()` by default.
When provided, the constructor validates scene invariants and canonicalizes
recoverable background-layer cases (ensures a background layer exists at index
0). Unrecoverable violations (for example multiple background layers) throw
`ArgumentError`.
Set `clearSelectionOnDrawModeEnter: true` if your UX requires dropping current
selection whenever mode switches to `CanvasMode.draw` (default is `false`).
`decodeScene(...)` applies the same background-layer canonicalization and throws
`SceneJsonFormatException` for multiple background layers.

### Simple view (no controller boilerplate)

```dart
SceneView(
  onControllerReady: (controller) {
    controller.addNode(
      RectNode(
        id: 'rect-1',
        size: const Size(120, 80),
        fillColor: const Color(0xFF2196F3),
      )..position = const Offset(120, 120),
    );
  },
);
```

When `controller` is omitted, you can configure the internally owned controller:

```dart
SceneView(
  pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 450),
  dragStartSlop: 12,
  nodeIdGenerator: () => 'node-${DateTime.now().microsecondsSinceEpoch}',
);
```

When `SceneView` owns the controller, updating these widget parameters at
runtime reconfigures the same controller instance (no recreation). If a pointer
gesture is active, the new configuration is applied after that gesture ends.

### Advanced view (external controller)

```dart
final controller = SceneController(scene: scene);

SceneView(
  controller: controller,
  thinLineSnapStrategy: ThinLineSnapStrategy.autoAxisAlignedThin,
);
```

Node IDs must be unique within a scene. By default, `SceneController` generates
`node-{n}` IDs for nodes it creates. The default counter starts at
`max(existing node-{n}) + 1` for the provided scene (so it doesn't scan the
whole scene on every new node when nodes are created in bulk). Pass
`nodeIdGenerator` if you need a custom scheme.

You can update input/runtime generation config without recreating the
controller:

```dart
controller.reconfigureInput(
  pointerSettings: const PointerInputSettings(doubleTapMaxDelayMs: 500),
  dragStartSlop: 10,
  nodeIdGenerator: () => 'custom-${DateTime.now().microsecondsSinceEpoch}',
);
```

If called during an active pointer gesture, the new config is deferred and
applies from the next gesture.

### Events

The app can listen to controller events to integrate with undo/redo and text
editing UI.

```dart
controller.actions.listen((event) {
  // ActionCommitted for undo/redo integration.
});

controller.editTextRequests.listen((event) {
  // Open a text editor for event.nodeId at event.position.
});

SceneView(
  controller: controller,
);
```

For `ActionCommitted.payload`:
- `transform`: `{delta: {a,b,c,d,tx,ty}}`
- `move` (layer move): `{sourceLayerIndex: int, targetLayerIndex: int}`
- `drawStroke/drawHighlighter/drawLine`: `{tool: String, color: int, thickness: double}`
- `erase`: `{eraserThickness: double}`

Payload keys are additive-only: existing keys must keep their meaning and type.

Decode helpers:
- `Transform2D.fromJsonMap(event.payload!['delta'] as Map<String, Object?>)`
- `event.tryTransformDelta()`
- `event.tryMoveLayerIndices()`
- `event.tryDrawStyle()`
- `event.tryEraserThickness()`

Notes:

- `actions` and `editTextRequests` are synchronous broadcast streams; handlers
  must be fast and avoid blocking work.
- The engine emits `ActionCommitted` boundaries, but the app is responsible for
  storing history and applying undo/redo.
- After an erase commit, deleted node ids are removed from selection before
  the `ActionType.erase` event is emitted.

### Scene mutations

Prefer mutating the scene through `SceneController` instead of touching
`scene.layers.first.nodes` directly:

```dart
controller.addNode(
  RectNode(
    id: 'rect-2',
    size: const Size(120, 80),
    fillColor: const Color(0xFF2196F3),
  )..position = const Offset(200, 200),
);

controller.moveNode('rect-2', targetLayerIndex: 0);
controller.removeNode('rect-2');
```

`addNode(...)` default target is the first non-background layer. If the scene
has only a background layer, the controller creates a new non-background layer
and adds the node there.

If you mutate `controller.scene` directly, prefer using
`controller.mutateStructural(...)` for structural edits:

```dart
controller.mutateStructural((scene) {
  final contentLayer = scene.layers.firstWhere((layer) => !layer.isBackground);
  contentLayer.nodes.add(myNode);
});
```

If you bypass controller helpers and mutate `controller.scene` directly, call
the appropriate update method afterwards to restore minimal invariants and/or
schedule repaint.

Notes about direct mutations:

- **Structural changes** (add/remove/reorder layers or nodes): call
  `controller.mutateStructural(...)` (or `controller.notifySceneChanged()` if
  you intentionally bypass mutation helpers).
- **Geometry-only changes** (e.g. `node.transform`, points, colors, sizes): call
  `controller.mutate(...)` (or `controller.requestRepaintOncePerFrame()` when
  mutating directly).

### Selection and transforms

- Locked nodes (`isLocked == true`) can be selected, but drag-move skips them.
- Geometric transforms (drag-move, rotate, flip) apply only to nodes with
  `isTransformable == true` and `isLocked == false`.
- Transform centers and bounds are computed from the transformable subset.
- Flip axis semantics: `flipSelectionHorizontal()` reflects across the vertical
  axis through selection center; `flipSelectionVertical()` reflects across the
  horizontal axis through selection center.

### Advanced rendering / input

If you need low-level APIs (custom painting via `ScenePainter`, hit-testing, or
raw pointer tracking), import the full export surface:

```dart
import 'package:iwb_canvas_engine/advanced.dart';
```

### Input limitations

The engine currently supports single-pointer input only. Multi-touch gestures
(pinch-to-zoom, two-finger pan) are not supported yet.
Tap/double-tap signal correlation is `pointerId`-based, and `SceneView`
accepts tap/double-tap candidates only from the active pointer while a gesture
is in progress.

## Serialization (JSON v2)

```dart
final json = encodeSceneToJson(controller.scene);
final restored = decodeSceneFromJson(json);
```

`decodeSceneFromJson` accepts only `schemaVersion = 2` and throws
`SceneJsonFormatException` when the input is invalid or fails validation.
Integer-valued numeric forms are accepted for integer fields (for example
`schemaVersion: 2.0`), while fractional values (for example `2.5`) are
rejected.

Numeric fields must be finite and within valid ranges (for example, opacity
must be within `[0,1]` and thickness values must be `> 0`). Invalid input
throws `SceneJsonFormatException`.
Palette arrays must be non-empty (`penColors`, `backgroundColors`, `gridSizes`).
For `background.grid.cellSize`, validation depends on `grid.enabled`:
- `enabled == true`: `cellSize` must be finite and `> 0`.
- `enabled == false`: any finite `cellSize` is accepted.

At runtime, bounds/hit-testing/rendering are defensive:
- non-finite or negative length-like values (`thickness`, `strokeWidth`,
  `hitPadding`) are soft-normalized to safe finite non-negative values;
- `opacity` is normalized in the core model (`!finite -> 1`, clamp `[0,1]`).

## API reference

API docs are generated from Dartdoc comments in `lib/`:

- Local: run `dart doc` and open `doc/api/index.html`.
- On pub.dev: the “API reference” tab is generated automatically on publish.
- On GitHub: enable GitHub Pages + run the `api_docs_pages` workflow to publish
  Dartdoc HTML to Pages.

### Text layout

`TextNode.size` is the layout box used for alignment, hit-testing, and
selection bounds. The engine does not auto-resize this box when text style
changes. If you need auto-fit behavior, recompute and update `size` in the app.

### ImageResolver and constraints

`ImageResolver` maps `imageId` from `ImageNode` to a `ui.Image` instance. It is
called during painting, so keep it fast and side-effect free.

Guidelines:

- Return `null` if the image is not ready; the painter will render a placeholder.
- Preload images in the app layer and cache the `ui.Image` objects.
- Avoid async work in the resolver; resolve before repainting.

## Additional information

See `ARCHITECTURE.md` for design notes and `example/` for a working app.

## AI-assisted development

This library (including its tests) was fully written with OpenAI Codex
(vibecoding).
