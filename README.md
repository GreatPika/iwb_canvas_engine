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
- Write-boundary validation: `addNode(...)`/`patchNode(...)` fail fast with `ArgumentError` for invalid `NodeSpec`/`NodePatch` values (including `transform`, `hitPadding`, and `opacity` outside `[0,1]`), and transform/translate write operations reject non-finite `Transform2D`/`Offset`.
- Serialization: `encodeScene*`, `decodeScene*`, `SceneJsonFormatException`.
- Event payload contract: `ActionCommitted.nodeIds/payload` are immutable snapshots.
- Selection contract: commit normalization keeps explicit non-selectable ids valid while filtering missing/background/invisible ids.
- Runtime notify contract: controller repaint notifications are deferred to a microtask after commit and coalesced to at most one notification per event-loop tick.
- Move drag contract: pointer move updates only visual preview; scene translation is committed once on pointer up, and pointer cancel keeps the document unchanged.
- Runtime snapshot validation: `initialSnapshot` and `replaceScene` fail fast with `ArgumentError` for malformed snapshots (duplicate node ids, invalid numbers, invalid SVG path data, invalid palette, multiple background layers).

## Invariants and quality gates

- Canonical invariants are defined in `tool/invariant_registry.dart`.
- Validation checks are available in `tool/` and run in CI.
- Background layer contract:
  - runtime/store snapshot boundary: at most one background layer; if present, it is canonicalized to index `0`; missing background is allowed and not auto-inserted.
  - JSON decoder boundary: at most one background layer; decoder canonicalizes to a single background layer at index `0`.

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
