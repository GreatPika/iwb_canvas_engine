# iwb_canvas_engine

[![pub package](https://img.shields.io/pub/v/iwb_canvas_engine.svg)](https://pub.dev/packages/iwb_canvas_engine)
[![CI](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml/badge.svg)](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml)

`iwb_canvas_engine` is a Flutter-first canvas engine for whiteboard-style
products. It provides an immutable scene document model, a controller + widget
runtime, transactional scene mutations, and JSON import/export.

This README describes the checked-in main branch. For published release history
and unreleased mainline changes, see [CHANGELOG.md](CHANGELOG.md).

## What the package includes

- Immutable scene documents built around `SceneSnapshot`, content layers, a
  dedicated `backgroundLayer`, and typed node families.
- A public runtime rooted at `SceneController`, with controller-owned
  capabilities exposed through `controller.scene`, `controller.selection`, and
  `controller.interaction`.
- A ready-to-use Flutter widget, `SceneView`, for rendering and interactive
  pointer routing.
- Transactional scene edits through `SceneWriteTxn`.
- Strict import/export and canonicalization through `SceneBuilder`,
  `encodeScene*`, and `decodeScene*`.
- A stable machine-readable error contract through `SceneDataException` and
  `SceneDataErrorCode`.

## What the package does not include

- Toolbars, dialogs, inspectors, or other product-specific UI.
- Persistence, sync, collaboration, or backend logic.
- App-level undo/redo storage.

## Requirements

- Dart: `^3.10.4`
- Flutter: `>=3.38.0`

This package is not a pure Dart engine. Public contract types use Flutter and
`dart:ui` primitives.

## Installation

```sh
flutter pub add iwb_canvas_engine
```

## Supported import

```dart
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
```

Do not import from `package:iwb_canvas_engine/src/**`. Everything under
`src/**` is internal implementation detail and is not a supported integration
contract.

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

## Core concepts

- `SceneSnapshot` is the immutable document boundary exchanged with app code.
- Public scene data has two layer families: one dedicated `backgroundLayer`
  plus ordered content `layers`.
- Supported node families are image, text, stroke, line, rect, and path.
- Use `NodeSpec` to create nodes and `NodePatch` + `PatchField` to apply
  partial updates.
- Use `SceneController` for runtime ownership, `SceneView` for the Flutter host
  surface, and `SceneBuilder` / `encodeScene*` / `decodeScene*` for import and
  serialization.
- Use `SceneDataException.code`, `path`, and `details` as the stable
  machine-readable failure contract when scene or JSON data is invalid.

## Serialization and validation

- Current mainline JSON write version: `schemaVersion = 7`
- Current mainline JSON read set: `{7}`
- `SceneBuilder.buildFromSnapshot(...)` and `SceneBuilder.buildFromJson(...)`
  validate and canonicalize data without requiring a controller.
- `encodeScene(...)` / `encodeSceneToJson(...)` validate before serializing.
- `decodeScene(...)` / `decodeSceneFromJson(...)` validate before returning a
  `SceneSnapshot`.
- Text nodes use derived bounds. Current schema payloads require explicit
  `textDirection` and must not include legacy stored text `size` metadata.

## Common integration points

- Listen to `controller.actions` for committed action events that can feed your
  app-level history or analytics.
- Listen to `controller.editTextRequests` to open app-owned text editing UI.
- Pass `imageResolver` to `SceneView` when the scene contains image nodes.
- Call `controller.scene.notifySceneChanged()` when host-owned visual resources
  change without a scene mutation, for example when an image backing store is
  refreshed.

## Documentation

- [API_GUIDE.md](API_GUIDE.md) — public API reference and integration rules.
- [ARCHITECTURE.md](ARCHITECTURE.md) — repository architecture, invariants, and
  ownership boundaries.
- [CHANGELOG.md](CHANGELOG.md) — published release history plus current
  unreleased changes.
- [example/README.md](example/README.md) — example app scope and run
  instructions.
- Hosted package docs: https://greatpika.github.io/iwb_canvas_engine/

## License

MIT. See [LICENSE](LICENSE).
