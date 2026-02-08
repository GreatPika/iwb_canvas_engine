import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart'
    as render_internal;

Future<Image> _solidImage(Color color, {int width = 8, int height = 8}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

SceneController _controllerFor(
  Scene scene, {
  Set<NodeId> selectedNodeIds = const <NodeId>{},
  Rect? selectionRect,
}) {
  final controller = SceneController(scene: scene);
  controller.debugSetSelection(selectedNodeIds);
  controller.debugSetSelectionRect(selectionRect);
  addTearDown(controller.dispose);
  return controller;
}

Future<Image> _paintToImage(
  ScenePainter painter, {
  int width = 96,
  int height = 96,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

Future<int> _countNonBackgroundPixels(Image image, Color background) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  final bytes = data.buffer.asUint8List();
  final argb = background.toARGB32();
  final bgA = (argb >> 24) & 0xFF;
  final bgR = (argb >> 16) & 0xFF;
  final bgG = (argb >> 8) & 0xFF;
  final bgB = argb & 0xFF;

  var count = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] != bgR ||
        bytes[i + 1] != bgG ||
        bytes[i + 2] != bgB ||
        bytes[i + 3] != bgA) {
      count++;
    }
  }
  return count;
}

Future<Color> _pixelAt(Image image, int x, int y) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  if (x < 0 || x >= image.width) {
    throw RangeError.range(x, 0, image.width - 1, 'x');
  }
  if (y < 0 || y >= image.height) {
    throw RangeError.range(y, 0, image.height - 1, 'y');
  }
  final bytes = data.buffer.asUint8List();
  final index = (y * image.width + x) * 4;
  return Color.fromARGB(
    bytes[index + 3],
    bytes[index],
    bytes[index + 1],
    bytes[index + 2],
  );
}

Future<double> _inkCentroidY(Image image, Color background) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  final bytes = data.buffer.asUint8List();
  final argb = background.toARGB32();
  final bgR = (argb >> 16) & 0xFF;
  final bgG = (argb >> 8) & 0xFF;
  final bgB = argb & 0xFF;

  double weightedY = 0;
  double totalInk = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final index = (y * image.width + x) * 4;
      final dr = (bytes[index] - bgR).abs();
      final dg = (bytes[index + 1] - bgG).abs();
      final db = (bytes[index + 2] - bgB).abs();
      final ink = (dr + dg + db).toDouble();
      if (ink <= 0) continue;
      weightedY += y * ink;
      totalInk += ink;
    }
  }
  if (totalInk == 0) {
    throw StateError('Expected non-background pixels.');
  }
  return weightedY / totalInk;
}

Future<double> _inkCentroidX(Image image, Color background) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  final bytes = data.buffer.asUint8List();
  final argb = background.toARGB32();
  final bgR = (argb >> 16) & 0xFF;
  final bgG = (argb >> 8) & 0xFF;
  final bgB = argb & 0xFF;

  double weightedX = 0;
  double totalInk = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final index = (y * image.width + x) * 4;
      final dr = (bytes[index] - bgR).abs();
      final dg = (bytes[index + 1] - bgG).abs();
      final db = (bytes[index + 2] - bgB).abs();
      final ink = (dr + dg + db).toDouble();
      if (ink <= 0) continue;
      weightedX += x * ink;
      totalInk += ink;
    }
  }
  if (totalInk == 0) {
    throw StateError('Expected non-background pixels.');
  }
  return weightedX / totalInk;
}

Future<List<int>> _rawRgbaBytes(Image image) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }
  return data.buffer.asUint8List();
}

class _EmptyMetricsPathNode extends PathNode {
  _EmptyMetricsPathNode({required super.id, required super.svgPathData});

  @override
  Path? buildLocalPath({bool copy = true}) {
    return Path();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ScenePainter paints without throwing', () {
    final scene = Scene(
      layers: [
        Layer(
          nodes: [
            RectNode(
              id: 'rect-1',
              size: const Size(100, 80),
              fillColor: const Color(0xFF2196F3),
            )..position = const Offset(150, 150),
            PathNode(
              id: 'path-1',
              svgPathData: 'M0 0 H40 V30 H0 Z',
              fillColor: const Color(0xFF4CAF50),
              fillRule: PathFillRule.nonZero,
            )..position = const Offset(60, 60),
          ],
        ),
      ],
      background: Background(
        color: const Color(0xFFFFFFFF),
        grid: GridSettings(
          isEnabled: true,
          cellSize: 20,
          color: const Color(0x1F000000),
        ),
      ),
    );

    final painter = ScenePainter(
      controller: _controllerFor(
        scene,
        selectedNodeIds: const {'rect-1'},
        selectionRect: const Rect.fromLTWH(10, 10, 50, 40),
      ),
      imageResolver: (_) => null,
    );

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(300, 300));
    recorder.endRecording();
  });

  test(
    'ScenePainter paints with invalid numeric fields without throwing',
    () async {
      // INV:INV-CORE-RUNTIME-NUMERIC-SANITIZATION
      const background = Color(0xFFFFFFFF);
      final nonFiniteTransformNode = RectNode(
        id: 'rect-nonfinite-transform',
        size: const Size(10, 10),
        fillColor: const Color(0xFF2196F3),
      )..transform = Transform2D(a: 1, b: 0, c: 0, d: 1, tx: double.nan, ty: 0);

      final scene = Scene(
        camera: Camera(offset: const Offset(0, 0)),
        background: Background(
          color: background,
          grid: GridSettings(
            isEnabled: true,
            cellSize: 10,
            color: const Color(0x1F000000),
          ),
        ),
        layers: [
          Layer(
            nodes: [
              RectNode(
                id: 'rect-1',
                size: const Size(double.infinity, double.nan),
                fillColor: const Color(0xFF4CAF50),
                strokeColor: const Color(0xFF000000),
                strokeWidth: double.infinity,
                opacity: double.nan,
                hitPadding: double.nan,
              )..position = const Offset(20, 20),
              LineNode(
                id: 'line-1',
                start: const Offset(0, 0),
                end: const Offset(40, 0),
                thickness: double.nan,
                color: const Color(0xFF000000),
                opacity: double.infinity,
              )..position = const Offset(10, 40),
              StrokeNode(
                id: 'stroke-1',
                points: const [Offset(0, 0), Offset(10, 10)],
                thickness: double.infinity,
                color: const Color(0xFF000000),
                opacity: double.nan,
              )..position = const Offset(40, 40),
              nonFiniteTransformNode,
            ],
          ),
        ],
      );
      final controller = _controllerFor(scene);
      // Deliberately break runtime values after constructor validation.
      scene.camera.offset = const Offset(double.infinity, double.nan);
      scene.background.grid.cellSize = double.nan;

      final painter = ScenePainter(
        controller: controller,
        imageResolver: (_) => null,
        selectionStrokeWidth: double.nan,
        gridStrokeWidth: double.nan,
      );
      controller.debugSetSelection(const {
        'rect-1',
        'line-1',
        'stroke-1',
        'rect-nonfinite-transform',
      });
      controller.debugSetSelectionRect(const Rect.fromLTWH(10, 10, 50, 40));

      final image = await _paintToImage(painter);
      expect(image.width, greaterThan(0));
    },
  );

  test('ScenePainter draws grid, selection overlays, and marquee', () async {
    const background = Color(0xFFFFFFFF);
    final scene = Scene(
      camera: Camera(offset: const Offset(5, -3)),
      background: Background(
        color: background,
        grid: GridSettings(
          isEnabled: true,
          cellSize: 10,
          color: const Color(0xFF000000),
        ),
      ),
      layers: [
        Layer(
          nodes: [
            RectNode(
              id: 'a',
              size: const Size(10, 10),
              fillColor: const Color(0xFF2196F3),
            )..position = const Offset(20, 20),
            RectNode(
              id: 'b',
              size: const Size(10, 10),
              fillColor: const Color(0xFF4CAF50),
            )..position = const Offset(40, 20),
          ],
        ),
      ],
    );

    final painter = ScenePainter(
      controller: _controllerFor(
        scene,
        selectedNodeIds: const {'a', 'b'},
        selectionRect: const Rect.fromLTRB(70, 70, 30, 50),
      ),
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
    );

    final image = await _paintToImage(painter);
    final nonBg = await _countNonBackgroundPixels(image, background);
    expect(nonBg, greaterThan(0));
  });

  test('ScenePainter skips grid when cellSize is below minimum', () async {
    // INV:INV-RENDER-GRID-SAFETY-LIMITS
    const background = Color(0xFFFFFFFF);
    final scene = Scene(
      background: Background(
        color: background,
        grid: GridSettings(
          isEnabled: true,
          cellSize: 10,
          color: const Color(0xFF000000),
        ),
      ),
      layers: [Layer()],
    );
    final controller = _controllerFor(scene);
    scene.background.grid.cellSize = 0.5;

    final painter = ScenePainter(
      controller: controller,
      imageResolver: (_) => null,
    );

    final image = await _paintToImage(painter, width: 120, height: 80);
    final nonBg = await _countNonBackgroundPixels(image, background);
    expect(nonBg, 0);
  });

  test('grid line count fallback handles non-finite inputs', () {
    expect(
      render_internal.debugGridLineCount(0, double.nan, 10),
      greaterThan(200),
    );
  });

  test('ScenePainter skips grid when camera offset is non-finite', () async {
    final scene = Scene(
      camera: Camera(offset: const Offset(0, 0)),
      background: Background(
        color: const Color(0xFFFFFFFF),
        grid: GridSettings(
          isEnabled: true,
          cellSize: 10,
          color: const Color(0xFF000000),
        ),
      ),
      layers: [Layer()],
    );
    final controller = _controllerFor(scene);
    scene.camera.offset = const Offset(double.nan, 0);

    final painter = ScenePainter(
      controller: controller,
      imageResolver: (_) => null,
    );

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(120, 80));
    recorder.endRecording();
  });

  test(
    'ScenePainter skips grid when expected line count exceeds safety cap',
    () async {
      // INV:INV-RENDER-GRID-SAFETY-LIMITS
      const background = Color(0xFFFFFFFF);
      final scene = Scene(
        background: Background(
          color: background,
          grid: GridSettings(
            isEnabled: true,
            cellSize: 1,
            color: const Color(0xFF000000),
          ),
        ),
        layers: [Layer()],
      );

      final painter = ScenePainter(
        controller: _controllerFor(scene),
        imageResolver: (_) => null,
      );

      final image = await _paintToImage(painter, width: 320, height: 80);
      final nonBg = await _countNonBackgroundPixels(image, background);
      expect(nonBg, 0);
    },
  );

  test(
    'ScenePainter uses TextNode maxWidth and lineHeight when valid',
    () async {
      // INV:INV-CORE-RUNTIME-NUMERIC-SANITIZATION
      const background = Color(0xFFFFFFFF);
      final scene = Scene(
        background: Background(color: background),
        layers: [
          Layer(
            nodes: [
              TextNode(
                id: 't1',
                text: 'Hello world',
                size: const Size(80, 30),
                fontSize: 12,
                maxWidth: 40,
                lineHeight: 18,
                color: const Color(0xFF000000),
              )..position = const Offset(20, 20),
            ],
          ),
        ],
      );

      final painter = ScenePainter(
        controller: _controllerFor(scene, selectedNodeIds: const {'t1'}),
        imageResolver: (_) => null,
        textLayoutCache: SceneTextLayoutCache(maxEntries: 8),
      );

      final image = await _paintToImage(painter, width: 120, height: 80);
      final nonBg = await _countNonBackgroundPixels(image, background);
      expect(nonBg, greaterThan(0));
    },
  );

  test('ScenePainter selection halo stays outside line geometry', () async {
    const background = Color(0xFFFFFFFF);
    final line = LineNode(
      id: 'line',
      start: const Offset(10, 20),
      end: const Offset(90, 20),
      thickness: 6,
      color: background,
    );
    final scene = Scene(
      background: Background(color: background),
      layers: [
        Layer(nodes: [line]),
      ],
    );

    final painter = ScenePainter(
      controller: _controllerFor(scene, selectedNodeIds: const {'line'}),
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
    );

    final image = await _paintToImage(painter, width: 100, height: 80);
    final onLine = await _pixelAt(image, 50, 20);
    final onHalo = await _pixelAt(image, 50, 24);
    final outside = await _pixelAt(image, 50, 27);

    expect(onLine, equals(background));
    expect(onHalo, isNot(background));
    expect(outside, equals(background));
  });

  test('ScenePainter selection renders for text nodes', () async {
    const background = Color(0xFFFFFFFF);
    final textNode = TextNode(
      id: 'text-1',
      text: 'Halo',
      size: const Size(60, 24),
      fontSize: 18,
      color: const Color(0xFF000000),
    )..position = const Offset(40, 40);

    final scene = Scene(
      background: Background(color: background),
      layers: [
        Layer(nodes: [textNode]),
      ],
    );

    final painter = ScenePainter(
      controller: _controllerFor(scene, selectedNodeIds: const {'text-1'}),
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
    );

    final image = await _paintToImage(painter, width: 120, height: 90);
    final nonBg = await _countNonBackgroundPixels(image, background);
    expect(nonBg, greaterThan(0));
  });

  test(
    'P1: ScenePainter uses stroke path cache for stroke paint + selection',
    () async {
      const background = Color(0xFFFFFFFF);
      final stroke = StrokeNode(
        id: 'stroke-1',
        points: const [Offset(10, 10), Offset(80, 10)],
        thickness: 6,
        color: const Color(0xFF000000),
      );
      final scene = Scene(
        background: Background(color: background),
        layers: [
          Layer(nodes: [stroke]),
        ],
      );
      final cache = SceneStrokePathCache(maxEntries: 8);

      final painter = ScenePainter(
        controller: _controllerFor(scene, selectedNodeIds: const {'stroke-1'}),
        imageResolver: (_) => null,
        strokePathCache: cache,
        selectionColor: const Color(0xFFFF0000),
        selectionStrokeWidth: 2,
      );

      await _paintToImage(painter, width: 100, height: 60);

      expect(cache.debugBuildCount, 1);
      expect(cache.debugHitCount, 1);
      expect(cache.debugSize, 1);
    },
  );

  test('ScenePainter selection keeps line color intact', () async {
    const background = Color(0xFFFFFFFF);
    const lineColor = Color(0xFF000000);
    final line = LineNode(
      id: 'line',
      start: const Offset(10, 20),
      end: const Offset(90, 20),
      thickness: 6,
      color: lineColor,
    );
    final scene = Scene(
      background: Background(color: background),
      layers: [
        Layer(nodes: [line]),
      ],
    );

    final painter = ScenePainter(
      controller: _controllerFor(scene, selectedNodeIds: const {'line'}),
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
    );

    final image = await _paintToImage(painter, width: 100, height: 80);
    final onLine = await _pixelAt(image, 50, 20);
    final onHalo = await _pixelAt(image, 50, 24);

    expect(onLine, equals(lineColor));
    expect(onHalo, isNot(lineColor));
  });

  test('ScenePainter selection halo skips inner path contours', () async {
    const background = Color(0xFFFFFFFF);
    final pathNode = PathNode(
      id: 'path',
      svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
      fillRule: PathFillRule.evenOdd,
      fillColor: const Color(0xFF81C784),
      strokeColor: const Color(0xFF2E7D32),
      strokeWidth: 2,
    )..position = const Offset(50, 50);

    final scene = Scene(
      background: Background(color: background),
      layers: [
        Layer(nodes: [pathNode]),
      ],
    );

    final painter = ScenePainter(
      controller: _controllerFor(scene, selectedNodeIds: const {'path'}),
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 3,
    );

    final image = await _paintToImage(painter, width: 100, height: 100);
    final insideHole = await _pixelAt(image, 50, 50);
    final outsideHalo = await _pixelAt(image, 27, 50);

    expect(insideHole, equals(background));
    expect(outsideHalo, isNot(background));
  });

  test('ScenePainter selection renders multiple closed contours', () async {
    const background = Color(0xFFFFFFFF);
    final pathNode = PathNode(
      id: 'path-multi',
      svgPathData: 'M0 0 H20 V20 H0 Z M40 0 H60 V20 H40 Z',
      strokeColor: const Color(0xFF000000),
      strokeWidth: 2,
      fillRule: PathFillRule.nonZero,
    )..position = const Offset(50, 50);

    final scene = Scene(
      background: Background(color: background),
      layers: [
        Layer(nodes: [pathNode]),
      ],
    );

    final painter = ScenePainter(
      controller: _controllerFor(scene, selectedNodeIds: const {'path-multi'}),
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 3,
    );

    final image = await _paintToImage(painter, width: 120, height: 90);
    final leftHalo = await _pixelAt(image, 18, 50);
    final rightHalo = await _pixelAt(image, 58, 50);

    expect(leftHalo, isNot(background));
    expect(rightHalo, isNot(background));
  });

  test('ScenePainter resolves TextAlign.start by textDirection', () async {
    // INV:INV-RENDER-TEXT-DIRECTION-ALIGNMENT
    const background = Color(0xFFFFFFFF);
    Scene sceneFor(TextDirection direction) => Scene(
      background: Background(color: background),
      layers: [
        Layer(
          nodes: [
            TextNode(
              id: 'text-start-$direction',
              text: 'Start',
              size: const Size(120, 28),
              fontSize: 20,
              color: const Color(0xFF000000),
              align: TextAlign.start,
            )..position = const Offset(80, 40),
          ],
        ),
      ],
    );

    final ltrImage = await _paintToImage(
      ScenePainter(
        controller: _controllerFor(sceneFor(TextDirection.ltr)),
        imageResolver: (_) => null,
        textDirection: TextDirection.ltr,
      ),
      width: 160,
      height: 80,
    );
    final rtlImage = await _paintToImage(
      ScenePainter(
        controller: _controllerFor(sceneFor(TextDirection.rtl)),
        imageResolver: (_) => null,
        textDirection: TextDirection.rtl,
      ),
      width: 160,
      height: 80,
    );

    final ltrCenterX = await _inkCentroidX(ltrImage, background);
    final rtlCenterX = await _inkCentroidX(rtlImage, background);
    expect(rtlCenterX, greaterThan(ltrCenterX));
  });

  test('ScenePainter resolves TextAlign.end by textDirection', () async {
    // INV:INV-RENDER-TEXT-DIRECTION-ALIGNMENT
    const background = Color(0xFFFFFFFF);
    Scene sceneFor(TextDirection direction) => Scene(
      background: Background(color: background),
      layers: [
        Layer(
          nodes: [
            TextNode(
              id: 'text-end-$direction',
              text: 'End',
              size: const Size(120, 28),
              fontSize: 20,
              color: const Color(0xFF000000),
              align: TextAlign.end,
            )..position = const Offset(80, 40),
          ],
        ),
      ],
    );

    final ltrImage = await _paintToImage(
      ScenePainter(
        controller: _controllerFor(sceneFor(TextDirection.ltr)),
        imageResolver: (_) => null,
        textDirection: TextDirection.ltr,
      ),
      width: 160,
      height: 80,
    );
    final rtlImage = await _paintToImage(
      ScenePainter(
        controller: _controllerFor(sceneFor(TextDirection.rtl)),
        imageResolver: (_) => null,
        textDirection: TextDirection.rtl,
      ),
      width: 160,
      height: 80,
    );

    final ltrCenterX = await _inkCentroidX(ltrImage, background);
    final rtlCenterX = await _inkCentroidX(rtlImage, background);
    expect(rtlCenterX, lessThan(ltrCenterX));
  });

  test(
    'ScenePainter selection halo honors PathNode.fillRule for inner contour',
    () async {
      // INV:INV-RENDER-PATH-SELECTION-FILLRULE
      final evenOddPath = PathNode(
        id: 'path-even-odd',
        svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
        fillRule: PathFillRule.evenOdd,
      )..position = const Offset(50, 50);
      final nonZeroPath = PathNode(
        id: 'path-non-zero',
        svgPathData: 'M0 0 H40 V30 H0 Z M12 8 H28 V22 H12 Z',
        fillRule: PathFillRule.nonZero,
      )..position = const Offset(50, 50);

      Future<Image> renderSelectedPath(PathNode node) async {
        final scene = Scene(
          background: Background(color: const Color(0xFFFFFFFF)),
          layers: [
            Layer(nodes: [node]),
          ],
        );
        return _paintToImage(
          ScenePainter(
            controller: _controllerFor(scene, selectedNodeIds: {node.id}),
            imageResolver: (_) => null,
            selectionColor: const Color(0xFFFF0000),
            selectionStrokeWidth: 3,
          ),
          width: 100,
          height: 100,
        );
      }

      final evenOddImage = await renderSelectedPath(evenOddPath);
      final nonZeroImage = await renderSelectedPath(nonZeroPath);
      final evenOddBytes = await _rawRgbaBytes(evenOddImage);
      final nonZeroBytes = await _rawRgbaBytes(nonZeroImage);

      expect(evenOddBytes.length, equals(nonZeroBytes.length));
      final differs = evenOddBytes.asMap().entries.any(
        (entry) => entry.value != nonZeroBytes[entry.key],
      );
      expect(differs, isTrue);
    },
  );

  test(
    'ScenePainter draws all node variants and respects visibility',
    () async {
      const background = Color(0xFFFFFFFF);
      final imageNodePlaceholder = ImageNode(
        id: 'img-null',
        imageId: 'img:null',
        size: const Size(20, 12),
      )..position = const Offset(20, 20);

      final hiddenImage = ImageNode(
        id: 'img-hidden',
        imageId: 'img:hidden',
        size: const Size(10, 10),
        isVisible: false,
      )..position = const Offset(80, 10);

      final resolvedImage = await _solidImage(const Color(0xFFFF00FF));
      final imageNodeResolved =
          ImageNode(
              id: 'img-ok',
              imageId: 'img:ok',
              size: const Size(16, 16),
              opacity: 2,
            )
            ..position = const Offset(70, 20)
            ..rotationDeg = 45
            ..scaleX = -1
            ..scaleY = 1.2;

      final textNode =
          TextNode(
              id: 'text',
              text: 'Hello',
              size: const Size(60, 24),
              fontSize: 18,
              color: const Color(0xFF000000),
              align: TextAlign.end,
              isBold: true,
              isItalic: true,
              isUnderline: true,
              lineHeight: 22,
            )
            ..position = const Offset(40, 70)
            ..rotationDeg = -15
            ..scaleX = 1.1
            ..scaleY = 0.9;

      final centeredText = TextNode(
        id: 'text-center',
        text: 'Center',
        size: const Size(60, 24),
        fontSize: 18,
        color: const Color(0xFF000000),
        align: TextAlign.center,
      )..position = const Offset(10, 70);

      final startText = TextNode(
        id: 'text-start',
        text: 'Start',
        size: const Size(60, 24),
        fontSize: 18,
        color: const Color(0xFF000000),
        align: TextAlign.start,
      )..position = const Offset(70, 70);

      final justifyText = TextNode(
        id: 'text-justify',
        text: 'Justify',
        size: const Size(60, 24),
        fontSize: 18,
        color: const Color(0xFF000000),
        align: TextAlign.justify,
      )..position = const Offset(90, 70);

      final emptyStroke = StrokeNode(
        id: 'stroke-empty',
        points: const <Offset>[],
        thickness: 4,
        color: const Color(0xFF000000),
      );

      final singlePointStroke = StrokeNode(
        id: 'stroke-single',
        points: const [Offset(10, 90)],
        thickness: 10,
        color: const Color(0xFF00BCD4),
      );

      final stroke = StrokeNode(
        id: 'stroke',
        points: const [Offset(5, 55), Offset(20, 55), Offset(20, 80)],
        thickness: 6,
        color: const Color(0xFF8E24AA),
      );

      final line = LineNode(
        id: 'line',
        start: const Offset(60, 60),
        end: const Offset(90, 90),
        thickness: 4,
        color: const Color(0xFFE53935),
      );

      final rect = RectNode(
        id: 'rect',
        size: const Size(30, 20),
        fillColor: const Color(0xFF43A047),
        strokeColor: const Color(0xFF1E88E5),
        strokeWidth: 3,
      )..position = const Offset(20, 45);

      final emptyPath = PathNode(id: 'path-empty', svgPathData: '   ');
      final invalidPath = PathNode(
        id: 'path-invalid',
        svgPathData: 'not-a-path',
      )..position = const Offset(80, 70);
      final path =
          PathNode(
              id: 'path',
              svgPathData: 'M0 0 H30 V20 H0 Z',
              fillColor: const Color(0xFFFFC107),
              strokeColor: const Color(0xFF000000),
              strokeWidth: 2,
              fillRule: PathFillRule.nonZero,
            )
            ..position = const Offset(80, 40)
            ..rotationDeg = 10
            ..scaleX = 1.2
            ..scaleY = 0.8;

      var resolveCalls = 0;
      Image? resolver(String imageId) {
        resolveCalls++;
        if (imageId == 'img:ok') return resolvedImage;
        return null;
      }

      final scene = Scene(
        background: Background(color: background),
        layers: [
          Layer(
            nodes: [
              imageNodePlaceholder,
              hiddenImage,
              imageNodeResolved,
              textNode,
              centeredText,
              startText,
              justifyText,
              emptyStroke,
              singlePointStroke,
              stroke,
              line,
              rect,
              emptyPath,
              invalidPath,
              path,
            ],
          ),
        ],
      );

      final painter = ScenePainter(
        controller: _controllerFor(
          scene,
          selectedNodeIds: const {'rect'},
          selectionRect: const Rect.fromLTRB(10, 90, 30, 80),
        ),
        imageResolver: resolver,
      );

      final image = await _paintToImage(painter);
      final nonBg = await _countNonBackgroundPixels(image, background);
      expect(nonBg, greaterThan(0));
      expect(resolveCalls, 2);
    },
  );

  test('ScenePainter.shouldRepaint compares controller and styles', () {
    final scene = Scene();
    Image? resolveNullImage(String _) => null;
    final controllerA = SceneController(scene: scene);
    addTearDown(controllerA.dispose);
    final painterA = ScenePainter(
      controller: controllerA,
      imageResolver: resolveNullImage,
    );
    final painterB = ScenePainter(
      controller: controllerA,
      imageResolver: resolveNullImage,
    );

    expect(painterB.shouldRepaint(painterA), isFalse);

    final controllerB = SceneController(scene: scene);
    addTearDown(controllerB.dispose);
    final painterC = ScenePainter(
      controller: controllerB,
      imageResolver: resolveNullImage,
    );

    expect(painterC.shouldRepaint(painterA), isTrue);

    final painterD = ScenePainter(
      controller: controllerA,
      imageResolver: resolveNullImage,
      selectionColor: const Color(0xFFFF0000),
    );

    expect(painterD.shouldRepaint(painterA), isTrue);
  });

  test('ScenePainter.shouldRepaint ignores non-finite stroke widths', () {
    final scene = Scene();
    Image? resolveNullImage(String _) => null;
    final controller = SceneController(scene: scene);
    addTearDown(controller.dispose);

    final painterNanA = ScenePainter(
      controller: controller,
      imageResolver: resolveNullImage,
      selectionStrokeWidth: double.nan,
      gridStrokeWidth: double.nan,
    );
    final painterNanB = ScenePainter(
      controller: controller,
      imageResolver: resolveNullImage,
      selectionStrokeWidth: double.nan,
      gridStrokeWidth: double.nan,
    );
    expect(painterNanB.shouldRepaint(painterNanA), isFalse);

    final painterZero = ScenePainter(
      controller: controller,
      imageResolver: resolveNullImage,
      selectionStrokeWidth: 0,
      gridStrokeWidth: 0,
    );
    expect(painterZero.shouldRepaint(painterNanA), isFalse);
  });

  test(
    'ScenePainter selection covers dot, open path, and empty metrics',
    () async {
      const background = Color(0xFFFFFFFF);
      final imageNode = ImageNode(
        id: 'image-selected',
        imageId: 'img:missing',
        size: const Size(14, 10),
      )..position = const Offset(12, 12);

      final dotStroke = StrokeNode(
        id: 'stroke-dot',
        points: const [Offset(26, 20)],
        thickness: 8,
        color: const Color(0xFF000000),
      );

      final polyStroke = StrokeNode(
        id: 'stroke-poly',
        points: const [Offset(30, 30), Offset(45, 30), Offset(45, 46)],
        thickness: 5,
        color: const Color(0xFF000000),
      );

      final openPath = PathNode(
        id: 'path-open',
        svgPathData: 'M0 0 L20 0 L20 12',
        strokeColor: const Color(0xFF000000),
        strokeWidth: 2,
      )..position = const Offset(60, 24);

      final emptyMetrics = _EmptyMetricsPathNode(
        id: 'path-empty-metrics',
        svgPathData: 'M0 0 L10 10',
      )..position = const Offset(70, 50);

      final scene = Scene(
        background: Background(color: background),
        layers: [
          Layer(
            nodes: [imageNode, dotStroke, polyStroke, openPath, emptyMetrics],
          ),
        ],
      );

      final painter = ScenePainter(
        controller: _controllerFor(
          scene,
          selectedNodeIds: const {
            'image-selected',
            'stroke-dot',
            'stroke-poly',
            'path-open',
            'path-empty-metrics',
          },
        ),
        imageResolver: (_) => null,
        selectionColor: const Color(0xFFFF0000),
        selectionStrokeWidth: 3,
      );

      final image = await _paintToImage(painter, width: 120, height: 80);
      final nonBg = await _countNonBackgroundPixels(image, background);
      expect(nonBg, greaterThan(0));
    },
  );

  test('ScenePainter snaps thin horizontal line in auto mode', () async {
    const background = Color(0xFFFFFFFF);
    final line = LineNode(
      id: 'line',
      start: const Offset(10, 20.3),
      end: const Offset(90, 20.3),
      thickness: 1,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      background: Background(color: background),
      layers: [
        Layer(nodes: [line]),
      ],
    );

    final painterNone = ScenePainter(
      controller: _controllerFor(scene),
      imageResolver: (_) => null,
      devicePixelRatio: 2,
      thinLineSnapStrategy: ThinLineSnapStrategy.none,
    );
    final painterAuto = ScenePainter(
      controller: _controllerFor(scene),
      imageResolver: (_) => null,
      devicePixelRatio: 2,
      thinLineSnapStrategy: ThinLineSnapStrategy.autoAxisAlignedThin,
    );

    final imageNone = await _paintToImage(painterNone, width: 100, height: 60);
    final imageAuto = await _paintToImage(painterAuto, width: 100, height: 60);
    final centroidNone = await _inkCentroidY(imageNone, background);
    final centroidAuto = await _inkCentroidY(imageAuto, background);

    expect((centroidAuto - 20.5).abs(), lessThan((centroidNone - 20.5).abs()));
  });

  test('ScenePainter snaps thin horizontal stroke in auto mode', () async {
    const background = Color(0xFFFFFFFF);
    final stroke = StrokeNode(
      id: 'stroke',
      points: const [Offset(10, 30.3), Offset(50, 30.3), Offset(90, 30.3)],
      thickness: 1,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      background: Background(color: background),
      layers: [
        Layer(nodes: [stroke]),
      ],
    );

    final painterNone = ScenePainter(
      controller: _controllerFor(scene),
      imageResolver: (_) => null,
      devicePixelRatio: 2,
      thinLineSnapStrategy: ThinLineSnapStrategy.none,
    );
    final painterAuto = ScenePainter(
      controller: _controllerFor(scene),
      imageResolver: (_) => null,
      devicePixelRatio: 2,
      thinLineSnapStrategy: ThinLineSnapStrategy.autoAxisAlignedThin,
    );

    final imageNone = await _paintToImage(painterNone, width: 100, height: 70);
    final imageAuto = await _paintToImage(painterAuto, width: 100, height: 70);
    final centroidNone = await _inkCentroidY(imageNone, background);
    final centroidAuto = await _inkCentroidY(imageAuto, background);

    expect((centroidAuto - 30.5).abs(), lessThan((centroidNone - 30.5).abs()));
  });

  test('ScenePainter snaps selected thin line and stroke overlays', () async {
    const background = Color(0xFFFFFFFF);
    final line = LineNode(
      id: 'line',
      start: const Offset(20, 10.3),
      end: const Offset(20, 50.3),
      thickness: 1,
      color: const Color(0xFF000000),
    );
    final stroke = StrokeNode(
      id: 'stroke',
      points: const [Offset(70, 10.3), Offset(70, 30.3), Offset(70, 50.3)],
      thickness: 1,
      color: const Color(0xFF000000),
    );
    final scene = Scene(
      background: Background(color: background),
      layers: [
        Layer(nodes: [line, stroke]),
      ],
    );

    final painter = ScenePainter(
      controller: _controllerFor(
        scene,
        selectedNodeIds: const {'line', 'stroke'},
      ),
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
      devicePixelRatio: 2,
      thinLineSnapStrategy: ThinLineSnapStrategy.autoAxisAlignedThin,
    );

    final image = await _paintToImage(painter, width: 100, height: 70);
    final nonBg = await _countNonBackgroundPixels(image, background);
    expect(nonBg, greaterThan(0));
  });

  test(
    'ScenePainter skips snapping when transformed points overflow',
    () async {
      const background = Color(0xFFFFFFFF);
      final stroke = StrokeNode(
        id: 'overflow-stroke',
        points: const [Offset(1e308, 0), Offset(1e308, 10)],
        thickness: 1,
        color: const Color(0xFF000000),
        transform: const Transform2D(a: 1e308, b: 0, c: 0, d: 1, tx: 0, ty: 0),
      );
      final scene = Scene(
        background: Background(color: background),
        layers: [
          Layer(nodes: [stroke]),
        ],
      );

      final painter = ScenePainter(
        controller: _controllerFor(scene),
        imageResolver: (_) => null,
        devicePixelRatio: 2,
        thinLineSnapStrategy: ThinLineSnapStrategy.autoAxisAlignedThin,
      );

      final image = await _paintToImage(painter, width: 100, height: 70);
      final nonBg = await _countNonBackgroundPixels(image, background);
      expect(nonBg, equals(0));
    },
  );
}
