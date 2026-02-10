# iwb_canvas_engine

[![pub package](https://img.shields.io/pub/v/iwb_canvas_engine.svg)](https://pub.dev/packages/iwb_canvas_engine)
[![CI](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml/badge.svg)](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml)

Scene-based canvas engine for Flutter: scene model, rendering, input handling,
and JSON serialization for whiteboard-style applications.

- Demo: https://greatpika.github.io/iwb_canvas_engine/demo/
- API docs: https://greatpika.github.io/iwb_canvas_engine/api/
- Detailed usage guide: `API_GUIDE.md`

## Scope

### What this package provides

- Scene graph (`Scene -> Layer -> Node`) with deterministic draw order.
- Interactive controller and widget for move/select/draw workflows.
- Built-in tools: pen, highlighter, line, eraser, marquee selection.
- JSON v2 codec for import/export (`schemaVersion = 2`).

### What this package does not provide

- Full app UI (toolbars, dialogs, side panels).
- Undo/redo storage (apps own history).
- Network/backend persistence.

## Install

```sh
flutter pub add iwb_canvas_engine
```

## Entrypoints

- `package:iwb_canvas_engine/basic.dart` - recommended default import.
- `package:iwb_canvas_engine/advanced.dart` - alias of `basic.dart`.

## Quick start

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
- Write intents: `NodeSpec` variants.
- Partial updates: `NodePatch` + tri-state `PatchField<T>`.
- Serialization: `encodeScene*`, `decodeScene*`, `SceneJsonFormatException`.

## Invariants and quality gates

- Canonical invariants are defined in `tool/invariant_registry.dart`.
- Validation checks are available in `tool/` and run in CI.
- Background layer contract: at most one background layer, canonicalized to index `0`.

## Development checks

Run from repository root:

```sh
dart format --output=none --set-exit-if-changed lib test example/lib tool
flutter analyze
flutter test
flutter test --coverage
dart run tool/check_coverage.dart
dart run tool/check_invariant_coverage.dart
dart run tool/check_import_boundaries.dart
```

## License

MIT. See `LICENSE`.
