# iwb_canvas_engine API Guide

This guide documents the supported public package surface on the checked-in
main branch. It intentionally describes the API exported from
`package:iwb_canvas_engine/iwb_canvas_engine.dart` and does not treat
`src/**` imports as supported integration surface.

## 1. Support policy

Use this import:

```dart
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
```

Support rules:

- The supported external contract is the symbol set exported from
  `lib/iwb_canvas_engine.dart`.
- Do not import from `package:iwb_canvas_engine/src/**`.
- The package is Flutter-first, not pure Dart. Public types rely on Flutter and
  `dart:ui` primitives, and `SceneRenderState` is `Listenable`.
- The current mainline JSON contract writes `schemaVersion = 7` and reads
  `schemaVersionsRead = {7}`.

Package scope:

- Owned by the package: scene documents, runtime controller behavior,
  rendering, interactive pointer handling, and JSON import/export.
- Not owned by the package: app UI, persistence, sync/collaboration, and
  app-level undo/redo storage.

## 2. Public API map

### Document model

- `SceneSnapshot`
- Scene snapshot value types:
  - `CameraSnapshot`
  - `BackgroundSnapshot`
  - `GridSnapshot`
  - `ScenePaletteSnapshot`
- Layer snapshots:
  - `BackgroundLayerSnapshot`
  - `ContentLayerSnapshot`
- `NodeSnapshot` and concrete variants:
  - `ImageNodeSnapshot`
  - `TextNodeSnapshot`
  - `StrokeNodeSnapshot`
  - `LineNodeSnapshot`
  - `RectNodeSnapshot`
  - `PathNodeSnapshot`
- `PathFillRule`
- `NodeId`, `LayerId`, `parseNodeId`, `parseLayerId`

### Write model

- `NodeSpec` and concrete variants:
  - `ImageNodeSpec`
  - `TextNodeSpec`
  - `StrokeNodeSpec`
  - `LineNodeSpec`
  - `RectNodeSpec`
  - `PathNodeSpec`
- `NodePatch` and concrete variants:
  - `CommonNodePatch`
  - `ImageNodePatch`
  - `TextNodePatch`
  - `StrokeNodePatch`
  - `LineNodePatch`
  - `RectNodePatch`
  - `PathNodePatch`
- `PatchField<T>` and `PatchFieldState`
- `SceneWriteTxn`
- `ClearSceneResult`

### Runtime and view

- `SceneController`
- `SceneControllerInteraction`
- `SceneControllerSelection`
- `SceneControllerScene`
- `SceneView` / `SceneViewInteractive`
- `SceneRenderState`

### Input and events

- `CanvasMode`
- `DrawTool`
- `CanvasPointerInput`
- `CanvasPointerPhase`
- `PointerInputSettings`
- `MoveCommitDeltaResolver`
- `ActionCommitted`
- `ActionCommittedDelta`
- `ActionType`
- `EditTextRequested`

### Serialization, transforms, and boundary validation

- `SceneBuilder`
- `Transform2D`
- Validated value types:
  - `NodeIdValue`
  - `LayerIdValue`
  - `ImageIdValue`
  - `InstanceRevisionValue`
  - `FiniteOffsetValue`
  - `PositiveFiniteDoubleValue`
  - `NonNegativeFiniteDoubleValue`
  - `OpacityValue`
  - `SvgPathDataValue`
  - `TextContentValue`
  - `FontFamilyValue`
- `encodeScene(...)`
- `encodeSceneToJson(...)`
- `decodeScene(...)`
- `decodeSceneFromJson(...)`
- `schemaVersionWrite`
- `schemaVersionsRead`
- `SceneDataException`
- `SceneDataErrorCode`

## 3. Scene document model

### 3.1 Root snapshot

`SceneSnapshot` is the immutable public document boundary. It contains:

- `layers`: ordered content layers
- `backgroundLayer`: a dedicated boundary layer for background content
- `camera`: camera state
- `background`: background color and grid settings
- `palette`: palette presets for pens, backgrounds, and grid sizes

Important boundary rules:

- `backgroundLayer` is a separate public layer family. Content-layer APIs such
  as `layerId` apply only to `layers`.
- `SceneSnapshot`, `ContentLayerSnapshot`, `BackgroundLayerSnapshot`,
  `ScenePaletteSnapshot`, and stroke point lists defensively copy inputs and
  expose unmodifiable collections.
- Public snapshot construction validates eagerly. Invalid ids, invalid numeric
  values, duplicate content-layer ids, duplicate node ids, and scene-wide
  structural overflow fail at the public boundary.

### 3.2 Snapshot families

| Family | Snapshot | Spec | Patch | Node-specific fields |
| --- | --- | --- | --- | --- |
| Image | `ImageNodeSnapshot` | `ImageNodeSpec` | `ImageNodePatch` | `imageId`, `size`, `naturalSize` |
| Text | `TextNodeSnapshot` | `TextNodeSpec` | `TextNodePatch` | `text`, `fontSize`, `color`, `align`, `textDirection`, `isBold`, `isItalic`, `isUnderline`, `fontFamily`, `maxWidth`, `lineHeight` |
| Stroke | `StrokeNodeSnapshot` | `StrokeNodeSpec` | `StrokeNodePatch` | `points`, `thickness`, `color` |
| Line | `LineNodeSnapshot` | `LineNodeSpec` | `LineNodePatch` | `start`, `end`, `thickness`, `color` |
| Rect | `RectNodeSnapshot` | `RectNodeSpec` | `RectNodePatch` | `size`, `fillColor`, `strokeColor`, `strokeWidth` |
| Path | `PathNodeSnapshot` | `PathNodeSpec` | `PathNodePatch` | `svgPathData`, `fillColor`, `strokeColor`, `strokeWidth`, `fillRule` |

Shared node fields across specs/snapshots/patches:

- `id` (`NodeSpec.id` is optional; snapshot/patch ids are required)
- `transform`
- `opacity`
- `hitPadding`
- `isVisible`
- `isSelectable`
- `isLocked`
- `isDeletable`
- `isTransformable`
- `instanceRevision` on snapshots only

### 3.3 Text contract

Text nodes have a few important boundary rules:

- `TextNodeSpec` and `TextNodeSnapshot` require explicit `textDirection`.
- Text bounds are derived from layout inputs; they are not writable boundary
  state.
- Current mainline JSON payloads must not contain legacy stored text `size`
  metadata.
- Import/decode rejects text whose derived bounds exceed scene limits.

### 3.4 Paths and transforms

- `PathFillRule` is the public fill-rule contract for path nodes.
- `Transform2D` is a public 2D affine transform type.
- `Transform2D` supports `translation(...)`, `scale(...)`, `rotationDeg(...)`,
  `trs(...)`, `multiply(...)`, `invert()`, `applyToPoint(...)`, and
  `applyToRect(...)`.
- `Transform2D.toJsonMap()` / `Transform2D.fromJsonMap(...)` are the shared map
  format used by JSON serialization and action payload helpers.

## 4. Creating and updating scene data

### 4.1 Use `NodeSpec` for creation

Use a `NodeSpec` subtype when adding a new node through `SceneControllerScene`
or `SceneWriteTxn`.

Rules that matter in integrations:

- `NodeSpec.id` is optional. If omitted, the engine allocates an id.
- If `NodeSpec.id` is explicitly provided and already exists, insertion throws
  `ArgumentError`.
- Constructor validation is eager, so invalid transforms, numeric values, ids,
  path payloads, or text settings fail before runtime mutation begins.

### 4.2 Use `NodePatch` for partial updates

Use a `NodePatch` subtype to partially update an existing node.

`PatchField<T>` is a tri-state wrapper:

- `PatchField.absent()` — do not change the field
- `PatchField.value(...)` — set the field to a concrete value
- `PatchField.nullValue()` — explicitly set the field to `null`

`CommonNodePatch` covers the shared node fields; subtype-specific patch classes
cover only node-family fields.

Important patch rules:

- Public patch constructors validate only fields that are actually present.
- `writeNodePatch(...)` / `patchNode(...)` return `false` when the node does
  not exist or when the patch is a semantic no-op.
- Patching a node with the wrong patch family throws `ArgumentError`.

### 4.3 Use validated value objects for external inputs

The validated value types (`NodeIdValue`, `LayerIdValue`, `OpacityValue`,
`TextContentValue`, and others) are useful when values enter your app as text,
JSON fragments, or other untrusted inputs.

They let you apply the same boundary rules before constructing snapshots,
specs, or patches.

## 5. Runtime integration

### 5.1 `SceneController`

`SceneController` is the concrete public runtime owner.

Constructor parameters:

- `initialSnapshot`
- `pointerSettings`
- `dragStartSlop`
- `clearSelectionOnDrawModeEnter`
- `moveCommitDeltaResolver`
- `textFontFamilyByDefault`

Primary read-only state and integration hooks:

- `snapshot`
- `selectedNodeIds`
- `controllerEpoch`
- `selectionRect`
- `cameraOffset`
- `previewDeltaResolver`
- `hasActiveStrokePreview`, `activeStrokePreviewPoints`,
  `activeStrokePreviewThickness`, `activeStrokePreviewColor`,
  `activeStrokePreviewOpacity`
- `hasActiveLinePreview`, `activeLinePreviewStart`, `activeLinePreviewEnd`,
  `activeLinePreviewThickness`, `activeLinePreviewColor`
- `actions`
- `editTextRequests`
- `interaction`, `selection`, and `scene`

Lifecycle rule:

- Call `dispose()` when the controller is no longer used.
- Public controller operations on a disposed controller throw `StateError`.

### 5.2 `controller.scene`

`controller.scene` owns document and environment mutations.

| Method | Meaning |
| --- | --- |
| `write(...)` | Open a synchronous transactional write callback with `SceneWriteTxn`. |
| `setBackgroundColor(...)` | Replace the background color. |
| `setGridEnabled(...)` | Enable or disable the background grid. |
| `setGridCellSize(...)` | Replace the grid cell size. Invalid values throw immediately. |
| `setCameraOffset(...)` | Replace the camera offset. |
| `addNode(...)` | Insert a node from a `NodeSpec`. |
| `ensureLayer(...)` | Create a content layer if it does not already exist. |
| `patchNode(...)` | Apply a `NodePatch` to an existing node. |
| `removeNode(...)` | Remove a single node by id. |
| `clearScene(...)` | Clear content layers while keeping the dedicated background layer concept. |
| `replaceScene(...)` | Replace the entire document from a `SceneSnapshot`. |
| `notifySceneChanged()` | Trigger a repaint/listener notification when host-owned visual state changed without a scene mutation. |

### 5.3 `controller.selection`

`controller.selection` owns public selection, transform, and delete verbs.

| Method | Meaning |
| --- | --- |
| `setSelection(...)` | Replace selection with normalized visible content ids. |
| `toggleSelection(...)` | Toggle a single visible content node. |
| `clearSelection()` | Clear selection. |
| `selectAll(...)` | Select all visible content nodes, optionally only selectable ones. |
| `rotateSelection(...)` | Rotate the current selection. |
| `flipSelectionVertical(...)` | Flip the current selection vertically. |
| `flipSelectionHorizontal(...)` | Flip the current selection horizontally. |
| `deleteSelection(...)` | Delete deletable nodes in the current selection. |

### 5.4 `controller.interaction`

`controller.interaction` owns interaction mode, draw configuration, pending
line state, preview state, and optional manual pointer input.

Current configuration and state:

- `mode`, `drawTool`, `drawColor`
- `penThickness`, `highlighterThickness`, `lineThickness`, `eraserThickness`
- `highlighterOpacity`
- `dragStartSlop`
- `pointerSettings`
- `selectionRect`
- `pendingLineStart`, `pendingLineTimestampMs`, `hasPendingLineStart`
- `pendingLineColor`, `pendingLineThickness`
- `hasActiveStrokePreview`, `activeStrokePreviewPoints`,
  `activeStrokePreviewThickness`, `activeStrokePreviewColor`,
  `activeStrokePreviewOpacity`
- `hasActiveLinePreview`, `activeLinePreviewStart`, `activeLinePreviewEnd`,
  `activeLinePreviewThickness`, `activeLinePreviewColor`

Public interaction methods:

- `handlePointer(...)`
- `handleDoubleTap(...)`
- `setMode(...)`
- `setDrawTool(...)`
- `setDrawColor(...)`
- thickness setters for pen/highlighter/line/eraser
- `highlighterOpacity = ...`
- `setPointerSettings(...)`
- `setDragStartSlop(...)`

Important notes:

- Most integrations should let `SceneView` own pointer routing.
  `handlePointer(...)` and `handleDoubleTap(...)` are for custom hosts.
- Two-tap line flows expose `pendingLineColor` and `pendingLineThickness` so
  host UI can mirror the pending commit style.
- Public scene and selection mutations are gesture-exclusive. During an active
  draw or move gesture, scene/selection mutation APIs may throw `StateError`.
- `PointerInputSettings` is treated as a value object and can be replaced live.

### 5.5 Events and async delivery

`SceneController` integrates with host apps through both `ChangeNotifier` and
streams:

- `actions` emits `ActionCommitted` values for committed runtime actions.
- `editTextRequests` emits `EditTextRequested` when the engine wants app-owned
  text editing UI.
- `SceneController`, `actions`, and `editTextRequests` are asynchronous from an
  integration point of view; notifications are deferred/coalesced rather than
  emitted inline from every mutation call.

`ActionCommittedDelta` adds convenience readers for common action payloads such
as transform deltas, layer move indices, draw style, and eraser thickness.

## 6. `SceneView`

`SceneView` is the preferred public widget export. It is a typedef to
`SceneViewInteractive`.

Constructor parameters:

- `controller` (required)
- `imageResolver`
- `selectionColor`
- `selectionStrokeWidth`
- `gridStrokeWidth`

Responsibilities:

- render the current scene
- own the Flutter pointer-routing path for normal interactive use
- render selection and preview overlays
- resolve image nodes through `imageResolver`, which has type
  `ui.Image? Function(String imageId)?`

Use `controller.scene.notifySceneChanged()` when image data or other external
visual resources changed but the scene document itself did not.

`SceneRenderState` is the read-only painter contract exposed for view/render
consumers. Most app integrations should use `SceneView` instead of building a
custom host surface.

## 7. Transactions with `SceneWriteTxn`

Use `controller.scene.write((txn) { ... })` when multiple scene/selection
mutations must happen atomically.

Transaction rules:

- The callback is synchronous-only. Returning a `Future` is a contract error.
- A `SceneWriteTxn` handle is valid only inside the active callback.
- Any new `txn.snapshot` or `txn.selectedNodeIds` read after callback close
  throws `StateError`.
- After each successful transaction mutation, `txn.snapshot` and
  `txn.selectedNodeIds` already reflect the finalized state that would commit if
  the callback returned immediately.

Available transaction verbs:

- document and environment:
  - `writeDocumentReplace(...)`
  - `writeCameraOffset(...)`
  - `writeGridEnable(...)`
  - `writeGridCellSize(...)`
  - `writeBackgroundColor(...)`
- nodes and layers:
  - `writeNodeInsert(...)`
  - `writeLayerEnsure(...)`
  - `writeNodeErase(...)`
  - `writeNodePatch(...)`
  - `writeNodeTransformSet(...)`
- selection:
  - `writeSelectionReplace(...)`
  - `writeSelectionToggle(...)`
  - `writeSelectionClear()`
  - `writeSelectionSelectAll(...)`
  - `writeSelectionTranslate(...)`
  - `writeSelectionTransform(...)`
  - `writeDeleteSelection()`
- clear-scene helpers:
  - `writeClearSceneKeepBackgroundResult()`
  - `writeClearSceneKeepBackground()`

Important transaction notes:

- `layerId` addresses content layers only, never `backgroundLayer`.
- `txn.selectedNodeIds` is a detached immutable selection snapshot for that
  read. Values captured while the transaction is active remain usable after the
  callback closes, but the transaction handle itself expires.
- `writeSelectionTransform(...)` uses pre-multiply semantics:
  `nextTransform = delta.multiply(existingTransform)`.
- `ClearSceneResult.removedNodeIds` is an immutable snapshot detached from the
  writer internals.

## 8. Serialization and import

### 8.1 Entry points

Use the public entry points based on your starting data:

- already have a `SceneSnapshot`: `SceneBuilder.buildFromSnapshot(...)`
- already have a parsed JSON-compatible map: `SceneBuilder.buildFromJson(...)`
- need a JSON-compatible map: `encodeScene(...)`
- need a JSON string: `encodeSceneToJson(...)`
- need to decode a parsed JSON-compatible map: `decodeScene(...)`
- need to decode a JSON string: `decodeSceneFromJson(...)`

### 8.2 Current schema contract

- `schemaVersionWrite == 7`
- `schemaVersionsRead == {7}`
- `decodeSceneFromJson(...)` rejects raw JSON strings longer than `33554432`
  characters before calling `jsonDecode`

### 8.3 Validation and canonicalization guarantees

Public import/export paths share the same boundary contract:

- `SceneBuilder.buildFromJson(...)`, `decodeScene(...)`, and
  `decodeSceneFromJson(...)` reject malformed scene data with
  `SceneDataException`.
- `SceneBuilder.buildFromSnapshot(...)`, `encodeScene(...)`, and
  `encodeSceneToJson(...)` validate/canonicalize snapshots before encoding.
- Compare failures by `SceneDataException.code`, `path`, and `details`.
  `message` is derived user-facing text.
- Oversized ids, text payloads, SVG path data, palette lists, stroke point
  lists, layer counts, and scene-wide node counts are rejected at the public
  boundary.
- Public builders and codecs canonicalize scene data to the current document
  model rather than exposing mutable runtime objects.

## 9. Error model

### 9.1 Error types

| Error type | Typical meaning |
| --- | --- |
| `ArgumentError` | The caller passed an invalid runtime argument or tried to construct an invalid public boundary value. |
| `StateError` | The runtime contract was violated, for example by using a disposed controller, reusing a stale transaction handle, or performing forbidden work during an active gesture. |
| `SceneDataException` | Scene data or JSON is malformed at the public boundary. |

### 9.2 `SceneDataException`

`SceneDataException` is the stable scene-data failure contract.

Use these fields for machine handling:

- `code`
- `path`
- `details`

`source` is diagnostic support only. It may contain a sanitized preview rather
than the original raw object.

### 9.3 `SceneDataErrorCode`

| Code | Meaning |
| --- | --- |
| `invalidJson` | JSON text is invalid or the root shape is not supported. |
| `unsupportedSchemaVersion` | The payload schema version is not accepted by this mainline. |
| `missingField` | A required field is absent. |
| `invalidFieldType` | A field exists but has the wrong type. |
| `invalidValue` | A field value violates semantic validation. |
| `duplicateNodeId` | Duplicate node ids were found in the scene. |
| `duplicateLayerId` | Duplicate content-layer ids were found in the scene. |
| `outOfRange` | A numeric or indexed value is outside the accepted range. |

## 10. Migration notes for older integrations

When aligning older code to the current mainline contract:

1. Use only `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
2. Treat the public document model as `backgroundLayer` plus content-only
   `layers`.
3. Use `NodeSpec` and `NodePatch`; do not depend on mutable internal scene
   classes from `src/**`.
4. Treat JSON as schema version `7` only on current mainline.
5. Treat text bounds as derived layout output, not writable document state.
6. Provide explicit `textDirection` for text nodes.
7. Obtain `SceneControllerInteraction`, `SceneControllerSelection`, and
   `SceneControllerScene` from `SceneController` instead of constructing them
   directly.
8. Treat `actions`, `editTextRequests`, and controller notifications as
   asynchronous integration signals.

## 11. Minimal integration example

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
  StreamSubscription<EditTextRequested>? editSub;

  @override
  void initState() {
    super.initState();

    controller = SceneController(
      initialSnapshot: SceneSnapshot(
        layers: [ContentLayerSnapshot(id: 'layer-0')],
      ),
    );

    controller.scene.addNode(
      TextNodeSpec(
        id: 'title',
        text: 'Hello',
        color: const Color(0xFF111111),
        textDirection: TextDirection.ltr,
      ),
    );

    editSub = controller.editTextRequests.listen((request) {
      // Open app-owned text editing UI for request.nodeId.
    });
  }

  @override
  void dispose() {
    editSub?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SceneView(controller: controller);
  }
}
```
