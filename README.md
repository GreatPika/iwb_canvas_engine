# iwb_canvas_engine

[![pub package](https://img.shields.io/pub/v/iwb_canvas_engine.svg)](https://pub.dev/packages/iwb_canvas_engine)
[![CI](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml/badge.svg)](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml)

`iwb_canvas_engine` is a Flutter-first canvas engine for whiteboard-style
products. It provides immutable scene documents, a controller + widget
runtime, transactional scene mutations, and JSON import/export.

This README stays intentionally short. Use it as the package landing page and
the entrypoint into the deeper docs.

## What the package includes

- Immutable scene documents rooted at `SceneSnapshot`.
- A public runtime rooted at `SceneController`.
- A ready-to-use Flutter host widget, `SceneView`.
- Transactional scene writes through `SceneWriteTxn`.
- Stable content-layer addressing through `layerId`, including same-write layer
  insertion before later node mutations.
- Eager public validation for snapshots, node specs, and node patches before
  runtime mutation begins.
- Build/import and JSON entrypoints through `SceneBuilder`,
  `encodeScene*`, and `decodeScene*`, with shared `SceneDataException`
  diagnostics for public scene-data failures.

## What the package does not include

- Product-specific UI such as toolbars, dialogs, or inspectors.
- Persistence, sync, collaboration, or backend logic.
- App-level undo/redo storage.

## Requirements

- Dart: `^3.10.4`
- Flutter: `>=3.38.0`

This package is Flutter-first, not a pure Dart engine.

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

## Documentation

Use the docs in this order:

1. [API_GUIDE.md](API_GUIDE.md) for the supported public API and runtime
   behavior.
2. [ARCHITECTURE.md](ARCHITECTURE.md) for the checked-in architecture,
   invariants, and ownership boundaries.
3. [docs/ARCHITECTURE_ATLAS.md](docs/ARCHITECTURE_ATLAS.md) for the engine
   architecture atlas, proof atlas, and family-level ownership routes.
4. [CHANGELOG.md](CHANGELOG.md) for released and unreleased user-visible
   changes.
5. [example/README.md](example/README.md) for example app scope and run
   instructions.

Hosted package docs: [greatpika.github.io/iwb_canvas_engine](https://greatpika.github.io/iwb_canvas_engine/)

## License

MIT. See [LICENSE](LICENSE).
