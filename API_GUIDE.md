# iwb_canvas_engine — API Usage Guide

This guide explains how to use the **public API** of `iwb_canvas_engine` in a Flutter app.
It is written to be **LLM/agent-friendly**: copy/paste snippets, explicit invariants, and clear “where to look” pointers.

## Audience

- Flutter app developers integrating a scene-based canvas (whiteboard / drawing tools).
- Coding agents implementing features **using** the package (not rewriting it).

## Non-goals (by design)

- No full app UI (toolbars, menus, pickers).
- No built-in undo/redo stack (the engine emits events; the app owns history).
- No storage backend beyond JSON import/export helpers.

## Entrypoints (what to import)

Prefer importing the smallest surface area that fits your use case:

- **Recommended:** `package:iwb_canvas_engine/basic.dart` — primary v2 API.
- **Advanced:** `package:iwb_canvas_engine/advanced.dart` — advanced alias of
  `basic.dart`.
- **Compatibility alias:** `package:iwb_canvas_engine/basic_v2.dart` —
  deprecated alias of `basic.dart`.
- **Compatibility alias:** `package:iwb_canvas_engine/advanced_v2.dart` —
  deprecated alias of `advanced.dart`.

### v2: minimal model creation examples

```dart
import 'package:iwb_canvas_engine/basic.dart';

final scene = SceneSnapshot(
  layers: [
    LayerSnapshot(
      nodes: [
        const RectNodeSnapshot(
          id: 'rect-1',
          size: Size(120, 80),
        ),
      ],
    ),
  ],
);

const spec = RectNodeSpec(
  id: 'rect-2',
  size: Size(100, 60),
);

const patch = RectNodePatch(
  id: 'rect-1',
  fillColor: PatchField<Color?>.nullValue(),
  strokeWidth: PatchField<double>.value(2),
);
```

`PatchField<T>` is tri-state by design:
- `absent()` => keep current field value.
- `value(x)` => set concrete value.
- `nullValue()` => explicitly clear nullable field.

---

## TL;DR: minimal integration skeletons

### 1) `SceneView` creates the controller (`onControllerReady`)

```dart
import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/basic.dart';

class CanvasScreen extends StatelessWidget {
  const CanvasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SceneView(
        onControllerReady: (controller) {
          controller.addNode(
            RectNode(
              id: 'rect-1',
              size: const Size(120, 80),
              fillColor: const Color(0xFF2196F3),
            )..position = const Offset(120, 120),
          );
        },
      ),
    );
  }
}
```

When `SceneView` owns the controller, updating its `pointerSettings`,
`dragStartSlop`, or `nodeIdGenerator` parameters reconfigures the same
controller instance (no recreation).

### 2) External `SceneController` + explicit `Scene(layers:[Layer()])`

```dart
import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/basic.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  late final SceneController controller;

  @override
  void initState() {
    super.initState();
    controller = SceneController(scene: Scene(layers: [Layer()]));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SceneView(controller: controller);
  }
}
```

### 3) Reconfigure input settings at runtime (without recreating controller)

```dart
controller.reconfigureInput(
  pointerSettings: const PointerInputSettings(
    tapSlop: 10,
    doubleTapMaxDelayMs: 450,
  ),
  dragStartSlop: 12,
  nodeIdGenerator: () => 'node-${DateTime.now().microsecondsSinceEpoch}',
);
```

If called during an active pointer gesture, the new config is applied after
that gesture ends.

---

## Rendering caches (performance)

`SceneView` enables bounded in-memory caches by default to reduce per-frame work:

- `SceneTextLayoutCache`: caches `TextPainter.layout()` results for `TextNode`
- `SceneStrokePathCache`: caches built `Path` geometry for `StrokeNode`
- `ScenePathMetricsCache`: caches decomposed path contours for selected
  `PathNode` rendering (`id + svgPathData + fillRule` key)

You can optionally provide your own cache instances to share across multiple
views or tune memory limits.

```dart
import 'package:iwb_canvas_engine/basic.dart';

final textCache = SceneTextLayoutCache(maxEntries: 512);
final strokeCache = SceneStrokePathCache(maxEntries: 1024);
final pathMetricsCache = ScenePathMetricsCache(maxEntries: 512);

SceneView(
  textLayoutCache: textCache,
  strokePathCache: strokeCache,
  pathMetricsCache: pathMetricsCache,
  thinLineSnapStrategy: ThinLineSnapStrategy.autoAxisAlignedThin,
);
```

`thinLineSnapStrategy` controls optional physical pixel-grid snapping in
`ScenePainter` for thin axis-aligned lines/strokes. Use
`ThinLineSnapStrategy.none` if you need exact raw coordinates without snapping.

## Core mental model (read this before coding)

## Stability and compatibility

This package follows a strict additive-only compatibility rule for public
protocols:

- Existing JSON fields and action payload keys must not change meaning or type.
- New fields/keys may be added in a backwards-compatible way.

Stable contracts (expected to remain compatible as the package evolves):

- `Transform2D` JSON/event format: `{a,b,c,d,tx,ty}`.
- JSON node type identifiers (strings written by the codec).
- `ActionType` values and the documented `ActionCommitted.payload` schemas.
- `SceneController` public command methods and selection helpers.
- `SceneView` widget contract (controller ownership, coordinate conversion).

### Scene graph

- `Scene → Layer → SceneNode`
- Layers are rendered in list order; nodes are rendered in list order.
- **Z-order / hit-test:** the **last** node in a layer is the top-most; the **last** layer is on top.
  - Source of truth: `hitTestTopNode` in `lib/src/core/hit_test.dart`.
  - `hitTestTopNode` skips layers with `isBackground == true`.
  - Hit-test tolerance uses `kHitSlop` + `SceneNode.hitPadding` in **scene/world units**
    (strict scene units for `LineNode`/`StrokeNode`, no anisotropic max-axis inflation).
    When `transform.invert()` is unavailable (degenerate
    transforms), hit-testing falls back to `boundsWorld.inflate(hitPadding + kHitSlop)`
    for coarse-but-selectable behavior. Exception: `PathNode` fill/stroke do not
    use coarse fallback and are non-interactive when inverse transform is unavailable.
  - **PathNode semantics:** hit-testing selects the union of fill and stroke.
    - Fill uses `Path.contains` (exact interior hit-test, requires invertible transform).
    - Stroke uses precise distance-to-path checks with tolerance
      `strokeWidth/2 + hitPadding + kHitSlop` in scene units (scale-aware).
    - Selection highlight for closed contours follows `PathNode.fillRule`
      (`nonZero` / `evenOdd`) for consistent hole behavior.
    - Invalid/unbuildable SVG path data is non-interactive at runtime
      (`buildLocalPath() == null` => no hit).
- **List ownership:** `Scene(layers: ...)` and `Layer(nodes: ...)` defensively copy
  the provided lists. Mutating the original list after construction does not affect
  the scene/layer.
- **Controller canonicalization:** `SceneController(scene: ...)` validates
  constructor input, ensures a background layer exists at index `0`, and moves
  a misordered background layer to index `0`. Multiple background layers are
  rejected with `ArgumentError`.
- **Mode policy:** `SceneController(clearSelectionOnDrawModeEnter: true)`
  clears current selection when switching mode to `CanvasMode.draw`
  (default is `false`).
- **Decoder canonicalization:** `decodeScene(...)` enforces the same background
  invariant: missing/misordered background is canonicalized to index `0`;
  multiple background layers are rejected with `SceneJsonFormatException`.
- **PathNode local path cache:** `PathNode.buildLocalPath()` returns a defensive
  copy by default. Pass `copy:false` only for performance-sensitive, read-only
  internal usage. To debug invalid SVG path data, enable
  `PathNode.enableBuildLocalPathDiagnostics` and inspect
  `debugLastBuildLocalPathFailureReason` (plus exception/stack trace getters).

### Coordinate systems

- **View/screen coordinates**: what Flutter pointer events provide (`PointerEvent.localPosition`).
- **Scene/world coordinates**: what the engine stores and hit-tests against.
- Conversions:
  - `toScene(viewPoint, scene.camera.offset) == viewPoint + cameraOffset`
  - `toView(scenePoint, scene.camera.offset) == scenePoint - cameraOffset`
  - Source of truth: `lib/src/core/geometry.dart`.

### Camera

- `scene.camera.offset` represents panning (camera movement).
- Rendering subtracts camera offset; input adds it.
- Do **not** “pan” by changing node geometry; pan by calling `SceneController.setCameraOffset(...)`.

### Transform is the single source of truth

- Every node has `SceneNode.transform` (`Transform2D`) which stores a 2×3 affine matrix `{a,b,c,d,tx,ty}`.
- Convenience accessors (`position`, `rotationDeg`, `scaleX`, `scaleY`) are derived from `transform`.
- Convenience setters `rotationDeg` / `scaleX` / `scaleY` require a TRS transform (no shear). For general affine edits, set `SceneNode.transform` directly.
- `scaleX` is a magnitude (non-negative). Flips/reflections (`det < 0`) are represented via the sign of `scaleY` and may shift `rotationDeg` by 180° as part of a canonical TRS(+flip) decomposition.
- Source of truth: `lib/src/core/transform2d.dart` and `lib/src/core/nodes.dart`.

### Numeric robustness (near-zero handling)

- Floating-point math is not exact. This package avoids strict `== 0` checks in core math where it can cause unstable behavior.
- `Transform2D.invert()` may return `null` not only for exactly singular matrices, but also for **near-singular** or **non-finite** transforms.
  - Always handle `null` and fall back to coarse behavior when needed
    (example: most hit-testing paths use an inflated `boundsWorld` fallback;
    `PathNode` fill/stroke stay non-interactive).
- Derived convenience accessors (`rotationDeg`, `scaleY`) are designed to stay finite and stable even when the underlying transform is almost-degenerate.
- UI-like positioning helpers (e.g. `topLeftWorld` setters) use epsilon comparisons to avoid floating-point micro-drift.

### Numeric validity (NaN/Infinity/ranges)

- **Serialization boundary (`decodeScene` / `encodeScene`) is strict:** non-finite
  numbers and out-of-range values throw `SceneJsonFormatException`.
- JSON palette lists (`penColors`, `backgroundColors`, `gridSizes`) must be
  non-empty.
- `background.grid.cellSize` validation is conditional:
  - when `grid.enabled == true`, `cellSize` must be finite and `> 0`;
  - when `grid.enabled == false`, any finite `cellSize` is accepted.
- `SceneControllerInteractiveV2.setGridCellSize(...)` is fail-fast: it rejects
  non-finite and non-positive values regardless of `grid.enabled`. When grid is
  enabled, values below the safety minimum are clamped to `kMinGridCellSize`.
- **Runtime behavior is defensive:** bounds, hit-testing, and rendering sanitize
  invalid numeric inputs to avoid propagating NaN/Infinity or crashing.
  - Length-like values (`thickness`, `strokeWidth`, `hitPadding`, `Size.*`) treat
    non-finite and negative values as `0`.
  - This soft normalization is runtime-only; JSON import/export remains strict.
  - `opacity` is normalized at core-model assignment: non-finite values become
    `1` and finite values are clamped to `[0,1]`.
  - Grid rendering treats non-finite / non-positive `cellSize` as "grid disabled"
    even if `grid.enabled == true`.
  - For over-dense grids, rendering degrades uniformly by drawing every `N`th
    line per axis so painted line count stays within the safety cap
    (`kMaxGridLinesPerAxis`); no major/accent lines are used.
  - `SceneController.setCameraOffset(...)` rejects non-finite components with
    `ArgumentError` (camera state is not mutated on rejection).
  - Non-finite transforms are treated as invalid at runtime: `boundsWorld` becomes
    `Rect.zero` and rendering skips the node (safe no-op).

### Geometry is local (around (0,0))

- Node geometry is stored in **local coordinates around the origin**.
- World placement/rotation/scale comes from `transform`.
- For interactive drawing, the controller may temporarily keep stroke points in world space and normalize them at gesture end.

---

## Cookbook (common tasks)

Each recipe includes:
- What you want
- Minimal snippet
- Gotchas
- Relevant APIs (with file pointers)

### 1) Add nodes safely (use `SceneController`)

What you want: add/remove/move nodes without breaking controller invariants.

### 2) Hook into `SceneView` pointer samples (snap, grouped drag)

What you want: integrate app-level logic (e.g., snap on drop, or dragging a
"board" together with attached pieces) without re-implementing `SceneView`.

Key contract:
- `PointerSample.position` is in view/screen coordinates.
- Call order per sample: `onPointerSampleBefore` → `controller.handlePointer` →
  `onPointerSampleAfter` → internal pointer signals (double-tap).

Example: expand selection on `down` when the user taps the board so the default
move tool drags the board and its attached pieces together.

```dart
import 'package:flutter/widgets.dart';
import 'package:iwb_canvas_engine/advanced.dart';

SceneView(
  controller: controller,
  onPointerSampleAfter: (controller, sample) {
    if (sample.phase != PointerPhase.down) return;

    final scenePoint = toScene(sample.position, controller.scene.camera.offset);
    final hit = hitTestTopNode(controller.scene, scenePoint);
    if (hit?.id != 'board') return;

    // App-owned domain state.
    final attachedPieceIds = <NodeId>{'piece-1', 'piece-2'};
    controller.setSelection(<NodeId>{'board', ...attachedPieceIds});
  },
);
```

Where to implement snap:
- Do snap computations on `PointerPhase.up` in `onPointerSampleAfter`, then
  apply the final node transform(s) via controller commands or direct mutations
  wrapped in `controller.mutate(...)`.

```dart
import 'package:iwb_canvas_engine/basic.dart';

final controller = SceneController(scene: Scene(layers: [Layer(), Layer()]));

controller.addNode(
  RectNode(
    id: 'rect-2',
    size: const Size(120, 80),
    fillColor: const Color(0xFF2196F3),
  )..position = const Offset(200, 200),
);

controller.moveNode('rect-2', targetLayerIndex: 2);
controller.removeNode('rect-2');
```

Gotchas:
- **Node IDs must be unique within a scene.** `SceneController.addNode(...)`
  throws `ArgumentError` for duplicates; `decodeScene(...)` throws
  `SceneJsonFormatException` if JSON contains duplicate IDs.
- `addNode(...)` without `layerIndex` targets the first non-background layer.
  When a scene has only background, the controller creates a non-background
  layer and adds the node there.
- If you want the controller to generate IDs, use controller-created nodes/flows or provide `nodeIdGenerator`.
- The default `node-{n}` generator starts at `max(existing node-{n}) + 1` for the provided scene (so bulk node creation stays fast).
- Use `reconfigureInput(...)` when you need to update pointer thresholds or
  ID-generation strategy at runtime without replacing the controller.

Relevant APIs:
- `SceneController.addNode/removeNode/moveNode` — `lib/src/input/scene_controller.dart`
- `NodeId` — `lib/src/core/nodes.dart`

### 2) Mutate the scene directly (escape hatch)

What you want: directly edit `controller.scene` (e.g., bulk changes), then restore minimal invariants.

```dart
// Preferred: use mutateStructural(...) for structural edits.
controller.mutateStructural((scene) {
  final contentLayer = scene.layers.firstWhere((layer) => !layer.isBackground);
  contentLayer.nodes.clear();
});

// Escape hatch:
// If you mutate the model directly, call notifySceneChanged() for structural
// changes, or requestRepaintOncePerFrame() for geometry-only changes.
```

Gotchas:
- If you mutate `scene.layers[..].nodes` directly and forget `notifySceneChanged()`,
  selection/invariants may become stale.

Relevant APIs:
- `SceneController.scene` + `SceneController.notifySceneChanged()` — `lib/src/input/scene_controller.dart`
- `SceneController.mutate(...)` / `SceneController.mutateStructural(...)` — `lib/src/input/scene_controller.dart`
- `Scene/Layer` — `lib/src/core/scene.dart`

### 3) Selection basics

What you want: react to selection changes, drive selection from your app UI,
and read selection geometry.

```dart
final selected = controller.selectedNodeIds; // snapshot view
if (selected.isEmpty) {
  // nothing selected
}

controller.clearSelection();

// App-driven selection helpers (useful for layer/object panels).
controller.setSelection(['node-1', 'node-2']);
controller.toggleSelection('node-3');
controller.selectAll();

final bounds = controller.selectionBoundsWorld;
final center = controller.selectionCenterWorld;
```

Gotchas:
- `selectedNodeIds` is an unordered set; iteration order is not guaranteed.
- `setSelection(...)` and `toggleSelection(...)` normalize inputs to
  interactive ids only: existing ids in non-background layers where
  `isVisible == true` and `isSelectable == true`.
- A node can be **selectable** but **locked**. Locked nodes can be selected, but drag-move skips them.
- Transform commands apply only to nodes with `isTransformable == true` and `isLocked == false`.
- Background-layer nodes are excluded from marquee/selectAll/transform helpers
  and are not deletable via `deleteSelection`, even if their ids are injected.

`clearScene()` behavior:
- removes all nodes from non-background layers,
- removes non-background layers themselves,
- keeps exactly one background layer at index `0`.

Relevant APIs:
- `SceneController.selectedNodeIds`, `clearSelection()` — `lib/src/input/scene_controller.dart`
- `SceneController.setSelection/toggleSelection/selectAll` — `lib/src/input/scene_controller.dart`
- `SceneController.selectionBoundsWorld/selectionCenterWorld` — `lib/src/input/scene_controller.dart`
- Flags: `isSelectable/isLocked/isTransformable` — `lib/src/core/nodes.dart`

### 4) Transform selection + undo/redo integration via `actions`

What you want: rotate/flip selection and record undo/redo using emitted action events.

```dart
controller.actions.listen((event) {
  // Use event.type + event.nodeIds + event.payload to build your own history.
  if (event.type == ActionType.transform) {
    final delta = event.tryTransformDelta(); // Transform2D? from payload['delta']
  }
});

controller.rotateSelection(clockwise: true);
controller.flipSelectionHorizontal();
controller.flipSelectionVertical();
```

Gotchas:
- `actions` is a **synchronous broadcast stream**; handlers must be fast (no heavy/async work).
- `ActionCommitted.timestampMs` is an internal monotonic timeline (ordered event time), not guaranteed UNIX epoch wall-clock time.
- Any inbound `timestampMs` (pointer samples, command args, pointer signals) is treated as a **hint** and normalized so emitted timestamps never go backwards.
- `EditTextRequested.timestampMs` uses the same internal monotonic timeline.
- Flip axis semantics are explicit:
  - `flipSelectionHorizontal()` reflects across the **vertical** axis through the current selection center.
  - `flipSelectionVertical()` reflects across the **horizontal** axis through the current selection center.
- `ActionType.transform` payload uses `{delta: {a,b,c,d,tx,ty}}`.
- `ActionType.move` payload uses `{sourceLayerIndex: int, targetLayerIndex: int}`.
- `ActionType.drawStroke/drawHighlighter/drawLine` payload uses `{tool: String, color: int, thickness: double}`.
- `ActionType.erase` payload uses `{eraserThickness: double}`.
- Eraser normalizes selection before emission: deleted ids are removed from
  `selectedNodeIds` before `ActionType.erase`.

Relevant APIs:
- `SceneController.actions` — `lib/src/input/scene_controller.dart`
- `ActionCommitted`, `ActionType`, payload helpers — `lib/src/input/action_events.dart`
- `Transform2D` — `lib/src/core/transform2d.dart`

### 5) Draw mode basics (pen/highlighter/line/eraser)

What you want: switch mode/tool and set tool parameters.

```dart
controller.setMode(CanvasMode.draw);
controller.setDrawTool(DrawTool.pen);
controller.setDrawColor(const Color(0xFF000000));

controller.penThickness = 3;
controller.highlighterOpacity = 0.4;
controller.eraserThickness = 20;
```

Gotchas:
- The engine currently supports **single-pointer input only** (no pinch-to-zoom, no multitouch).
- Tap/double-tap correlation is per `pointerId` (not per `PointerDeviceKind`).
- While a gesture is active, only the active pointer should be allowed to feed
  tap/double-tap candidates to signal routing.
- Draw strokes and line gestures emit action events (`drawStroke/drawHighlighter/drawLine/erase`).
- Move drag is transactional: cancel and mode switch during an active drag
  rollback transforms and emit no transform action.
- Eraser is commit-on-up: move only records trajectory for feedback; scene
  mutation + `ActionType.erase` happen on pointer up only.
- Two-tap line start expires after 10 seconds via an internal timer even if
  no new pointer events arrive.

Relevant APIs:
- `CanvasMode`, `DrawTool`, `SceneController.setMode/setDrawTool/setDrawColor` — `lib/src/input/scene_controller.dart`
- Defaults: `SceneDefaults` — `lib/src/core/defaults.dart`

### 6) Text editing integration (`editTextRequests`)

What you want: open your own text editor UI on double-tap and commit changes back to the scene.

```dart
controller.editTextRequests.listen((event) {
  // event.nodeId identifies the TextNode to edit.
  // event.position is in view/screen coordinates (good for placing an overlay).
});

// Later, when you commit text changes:
final nodeId = 'some-text-id';
TextNode? node;
for (final layer in controller.scene.layers) {
  for (final candidate in layer.nodes) {
    if (candidate is TextNode && candidate.id == nodeId) {
      node = candidate;
      break;
    }
  }
  if (node != null) break;
}

if (node != null) {
  node.text = 'New text';
  // Optionally update node.size if your app reflows text.
  controller.notifySceneChanged();
}
```

Gotchas:
- `TextNode.size` is the layout box used for alignment/hit-test/selection. The engine does **not**
  auto-resize it when text/style changes. If you need auto-fit, recompute in the app.
- `TextAlign.start` / `TextAlign.end` follow ambient `Directionality`
  (`TextDirection.ltr` / `TextDirection.rtl`) provided by the widget tree
  around `SceneView`.

Relevant APIs:
- `SceneController.editTextRequests` — `lib/src/input/scene_controller.dart`
- `EditTextRequested` — `lib/src/input/action_events.dart`
- `TextNode` — `lib/src/core/nodes.dart`

### 7) Persistence (JSON v2)

What you want: save/load a scene.

```dart
import 'package:iwb_canvas_engine/basic.dart';

final json = encodeSceneToJson(controller.scene);
final restored = decodeSceneFromJson(json);
```

For snapshot API:

```dart
import 'package:iwb_canvas_engine/basic.dart';

final snapshot = SceneSnapshot(
  layers: [LayerSnapshot(nodes: [const RectNodeSnapshot(id: 'rect-1', size: Size(120, 80))])],
);
final json = encodeSceneToJson(snapshot);
final restored = decodeSceneFromJson(json); // SceneSnapshot
```

Gotchas:
- Only `schemaVersion = 2` is accepted. Integer-valued numeric forms (for
  example, `2.0`) are accepted for integer fields; fractional values (for
  example, `2.5`) are rejected. Invalid input throws
  `SceneJsonFormatException`.

Relevant APIs:
- `encodeSceneToJson`, `decodeSceneFromJson`, `SceneJsonFormatException` —
  `lib/src/v2/serialization/scene_codec.dart`

### 8) Background / grid / camera

What you want: change background visuals and pan the camera.

```dart
controller.setBackgroundColor(const Color(0xFFFFFFFF));
controller.setGridEnabled(true);
controller.setGridCellSize(20);

controller.setCameraOffset(const Offset(120, 0)); // pan right by 120 scene units
```

Gotchas:
- Camera offset affects both rendering and input conversion; keep it as the only pan source of truth.
- `setGridCellSize(...)` rejects non-finite and non-positive values with
  `ArgumentError` in both legacy `SceneController` and
  `SceneControllerInteractiveV2`.

Relevant APIs:
- `Scene.background/grid` — `lib/src/core/scene.dart`
- `SceneController.setBackgroundColor/setGridEnabled/setGridCellSize/setCameraOffset` — `lib/src/input/scene_controller.dart`
- `SceneControllerInteractiveV2.setBackgroundColor/setGridEnabled/setGridCellSize/setCameraOffset` — `lib/src/v2/interactive/scene_controller_interactive_v2.dart`

### 9) Image rendering (`ImageNode` + `ImageResolver`)

What you want: render images referenced by ID.

```dart
final imageNode = ImageNode(
  id: 'img-1',
  imageId: 'photo://123',
  size: const Size(240, 160),
)..position = const Offset(200, 200);

controller.addNode(imageNode);

SceneView(
  controller: controller,
  imageResolver: (imageId) {
    // Must be synchronous and fast.
    // Return null if not ready; painter draws a placeholder.
    return null;
  },
);
```

Gotchas:
- `ImageResolver` is invoked during paint. It must be **sync/fast/side-effect free**.
- Do not do async work inside `imageResolver`. Preload and cache `ui.Image` in your app layer.

Relevant APIs:
- `ImageNode` — `lib/src/core/nodes.dart`
- `ImageResolver` + `ScenePainter` placeholder behavior — `lib/src/render/scene_painter.dart`

### 10) Advanced host (no `SceneView`): feed `PointerSample` manually

What you want: integrate engine input without using `SceneView` (custom widgets/gestures).

```dart
import 'package:flutter/gestures.dart';
import 'package:iwb_canvas_engine/advanced.dart';

final controller = SceneController();
final tracker = PointerInputTracker(settings: controller.pointerSettings);
int? activePointerId;
Timer? pendingTapTimer;

void onPointerEvent(PointerEvent event, PointerPhase phase) {
  final sample = PointerSample(
    pointerId: event.pointer,
    position: event.localPosition, // view/screen coordinates
    timestampMs: event.timeStamp.inMilliseconds, // timestamp hint
    phase: phase,
    kind: event.kind,
  );

  if (phase == PointerPhase.down && activePointerId == null) {
    activePointerId = sample.pointerId;
  }

  controller.handlePointer(sample);

  final allowSignals =
      activePointerId == null || activePointerId == sample.pointerId;
  if (allowSignals) {
    for (final signal in tracker.handle(sample)) {
      if (signal.type == PointerSignalType.doubleTap) {
        controller.handlePointerSignal(signal);
      }
    }
  }

  if (phase == PointerPhase.up || phase == PointerPhase.cancel) {
    if (activePointerId == sample.pointerId) {
      activePointerId = null;
    }
  }

  final nextFlushTs = tracker.nextPendingFlushTimestampMs;
  if (nextFlushTs == null) {
    pendingTapTimer?.cancel();
    pendingTapTimer = null;
    return;
  }

  pendingTapTimer ??= Timer(
    Duration(
      milliseconds: (nextFlushTs - sample.timestampMs)
          .clamp(0, 1 << 30)
          .toInt(),
    ),
    () {
      final flushedSignals = tracker.flushPending(nextFlushTs);
      for (final signal in flushedSignals) {
        if (signal.type == PointerSignalType.doubleTap) {
          controller.handlePointerSignal(signal);
        }
      }
      pendingTapTimer = null;
    },
  );
}
```

Gotchas:
- You must pass **view/screen coordinates**; the controller converts using `scene.camera.offset`.
- If you defer single taps, keep **at most one timer** and schedule it only
  while `tracker.hasPendingTap` is true.
- When a gesture is active, ignore tap/double-tap candidates from non-active pointers.

Relevant APIs:
- `PointerSample`, `PointerPhase`, `PointerInputTracker`, `PointerSignal` — `lib/src/input/pointer_input.dart`
- `SceneController.handlePointer/handlePointerSignal` — `lib/src/input/scene_controller.dart`
- Reference host: `SceneView` — `lib/src/view/scene_view.dart`

---

## JSON v2 schema cheat sheet (agent-friendly)

Source of truth: `lib/src/serialization/scene_codec.dart` (v1) and
`lib/src/v2/serialization/scene_codec.dart` (v2 snapshot codec).

### Root

- `schemaVersion` (integer-valued number) — must be `2` (`2` or `2.0`)
- `camera`:
  - `offsetX` (double), `offsetY` (double)
- `background`:
  - `color` (string: `#AARRGGBB` or `#RRGGBB`)
  - `grid`:
    - `enabled` (bool), `cellSize` (double), `color` (string)
    - `cellSize` rule: if `enabled` then finite `> 0`, otherwise any finite
- `palette`:
  - `penColors` (string[]), `backgroundColors` (string[]), `gridSizes` (double[])
  - each list must be non-empty
- `layers` (array)

### Layer

- `isBackground` (bool)
- `nodes` (array)

Decode canonicalization:
- exactly one background layer must exist at index `0`;
- missing/misordered background is fixed automatically;
- multiple background layers fail decode.

### Base node fields (all node types)

- `id` (string)
- `type` (`image|text|stroke|line|rect|path`)
- `transform` (map): `{a,b,c,d,tx,ty}` (numbers)
- `hitPadding` (double)
- `opacity` (double)
- `isVisible` (bool)
- `isSelectable` (bool)
- `isLocked` (bool)
- `isDeletable` (bool)
- `isTransformable` (bool)

### Per-type fields

- image:
  - `imageId` (string)
  - `size` `{w,h}` (numbers)
  - `naturalSize` `{w,h}` (optional)
- text:
  - `text` (string)
  - `size` `{w,h}`
  - `fontSize` (double)
  - `color` (string)
  - `align` (`left|center|right`)
  - `isBold|isItalic|isUnderline` (bool)
  - `fontFamily|maxWidth|lineHeight` (optional)
- stroke:
  - `localPoints` array of `{x,y}`
  - `thickness` (double)
  - `color` (string)
- line:
  - `localA` `{x,y}`, `localB` `{x,y}`
  - `thickness` (double)
  - `color` (string)
- rect:
  - `size` `{w,h}`
  - `strokeWidth` (double)
  - `fillColor|strokeColor` (optional, strings)
- path:
  - `svgPathData` (string, validated)
  - `fillRule` (`nonZero|evenOdd`)
  - `strokeWidth` (double)
  - `fillColor|strokeColor` (optional)

### Numeric semantics

- **Runtime:** negative `thickness`/`strokeWidth` values are clamped to `0` for
  bounds, hit-testing (including low-level helpers like `hitTestLine`), and
  rendering.
- **JSON import/export:** validation remains strict: `stroke`/`line` nodes
  require `thickness > 0`, and `rect`/`path` nodes require `strokeWidth >= 0`.

### Minimal JSON example

```json
{
  "schemaVersion": 2,
  "camera": { "offsetX": 0.0, "offsetY": 0.0 },
  "background": {
    "color": "#FFFFFFFF",
    "grid": { "enabled": false, "cellSize": 20.0, "color": "#1F000000" }
  },
  "palette": {
    "penColors": ["#FF000000", "#FFE53935", "#FF1E88E5", "#FF43A047", "#FFFB8C00", "#FF8E24AA"],
    "backgroundColors": ["#FFFFFFFF", "#FFFFF9C4", "#FFBBDEFB", "#FFC8E6C9"],
    "gridSizes": [10.0, 20.0, 40.0, 80.0]
  },
  "layers": [
    {
      "isBackground": false,
      "nodes": [
        {
          "id": "rect-1",
          "type": "rect",
          "transform": { "a": 1.0, "b": 0.0, "c": 0.0, "d": 1.0, "tx": 120.0, "ty": 120.0 },
          "hitPadding": 0.0,
          "opacity": 1.0,
          "isVisible": true,
          "isSelectable": true,
          "isLocked": false,
          "isDeletable": true,
          "isTransformable": true,
          "size": { "w": 120.0, "h": 80.0 },
          "strokeWidth": 1.0,
          "fillColor": "#FF2196F3"
        }
      ]
    }
  ]
}
```

---

## API Map (where to find things)

### Entrypoints

- `lib/basic.dart` — primary v2 public surface (recommended)
- `lib/advanced.dart` — advanced alias of `basic.dart`

### Primary integration

- `SceneViewInteractiveV2` — `lib/src/v2/view/scene_view_interactive_v2.dart`
- `SceneControllerInteractiveV2` —
  `lib/src/v2/interactive/scene_controller_interactive_v2.dart`
- Events: `ActionCommitted`, `ActionType`, `EditTextRequested` —
  `lib/src/core/action_events.dart`

### Model

- `Scene`, `Layer`, `Camera`, `Background`, `GridSettings`, `ScenePalette` — `lib/src/core/scene.dart`
- Nodes (`ImageNode`, `TextNode`, `StrokeNode`, `LineNode`, `RectNode`, `PathNode`) — `lib/src/core/nodes.dart`
- `Transform2D` — `lib/src/core/transform2d.dart`

### Rendering

- `ScenePainter` + `ImageResolver` + `SceneStaticLayerCache` — `lib/src/render/scene_painter.dart`

### Input primitives

- `PointerSample`, `PointerPhase`, `PointerSignal`, `PointerInputTracker`, `PointerInputSettings` — `lib/src/input/pointer_input.dart`

### Hit test & math

- `hitTestTopNode`, `hitTestNode`, `kHitSlop` — `lib/src/core/hit_test.dart`
- `toScene`, `toView` — `lib/src/core/geometry.dart`

---

## Gotchas / LLM traps (read before changing code)

- **View vs scene coordinates:** input positions are in view space; the controller converts via `camera.offset`.
  Using the wrong sign is the #1 bug source.
- **Direct mutation:**
  - Structural changes (add/remove/reorder layers or nodes): use `controller.mutateStructural(...)` (or call `controller.notifySceneChanged()` if you mutate directly).
  - Geometry-only changes (e.g. `node.transform`, points, colors, sizes): use `controller.mutate(...)` (or call `controller.requestRepaintOncePerFrame()` if you mutate directly).
- **ImageResolver:** keep it sync/fast; never do async work in the resolver.
- **Text layout:** `TextNode.size` is not auto-updated; the app must manage it if needed.
- **Multitouch:** not supported (single pointer only).
- **State duplication:** do not build “sync glue” between app state and controller state; prefer consuming `actions`.

---

## Verification commands (repo conventions)

When changing code in this repo, run:

```sh
dart format --output=none --set-exit-if-changed lib test example/lib
dart analyze
flutter test
```

Optional (generates `doc/api` HTML):

```sh
dart doc
```
