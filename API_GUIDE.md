# iwb_canvas_engine API Guide

This document is the canonical integration reference for the current mainline.
It describes the supported public API, the runtime contracts that matter in
production, and the migration expectations for the current mainline release.

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
  - `SceneController`
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

JSON string boundary note:

- `decodeSceneFromJson(...)` rejects raw JSON strings longer than
  `33554432` characters before `jsonDecode`
- oversized raw JSON is reported as `SceneDataErrorCode.invalidJson` with
  `details.template == 'jsonPayloadTooLarge'`

Public runtime surface:

- `SceneController` is the concrete public runtime owner
- `SceneControllerInteraction`, `SceneControllerSelection`, and
  `SceneControllerScene` are capability owners exposed through
  `controller.interaction`, `controller.selection`, and `controller.scene`
- `SceneView` is the public interactive widget export

Migration note:

- `SceneControllerInteraction.snapshot` was removed from the public runtime
  surface
- read committed render-state from `controller.snapshot`
- keep `controller.interaction` for interactive mode/tool/preview concerns only

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

- `backgroundLayer` is always a dedicated layer on the snapshot/JSON boundary
  and is rendered below content
- `layers` contains content layers only
- each content layer has a stable `LayerId`
- z-order is defined only by list order in `layers`
- `LayerId` is identity, not ordering

Write APIs target content layers only. The background layer is never addressed
through `LayerId`.

Runtime note:

- mutable internal `Scene.backgroundLayer` may stay `null`
- runtime write paths materialize it only when background-node mutation needs
  it
- this runtime-nullable shape is internal and does not change the canonical
  snapshot/JSON contract

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
- runtime invalidation identity is composite: `controllerEpoch + instanceRevision`
- snapshot/import preserves existing positive safe-int `instanceRevision`
  values; missing or non-positive values are normalized from a local allocator
  that starts at `1`
- runtime revision overflow does not saturate or wrap: it resets the next
  revision to `1` and requires an epoch bump
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

- `SceneController.scene.addNode(...)` accepts only `NodeSpec`
- public `NodeSpec` constructors validate boundary values eagerly and are
  runtime constructors rather than `const` entry points
- `NodeSpec.id` is optional; the controller can generate ids
- explicit ids remain `String`-compatible at the public API boundary, and the
  supported validation surface is `NodeIdValue`, `LayerIdValue`,
  `parseNodeId(...)`, and `parseLayerId(...)`
- runtime-generated ids are internal allocator output; callers must treat them
  as opaque strings rather than depend on a parseable public format
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
- `NodeIdValue` / `LayerIdValue` reject blank ids and enforce max lengths for
  explicit public ids
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
- explicit `dragStartSlop` must be finite and `>= 0`; `null` keeps the
  fallback to `pointerSettings.tapSlop`
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
controller.interaction.setMode(CanvasMode.draw);
controller.interaction.setDrawTool(DrawTool.pen);
controller.interaction.setDrawColor(const Color(0xFF1565C0));
controller.interaction.setPointerSettings(const PointerInputSettings());
controller.interaction.setDragStartSlop(12);
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
- explicit `dragStartSlop` uses the same finite `>= 0` rule in the constructor
  and in `setDragStartSlop(...)`
- `setPointerSettings(...)` is applied live by `SceneView`
- if a gesture is already active, new pointer settings take effect after
  `up` or `cancel`
- `SceneView` owns only raw pointer routing; tap/double-tap recognition,
  deferred tap flush, and applied-versus-pending pointer settings are owned by
  a controller-side pointer-semantics runtime
- active gesture ownership is controller-local: parallel `pointerId`s are
  ignored until terminal release, and `replaceScene(...)`, `setCameraOffset(...)`,
  `setMode(...)`, `setDrawTool(...)`, and `dispose()` force-reset the active
  gesture only when the boundary transition will actually continue with an
  observable state change
- all public `controller.selection.*` mutations plus
  `scene.write(...)`,
  `setBackgroundColor(...)`,
  `setGridEnabled(...)`,
  `setGridCellSize(...)`,
  `addNode(...)`,
  `ensureLayer(...)`,
  `patchNode(...)`,
  `removeNode(...)`, and
  `clearScene(...)` throw `StateError` while an active move/draw gesture owns
  the controller
- interactive rotate/flip/delete preflight uses one internal snapshot-based
  eligibility policy owner; write-layer guards remain separate defensive
  barriers in the transactional core
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

Active-gesture mutation exclusivity:

- `setSelection(...)`, `toggleSelection(...)`, `clearSelection()`,
  `selectAll(...)`, `rotateSelection(...)`, `flipSelectionVertical(...)`,
  `flipSelectionHorizontal(...)`, `deleteSelection(...)`, `scene.write(...)`,
  `setBackgroundColor(...)`, `setGridEnabled(...)`, `setGridCellSize(...)`,
  `addNode(...)`, `ensureLayer(...)`, `patchNode(...)`, `removeNode(...)`, and
  `clearScene(...)` are external public mutations
- these APIs throw `StateError` while an active move/draw gesture is in
  progress
- after terminal `up` or `cancel`, these APIs become available again
- `setCameraOffset(...)` and `replaceScene(...)` are the only public scene
  mutations that may reset the active gesture instead of being denied
- `setCameraOffset(...)` keeps its existing finite/no-op preflight before any
  reset, and `replaceScene(...)` keeps snapshot validation before any reset

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
controller.interaction.handlePointer(
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
- non-finite `down`/`move` are ignored as a no-op
- non-finite `up`/`cancel` keep their original terminal phase only when the
  same `pointerId` already has a cached finite position; otherwise they stay
  a no-op
- `SceneView` forwards invalid terminal host events through
  `handlePointer(...)` and leaves canonical terminal normalization to the
  controller boundary
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
- `dragStartSlop` is captured once on pointer `down` and stays fixed for that
  gesture lifetime, even if pointer settings change before terminal release

### 7.2 Draw and move behavior

- pen and highlighter commit a stroke on pointer `up`
- long strokes are capped to `20_000` points with deterministic downsampling
- line supports drag creation and two-tap creation
- `dragStartSlop` applies to both move and line drag start
- preview state is ephemeral and does not mutate the committed snapshot
- move-mode hit-testing and marquee inclusion use the same selection
  admissibility owner (`canSelect(...)`)
- move preview and move commit use the same move admissibility owner, so
  selectable-but-non-previewable nodes may still become selected on `down` but
  never start move preview or move commit
- pointer `cancel` clears preview state without committing and restores the
  baseline selection if that gesture changed selection locally before terminal
  completion
- while a gesture is active, external `setSelection(...)`,
  `toggleSelection(...)`, `clearSelection()`, and `selectAll(...)` are
  rejected so gesture-local selection lifecycle has one owner

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
- routes them into controller input handling through a view-owned routed
  `pointerId` space
- paints the committed scene
- paints interactive previews
- owns render caches by default and resets them on document/epoch boundaries
- uses one internal grid renderer owner for both direct painting and
  static-cache picture recording, so drawable checks, density bucketing,
  camera shift, and bounded anti-flap policy stay aligned without cross-frame
  mutable grid state

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

When input comes from `SceneView`, `pointerId` is a view-routed runtime value:

- a routed id is allocated only on pointer `down`
- the same routed id stays stable until matching `up` or `cancel`
- stray non-down Flutter host events are dropped instead of falling back to raw
  host pointer ids

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
- value semantics include all four fields (`==` / `hashCode`)
- `SceneView` applies updated settings immediately only when the raw-pointer
  router is idle
- when raw host pointers are still live, the controller-owned pointer-semantics
  owner keeps one pending settings value and applies only the last update
  after router idle
- controller swaps discard pending settings from the previous controller owner

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
  boundary as `decodeScene(...)`, but skips JSON string parsing. Parsed-map
  normalization stays inside the `SceneBuilder` model boundary rather than in
  the public API entrypoint.
- both methods throw `SceneDataException` when the input violates schema or
  boundary validation rules
- nested validation failures include `SceneDataException.path` when the
  boundary can identify the exact field location
- compare builder/decode failures by `SceneDataException.code`, `path`, and
  immutable `details`; `message` is derived user-facing text

### 11.3 Decode and import guarantees

- `decodeSceneFromJson(...)` is the string-JSON boundary:
  - it always throws `SceneDataException` for public decode failures
  - JSON parse failures and non-object root values use
    `SceneDataErrorCode.invalidJson`
- `decodeScene(...)` is the parsed-map boundary:
  - it throws `SceneDataException` for schema and nested import validation
    failures
  - it reuses the same parsed-map guard contract as
    `SceneBuilder.buildFromJson(...)` so malformed map normalization stays
    aligned on `code` / `path` / `details`
- `encodeScene(...)` and `encodeSceneDocument(...)` are the snapshot/runtime
  encode boundaries:
  - they preserve policy-owned validation diagnostics and route unexpected
    transport failures through the same `SceneDataException` invalid-json
    factory used by the other codec entrypoints
- nested validation errors include a fully-qualified `SceneDataException.path`
- root-level parse or schema failures may omit `path` when the boundary does
  not yet know a more specific field location
- compare boundary-equivalent failures by `SceneDataException.code`,
  `path`, and immutable `details`; `message` is derived user-facing text
- `SceneDataException.source` remains a diagnostic/`FormatException`
  compatibility field and is not part of cross-boundary parity
- decode accepts a missing `backgroundLayer` field and canonicalizes it to an
  empty dedicated layer
- decode/build boundaries expose a canonical single-background-layer contract;
  nullable `Scene.backgroundLayer` remains an internal runtime shape
- text node bounds are canonicalized from layout inputs; incoming serialized
  text `size` is not treated as the source of truth
- supported text-align values stay aligned across boundary constructors,
  serialization, and import/runtime semantics:
  `left`, `center`, `right`, `justify`, `start`, `end`
- decode/build paths reuse the exported validated boundary value types for ids,
  image ids, revisions, text/font payloads, SVG path data, opacity, finite
  offsets, and bounded numeric node fields
- scene-level duplicate/count/range policy has a single owner:
  `ScenePolicy`
- for the same scene defect, `SceneBuilder.buildFromSnapshot(...)`,
  `SceneBuilder.buildFromJson(...)`, `decodeScene(...)`,
  `decodeSceneFromJson(...)`, `encodeScene(...)`, `encodeSceneDocument(...)`,
  and runtime scene canonicalization return the same deterministic
  `SceneDataException.code`, `path`, and `details`
- scene-level error contract:
  - duplicate node id:
    `code = SceneDataErrorCode.duplicateNodeId`,
    `details = {'template': 'duplicateNodeId'}`, and `path` points to the
    repeated id field (`backgroundLayer.nodes[i].id` or
    `layers[l].nodes[n].id`); `message` is derived as
    `Must be unique across scene layers.`
  - duplicate content layer id:
    `code = SceneDataErrorCode.duplicateLayerId`,
    `details = {'template': 'duplicateLayerId'}`, and `path = layers[i].id`;
    `message` is derived as
    `Field layers[i].id must be unique across content layers.`
  - scene-level numeric range violations:
    `code = SceneDataErrorCode.outOfRange`,
    `details = {'template': 'outOfRange', 'min': <min>, 'max': <max>}`, and
    `path` points to the exact offending field; `message` is derived as
    `Field <path> must be within [<min>, <max>].`
  - content-layer count overflow:
    `code = SceneDataErrorCode.invalidValue`,
    `details = {'template': 'maxItems', 'maxItems': <limit>}`, and
    `path = layers`; `message` is derived as
    `Field layers must contain at most <limit> items.`
  - scene-wide node-count overflow:
    `code = SceneDataErrorCode.invalidValue`,
    `details = {'template': 'maxNodes', 'maxNodes': <limit>}`, and `path` is
    the collection where overflow was observed (`backgroundLayer.nodes` or
    `layers[i].nodes`); `message` is derived as
    `Scene must contain at most <limit> nodes.`
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
| `SceneDataException` | Scene or JSON data is malformed. Stable machine-readable fields are `code`, `path`, and immutable `details`; `message` is derived user-facing text. `source` preserves small scalar values, snapshots small structured payloads into immutable containers, and sanitizes oversized or opaque objects into previews. The constructor is not `const`. | `initialSnapshot`, `replaceScene`, `SceneBuilder`, `decodeScene*`, `encodeScene*` |

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

    controller.scene.addNode(
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
