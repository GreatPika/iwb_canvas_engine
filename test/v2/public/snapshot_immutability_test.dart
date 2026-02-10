import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic_v2.dart';

// INV:INV-V2-NO-EXTERNAL-MUTATION

void main() {
  test('SceneSnapshot and LayerSnapshot defensively copy and freeze lists', () {
    final sourceNodes = <NodeSnapshot>[
      const RectNodeSnapshot(id: 'rect-1', size: Size(10, 20)),
    ];
    final layer = LayerSnapshot(nodes: sourceNodes);
    sourceNodes.add(const RectNodeSnapshot(id: 'rect-2', size: Size(1, 1)));

    expect(layer.nodes.length, 1);
    expect(
      () => layer.nodes.add(
        const RectNodeSnapshot(id: 'rect-3', size: Size(1, 1)),
      ),
      throwsUnsupportedError,
    );

    final sourceLayers = <LayerSnapshot>[layer];
    final scene = SceneSnapshot(layers: sourceLayers);
    sourceLayers.add(LayerSnapshot());

    expect(scene.layers.length, 1);
    expect(() => scene.layers.add(LayerSnapshot()), throwsUnsupportedError);

    final defaultScene = SceneSnapshot();
    expect(defaultScene.layers, isEmpty);
  });

  test('ScenePaletteSnapshot defensively copies and freezes lists', () {
    final sourcePen = <Color>[const Color(0xFF111111)];
    final sourceBackground = <Color>[const Color(0xFF222222)];
    final sourceGrid = <double>[16];

    final palette = ScenePaletteSnapshot(
      penColors: sourcePen,
      backgroundColors: sourceBackground,
      gridSizes: sourceGrid,
    );

    sourcePen.add(const Color(0xFF000000));
    sourceBackground.add(const Color(0xFFFFFFFF));
    sourceGrid.add(32);

    expect(palette.penColors, hasLength(1));
    expect(palette.backgroundColors, hasLength(1));
    expect(palette.gridSizes, hasLength(1));
    expect(
      () => palette.penColors.add(const Color(0xFF333333)),
      throwsUnsupportedError,
    );
    expect(
      () => palette.backgroundColors.add(const Color(0xFF444444)),
      throwsUnsupportedError,
    );
    expect(() => palette.gridSizes.add(8), throwsUnsupportedError);

    final defaultPalette = ScenePaletteSnapshot();
    expect(defaultPalette.penColors, isNotEmpty);
    expect(defaultPalette.backgroundColors, isNotEmpty);
    expect(defaultPalette.gridSizes, isNotEmpty);
  });

  test('StrokeNodeSnapshot defensively copies and freezes points', () {
    final sourcePoints = <Offset>[const Offset(1, 2), const Offset(3, 4)];

    final stroke = StrokeNodeSnapshot(
      id: 'stroke-1',
      points: sourcePoints,
      thickness: 3,
      color: const Color(0xFFABCDEF),
    );

    sourcePoints.add(const Offset(5, 6));

    expect(stroke.points.length, 2);
    expect(() => stroke.points.add(const Offset(7, 8)), throwsUnsupportedError);
  });

  test('NodeSnapshot variants keep provided immutable values', () {
    const transform = Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 20);

    const image = ImageNodeSnapshot(
      id: 'img-1',
      imageId: 'image://1',
      size: Size(100, 80),
      naturalSize: Size(200, 160),
      transform: transform,
      opacity: 0.7,
      hitPadding: 2,
      isVisible: false,
      isSelectable: false,
      isLocked: true,
      isDeletable: false,
      isTransformable: false,
    );

    const text = TextNodeSnapshot(
      id: 'txt-1',
      text: 'hello',
      size: Size(50, 20),
      fontSize: 18,
      color: Color(0xFF0000FF),
      align: TextAlign.center,
      isBold: true,
      isItalic: true,
      isUnderline: true,
      fontFamily: 'Mono',
      maxWidth: 120,
      lineHeight: 1.3,
    );

    const line = LineNodeSnapshot(
      id: 'line-1',
      start: Offset(0, 0),
      end: Offset(10, 10),
      thickness: 2,
      color: Color(0xFF00FF00),
    );

    const rect = RectNodeSnapshot(
      id: 'rect-1',
      size: Size(40, 30),
      fillColor: Color(0xFFFF0000),
      strokeColor: Color(0xFF000000),
      strokeWidth: 1.5,
    );

    const path = PathNodeSnapshot(
      id: 'path-1',
      svgPathData: 'M0 0 L10 10',
      fillColor: Color(0xFF123456),
      strokeColor: Color(0xFF654321),
      strokeWidth: 2.5,
      fillRule: V2PathFillRule.evenOdd,
    );

    expect(image.imageId, 'image://1');
    expect(image.transform.tx, 10);
    expect(image.isTransformable, isFalse);
    expect(text.align, TextAlign.center);
    expect(text.fontFamily, 'Mono');
    expect(line.end, const Offset(10, 10));
    expect(rect.strokeWidth, 1.5);
    expect(path.fillRule, V2PathFillRule.evenOdd);
  });

  test('Scene-level snapshot value objects are configurable and immutable', () {
    const camera = CameraSnapshot(offset: Offset(3, 4));
    const grid = GridSnapshot(
      isEnabled: true,
      cellSize: 24,
      color: Color(0xFF101010),
    );
    const background = BackgroundSnapshot(color: Color(0xFFFAFAFA), grid: grid);

    final scene = SceneSnapshot(
      camera: camera,
      background: background,
      layers: <LayerSnapshot>[LayerSnapshot()],
      palette: ScenePaletteSnapshot(
        penColors: <Color>[Color(0xFF111111)],
        backgroundColors: <Color>[Color(0xFFEEEEEE)],
        gridSizes: <double>[24],
      ),
    );

    expect(scene.camera.offset, const Offset(3, 4));
    expect(scene.background.grid.isEnabled, isTrue);
    expect(scene.background.color, const Color(0xFFFAFAFA));
  });

  test('Node snapshot constructors execute in runtime (non-const path)', () {
    final image = ImageNodeSnapshot(
      id: 'i-runtime',
      imageId: 'image://runtime',
      size: const Size(10, 10),
      naturalSize: const Size(20, 20),
    );
    final text = TextNodeSnapshot(
      id: 't-runtime',
      text: 'runtime',
      size: const Size(10, 10),
      color: const Color(0xFF010203),
    );
    final line = LineNodeSnapshot(
      id: 'l-runtime',
      start: const Offset(0, 0),
      end: const Offset(2, 2),
      thickness: 1,
      color: const Color(0xFF040506),
    );
    final path = PathNodeSnapshot(id: 'p-runtime', svgPathData: 'M0 0 L2 2');

    expect(image.naturalSize, const Size(20, 20));
    expect(text.text, 'runtime');
    expect(line.end, const Offset(2, 2));
    expect(path.svgPathData, 'M0 0 L2 2');
  });
}
