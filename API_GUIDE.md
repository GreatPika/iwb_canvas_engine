# iwb_canvas_engine API Guide

This guide is a complete, implementation-aligned reference for integrating `iwb_canvas_engine` in Flutter apps.
It is designed for both human developers and coding agents.

## 1. Package purpose and boundaries

`iwb_canvas_engine` provides:

- Scene model (`SceneSnapshot`, layers, nodes)
- Interactive runtime (`SceneController`, `SceneView`)
- Input handling (move/select/draw tools)
- JSON import/export (`schemaVersion = 2`)

`iwb_canvas_engine` does not provide:

- Application UI shell (toolbars, side panels, dialogs)
- Undo/redo history storage
- Network/storage backends

## 2. Entrypoints and aliases

Recommended import:

```dart
import 'package:iwb_canvas_engine/basic.dart';
```

Alternative import:

```dart
import 'package:iwb_canvas_engine/advanced.dart';
```

`advanced.dart` is currently an alias of `basic.dart`.

Runtime aliases exposed publicly:

- `SceneController` is a typedef alias of `SceneControllerInteractiveV2`
- `SceneView` is a typedef alias of `SceneViewInteractiveV2`

## 3. Public API map

`basic.dart` exports:

- Public immutable model contracts:
  - `SceneSnapshot`, `LayerSnapshot`, `NodeSnapshot` variants
  - `NodeSpec` variants
  - `NodePatch` variants
  - `PatchField<T>` and `PatchFieldState`
- Runtime:
  - `SceneController`, `SceneView`
- Input/event contracts:
  - `CanvasMode`, `DrawTool`
  - `PointerSample`, `PointerSignal`, `PointerInputSettings`
  - `ActionCommitted`, `ActionType`, `EditTextRequested`
- Serialization:
  - `encodeSceneToJson`, `decodeSceneFromJson`
  - `encodeScene`, `decodeScene`
  - `schemaVersionWrite`, `schemaVersionsRead`
  - `SceneJsonFormatException`
- Rendering support:
  - `ImageResolverV2`
  - `SceneStaticLayerCacheV2`, `SceneTextLayoutCacheV2`, `SceneStrokePathCacheV2`, `ScenePathMetricsCacheV2`

## 4. Scene data model

### 4.1 Root snapshot

`SceneSnapshot` contains:

- `layers: List<LayerSnapshot>`
- `camera: CameraSnapshot` (`offset`)
- `background: BackgroundSnapshot` (`color`, `grid`)
- `palette: ScenePaletteSnapshot` (`penColors`, `backgroundColors`, `gridSizes`)

### 4.2 Layer

`LayerSnapshot` contains:

- `nodes: List<NodeSnapshot>`
- `isBackground: bool`

Background layer constraints are canonicalized/validated by runtime and decoder.

### 4.3 Node snapshots

`NodeSnapshot` base fields:

- `id`
- `transform`
- `opacity`
- `hitPadding`
- `isVisible`
- `isSelectable`
- `isLocked`
- `isDeletable`
- `isTransformable`

Variants:

- `ImageNodeSnapshot`
- `TextNodeSnapshot`
- `StrokeNodeSnapshot`
- `LineNodeSnapshot`
- `RectNodeSnapshot`
- `PathNodeSnapshot`

Path fill rule enum:

- `V2PathFillRule.nonZero`
- `V2PathFillRule.evenOdd`

## 5. Write model: `NodeSpec`, `NodePatch`, `PatchField`

### 5.1 Create nodes (`NodeSpec`)

`SceneController.addNode(...)` accepts `NodeSpec` (preferred) and returns created node id.

Node spec variants:

- `ImageNodeSpec`
- `TextNodeSpec`
- `StrokeNodeSpec`
- `LineNodeSpec`
- `RectNodeSpec`
- `PathNodeSpec`

`NodeSpec.id` is optional; controller can generate ids.

### 5.2 Patch nodes (`NodePatch`)

`SceneController.patchNode(...)` accepts `NodePatch` and returns `bool` (true when node was updated).

Patch variants:

- `ImageNodePatch`
- `TextNodePatch`
- `StrokeNodePatch`
- `LineNodePatch`
- `RectNodePatch`
- `PathNodePatch`

Common patch fields are grouped in `CommonNodePatch`.

### 5.3 Tri-state patch semantics (`PatchField<T>`)

- `PatchField.absent()` -> leave field unchanged
- `PatchField.value(x)` -> set field to `x`
- `PatchField.nullValue()` -> explicitly set nullable field to `null`

Use `nullValue()` only for nullable fields.

## 6. Runtime controller (`SceneController`)

### 6.1 Construction

```dart
final controller = SceneController(
  // Optional legacy mutable scene source.
  scene: null,

  // Optional immutable startup scene.
  initialSnapshot: SceneSnapshot(
    layers: [
      LayerSnapshot(isBackground: true),
      LayerSnapshot(),
    ],
  ),

  // Optional input settings.
  pointerSettings: const PointerInputSettings(
    tapSlop: 16,
    doubleTapSlop: 32,
    doubleTapMaxDelayMs: 450,
  ),

  // Optional draw line slop override.
  dragStartSlop: 12,

  // Optional policy.
  clearSelectionOnDrawModeEnter: true,
);
```

### 6.2 Read-only state

- `snapshot: SceneSnapshot`
- `scene: Scene` (legacy mutable projection)
- `selectedNodeIds: Set<NodeId>`
- `mode: CanvasMode`
- `drawTool: DrawTool`
- `drawColor: Color`
- Thickness/opacity properties:
  - `penThickness`
  - `highlighterThickness`
  - `lineThickness`
  - `eraserThickness`
  - `highlighterOpacity`
- Interaction state:
  - `selectionRect`
  - `pendingLineStart`
  - `pendingLineTimestampMs`
  - `hasPendingLineStart`
  - `hasActiveStrokePreview`
  - `activeStrokePreviewPoints`
  - `hasActiveLinePreview`
- Streams:
  - `actions`
  - `editTextRequests`

### 6.3 Runtime configuration methods

- `setMode(CanvasMode value)`
- `setDrawTool(DrawTool value)`
- `setDrawColor(Color value)`
- `setPointerSettings(PointerInputSettings value)`
- `setDragStartSlop(double? value)`

Numeric property setters validate values and throw `ArgumentError` on invalid input:

- `penThickness = ...` (finite > 0)
- `highlighterThickness = ...` (finite > 0)
- `lineThickness = ...` (finite > 0)
- `eraserThickness = ...` (finite > 0)
- `highlighterOpacity = ...` (finite in `[0,1]`)

### 6.4 Scene/background/camera methods

- `setBackgroundColor(Color value)`
- `setGridEnabled(bool value)`
- `setGridCellSize(double value)`
- `setCameraOffset(Offset value)`
- `replaceScene(SceneSnapshot snapshot)`
- `notifySceneChanged()`

Validation notes:

- `setGridCellSize` requires finite positive value; with enabled grid it clamps to internal minimum safety limit.
- `setCameraOffset` rejects non-finite offsets.

### 6.5 Node and selection methods

- `String addNode(Object node, {int? layerIndex})`
  - Accepts `NodeSpec` and legacy `SceneNode`.
- `bool patchNode(NodePatch patch)`
- `bool removeNode(NodeId id, {int? timestampMs})`
- `setSelection(Iterable<NodeId> nodeIds)`
- `toggleSelection(NodeId nodeId)`
- `clearSelection()`
- `selectAll({bool onlySelectable = true})`

### 6.6 Transform/delete/clear commands

- `rotateSelection({required bool clockwise, int? timestampMs})`
- `flipSelectionVertical({int? timestampMs})`
- `flipSelectionHorizontal({int? timestampMs})`
- `deleteSelection({int? timestampMs})`
- `clearScene({int? timestampMs})`

Behavior notes:

- Transform operations affect transformable, unlocked selected nodes.
- Background/non-deletable policy is respected by delete flows.
- `clearScene` keeps canonical background layer and clears non-background content.

### 6.7 Low-level input hooks

- `handlePointer(PointerSample sample)`
- `handlePointerSignal(PointerSignal signal)`

Usually these are called by `SceneView` automatically.
Direct usage is useful when embedding the controller in custom input pipelines.

### 6.8 Direct transactional writes

- `write<T>(T Function(SceneWriter writer) fn)`

This is advanced API for controlled low-level writes.
Prefer high-level command methods unless you need custom transactional logic.

## 7. Interaction model details

### 7.1 Modes

- `CanvasMode.move`: selection, drag move, marquee
- `CanvasMode.draw`: pen/highlighter/line/eraser

### 7.2 Draw tool behavior

- Pen/highlighter: freehand stroke commit on pointer up
- Line: drag line or two-tap line (first tap sets pending start, second tap commits)
- Eraser: erases supported annotations (`StrokeNode`, `LineNode`) based on eraser trajectory

### 7.3 Double tap behavior

On double tap in move mode, if top hit node is a text node, controller emits `EditTextRequested`.

## 8. Events and payload contracts

### 8.1 `actions` stream

`actions` emits `ActionCommitted` with:

- `actionId` (`a0`, `a1`, ...)
- `type: ActionType`
- `nodeIds`
- `timestampMs`
- optional `payload`

`ActionType` values:

- `move`
- `selectMarquee`
- `transform`
- `delete`
- `clear`
- `drawStroke`
- `drawHighlighter`
- `drawLine`
- `erase`

Known payload schemas:

- transform: `{delta: {a,b,c,d,tx,ty}}`
- draw stroke/highlighter/line: `{tool: String, color: int, thickness: double}`
- erase: `{eraserThickness: double}`

Helper parsers on `ActionCommitted`:

- `tryTransformDelta()`
- `tryMoveLayerIndices()`
- `tryDrawStyle()`
- `tryEraserThickness()`

### 8.2 `editTextRequests` stream

`EditTextRequested` provides:

- `nodeId`
- `timestampMs`
- `position` (view coordinates)

Use this to open app-level text editor overlays.

## 9. View widget (`SceneView`)

### 9.1 Constructor

```dart
SceneView(
  controller: controller,
  imageResolver: (imageId) => null,
  staticLayerCache: null,
  textLayoutCache: null,
  strokePathCache: null,
  pathMetricsCache: null,
  selectionColor: const Color(0xFF1565C0),
  selectionStrokeWidth: 1,
  gridStrokeWidth: 1,
)
```

### 9.2 What `SceneView` does

- Captures pointer events via `Listener`
- Converts Flutter pointer events into `PointerSample`
- Feeds samples to `controller.handlePointer(...)`
- Uses `PointerInputTracker` for tap/double-tap derivation and forwards double taps to controller
- Paints scene via `ScenePainterV2`
- Paints interactive overlays (in-progress stroke/line previews)

### 9.3 Cache ownership semantics

If you do not pass cache instances, `SceneView` creates and owns internal caches.
If you pass external caches, ownership stays external.

When controller instance changes, view resets pointer tracking state and clears caches to prevent stale reuse across scenes.

## 10. Pointer contracts

### 10.1 `PointerSample`

Fields:

- `pointerId`
- `position` (view coords)
- `timestampMs` (hint)
- `phase` (`down/move/up/cancel`)
- `kind`

Controller normalizes timestamps into a monotonic internal timeline.

### 10.2 `PointerInputSettings`

- `tapSlop`
- `doubleTapSlop`
- `doubleTapMaxDelayMs`
- `deferSingleTap`

## 11. Serialization contracts

### 11.1 Functions

- `String encodeSceneToJson(SceneSnapshot snapshot)`
- `SceneSnapshot decodeSceneFromJson(String json)`
- `Map<String, dynamic> encodeScene(SceneSnapshot snapshot)`
- `SceneSnapshot decodeScene(Map<String, dynamic> json)`

### 11.2 Versioning

- `schemaVersionWrite == 2`
- `schemaVersionsRead == {2}`

### 11.3 Errors

Invalid input throws `SceneJsonFormatException` with validation details.

## 12. Full integration example

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/basic.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  late final SceneController controller;
  StreamSubscription<ActionCommitted>? actionsSub;
  StreamSubscription<EditTextRequested>? editTextSub;

  @override
  void initState() {
    super.initState();

    controller = SceneController(
      initialSnapshot: SceneSnapshot(
        layers: [
          LayerSnapshot(isBackground: true),
          LayerSnapshot(),
        ],
      ),
      pointerSettings: const PointerInputSettings(
        tapSlop: 16,
        doubleTapSlop: 32,
        doubleTapMaxDelayMs: 450,
      ),
      clearSelectionOnDrawModeEnter: true,
    );

    controller.addNode(
      RectNodeSpec(
        id: 'rect-1',
        size: const Size(120, 80),
        fillColor: const Color(0xFF2196F3),
      ),
    );

    actionsSub = controller.actions.listen((event) {
      // App-level undo/redo boundary.
      // Persist event or derive command history.
    });

    editTextSub = controller.editTextRequests.listen((event) {
      // Open app-level text editor for event.nodeId.
    });
  }

  @override
  void dispose() {
    actionsSub?.cancel();
    editTextSub?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SceneView(
        controller: controller,
        imageResolver: (imageId) => null,
      ),
    );
  }
}
```

## 13. Agent checklist for safe edits

When an agent modifies integration code:

1. Use `NodeSpec`/`NodePatch` in app code; avoid mutating internal scene structures directly.
2. Keep app-owned undo/redo separate from engine internals.
3. Handle `SceneJsonFormatException` around imports.
4. Keep `ActionCommitted.payload` parsing defensive via helper extensions.
5. Respect background layer semantics and non-deletable/non-selectable flags.
6. Prefer `SceneController`/`SceneView` aliases in app-facing docs/examples.

## 14. Quick recipes

### 14.1 Export/import JSON

```dart
final json = encodeSceneToJson(controller.snapshot);
final restored = decodeSceneFromJson(json);
controller.replaceScene(restored);
```

### 14.2 Rotate selected nodes clockwise

```dart
controller.rotateSelection(clockwise: true);
```

### 14.3 Toggle draw mode and set pen style

```dart
controller.setMode(CanvasMode.draw);
controller.setDrawTool(DrawTool.pen);
controller.setDrawColor(const Color(0xFF0D47A1));
controller.penThickness = 4;
```

### 14.4 Clear scene while keeping background

```dart
controller.clearScene();
```
