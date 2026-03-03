# iwb_canvas_engine

[![pub package](https://img.shields.io/pub/v/iwb_canvas_engine.svg)](https://pub.dev/packages/iwb_canvas_engine)
[![CI](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml/badge.svg)](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml)

Scene-based canvas engine for Flutter: scene model, rendering, input handling,
and JSON serialization for whiteboard-style applications.

- Demo: https://greatpika.github.io/iwb_canvas_engine/demo/
- API docs: https://greatpika.github.io/iwb_canvas_engine/api/
- Detailed usage guide: `API_GUIDE.md`
- Current stable release: `5.0.0`

## Release 5.0.0 highlights

- Strict runtime and write-boundary validation for snapshots/specs/patches.
- Copy-on-write transaction path and incremental spatial-index updates for large scenes.
- Text node size is engine-derived from text layout inputs (not writable in public API).
- Coalesced microtask-based repaint notifications and asynchronous interactive streams.

## Scope

### What this package provides

- Scene graph (`Scene -> backgroundLayer + content layers -> Node`) with deterministic draw order.
- Interactive controller and widget for move/select/draw workflows.
- Built-in tools: pen, highlighter, line, eraser, marquee selection.
- JSON v5 codec for import/export (`schemaVersion = 5`).

### What this package does not provide

- Full app UI (toolbars, dialogs, side panels).
- Undo/redo storage (apps own history).
- Network/backend persistence.

## Install

```sh
flutter pub add iwb_canvas_engine
```

## Entrypoints

- `package:iwb_canvas_engine/iwb_canvas_engine.dart` - single public entrypoint.
- Imports from `package:iwb_canvas_engine/src/**` are unsupported and may break without notice.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

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
    controller = SceneController();

    controller.addNode(
      RectNodeSpec(
        id: 'rect-1',
        size: const Size(160, 100),
        fillColor: const Color(0xFF2196F3),
      ),
    );
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

## Core API

- Runtime: `SceneController`, `SceneView`, `SceneSnapshot`.
- Safe transactional writes: `SceneWriteTxn` via `controller.write((txn) { ... })`.
- `write(...)` callback is synchronous-only; returning `Future` fails fast with `StateError`.
- Transaction handle lifetime: `SceneWriteTxn` write methods are valid only inside the active `write(...)` callback; post-callback `write*` calls throw `StateError`.
- Selection transaction methods report no-op vs change explicitly:
  - `writeSelectionReplace(...)`, `writeSelectionToggle(...)`, `writeSelectionClear()` return `bool changed`.
- Clear transaction semantics are explicit:
  - `writeClearSceneKeepBackgroundResult() -> ClearSceneResult`, where `didStructuralClear` marks structural clear side effects and `removedNodeIds` can be empty for structural-only clear.
  - `ClearSceneResult.removedNodeIds` is returned as an immutable snapshot.
- Write intents: `NodeSpec` variants.
- `SceneControllerInteractive(textFontFamilyByDefault: '...')` can stamp a
  default `fontFamily` into newly inserted `TextNodeSpec` values when the spec
  leaves `fontFamily` unset.
- Partial updates: `NodePatch` + tri-state `PatchField<T>`.
- Text layout sizing is engine-derived: `TextNodeSpec`/`TextNodePatch` do not expose writable `size`; update text/style fields and the runtime recomputes text box bounds.
- Serialized `TextNode.size` is derived metadata, not an authoritative input: decode/import and layout-affecting text patches re-derive size from text layout fields.
- Cross-platform note: font metrics can differ slightly between platforms/font engines, so JSON snapshot comparisons should prefer semantic checks or numeric tolerance for text `size`.
- Write-boundary validation: `addNode(...)`/`patchNode(...)` fail fast with `ArgumentError` for invalid `NodeSpec`/`NodePatch` values (including `transform`, `hitPadding`, and `opacity` outside `[0,1]`), and transform/translate write operations reject non-finite `Transform2D`/`Offset`.
- Serialization: `encodeScene*`, `decodeScene*`, `SceneDataException`.
- JSON map entrypoints accept `Map<String, dynamic>` (`decodeScene(...)`, `SceneBuilder.buildFromJson(...)`).
- JSON decode/build diagnostics include fully-qualified field paths (for example `layers[0].nodes[0].isVisible`).
- Event payload contract: `ActionCommitted.nodeIds/payload` are immutable snapshots.
- Interactive event delivery contract: `actions` and `editTextRequests` are asynchronous; relative ordering against repaint/listener notifications is not a public contract.
- Event-ordering guarantees:
  - no `actions`/`editTextRequests` delivery happens in the same call stack as mutating runtime API calls;
  - no controller `notifyListeners()` happens synchronously inside `write(...)` or `handlePointer(...)`;
  - listener notifications are always microtask-deferred and coalesced.
- Public error taxonomy:
  - `ArgumentError`: invalid write-boundary/runtime setter arguments;
  - `StateError`: invalid lifecycle/contract state (`dispose`, reentrancy, stale txn handle, invariant violations);
  - `SceneDataException`: malformed scene/snapshot/json import-export boundary data.
- Selection contract: commit normalization keeps explicit non-selectable ids valid while filtering missing/background/invisible ids.
- Runtime notify contract: both core and interactive controller `ChangeNotifier` updates are deferred to a microtask and coalesced to at most one notification per event-loop tick (not one notification per transaction).
- Drag-start threshold contract: `dragStartSlop` is used for move and line drag start; if unset, it falls back to `pointerSettings.tapSlop`.
- Pointer settings validation contract: runtime boundaries reject invalid `PointerInputSettings` (`tapSlop`/`doubleTapSlop` must be finite and `>= 0`; `doubleTapMaxDelayMs >= 0`).
- Live pointer settings contract: `setPointerSettings(...)` is applied by `SceneView` without controller remount; if a pointer gesture is active, the new settings are applied immediately after `up`/`cancel`.
- Single-active-pointer contract: each active move/draw gesture is bound to one `pointerId`; parallel pointer ids are ignored until gesture end (`up`/`cancel`).
- After gesture end via `up`/`cancel`, the next pointer can start a new gesture immediately.
- Move drag contract: pointer move updates only visual preview; scene translation is committed once on pointer up, and pointer cancel keeps the document unchanged.
- `MoveCommitDeltaResolver` can adjust the final committed move delta on
  pointer up; the adjusted delta is applied in the same transaction, is the one
  emitted in `ActionType.transform`, and the callback must stay pure with
  respect to public mutating/effectful `SceneControllerInteractive` APIs (those
  fail fast with `StateError`).
- Line cancel contract: pointer cancel clears line preview and clears pending two-tap line start (`pendingLineStart`).
- Draw preview contract: active stroke/line preview does not mutate committed scene before pointer up commit; pointer cancel clears preview without scene mutation.
- Runtime guardrails bound worst-case input/query cost: interactive stroke commits are capped to `20_000` points (deterministic downsampling), path-stroke precise hit-testing is capped to `2_048` samples per path metric, and oversized spatial queries switch to bounded candidate-scan fallback.
- Runtime snapshot validation: `initialSnapshot` and `replaceScene` fail fast with `SceneDataException` for malformed snapshots (duplicate node ids, invalid numbers, invalid SVG path data, invalid palette, invalid typed layer fields).
- JSON decode boundary enforces hard payload limits: content layers `<= 4_096`, total scene nodes `<= 200_000`, stroke `localPoints` per node `<= 20_000`, and `svgPathData` length `<= 200_000`.
- `clearScene` emits clear semantics on any clear-side state change: removing content nodes and/or creating missing dedicated `backgroundLayer` during clear canonicalization.
- Commit invariant checks are two-tiered:
  - critical commit invariants fail fast with `StateError` in all build modes (`debug`/`profile`/`release`);
  - full committed-store invariant sweep remains enabled in `debug`/`profile` modes.
- Lifecycle fail-fast: after `dispose()`, mutating/effectful runtime calls (`write(...)`, `replaceScene(...)`, `notifySceneChanged()`/core repaint request, `handlePointer(...)`, `handleDoubleTap(...)`, interactive mode/tool/settings setters, selection/scene mutators) throw `StateError` and do not mutate state.

## Render cache and image lifecycle

- `SceneStrokePathCache`, `SceneTextLayoutCache`, and `ScenePathMetricsCache` validate constructor input at runtime and throw `ArgumentError` when `maxEntries <= 0`.
- Render caches isolate node instances by `(NodeId, instanceRevision)` and then validate geometry-specific freshness (for example stroke `pointsRevision`), so id reuse cannot return stale geometry.
- `ScenePainter` consumes `RenderGeometryCache` keyed by node instance identity + geometry validity fields, so path parsing and local/world bounds computation are reused across culling, selection, and paint paths.
- `SceneView` owns render caches by default and clears them on controller epoch/document boundaries.
- `SceneView(imageResolver: ...)` accepts an optional callback (`ui.Image? Function(String imageId)`); when omitted, image nodes are rendered as placeholders.
- The app that creates/caches `dart:ui Image` objects owns their lifecycle and should dispose them when those images are no longer needed.

## Invariants and quality gates

- Canonical invariants are defined in `tool/invariant_registry.dart`.
- Validation checks are available in `tool/` and run in CI.
- Runtime commit invariant checks are enforced as a two-tier contract:
  - critical checks (`camera/grid finite+valid`, strictly monotonic commit revision vs previous committed state) run in all build modes;
  - full committed-store invariant sweep runs in `debug`/`profile`.
- Typed layer contract:
  - snapshot/runtime model uses `backgroundLayer` as a dedicated typed field and `layers` as content-only ordered layers.
  - each `ContentLayerSnapshot` has stable `id: LayerId`.
  - `writeNodeInsert(..., layerId, insertIndex)` addresses content layers by
    `LayerId` and can place a node at an explicit z-order inside the layer.
  - `writeLayerEnsure(layerId, index: ...)` creates a missing content layer
    explicitly and keeps the existing fail-fast contract for unknown `layerId`
    in node insertion APIs.
  - z-order is defined only by list order in `layers` (not by `layerId`).
  - runtime/public `SceneSnapshot` always includes dedicated `backgroundLayer`.
  - input may omit `backgroundLayer`, but decode/import boundaries canonicalize it to a dedicated empty layer.

## Development checks

Run from repository root:

```sh
dart format --output=none --set-exit-if-changed lib test example/lib tool
flutter analyze
flutter test
flutter test --coverage
dart run tool/check_coverage.dart
dart run tool/check_invariant_coverage.dart
dart run tool/check_guardrails.dart
dart run tool/check_import_boundaries.dart
```

## License

MIT. See `LICENSE`.
