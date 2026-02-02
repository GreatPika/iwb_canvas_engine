import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('encode -> decode -> encode is stable', () {
    final scene = _buildScene();

    final encoded = encodeScene(scene);
    final decoded = decodeScene(encoded);
    final reEncoded = encodeScene(decoded);

    expect(reEncoded, encoded);
  });

  test('decodeSceneFromJson rejects invalid schema', () {
    final json = '{"schemaVersion": 999}';
    expect(
      () => decodeSceneFromJson(json),
      throwsA(isA<SceneJsonFormatException>()),
    );
  });

  test('decodeSceneFromJson rejects invalid color', () {
    final scene = _buildScene();
    final encoded = encodeScene(scene);
    encoded['background']['color'] = 'not-a-color';

    expect(
      () => decodeScene(encoded),
      throwsA(isA<SceneJsonFormatException>()),
    );
  });
}

Scene _buildScene() {
  final image =
      ImageNode(
          id: 'img-1',
          imageId: 'asset:sample',
          size: const Size(100, 80),
          naturalSize: const Size(200, 160),
        )
        ..position = const Offset(10, 20)
        ..rotationDeg = 90
        ..scaleX = 1
        ..scaleY = -1
        ..opacity = 0.8
        ..isVisible = true
        ..isSelectable = true
        ..isLocked = false
        ..isDeletable = true
        ..isTransformable = true;

  final text =
      TextNode(
          id: 'text-1',
          text: 'Hello',
          size: const Size(120, 30),
          fontSize: 24,
          color: const Color(0xFF112233),
          align: TextAlign.center,
          isBold: true,
          isItalic: false,
          isUnderline: true,
          fontFamily: 'Roboto',
          maxWidth: 200,
          lineHeight: 1.2,
        )
        ..position = const Offset(50, 50)
        ..rotationDeg = -90
        ..scaleX = 1.5
        ..scaleY = 0.5
        ..opacity = 0.9
        ..isVisible = true
        ..isSelectable = true
        ..isLocked = false
        ..isDeletable = true
        ..isTransformable = true;

  final stroke = StrokeNode.fromWorldPoints(
    id: 'stroke-1',
    points: const [Offset(0, 0), Offset(10, 10)],
    thickness: 3,
    color: const Color(0xFF000000),
  )..opacity = 0.4;

  final line = LineNode.fromWorldSegment(
    id: 'line-1',
    start: const Offset(5, 5),
    end: const Offset(15, 15),
    thickness: 5,
    color: const Color(0xFF00FF00),
  );

  final rect = RectNode(
    id: 'rect-1',
    size: const Size(50, 60),
    fillColor: const Color(0xFFFF0000),
    strokeColor: const Color(0xFF0000FF),
    strokeWidth: 2,
  )..position = const Offset(-10, -20);

  final path = PathNode(
    id: 'path-1',
    svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
    fillColor: const Color(0xFF4CAF50),
    strokeColor: const Color(0xFF1B5E20),
    strokeWidth: 2,
    fillRule: PathFillRule.evenOdd,
  )..position = const Offset(100, -40);

  final layer = Layer(nodes: [image, text, stroke, line, rect, path]);

  return Scene(
    layers: [layer],
    camera: Camera(offset: const Offset(7, -3)),
    background: Background(
      color: const Color(0xFFFFFFFF),
      grid: GridSettings(
        isEnabled: true,
        cellSize: 20,
        color: const Color(0x1F000000),
      ),
    ),
    palette: ScenePalette(
      penColors: const [Color(0xFF000000), Color(0xFFE53935)],
      backgroundColors: const [Color(0xFFFFFFFF)],
      gridSizes: const [10, 20],
    ),
  );
}
