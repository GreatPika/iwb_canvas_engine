# iwb_canvas_engine API Guide

This document is the canonical integration reference for the current mainline.
It describes the supported public API, the runtime contracts that matter in
production, and the migration expectations for the `5.x` line.

## 1. Package boundary

`iwb_canvas_engine` provides:

- an immutable scene model
- a Flutter runtime controller and view
- interactive input handling for move/select/draw flows
- JSON import/export for scene snapshots
- contract-facing value types built on Flutter primitives (`dart:ui`)

`iwb_canvas_engine` does not provide:

- product UI such as toolbars, dialogs, or side panels
- app-level undo/redo storage
- persistence, sync, or backend collaboration

Current public contract:

- package version: `5.1.0`
- single supported import:

```dart
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
```

- the supported public surface is exactly the export surface of
  `lib/iwb_canvas_engine.dart`
- `validated.dart` is part of that supported public surface through the package
  barrel export

- current JSON write version: `schemaVersion = 5`
- current JSON read set: `{5}`

Do not import from `package:iwb_canvas_engine/src/**`.
Imports under `src/**` are internal implementation details and are not a
supported integration contract, even if package tests use them for white-box
coverage.

The package is not designed as a pure Dart engine. Public contract types rely
on Flutter-oriented primitives (`dart:ui`), and `SceneRenderState` uses
`Listenable` from `package:flutter/foundation.dart`.

## 2. Public surface at a glance

`iwb_canvas_engine.dart` exports:

- scene model:
  - `SceneSnapshot`
  - `BackgroundLayerSnapshot`
  - `ContentLayerSnapshot`
  - `NodeSnapshot` variants
  - `PathFillRule`
- write contracts:
  - `NodeSpec` variants
  - `NodePatch` variants
  - `PatchField<T>`
  - `PatchFieldState`
  - `SceneWriteTxn`
  - `ClearSceneResult`
- runtime:
  - `SceneController`
  - `SceneControllerInteractive`
  - `SceneView`
  - `SceneViewInteractive`
  - `SceneRenderState`
- input and interaction:
  - `CanvasMode`
  - `DrawTool`
  - `CanvasPointerInput`
  - `CanvasPointerPhase`
  - `PointerInputSettings`
  - `MoveCommitDeltaResolver`
- events:
  - `ActionCommitted`
  - `ActionCommittedDelta`
  - `ActionType`
  - `EditTextRequested`
- utilities:
  - `Transform2D`
  - `SceneBuilder`
  - validated boundary values:
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
- serialization:
  - `encodeScene`
  - `encodeSceneToJson`
  - `decodeScene`
  - `decodeSceneFromJson`
  - `schemaVersionWrite`
  - `schemaVersionsRead`
  - `SceneDataException`

Public aliases:

- `SceneController` is a typedef alias of `SceneControllerInteractive`
- `SceneView` is a typedef alias of `SceneViewInteractive`

## 3. Scene model

### 3.1 Root snapshot

`SceneSnapshot` is the immutable document boundary returned by the runtime and
serialization APIs.

Fields:

- `backgroundLayer: BackgroundLayerSnapshot`
- `layers: List<ContentLayerSnapshot>`
- `camera: CameraSnapshot`
- `background: BackgroundSnapshot`
- `palette: ScenePaletteSnapshot`

Constructor defaults:

- omitting `backgroundLayer` creates an empty dedicated background layer
- omitting `layers` creates no content layers
- camera, background, and palette default to safe built-in values
- public snapshot/layer/node constructors validate boundary ids and numeric
  fields eagerly and therefore are runtime constructors rather than `const`
  entry points

### 3.2 Layer model

Layer semantics are explicit:

- `backgroundLayer` is always a dedicated layer rendered below content
- `layers` contains content layers only
- each content layer has a stable `LayerId`
- z-order is defined only by list order in `layers`
- `LayerId` is identity, not ordering

Write APIs target content layers only. The background layer is never addressed
through `LayerId`.

### 3.3 Node snapshots

Base `NodeSnapshot` fields:

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

Public variants:

- `ImageNodeSnapshot`
- `TextNodeSnapshot`
- `StrokeNodeSnapshot`
- `LineNodeSnapshot`
- `RectNodeSnapshot`
- `PathNodeSnapshot`

Important runtime details:

- `StrokeNodeSnapshot.pointsRevision` is runtime metadata used by render caches
- `pointsRevision` is not serialized into JSON
- `instanceRevision` is part of runtime node identity and is serialized
- `PathNodeSnapshot` uses `PathFillRule`

### 3.4 Text sizing contract

`TextNode.size` and `TextNodeSnapshot.size` are derived metadata.

- `TextNodeSpec` does not expose writable `size`
- `TextNodePatch` does not expose writable `size`
- import/decode and layout-affecting text patches re-derive the box size inside
  the engine
- incoming `TextNodeSnapshot.size` is treated as non-authoritative and may be
  ignored during canonicalization/import

If you compare serialized text sizes across platforms, use semantic assertions
or numeric tolerance. Font metrics can differ slightly by platform and font
engine.

## 4. Creating and updating nodes

### 4.1 `NodeSpec`

Use `NodeSpec` variants for creation:

- `ImageNodeSpec`
- `TextNodeSpec`
- `StrokeNodeSpec`
- `LineNodeSpec`
- `RectNodeSpec`
- `PathNodeSpec`

Shared base fields:

- optional `id`
- `transform`
- `opacity`
- `hitPadding`
- visibility / selection / lock policy flags

Key rules:

- `SceneController.addNode(...)` accepts only `NodeSpec`
- public `NodeSpec` constructors validate boundary values eagerly and are
  runtime constructors rather than `const` entry points
- `NodeSpec.id` is optional; the controller can generate ids
- explicit ids remain `String`-compatible at the public API boundary, but the
  supported parsing/generation policy is now exposed through `NodeIdValue`,
  `LayerIdValue`, `parseNodeId(...)`, `parseLayerId(...)`,
  `generateNodeId(...)`, `generateLayerId(...)`,
  `tryParseGeneratedNodeIdSeed(...)`, and `tryParseGeneratedLayerIdSeed(...)`
- generated-id recognition is canonical-only: helper parsing accepts
  `node-<n>` / `layer-<n>` without leading-zero variants
- malformed values fail fast with `ArgumentError`

### 4.2 `NodePatch`

Use `NodePatch` variants for partial updates:

- `ImageNodePatch`
- `TextNodePatch`
- `StrokeNodePatch`
- `LineNodePatch`
- `RectNodePatch`
- `PathNodePatch`

Patch semantics use `PatchField<T>`:

- `PatchField.absent()` leaves a field unchanged
- `PatchField.value(x)` writes a value
- `PatchField.nullValue()` explicitly clears a nullable field

`PatchField.nullValue()` is invalid for non-nullable fields and throws
`ArgumentError`.

Public `NodePatch` and `CommonNodePatch` constructors validate only present
fields eagerly and are runtime constructors rather than `const` entry points.
Collection payloads such as stroke points are captured as immutable snapshots
at the boundary.

### 4.3 Write-boundary validation

Public write-boundary values validate eagerly at construction time:

- invalid `NodeSpec`, `NodePatch`, or `CommonNodePatch` values throw
  `ArgumentError` at the public boundary
- `PatchField.absent()` is not validated just for symmetry; only present patch
  fields are checked at the public boundary
- duplicate explicit `NodeSpec.id` in `addNode(...)` / `writeNodeInsert(...)`
  throws `ArgumentError`
- runtime write/model paths consume already validated boundary objects and own
  only runtime/stateful semantics such as target existence, patch target
  id/type compatibility, range/index checks, canonicalization, and derived
  recomputation
- validated boundary value types expose the supported parse rules without
  changing the wire/runtime representation used by `SceneSnapshot`, `NodeSpec`,
  `NodePatch`, `NodeId`, or `LayerId`
- supported validated-value factory surface is `parse(...)`, `of(...)`, and
  `fromJson(...)`; no validation-bypass fast path is part of the public
  contract
- `NodeIdValue` / `LayerIdValue` reject blank ids, enforce max lengths, and
  keep the legacy generated-id policy (`node-<n>`, `layer-<n>`) explicit with
  canonical-only recognition
- `ImageIdValue` enforces the public max length for image ids while preserving
  the current empty-string runtime contract
- `InstanceRevisionValue` keeps the zero-allowed snapshot policy separate from
  the positive-only internal-scene policy
- `TextContentValue` enforces text length while still allowing empty text
- `FontFamilyValue` rejects blank values and enforces the public max length
- `SvgPathDataValue` enforces non-empty bounded path payloads and SVG parsing
- non-finite `Transform2D` and `Offset` values are rejected by transform and
  translate write paths
- non-finite camera offsets and non-positive/non-finite grid cell sizes are
  rejected by their runtime write paths
- `opacity` is strict at the public boundary and must stay in `[0, 1]`
- in-memory write/import validation now mirrors the same id/text/font-family,
  revision, opacity, and finite-offset rules used by the JSON boundary

## 5. Runtime controller

`SceneController` is the primary runtime entrypoint.

### 5.1 Construction

```dart
final controller = SceneController(
  initialSnapshot: SceneSnapshot(
    layers: [ContentLayerSnapshot(id: 'layer-0')],
  ),
  pointerSettings: const PointerInputSettings(
    tapSlop: 16,
    doubleTapSlop: 32,
    doubleTapMaxDelayMs: 450,
  ),
  dragStartSlop: 12,
  clearSelectionOnDrawModeEnter: true,
  moveCommitDeltaResolver: null,
  textFontFamilyByDefault: 'Roboto',
);
```

Constructor parameters:

- `initialSnapshot`
- `pointerSettings`
- `dragStartSlop`
- `clearSelectionOnDrawModeEnter`
- `moveCommitDeltaResolver`
- `textFontFamilyByDefault`

Validation notes:

- malformed snapshot boundary values fail fast with `ArgumentError` during
  snapshot construction; scene-level invariant failures still throw
  `SceneDataException` when the controller canonicalizes `initialSnapshot`
- invalid `pointerSettings` throws `ArgumentError`
- `textFontFamilyByDefault` is used only when newly inserted `TextNodeSpec`
  leaves `fontFamily` unset

### 5.2 Read-only runtime state

Committed state:

- `snapshot`
- `selectedNodeIds`
- `mode`
- `drawTool`
- `drawColor`
- `pointerSettings`
- resolved `dragStartSlop`

Editable drawing properties:

- `penThickness`
- `highlighterThickness`
- `lineThickness`
- `eraserThickness`
- `highlighterOpacity`

Interactive preview state:

- `selectionRect`
- `pendingLineStart`
- `pendingLineTimestampMs`
- `hasPendingLineStart`
- `hasActiveStrokePreview`
- `activeStrokePreviewPoints`
- `activeStrokePreviewThickness`
- `activeStrokePreviewColor`
- `activeStrokePreviewOpacity`
- `hasActiveLinePreview`
- `activeLinePreviewStart`
- `activeLinePreviewEnd`
- `activeLinePreviewThickness`
- `activeLinePreviewColor`

Streams:

- `actions`
- `editTextRequests`

### 5.3 Configuration methods

```dart
controller.setMode(CanvasMode.draw);
controller.setDrawTool(DrawTool.pen);
controller.setDrawColor(const Color(0xFF1565C0));
controller.setPointerSettings(const PointerInputSettings());
controller.setDragStartSlop(12);
```

Available methods:

- `setMode(CanvasMode value)`
- `setDrawTool(DrawTool value)`
- `setDrawColor(Color value)`
- `setPointerSettings(PointerInputSettings value)`
- `setDragStartSlop(double? value)`
- `setBackgroundColor(Color value)`
- `setGridEnabled(bool value)`
- `setGridCellSize(double value)`
- `setCameraOffset(Offset value)`
- `notifySceneChanged()`

Important behavior:

- `setDragStartSlop(null)` restores fallback to `pointerSettings.tapSlop`
- `setPointerSettings(...)` is applied live by `SceneView`
- if a gesture is already active, new pointer settings take effect after
  `up` or `cancel`
- `setGridCellSize(...)` requires a finite positive value and applies an
  internal safety minimum when the grid is enabled
- invalid numeric settings throw `ArgumentError`

### 5.4 Scene and node mutation methods

Node and layer writes:

- `NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex})`
- `bool ensureLayer(LayerId layerId, {int? index})`
- `bool patchNode(NodePatch patch)`
- `bool removeNode(NodeId id, {int? timestampMs})`

Selection helpers:

- `setSelection(Iterable<NodeId> nodeIds)`
- `toggleSelection(NodeId nodeId)`
- `clearSelection()`
- `selectAll({bool onlySelectable = true})`

Transform and document helpers:

- `rotateSelection({required bool clockwise, int? timestampMs})`
- `flipSelectionVertical({int? timestampMs})`
- `flipSelectionHorizontal({int? timestampMs})`
- `deleteSelection({int? timestampMs})`
- `clearScene({int? timestampMs})`
- `replaceScene(SceneSnapshot snapshot)`

Layer rules:

- `layerId` addresses only content layers
- `layerId == null` inserts into the last content layer
- if there are no content layers, `addNode(...)` creates one automatically
- `insertIndex` controls explicit z-position inside the target content layer
- unknown `layerId` throws `ArgumentError`
- `ensureLayer(...)` creates a missing content layer and returns `false` when
  the layer already exists

Selection rules:

- `selectAll(onlySelectable: true)` targets visible selectable foreground nodes
- `selectAll(onlySelectable: false)` may include visible non-selectable
  foreground nodes
- committed normalization removes only missing, background, or invisible ids

Clear rules:

- `clearScene()` keeps or creates the dedicated background layer
- a clear action can be structural-only, even if no node ids were removed
- `replaceScene(...)` validates the snapshot boundary and throws
  `SceneDataException` for malformed input

### 5.5 Low-level input hooks

```dart
controller.handlePointer(
  const CanvasPointerInput(
    pointerId: 1,
    position: Offset(100, 100),
    phase: CanvasPointerPhase.down,
    kind: PointerDeviceKind.touch,
  ),
);
```

Public hooks:

- `handlePointer(CanvasPointerInput input)`
- `handleDoubleTap({required Offset position, int? timestampMs})`

Use these only when you are not relying on `SceneView` to route input.

Guardrails:

- same-stack `handlePointer(...)` reentrancy throws `StateError`
- non-finite coordinates are ignored as a no-op
- after `dispose()`, mutating and effectful entrypoints throw `StateError`

### 5.6 Lifecycle and notification semantics

- `dispose()` releases controller resources and closes future mutating or
  effectful entrypoints with fail-fast `StateError`
- `write(...)`, `handlePointer(...)`, and `handleDoubleTap(...)` never call
  `notifyListeners()` synchronously
- listener notifications are scheduled in a microtask
- multiple writes in one event-loop tick are coalesced into one listener update
- `actions` and `editTextRequests` are asynchronous streams
- relative ordering between stream delivery and repaint notifications is not a
  public contract

## 6. Transactional writes

### 6.1 Public transaction entrypoint

```dart
controller.write<void>((txn) {
  txn.writeLayerEnsure('annotations');
  txn.writeNodeInsert(
    RectNodeSpec(
      id: 'note-1',
      size: const Size(120, 80),
      fillColor: const Color(0xFFFFF59D),
    ),
    layerId: 'annotations',
  );
});
```

Signature:

- `T write<T>(T Function(SceneWriteTxn txn) fn)`

Contract:

- the callback must complete synchronously
- returning a `Future` throws `StateError`
- buffered side effects roll back if the transaction fails

### 6.2 `SceneWriteTxn`

`SceneWriteTxn` exposes immutable reads plus explicit write operations.

Read access:

- `snapshot` is an immutable snapshot of the current transaction state
- `selectedNodeIds` is an immutable view of the current normalized selection

Structural and content writes:

- `writeNodeInsert(...)`
- `writeLayerEnsure(...)`
- `writeNodeErase(...)`
- `writeNodePatch(...)`
- `writeNodeTransformSet(...)`
- `writeClearSceneKeepBackgroundResult()`
- `writeClearSceneKeepBackground()`
- `writeDocumentReplace(...)`

Runtime contract highlights:

- `writeNodeInsert(...)` throws `ArgumentError` for duplicate explicit
  `spec.id` and unknown content `layerId`, and `RangeError` for out-of-bounds
  `insertIndex`
- `writeLayerEnsure(...)` throws `RangeError` for an out-of-bounds explicit
  insertion index
- `writeNodePatch(...)` returns `false` when the target node is missing or the
  patch is a semantic no-op, and throws `ArgumentError` only when patch id/type
  runtime semantics do not match the target node
- `writeNodeTransformSet(...)`, `writeSelectionTranslate(...)`,
  `writeSelectionTransform(...)`, `writeCameraOffset(...)`, and
  `writeGridCellSize(...)` validate only the runtime numeric arguments required
  by those operations
- `writeSelectionTransform(...)` composes transforms with pre-multiply
  semantics: `nextTransform = delta.multiply(existingTransform)`

Selection writes:

- `writeSelectionReplace(...)`
- `writeSelectionToggle(...)`
- `writeSelectionClear()`
- `writeSelectionSelectAll(...)`
- `writeSelectionTranslate(...)`
- `writeSelectionTransform(...)`
- `writeDeleteSelection()`

Selection semantics:

- `writeSelectionReplace(...)` normalizes input to visible content-node ids
- if normalization produces an empty set, `writeSelectionReplace(...)` is a
  no-op and returns `false`; use `writeSelectionClear()` for explicit clearing

Scene settings writes:

- `writeCameraOffset(...)`
- `writeGridEnable(...)`
- `writeGridCellSize(...)`
- `writeBackgroundColor(...)`

Signal write:

- `writeSignalEnqueue(...)`

Transaction handle lifetime:

- a transaction handle is valid only inside the active callback
- calling a `write*` method after callback completion throws `StateError`

### 6.3 `ClearSceneResult`

`writeClearSceneKeepBackgroundResult()` returns `ClearSceneResult`:

- `removedNodeIds`
- `didStructuralClear`

Contract:

- `removedNodeIds` is an immutable snapshot
- `writeClearSceneKeepBackground()` returns the same immutable removed-id
  snapshot contract without the extra metadata wrapper
- `didStructuralClear` is `true` for any structural clear effect, including
  creating a missing dedicated background layer

## 7. Interaction model

### 7.1 Modes and pointer policy

- `CanvasMode.move` handles selection, marquee, and drag-move
- `CanvasMode.draw` handles pen, highlighter, line, and eraser
- each active gesture belongs to one `pointerId`
- parallel pointer ids are ignored until the active gesture ends with `up` or
  `cancel`

### 7.2 Draw and move behavior

- pen and highlighter commit a stroke on pointer `up`
- long strokes are capped to `20_000` points with deterministic downsampling
- line supports drag creation and two-tap creation
- `dragStartSlop` applies to both move and line drag start
- preview state is ephemeral and does not mutate the committed snapshot
- pointer `cancel` clears preview state without committing

### 7.3 `MoveCommitDeltaResolver`

`MoveCommitDeltaResolver` runs once, on pointer `up`, before the final move
commit.

Callback shape:

```dart
Offset Function({
  required SceneSnapshot snapshot,
  required List<NodeSnapshot> movedNodes,
  required Offset proposedDelta,
})
```

Rules:

- return the final delta that should be committed
- the returned delta is also the one emitted in `ActionType.transform`
- do not call public mutating or effectful controller APIs from inside this
  callback; those fail fast with `StateError`

### 7.4 Text editing hook

On double tap in move mode, if the top hit node is a text node, the controller
emits `EditTextRequested`.

Use that event to open your own text editor UI.

## 8. Events

### 8.1 `actions`

`actions` emits `ActionCommitted`.

Fields:

- `actionId`
- `type`
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

Payload helpers are provided by the `ActionCommittedDelta` extension:

- `tryTransformDelta()`
- `tryMoveLayerIndices()`
- `tryDrawStyle()`
- `tryEraserThickness()`

Delivery contract:

- delivery is asynchronous
- `nodeIds` and `payload` are immutable snapshots
- consumers must not depend on relative ordering against `ChangeNotifier`
  updates

### 8.2 `editTextRequests`

`EditTextRequested` contains:

- `nodeId`
- `timestampMs`
- `position`

Delivery is asynchronous under the same contract as `actions`.

## 9. `SceneView`

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

Parameters:

- `controller`
- `imageResolver`
- `selectionColor`
- `selectionStrokeWidth`
- `gridStrokeWidth`

### 9.2 Responsibilities

`SceneView`:

- captures pointer events from Flutter
- routes them into controller input handling
- paints the committed scene
- paints interactive previews
- owns render caches by default and resets them on document/epoch boundaries

### 9.3 Image resolver

`imageResolver` has type `ui.Image? Function(String imageId)?`.

- if omitted, image nodes render as placeholders
- image lifecycle ownership stays with the host app
- dispose app-owned `ui.Image` instances when they are no longer needed

## 10. Pointer contracts

### 10.1 `CanvasPointerInput`

Fields:

- `pointerId`
- `position`
- optional `timestampMs`
- `phase`
- `kind`

`CanvasPointerPhase` values:

- `down`
- `move`
- `up`
- `cancel`

When `timestampMs` is `null`, the controller assigns a monotonic internal
timestamp.

### 10.2 `PointerInputSettings`

Fields:

- `tapSlop`
- `doubleTapSlop`
- `doubleTapMaxDelayMs`
- `deferSingleTap`

Validation rules:

- `tapSlop` must be finite and `>= 0`
- `doubleTapSlop` must be finite and `>= 0`
- `doubleTapMaxDelayMs` must be `>= 0`

## 11. Serialization

### 11.1 Public functions

- `String encodeSceneToJson(SceneSnapshot snapshot)`
- `SceneSnapshot decodeSceneFromJson(String json)`
- `Map<String, dynamic> encodeScene(SceneSnapshot snapshot)`
- `SceneSnapshot decodeScene(Map<String, dynamic> json)`

### 11.2 `SceneBuilder`

`SceneBuilder` is the public import and canonicalization gateway for callers
that already have typed snapshots or parsed JSON maps:

- `SceneSnapshot buildFromSnapshot(SceneSnapshot raw)`
- `SceneSnapshot buildFromJson(Map<String, dynamic> rawJson)`

Use it when you want validation and canonicalization without going through a
controller.

- `buildFromSnapshot(...)` is the typed-snapshot import path.
- `buildFromJson(...)` is the parsed-map import path and reuses the same import
  boundary as `decodeScene(...)`, but skips JSON string parsing.
- both methods throw `SceneDataException` when the input violates schema or
  boundary validation rules
- nested validation failures include `SceneDataException.path` when the
  boundary can identify the exact field location

### 11.3 Decode and import guarantees

- `decodeSceneFromJson(...)` is the string-JSON boundary:
  - it always throws `SceneDataException` for public decode failures
  - JSON parse failures and non-object root values use
    `SceneDataErrorCode.invalidJson`
- `decodeScene(...)` is the parsed-map boundary:
  - it throws `SceneDataException` for schema and nested import validation
    failures
- nested validation errors include a fully-qualified `SceneDataException.path`
- root-level parse or schema failures may omit `path` when the boundary does
  not yet know a more specific field location
- decode accepts a missing `backgroundLayer` field and canonicalizes it to an
  empty dedicated layer
- text node bounds are canonicalized from layout inputs; incoming serialized
  text `size` is not treated as the source of truth
- supported text-align values stay aligned across boundary constructors,
  serialization, and import/runtime semantics:
  `left`, `center`, `right`, `justify`, `start`, `end`
- decode/build paths reuse the exported validated boundary value types for ids,
  image ids, revisions, text/font payloads, SVG path data, opacity, finite
  offsets, and bounded numeric node fields
- when `SceneDataException.source` would otherwise capture mutable or oversized
  payloads, the boundary stores an immutable snapshot or sanitized preview
  instead of a live raw object
- decode rejects oversized payloads:
  - content layers must stay `<= 4096`
  - total node count must stay `<= 200000`
  - stroke point count per node must stay `<= 20000`
  - `svgPathData` length must stay `<= 200000`
  - content layer id length must stay `<= 256`
  - node id length must stay `<= 256`
  - image id length must stay `<= 1024`
  - text length must stay `<= 100000`
  - text `fontFamily` length must stay `<= 256`
  - palette list sizes (`penColors`, `backgroundColors`, `gridSizes`) must stay
    `<= 1024` items each

## 12. Error taxonomy

| Error type | Meaning | Typical boundaries |
| --- | --- | --- |
| `ArgumentError` | The caller passed an invalid runtime argument. | `addNode` (including duplicate explicit `NodeSpec.id`), `patchNode`, transforms, numeric setters, invalid pointer settings |
| `StateError` | The runtime contract was violated. | disposed controller calls, stale transaction handle, async `write(...)`, reentrant `handlePointer(...)`, invariant failures |
| `SceneDataException` | Scene or JSON data is malformed. `source` preserves small scalar values, snapshots small structured payloads into immutable containers, and sanitizes oversized or opaque objects into previews. The constructor is not `const`. | `initialSnapshot`, `replaceScene`, `SceneBuilder`, `decodeScene*`, `encodeScene*` |

## 13. Migration checklist for current integrations

If you are aligning older integration code to the current `5.x` contract:

1. Use only `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
2. Use `NodeSpec` and `NodePatch`; do not depend on internal mutable scene
   types.
3. Use typed layers: `backgroundLayer` plus content-only `layers`.
4. Address content layers by `LayerId`, not legacy layer indexes in write APIs.
5. Treat JSON as schema `5` only.
6. Treat `TextNode.size` / `TextNodeSnapshot.size` as derived metadata, not a
   source of truth.
7. Treat `actions` and `editTextRequests` as asynchronous.

## 14. Integration example

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

    controller.addNode(
      TextNodeSpec(
        id: 'title',
        text: 'Hello',
        color: const Color(0xFF111111),
      ),
    );

    editSub = controller.editTextRequests.listen((event) {
      // Open app-owned text editing UI for event.nodeId.
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
