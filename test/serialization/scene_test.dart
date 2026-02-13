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
      () => scene.layers.add(ContentLayerSnapshot()),
      throwsUnsupportedError,
    );
    expect(
      () => scene.layers.first.nodes.add(
        const RectNodeSnapshot(id: 'extra', size: Size(1, 1)),
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
      final layers = encoded['layers'] as List<dynamic>;
      final layer = layers[1] as Map<String, dynamic>;
      final nodes = layer['nodes'] as List<dynamic>;
      final firstNode = nodes.first as Map<String, dynamic>;
      firstNode.remove('instanceRevision');

      final decoded = decodeScene(encoded);
      final reEncoded = encodeScene(decoded);
      final reEncodedLayers = reEncoded['layers'] as List<dynamic>;
      final reEncodedLayer = reEncodedLayers[1] as Map<String, dynamic>;
      final reEncodedNodes = reEncodedLayer['nodes'] as List<dynamic>;
      final reEncodedFirstNode = reEncodedNodes.first as Map<String, dynamic>;

      expect(reEncodedFirstNode['instanceRevision'], isA<int>());
      expect(reEncodedFirstNode['instanceRevision'], greaterThanOrEqualTo(1));
    },
  );

  test('decodeScene recomputes derived text size from content', () {
    final encoded = encodeScene(_buildScene());
    final textNode =
        (encoded['layers'] as List<dynamic>)[1]['nodes'][1]
            as Map<String, dynamic>;
    textNode['text'] = 'Auto-derived size from decode';
    textNode['fontSize'] = 28.0;
    textNode['size'] = <String, dynamic>{'w': 1.0, 'h': 1.0};
    textNode['maxWidth'] = null;

    final decoded = decodeScene(encoded);
    final decodedText = decoded.layers[1].nodes[1] as TextNodeSnapshot;
    final expectedSize = measureTextLayoutSize(
      text: decodedText.text,
      textStyle: buildTextStyleForTextLayout(
        color: decodedText.color,
        fontSize: decodedText.fontSize,
        isBold: decodedText.isBold,
        isItalic: decodedText.isItalic,
        isUnderline: decodedText.isUnderline,
        fontFamily: decodedText.fontFamily,
        lineHeight: decodedText.lineHeight,
      ),
      textAlign: decodedText.align,
      maxWidth: decodedText.maxWidth,
    );

    expect(decodedText.size, expectedSize);
    expect(decodedText.size, isNot(const Size(1, 1)));
  });
}

SceneSnapshot _buildScene() {
  final textStyle = buildTextStyleForTextLayout(
    color: const Color(0xFF112233),
    fontSize: 24,
    isBold: true,
    isItalic: false,
    isUnderline: true,
    fontFamily: 'Roboto',
    lineHeight: 1.2,
  );
  final derivedTextSize = measureTextLayoutSize(
    text: 'Hello',
    textStyle: textStyle,
    textAlign: TextAlign.center,
    maxWidth: 200,
  );

  return SceneSnapshot(
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(),
      ContentLayerSnapshot(
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
          const LineNodeSnapshot(
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
            fillRule: V2PathFillRule.evenOdd,
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
