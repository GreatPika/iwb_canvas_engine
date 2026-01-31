# iwb_canvas_engine

[![pub package](https://img.shields.io/pub/v/iwb_canvas_engine.svg)](https://pub.dev/packages/iwb_canvas_engine)
[![CI](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml/badge.svg)](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml)

Scene-based canvas engine for Flutter: model, rendering, input handling, and
JSON serialization for drawing tools and whiteboard-style apps.

Live demo and docs:

- Web demo: https://greatpika.github.io/iwb_canvas_engine/demo/
- API reference: https://greatpika.github.io/iwb_canvas_engine/api/

## Features

- Scene model with layers and nodes (image, text, stroke, line, rect, path).
- Rendering via `ScenePainter` with background and grid.
- Hit-testing for selection and interaction.
- JSON v1 import/export with validation.

## Getting started

Add the dependency:

```sh
flutter pub add iwb_canvas_engine
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/basic.dart';

final scene = Scene(
  layers: [
    Layer(nodes: [
      RectNode(
        id: 'rect-1',
        size: const Size(120, 80),
        fillColor: const Color(0xFF2196F3),
      )..position = const Offset(120, 120),
      PathNode(
        id: 'path-1',
        svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
        fillRule: PathFillRule.evenOdd,
        fillColor: const Color(0xFF4CAF50),
      )..position = const Offset(260, 120),
    ]),
  ],
);

final controller = SceneController(scene: scene);

SceneView(
  controller: controller,
  imageResolver: (imageId) => null,
);
```

Node IDs must be unique within a scene. By default, `SceneController` generates
`node-{n}` IDs for nodes it creates; pass `nodeIdGenerator` if you need a custom
scheme.

### Events

The app can listen to controller events to integrate with undo/redo and text
editing UI.

```dart
controller.actions.listen((event) {
  // ActionCommitted for undo/redo integration.
});

controller.editTextRequests.listen((event) {
  // Open a text editor for event.nodeId at event.position.
});

SceneView(
  controller: controller,
  imageResolver: (imageId) => null,
);
```

### Scene mutations

Prefer mutating the scene through `SceneController` instead of touching
`scene.layers.first.nodes` directly:

```dart
controller.addNode(
  RectNode(
    id: 'rect-2',
    size: const Size(120, 80),
    fillColor: const Color(0xFF2196F3),
  )..position = const Offset(200, 200),
);

controller.moveNode('rect-2', targetLayerIndex: 0);
controller.removeNode('rect-2');
```

If you mutate `controller.scene` directly, call `controller.notifySceneChanged()`
afterwards to let the controller restore minimal invariants (e.g. selection).

### Advanced rendering / input

If you need low-level APIs (custom painting via `ScenePainter`, hit-testing, or
raw pointer tracking), import the full export surface:

```dart
import 'package:iwb_canvas_engine/advanced.dart';
```

For backward compatibility, `package:iwb_canvas_engine/iwb_canvas_engine.dart`
still exports the full surface in 0.x.

## Serialization (JSON v1)

```dart
final json = encodeSceneToJson(controller.scene);
final restored = decodeSceneFromJson(json);
```

## API reference

Entrypoints:

- `package:iwb_canvas_engine/basic.dart` — minimal "happy path" API.
- `package:iwb_canvas_engine/advanced.dart` — full export surface.
- `package:iwb_canvas_engine/iwb_canvas_engine.dart` — legacy full surface
  (0.x compatibility; may change for 1.0).

API docs are generated from Dartdoc comments in `lib/`:

- Local: run `dart doc` and open `doc/api/index.html`.
- On pub.dev: the “API reference” tab is generated automatically on publish.
- On GitHub: enable GitHub Pages + run the `api_docs_pages` workflow to publish
  Dartdoc HTML to Pages.

### Text layout

`TextNode.size` is the layout box used for alignment, hit-testing, and
selection bounds. The engine does not auto-resize this box when text style
changes. If you need auto-fit behavior, recompute and update `size` in the app.

### ImageResolver and constraints

`ImageResolver` maps `imageId` from `ImageNode` to a `ui.Image` instance. It is
called during painting, so keep it fast and side-effect free.

Guidelines:

- Return `null` if the image is not ready; the painter will render a placeholder.
- Preload images in the app layer and cache the `ui.Image` objects.
- Avoid async work in the resolver; resolve before repainting.

## Additional information

See `ARCHITECTURE.md` for design notes and `example/` for a working app.
