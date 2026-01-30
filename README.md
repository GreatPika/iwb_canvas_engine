<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

`iwb_canvas_engine` is a Flutter/Dart package for rendering and editing
scene-based canvas content. It provides a scene model, rendering, hit-testing,
and JSON serialization for drawing tools and whiteboard-style apps.

## Features

- Scene model with layers and nodes (image, text, stroke, line, rect, path).
- Rendering via `ScenePainter` with background and grid.
- Hit-testing for selection and interaction.
- JSON v1 import/export with validation.

## Getting started

Requires Flutter stable and Dart compatible with the pinned SDK in
`pubspec.yaml`.

## Usage

```dart
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

CustomPaint(
  painter: ScenePainter(
    scene: scene,
    imageResolver: (_) => null,
  ),
);
```

### SceneView integration

`SceneView` wires pointer input to `SceneController` and repaints via
`ScenePainter`. The app provides an `ImageResolver` and listens to events.

```dart
final controller = SceneController(scene: scene);

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

## API reference

The package public surface is exported from `lib/iwb_canvas_engine.dart`
(imported as `package:iwb_canvas_engine/iwb_canvas_engine.dart`).

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

See `ARCHITECTURE.md` for design notes.
