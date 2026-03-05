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

- Deterministic scene rendering with a dedicated `backgroundLayer` plus ordered
  content `layers`.
- Public runtime aliases `SceneController` and `SceneView` for move, select,
  draw, and edit flows.
- Transactional write API via `SceneWriteTxn`.
- Explicit path fill-rule contract via `PathFillRule`.
- JSON import/export with strict validation and canonicalization.

## What it does not provide

- Toolbars, dialogs, side panels, or product-specific UI.
- Storage, sync, or backend collaboration.
- App-level history management.

## Install

```sh
flutter pub add iwb_canvas_engine
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

    controller.addNode(
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
- `backgroundLayer` is always distinct from content `layers`; content writes use
  `LayerId`.
- `ensureLayer(...)` and `writeLayerEnsure(...)` are the supported APIs for
  explicit content-layer creation.
- `write(...)` is synchronous-only. Returning a `Future` throws `StateError`.
- explicit duplicate `NodeSpec.id` in `addNode(...)` or `writeNodeInsert(...)`
  throws `ArgumentError`.
- `actions`, `editTextRequests`, and `ChangeNotifier` updates are asynchronous;
  listener notifications are microtask-deferred and coalesced.
- `setPointerSettings(...)` is applied live by `SceneView`; active gestures keep
  their current settings until `up` or `cancel`.

## Where to look next

- `API_GUIDE.md` for public API details, validation rules, and migration notes.
- `ARCHITECTURE.md` for module layout, runtime data flow, and invariants.
- `CHANGELOG.md` for release history and unreleased changes.
- `example/README.md` for the demo app scope.

## License

MIT. See `LICENSE`.
