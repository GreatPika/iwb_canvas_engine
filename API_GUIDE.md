# iwb_canvas_engine API Guide

This guide is a complete, implementation-aligned reference for integrating `iwb_canvas_engine` on the current mainline in Flutter apps.
It is designed for both human developers and coding agents.

## 1. Package purpose and boundaries

`iwb_canvas_engine` provides:

- Scene model (`SceneSnapshot`, layers, nodes)
- Interactive runtime (`SceneController`, `SceneView`)
- Input handling (move/select/draw tools)
- JSON import/export (`schemaVersion = 4`)

`iwb_canvas_engine` does not provide:

- Application UI shell (toolbars, side panels, dialogs)
- Undo/redo history storage
- Network/storage backends

## 2. Entrypoints and aliases

Recommended import:

```dart
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
```

Runtime aliases exposed publicly:

- `SceneController` is a typedef alias of `SceneControllerInteractiveV2`
- `SceneView` is a typedef alias of `SceneViewInteractiveV2`

## 3. Public API map

`iwb_canvas_engine.dart` exports:

- Public immutable model contracts:
  - `SceneSnapshot`, `BackgroundLayerSnapshot`, `ContentLayerSnapshot`, `NodeSnapshot` variants
  - `NodeSpec` variants
  - `NodePatch` variants
  - `PatchField<T>` and `PatchFieldState`
- Runtime:
  - `SceneController`, `SceneView`
  - `SceneWriteTxn`, `SceneRenderState`
- Input/event contracts:
  - `CanvasMode`, `DrawTool`
  - `PointerInputSettings`, `CanvasPointerInput`, `CanvasPointerPhase`
  - `ActionCommitted`, `ActionType`, `EditTextRequested`
- Serialization:
  - `encodeSceneToJson`, `decodeSceneFromJson`
  - `encodeScene`, `decodeScene`
  - `schemaVersionWrite`, `schemaVersionsRead`
  - `SceneDataException`
## 4. Scene data model

### 4.1 Root snapshot

`SceneSnapshot` contains:

- `backgroundLayer: BackgroundLayerSnapshot?`
- `layers: List<ContentLayerSnapshot>`
- `camera: CameraSnapshot` (`offset`)
- `background: BackgroundSnapshot` (`color`, `grid`)
- `palette: ScenePaletteSnapshot` (`penColors`, `backgroundColors`, `gridSizes`)

### 4.2 Layer

`BackgroundLayerSnapshot` contains:

- `nodes: List<NodeSnapshot>`

`ContentLayerSnapshot` contains:

- `nodes: List<NodeSnapshot>`

Typed layer boundary:

- `backgroundLayer` is a dedicated typed layer (rendered below content).
- `layers` is an ordered list of content layers only.
- import/encode boundaries canonicalize missing `backgroundLayer` to an empty
  dedicated background layer.

### 4.3 Node snapshots

`NodeSnapshot` base fields:

- `id`
- `instanceRevision`
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

`StrokeNodeSnapshot` runtime fields:

- `pointsRevision` is a non-negative monotonic geometry revision used by
  render caches for O(1) stroke-path freshness checks.
- `pointsRevision` is runtime metadata and is not serialized into JSON.
- `instanceRevision` is an immutable per-node-instance identity revision.
  Runtime import allocates it when input value is `<= 0`, JSON encoder writes
  it for every node, and render caches use `(id, instanceRevision)` isolation
  to avoid stale hits after id reuse.

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

Validation notes:

- `addNode(...)` validates incoming `NodeSpec` values strictly and throws `ArgumentError` for malformed numeric/geometry input (including non-finite `transform`, negative `hitPadding`, invalid geometry fields, invalid `svgPathData`, and `opacity` outside `[0,1]`).
- `TextNodeSpec` no longer accepts `size`; text node size is derived from text layout (`text/fontSize/fontFamily/style/lineHeight/maxWidth`) inside the engine.

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

Validation notes:

- `patchNode(...)` validates only fields present in `NodePatch`/`CommonNodePatch` and throws `ArgumentError` for malformed values.
- `PatchField.nullValue()` is rejected for non-nullable fields with `ArgumentError`.
- `CommonNodePatch.opacity` is strict at write boundary (`[0,1]`).
- `TextNodePatch` no longer accepts `size`; text size is re-derived automatically when layout-affecting fields change (`text`, `fontSize`, `isBold`, `isItalic`, `isUnderline`, `fontFamily`, `lineHeight`, `maxWidth`).

### 5.3 Tri-state patch semantics (`PatchField<T>`)

- `PatchField.absent()` -> leave field unchanged
- `PatchField.value(x)` -> set field to `x`
- `PatchField.nullValue()` -> explicitly set nullable field to `null`

Use `nullValue()` only for nullable fields.

## 6. Runtime controller (`SceneController`)

### 6.1 Construction

```dart
final controller = SceneController(
  // Optional immutable startup scene.
  initialSnapshot: SceneSnapshot(
    backgroundLayer: BackgroundLayerSnapshot(),
    layers: [
      ContentLayerSnapshot(),
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

Construction validation notes:

- `initialSnapshot` is validated strictly.
- Malformed snapshot input throws `SceneDataException` (duplicate ids, invalid numeric fields, invalid `svgPathData`, invalid palette, invalid typed layer fields).
- Runtime snapshot boundary canonicalizes missing `backgroundLayer` to an empty dedicated layer.

### 6.2 Read-only state

- `snapshot: SceneSnapshot`
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
- `replaceScene` validates snapshot input strictly and throws `SceneDataException` on malformed snapshots.

Notification semantics:

- Scene repaint notifications are deferred to a microtask after commit/repaint request.
- Multiple writes/repaint requests in the same event-loop tick are coalesced into one listener notification.
- `requestRepaint()` called inside `write(...)` is buffered and published only after a successful transaction commit.
- If `write(...)` rolls back with an exception, buffered repaint/signal effects are discarded.

### 6.5 Node and selection methods

- `String addNode(NodeSpec node, {int? layerIndex})`
- `bool patchNode(NodePatch patch)`
- `bool removeNode(NodeId id, {int? timestampMs})`
- `setSelection(Iterable<NodeId> nodeIds)`
- `toggleSelection(NodeId nodeId)`
- `clearSelection()`
- `selectAll({bool onlySelectable = true})`

`layerIndex` contract:

- `addNode(..., layerIndex)` addresses `SceneSnapshot.layers` only (content layers).

### 6.6 Transform/delete/clear commands

- `rotateSelection({required bool clockwise, int? timestampMs})`
- `flipSelectionVertical({int? timestampMs})`
- `flipSelectionHorizontal({int? timestampMs})`
- `deleteSelection({int? timestampMs})`
- `clearScene({int? timestampMs})`

Behavior notes:

- Transform operations affect transformable, unlocked selected nodes.
- Transform/translate write operations reject non-finite deltas (`Transform2D`/`Offset`) with `ArgumentError`.
- Background/non-deletable policy is respected by delete flows.
- `selectAll(onlySelectable: true)` selects visible selectable foreground nodes.
- `selectAll(onlySelectable: false)` also includes visible non-selectable foreground nodes.
- Commit-time selection normalization removes only missing/background/invisible ids and preserves explicitly selected non-selectable nodes.
- `clearScene` keeps/creates dedicated `backgroundLayer` and clears all content layers.

### 6.7 Low-level input hooks

- `handlePointer(CanvasPointerInput input)`
- `handleDoubleTap({required Offset position, int? timestampMs})`

Usually these are called by `SceneView` automatically.
Direct usage is useful when embedding the controller in custom input pipelines.

Internal low-level types (`PointerSample`, `PointerSignal`) are not part of the
public API surface.

### 6.8 Direct transactional writes

- `write<T>(T Function(SceneWriteTxn txn) fn)`

`SceneWriteTxn` is a safe contract:

- Includes state snapshots (`snapshot`, `selectedNodeIds`) and explicit write operations.
- Does not expose mutable `Scene`/`SceneNode`.
- Does not include `writeFindNode` or `writeMark*` escape methods.
- Does not expose node-id bookkeeping internals; ids are allocated via structural writes (`writeNodeInsert`).

Prefer high-level command methods unless custom transactional logic is required.

Write-notify semantics:

- `write(...)` finalizes transaction state first, then schedules listener notification in a microtask when repaint is needed.
- Committed `signals` are emitted before repaint listener notification for the same successful commit.
- Calling `write(...)` from `addListener(...)` is allowed; it runs after the original transaction is finished.

## 7. Interaction model details

### 7.1 Modes

- `CanvasMode.move`: selection, drag move, marquee
- `CanvasMode.draw`: pen/highlighter/line/eraser

### 7.2 Draw tool behavior

- Pen/highlighter: freehand stroke commit on pointer up
- Pen/highlighter guardrail: if captured stroke points exceed `20_000`, commit applies deterministic index-uniform downsampling while preserving first/last points.
- Line: drag line or two-tap line (first tap sets pending start, second tap commits)
- Eraser: erases supported annotations (`StrokeNode`, `LineNode`) based on eraser trajectory

### 7.3 Move drag behavior

- During move drag, selected nodes are translated in preview only (render/hit-test use effective preview bounds).
- The scene snapshot is committed once on pointer up with the accumulated drag delta.
- Pointer cancel clears preview and does not mutate scene geometry.

### 7.4 Double tap behavior

On double tap in move mode, if top hit node is a text node, controller emits `EditTextRequested`.

## 8. Events and payload contracts

### 8.1 `actions` stream

`actions` emits `ActionCommitted` with:

- `actionId` (`a0`, `a1`, ...)
- `type: ActionType`
- `nodeIds`
- `timestampMs`
- optional `payload`

Delivery and mutability contract:

- Delivery is asynchronous; subscribers are called after the emitting controller method returns.
- Relative ordering against `ChangeNotifier` listener notifications/repaint is not a public contract.
- `nodeIds` and `payload` are immutable snapshots; subscribers cannot mutate shared event data.

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

Delivery contract:

- Delivery is asynchronous; subscribers are called after the emitting controller method returns.
- Relative ordering against `ChangeNotifier` listener notifications/repaint is not a public contract.

## 9. View widget (`SceneView`)

### 9.1 Constructor

```dart
SceneView(
  controller: controller,
  imageResolver: (imageId) => null,
  selectionColor: const Color(0xFF1565C0),
  selectionStrokeWidth: 1,
  gridStrokeWidth: 1,
)
```

### 9.2 What `SceneView` does

- Captures pointer events via `Listener`
- Routes Flutter pointer input into controller interaction flow
- Paints scene via `ScenePainterV2`
- Paints interactive overlays (in-progress stroke/line previews)
- Owns render caches by default and clears them on controller epoch/document boundaries.

### 9.3 Image resolver

- `imageResolver` is optional and accepts `ui.Image? Function(String imageId)`.
- If not provided, image nodes are rendered as placeholders.
- Image lifecycle ownership stays on app side (dispose app-owned images when no longer used).

## 10. Pointer contracts

### 10.1 `CanvasPointerInput`

Fields:

- `pointerId`
- `position` (view coordinates)
- `timestampMs` (optional timestamp hint)
- `phase` (`CanvasPointerPhase.down/move/up/cancel`)
- `kind`

Controller normalizes timestamps to a monotonic internal timeline.

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

- `schemaVersionWrite == 4`
- `schemaVersionsRead == {4}`

### 11.3 Errors

Invalid input throws `SceneDataException` with validation details.

Encoding notes:

- `encodeScene(...)` validates `SceneSnapshot` input before encoding and throws `SceneDataException` on malformed snapshots.

## 12. Full integration example

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

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
        backgroundLayer: BackgroundLayerSnapshot(),
        layers: [
          ContentLayerSnapshot(),
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
      ),
    );
  }
}
```

## 13. Agent checklist for safe edits

When an agent modifies integration code:

1. Use `NodeSpec`/`NodePatch` in app code; avoid mutating internal scene structures directly.
2. Keep app-owned undo/redo separate from engine internals.
3. Handle `SceneDataException` around imports.
4. Keep `ActionCommitted.payload` parsing defensive via helper extensions.
5. Respect background layer semantics and non-deletable/non-selectable flags.
6. Prefer `SceneController`/`SceneView` aliases in app-facing docs/examples.

## 14. Migration notes

### 14.1 From 1.x to 2.x

Required updates:

1. Remove `advanced.dart` imports and use `iwb_canvas_engine.dart` only.
2. Replace legacy constructor usage:
   - Remove `scene: ...` from `SceneController(...)`.
   - Use `initialSnapshot: SceneSnapshot(...)` instead.
3. Replace `addNode(Object ...)` calls with explicit `NodeSpec` variants.
4. Replace low-level write callbacks:
   - from `write((SceneWriter w) { ... })`
   - to `write((SceneWriteTxn txn) { ... })`
5. Remove any dependency on legacy mutable getters (`controller.scene`, `controller.core`).

### 14.2 From 2.x to 3.0.0

Required updates:

1. Remove `TextNodeSpec.size` and `TextNodePatch.size` usage; text bounds are runtime-derived from layout fields.
2. Ensure `initialSnapshot`/`replaceScene(...)` inputs are strictly valid; malformed snapshots now throw `SceneDataException`.
3. Ensure `addNode(...)` and `patchNode(...)` inputs are valid at write boundary; malformed values now throw `ArgumentError`.
4. If app logic depended on synchronous `actions`/`editTextRequests` delivery, update it for asynchronous stream delivery.
5. Replace layer model usage:
   - remove `LayerSnapshot(isBackground: ...)`,
   - use `backgroundLayer: BackgroundLayerSnapshot?` + `layers: List<ContentLayerSnapshot>`.
6. JSON codec now writes/reads only schema `4`; schema `3` and legacy schema `2` are unsupported.

## 15. Quick recipes

### 15.1 Export/import JSON

```dart
final json = encodeSceneToJson(controller.snapshot);
final restored = decodeSceneFromJson(json);
controller.replaceScene(restored);
```

### 15.2 Rotate selected nodes clockwise

```dart
controller.rotateSelection(clockwise: true);
```

### 15.3 Toggle draw mode and set pen style

```dart
controller.setMode(CanvasMode.draw);
controller.setDrawTool(DrawTool.pen);
controller.setDrawColor(const Color(0xFF0D47A1));
controller.penThickness = 4;
```

### 15.4 Clear scene while keeping background

```dart
controller.clearScene();
```
