# iwb_canvas_engine

[![pub package](https://img.shields.io/pub/v/iwb_canvas_engine.svg)](https://pub.dev/packages/iwb_canvas_engine)
[![CI](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml/badge.svg)](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml)

`iwb_canvas_engine` is a Flutter canvas engine for whiteboard-style products. It
provides an immutable scene model, rendering, interactive input handling, and
JSON serialization. It does not include app UI, persistence, or undo/redo
storage.

- Current package version: `5.1.0`
- Single public import: `package:iwb_canvas_engine/iwb_canvas_engine.dart`
- JSON contract: write `schemaVersion = 5`, read `{5}`
- Demo: https://greatpika.github.io/iwb_canvas_engine/demo/
- Hosted API docs: https://greatpika.github.io/iwb_canvas_engine/api/
- Full integration reference: `API_GUIDE.md`

## What it provides

- Deterministic scene rendering with a dedicated boundary `backgroundLayer`
  plus ordered content `layers`.
- Public runtime aliases `SceneController` and `SceneView` for move, select,
  draw, and edit flows.
- Transactional write API via `SceneWriteTxn`.
- Explicit path fill-rule contract via `PathFillRule`.
- JSON import/export with strict validation and canonicalization.
- Parsed-map import via `SceneBuilder.buildFromJson(...)` with the same stable
  `SceneDataException.code` / `path` / `details` contract used by
  `decodeScene(...)`.
- Bounded JSON import guardrails for layers/nodes/points/path data plus string
  and palette payload sizes, including a raw `decodeSceneFromJson(...)` input
  limit of `33554432` characters before parsing.
- Boundary failures expose stable `SceneDataException.code`, `path`, and
  immutable `details`; `message` remains a derived human-readable summary.
- Public validated boundary value types such as `NodeIdValue`,
  `LayerIdValue`, `ImageIdValue`, `FiniteOffsetValue`, and `OpacityValue` for
  pre-validating external inputs before snapshot/spec construction and for
  keeping decode/build boundary rules aligned with the exported contract.

## What it does not provide

- Toolbars, dialogs, side panels, or product-specific UI.
- Storage, sync, or backend collaboration.
- App-level history management.

## Install

```sh
flutter pub add iwb_canvas_engine
```

## Developer tooling

This repository uses the external DCM CLI for additional static analysis on top
of `flutter analyze`.

1. Install DCM for your platform by following the official guide:
   [Installation](https://dcm.dev/docs/getting-started/for-developers/installation/).
2. Run the repository checks:

```sh
dcm analyze .
flutter analyze
```

In CI, DCM is installed with the official GitHub Action before the static
checks job runs.

For clone-hunting during refactors, use the development-only analyzer script:

```sh
dart run tool/analysis/find_similar_clones.dart . 60 30 5 4 0.55 12
```

Use `dart run tool/analysis/find_similar_clones.dart --help` for the full
argument list and additional examples. Useful variants:

```sh
dart run tool/analysis/find_similar_clones.dart --exclude-main test 60 30 5 4 0.70 10
dart run tool/analysis/find_similar_clones.dart --json --top 20 lib 50 30 5 4 0.55 12
```

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
    controller = SceneController(
      initialSnapshot: SceneSnapshot(
        layers: [ContentLayerSnapshot(id: 'layer-0')],
      ),
    );

    controller.scene.addNode(
      RectNodeSpec(
        id: 'rect-1',
        size: const Size(160, 100),
        fillColor: const Color(0xFF1565C0),
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

## Runtime contracts worth knowing

- `TextNode.size` and `TextNodeSnapshot.size` are derived metadata.
  `TextNodeSpec` and `TextNodePatch` do not expose writable `size`, and import
  paths may ignore incoming text `size` and recompute canonical bounds.
- Public snapshot/node/spec/patch constructors validate boundary ids and
  numeric values eagerly and are runtime constructors rather than `const`
  entry points.
- runtime `Scene.backgroundLayer` may be absent internally, while snapshot/JSON
  boundaries canonicalize it to a dedicated layer distinct from content
  `layers`; content writes use `LayerId`.
- Boundary helpers such as `parseNodeId(...)`, `parseLayerId(...)`, and
  validated value types including `ImageIdValue` keep external payload checks
  aligned with import/build rules. Runtime-generated ids are internal engine
  details rather than a public compatibility promise. See `API_GUIDE.md` for
  the full list.
- For import/build/encode failures, compare `SceneDataException` instances by
  `code` / `path` / `details`; this parity is shared by
  `SceneBuilder.buildFromJson(...)`, `decodeScene(...)`,
  `decodeSceneFromJson(...)`, `encodeScene(...)`, and `encodeSceneDocument(...)`.
  Treat `message` as user-facing text rather than the primary machine
  contract.
- `ensureLayer(...)` and `writeLayerEnsure(...)` are the supported APIs for
  explicit content-layer creation.
- `write(...)` is synchronous-only. Returning a `Future` throws `StateError`.
- explicit duplicate `NodeSpec.id` in `addNode(...)` or `writeNodeInsert(...)`
  throws `ArgumentError`.
- `actions`, `editTextRequests`, and `ChangeNotifier` updates are asynchronous;
  listener notifications are microtask-deferred and coalesced.
- `setPointerSettings(...)` is applied live by `SceneView`; active gestures keep
  their current settings until `up` or `cancel`, and parallel raw host pointers
  do not force an early reset of routed pointer tracking. Settings are treated
  as a value object, and while raw pointers remain live the view keeps only the
  last pending update until router idle.
- `SceneController` keeps one controller-owned active gesture owner:
  parallel `pointerId`s are ignored until the owner ends, and
  `replaceScene(...)`, `setCameraOffset(...)`, mode/tool changes, and `dispose()`
  force-release the active gesture only when the boundary mutation will proceed
  with an observable state change.
- Public selection mutations are gesture-exclusive: `setSelection(...)`,
  `toggleSelection(...)`, `clearSelection()`, and `selectAll(...)` throw
  `StateError` while an active move/draw gesture is in progress.
- Background grid rendering now has one internal owner in
  `src/render/scene_grid_renderer.dart`: direct painter draw and static-cache
  recording share the same drawable predicate, density bucketing, camera-shift
  math, and bounded anti-flap policy without any cross-frame mutable grid
  state.
- Interactive transform/delete preflight is snapshot-based and shared:
  controller-side rotate/flip/delete entrypoints use one internal eligibility
  policy owner, while write-layer guards remain defensive commit barriers.
- Move-mode hit-testing, marquee selection, move preview, and move commit now
  share one internal eligibility policy: selectable-but-non-movable nodes can
  still become the selection target, but they do not start move preview, and
  pointer `cancel` restores the gesture baseline selection after any temporary
  move-local selection change.
- `handlePointer(...)` treats non-finite `down`/`move` as no-op admission
  failures. For non-finite terminal `up`/`cancel`, the controller preserves the
  original terminal phase only when the same `pointerId` already has a cached
  finite position; otherwise the terminal sample stays a no-op. Explicit
  `dragStartSlop` uses the same finite `>= 0` contract in both the constructor
  and `setDragStartSlop(...)`.

## Where to look next

- `API_GUIDE.md` for public API details, validation rules, and migration notes.
- `ARCHITECTURE.md` for module layout, runtime data flow, and invariants.
- `CHANGELOG.md` for release history and unreleased changes.
- `example/README.md` for the demo app scope.

## License

MIT. See `LICENSE`.
