import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/text_layout.dart';

void main() {
  test('encode -> decode -> encode is stable', () {
    final scene = _buildScene();

    final encoded = encodeScene(scene);
    final decoded = decodeScene(encoded);
    final reEncoded = encodeScene(decoded);

    expect(reEncoded, encoded);
  });

  test('decodeSceneFromJson rejects invalid schema', () {
    const json = '{"schemaVersion": 999}';
    expect(() => decodeSceneFromJson(json), throwsA(isA<SceneDataException>()));
  });

  test('decodeSceneFromJson rejects schemaVersion 1', () {
    const json = '{"schemaVersion": 1}';
    expect(() => decodeSceneFromJson(json), throwsA(isA<SceneDataException>()));
  });

  test('decodeSceneFromJson rejects invalid color', () {
    final scene = _buildScene();
    final encoded = encodeScene(scene);
    encoded['background']['color'] = 'not-a-color';

    expect(() => decodeScene(encoded), throwsA(isA<SceneDataException>()));
  });

  test('decodeScene returns immutable snapshots', () {
    final scene = decodeScene(encodeScene(_buildScene()));
    expect(
      () => scene.layers.add(ContentLayerSnapshot(id: 'layer-auto-0')),
      throwsUnsupportedError,
    );
    expect(
      () => scene.layers.first.nodes.add(
        RectNodeSnapshot(id: 'extra', size: Size(1, 1)),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => scene.palette.penColors.add(const Color(0xFF00FF00)),
      throwsUnsupportedError,
    );
  });

  test(
    'decodeScene accepts JSON without instanceRevision and re-encodes with it',
    () {
      final encoded = encodeScene(_buildScene());
      final layers = encoded['layers'] as List<Object?>;
      final layer = layers[1] as Map<String, Object?>;
      final nodes = layer['nodes'] as List<Object?>;
      final firstNode = nodes.first as Map<String, Object?>;
      firstNode.remove('instanceRevision');

      final decoded = decodeScene(encoded);
      final reEncoded = encodeScene(decoded);
      final reEncodedLayers = reEncoded['layers'] as List<Object?>;
      final reEncodedLayer = reEncodedLayers[1] as Map<String, Object?>;
      final reEncodedNodes = reEncodedLayer['nodes'] as List<Object?>;
      final reEncodedFirstNode = reEncodedNodes.first as Map<String, Object?>;

      expect(reEncodedFirstNode['instanceRevision'], isA<int>());
      expect(reEncodedFirstNode['instanceRevision'], greaterThanOrEqualTo(1));
    },
  );

  test('decodeScene recomputes derived text size from content', () {
    final encoded = encodeScene(_buildScene());
    final textNode =
        ((encoded['layers'] as List<Object?>)[1]
                as Map<String, Object?>)['nodes']
            as List<Object?>;
    final textNodeMap = textNode[1] as Map<String, Object?>;
    textNodeMap['text'] = 'Auto-derived size from decode';
    textNodeMap['fontSize'] = 28.0;
    textNodeMap['size'] = <String, Object?>{'w': 1.0, 'h': 1.0};
    textNodeMap['maxWidth'] = null;

    final decoded = decodeScene(encoded);
    final decodedText = decoded.layers[1].nodes[1] as TextNodeSnapshot;
    final expectedSize = TextLayoutRequest(
      text: decodedText.text,
      color: decodedText.color,
      fontSize: decodedText.fontSize,
      isBold: decodedText.isBold,
      isItalic: decodedText.isItalic,
      isUnderline: decodedText.isUnderline,
      textAlign: decodedText.align,
      fontFamily: decodedText.fontFamily,
      lineHeight: decodedText.lineHeight,
      maxWidth: decodedText.maxWidth,
    ).measure();

    expect(decodedText.size, expectedSize);
    expect(decodedText.size, isNot(const Size(1, 1)));
  });
}

SceneSnapshot _buildScene() {
  final textLayout = TextLayoutRequest(
    text: 'Hello',
    color: const Color(0xFF112233),
    fontSize: 24,
    isBold: true,
    isItalic: false,
    isUnderline: true,
    textAlign: TextAlign.center,
    fontFamily: 'Roboto',
    lineHeight: 1.2,
    maxWidth: 200,
  );
  final derivedTextSize = textLayout.measure();

  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(id: 'layer-auto-1'),
      ContentLayerSnapshot(
        id: 'layer-auto-2',
        nodes: <NodeSnapshot>[
          ImageNodeSnapshot(
            id: 'img-1',
            imageId: 'asset:sample',
            size: const Size(100, 80),
            naturalSize: const Size(200, 160),
            transform: Transform2D.trs(
              translation: const Offset(10, 20),
              rotationDeg: 90,
              scaleX: 1,
              scaleY: -1,
            ),
            opacity: 0.8,
            isVisible: true,
            isSelectable: true,
            isLocked: false,
            isDeletable: true,
            isTransformable: true,
          ),
          TextNodeSnapshot(
            id: 'text-1',
            text: 'Hello',
            size: derivedTextSize,
            fontSize: 24,
            color: const Color(0xFF112233),
            align: TextAlign.center,
            isBold: true,
            isItalic: false,
            isUnderline: true,
            fontFamily: 'Roboto',
            maxWidth: 200,
            lineHeight: 1.2,
            transform: Transform2D.trs(
              translation: const Offset(50, 50),
              rotationDeg: -90,
              scaleX: 1.5,
              scaleY: 0.5,
            ),
            opacity: 0.9,
            isVisible: true,
            isSelectable: true,
            isLocked: false,
            isDeletable: true,
            isTransformable: true,
          ),
          StrokeNodeSnapshot(
            id: 'stroke-1',
            points: const <Offset>[Offset(0, 0), Offset(10, 10)],
            thickness: 3,
            color: Color(0xFF000000),
            opacity: 0.4,
          ),
          LineNodeSnapshot(
            id: 'line-1',
            start: Offset(5, 5),
            end: Offset(15, 15),
            thickness: 5,
            color: Color(0xFF00FF00),
          ),
          RectNodeSnapshot(
            id: 'rect-1',
            size: const Size(50, 60),
            fillColor: const Color(0xFFFF0000),
            strokeColor: const Color(0xFF0000FF),
            strokeWidth: 2,
            transform: Transform2D.translation(const Offset(-10, -20)),
          ),
          PathNodeSnapshot(
            id: 'path-1',
            svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
            fillColor: Color(0xFF4CAF50),
            strokeColor: Color(0xFF1B5E20),
            strokeWidth: 2,
            fillRule: PathFillRule.evenOdd,
            transform: Transform2D.translation(Offset(100, -40)),
          ),
        ],
      ),
    ],
    camera: const CameraSnapshot(offset: Offset(7, -3)),
    background: const BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0x1F000000),
      ),
    ),
    palette: ScenePaletteSnapshot(
      penColors: const <Color>[Color(0xFF000000), Color(0xFFE53935)],
      backgroundColors: const <Color>[Color(0xFFFFFFFF)],
      gridSizes: const <double>[10, 20],
    ),
  );
}
