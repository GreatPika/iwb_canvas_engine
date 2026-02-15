# iwb_canvas_engine

[![pub package](https://img.shields.io/pub/v/iwb_canvas_engine.svg)](https://pub.dev/packages/iwb_canvas_engine)
[![CI](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml/badge.svg)](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml)

Scene-based canvas engine for Flutter: scene model, rendering, input handling,
and JSON serialization for whiteboard-style applications.

- Demo: https://greatpika.github.io/iwb_canvas_engine/demo/
- API docs: https://greatpika.github.io/iwb_canvas_engine/api/
- Detailed usage guide: `API_GUIDE.md`
- Current stable release: `3.0.0`

## Release 3.0.0 highlights

- Strict runtime and write-boundary validation for snapshots/specs/patches.
- Copy-on-write transaction path and incremental spatial-index updates for large scenes.
- Text node size is engine-derived from text layout inputs (not writable in public API).
- Coalesced microtask-based repaint notifications and asynchronous interactive streams.

## Scope

### What this package provides

- Scene graph (`Scene -> backgroundLayer + content layers -> Node`) with deterministic draw order.
- Interactive controller and widget for move/select/draw workflows.
- Built-in tools: pen, highlighter, line, eraser, marquee selection.
- JSON v4 codec for import/export (`schemaVersion = 4`).

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
- Write intents: `NodeSpec` variants.
- Partial updates: `NodePatch` + tri-state `PatchField<T>`.
- Text layout sizing is engine-derived: `TextNodeSpec`/`TextNodePatch` do not expose writable `size`; update text/style fields and the runtime recomputes text box bounds.
- Write-boundary validation: `addNode(...)`/`patchNode(...)` fail fast with `ArgumentError` for invalid `NodeSpec`/`NodePatch` values (including `transform`, `hitPadding`, and `opacity` outside `[0,1]`), and transform/translate write operations reject non-finite `Transform2D`/`Offset`.
- Serialization: `encodeScene*`, `decodeScene*`, `SceneDataException`.
- Event payload contract: `ActionCommitted.nodeIds/payload` are immutable snapshots.
- Interactive event delivery contract: `actions` and `editTextRequests` are asynchronous; relative ordering against repaint/listener notifications is not a public contract.
- Selection contract: commit normalization keeps explicit non-selectable ids valid while filtering missing/background/invisible ids.
- Runtime notify contract: both core and interactive controller `ChangeNotifier` updates are deferred to a microtask and coalesced to at most one notification per event-loop tick.
- Move drag contract: pointer move updates only visual preview; scene translation is committed once on pointer up, and pointer cancel keeps the document unchanged.
- Runtime guardrails bound worst-case input/query cost: interactive stroke commits are capped to `20_000` points (deterministic downsampling), path-stroke precise hit-testing is capped to `2_048` samples per path metric, and oversized spatial queries switch to bounded candidate-scan fallback.
- Runtime snapshot validation: `initialSnapshot` and `replaceScene` fail fast with `SceneDataException` for malformed snapshots (duplicate node ids, invalid numbers, invalid SVG path data, invalid palette, invalid typed layer fields).
- Commit invariant checks fail fast with `StateError` in all build modes when committed store state violates runtime invariants.
- Lifecycle fail-fast: after `dispose()`, mutating/effectful runtime calls (`write(...)`, `replaceScene(...)`, `notifySceneChanged()`/core repaint request) throw `StateError` and do not mutate state.

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
- Runtime commit invariant checks are enforced in all build modes (`debug`/`profile`/`release`) and throw `StateError` on violations.
- Typed layer contract:
  - snapshot/runtime model uses `backgroundLayer` as a dedicated typed field and `layers` as content-only ordered layers.
  - `writeNodeInsert(..., layerIndex)` addresses content layers only.
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
