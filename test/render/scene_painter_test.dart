import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';

Future<Image> _solidImage(Color color, {int width = 8, int height = 8}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(width, height);
}

Future<Image> _paintToImage(
  ScenePainterV2 painter, {
  int width = 120,
  int height = 120,
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
  final bg = background.toARGB32();
  final bgA = (bg >> 24) & 0xFF;
  final bgR = (bg >> 16) & 0xFF;
  final bgG = (bg >> 8) & 0xFF;
  final bgB = bg & 0xFF;

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
      if (ink <= 0) {
        continue;
      }
      weightedX += x * ink;
      totalInk += ink;
    }
  }
  if (totalInk == 0) {
    throw StateError('Expected non-background pixels.');
  }
  return weightedX / totalInk;
}

Future<Rect> _inkBounds(Image image, Color background) async {
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

  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final index = (y * image.width + x) * 4;
      if (bytes[index] == bgR &&
          bytes[index + 1] == bgG &&
          bytes[index + 2] == bgB &&
          bytes[index + 3] == bgA) {
        continue;
      }
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX < minX || maxY < minY) {
    throw StateError('Expected non-background pixels.');
  }
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ScenePainterV2 paints all node variants and selection', () async {
    const background = Color(0xFFFFFFFF);
    final image = await _solidImage(const Color(0xFFFF00FF));

    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        camera: const CameraSnapshot(offset: Offset(4, -3)),
        background: const BackgroundSnapshot(
          color: background,
          grid: GridSnapshot(
            isEnabled: true,
            cellSize: 10,
            color: Color(0xFF000000),
          ),
        ),
        layers: <LayerSnapshot>[
          LayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'rect-1',
                size: const Size(30, 20),
                fillColor: const Color(0xFF2196F3),
                strokeColor: const Color(0xFF000000),
                transform: Transform2D.translation(const Offset(20, 20)),
              ),
              const LineNodeSnapshot(
                id: 'line-1',
                start: Offset(0, 0),
                end: Offset(20, 0),
                thickness: 3,
                color: Color(0xFF4CAF50),
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 55, ty: 18),
              ),
              StrokeNodeSnapshot(
                id: 'stroke-1',
                points: const <Offset>[Offset(0, 0), Offset(10, 10)],
                thickness: 4,
                color: const Color(0xFFFF9800),
                transform: Transform2D.translation(const Offset(70, 25)),
              ),
              TextNodeSnapshot(
                id: 'text-1',
                text: 'V2',
                size: const Size(40, 20),
                fontSize: 14,
                color: const Color(0xFF000000),
                align: TextAlign.center,
                transform: Transform2D.translation(const Offset(25, 60)),
              ),
              ImageNodeSnapshot(
                id: 'img-1',
                imageId: 'img',
                size: const Size(16, 16),
                transform: Transform2D.translation(const Offset(55, 55)),
              ),
              PathNodeSnapshot(
                id: 'path-1',
                svgPathData: 'M0 0 H16 V16 H0 Z M4 4 H12 V12 H4 Z',
                fillColor: const Color(0xFF81C784),
                strokeColor: const Color(0xFF1B5E20),
                strokeWidth: 2,
                fillRule: V2PathFillRule.evenOdd,
                transform: Transform2D.translation(const Offset(85, 60)),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <String>{'rect-1', 'path-1'});
    });

    final painter = ScenePainterV2(
      controller: controller,
      imageResolver: (id) => id == 'img' ? image : null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
    );

    final rendered = await _paintToImage(painter, width: 120, height: 90);
    final nonBackground = await _countNonBackgroundPixels(rendered, background);
    expect(nonBackground, greaterThan(0));
  });

  test('ScenePainterV2 paints marquee selection rectangle', () async {
    const background = Color(0xFFFFFFFF);
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        background: const BackgroundSnapshot(color: background),
        layers: <LayerSnapshot>[LayerSnapshot()],
      ),
    );
    addTearDown(controller.dispose);

    final withoutMarquee = ScenePainterV2(
      controller: controller,
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
    );
    final withMarquee = ScenePainterV2(
      controller: controller,
      imageResolver: (_) => null,
      selectionRect: const Rect.fromLTRB(20, 20, 70, 60),
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
    );

    final imageWithout = await _paintToImage(withoutMarquee);
    final imageWith = await _paintToImage(withMarquee);
    final nonBackgroundWithout = await _countNonBackgroundPixels(
      imageWithout,
      background,
    );
    final nonBackgroundWith = await _countNonBackgroundPixels(
      imageWith,
      background,
    );
    expect(nonBackgroundWith, greaterThan(nonBackgroundWithout));
  });

  test('SceneControllerV2 rejects invalid numeric snapshot fields', () {
    expect(
      () => SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          camera: const CameraSnapshot(offset: Offset(double.nan, 0)),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('ScenePainterV2 paints selected line and stroke', () async {
    const background = Color(0xFFFFFFFF);
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        background: const BackgroundSnapshot(color: background),
        layers: <LayerSnapshot>[
          LayerSnapshot(
            nodes: <NodeSnapshot>[
              const LineNodeSnapshot(
                id: 'line-valid',
                start: Offset(0, 0),
                end: Offset(20, 0),
                thickness: 3,
                color: Color(0xFF000000),
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 20, ty: 20),
              ),
              StrokeNodeSnapshot(
                id: 'stroke-valid',
                points: <Offset>[Offset(0, 0), Offset(10, 10)],
                thickness: 3,
                color: Color(0xFF000000),
                transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 60, ty: 20),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <String>{
        'line-valid',
        'stroke-valid',
      });
    });

    final painter = ScenePainterV2(
      controller: controller,
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
      strokePathCache: null,
    );
    final rendered = await _paintToImage(painter, width: 100, height: 60);
    final nonBackground = await _countNonBackgroundPixels(rendered, background);
    expect(nonBackground, greaterThan(0));

    final cachedPainter = ScenePainterV2(
      controller: controller,
      imageResolver: (_) => null,
      selectionColor: const Color(0xFFFF0000),
      selectionStrokeWidth: 2,
      strokePathCache: SceneStrokePathCacheV2(maxEntries: 8),
    );
    final cachedRendered = await _paintToImage(
      cachedPainter,
      width: 100,
      height: 60,
    );
    final cachedNonBackground = await _countNonBackgroundPixels(
      cachedRendered,
      background,
    );
    expect(cachedNonBackground, greaterThan(0));
  });

  test(
    'ScenePainterV2 keeps grid visible with over-density via stride',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(
            color: background,
            grid: GridSnapshot(
              isEnabled: true,
              cellSize: 1,
              color: Color(0xFF000000),
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);

      final painter = ScenePainterV2(
        controller: controller,
        imageResolver: (_) => null,
      );
      final image = await _paintToImage(painter, width: 500, height: 500);
      final nonBackground = await _countNonBackgroundPixels(image, background);
      expect(nonBackground, greaterThan(0));
    },
  );

  test('ScenePainterV2 skips grid for invalid drawable state', () async {
    const background = Color(0xFFFFFFFF);
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        background: BackgroundSnapshot(
          color: background,
          grid: GridSnapshot(
            isEnabled: true,
            cellSize: 0.5,
            color: Color(0xFF000000),
          ),
        ),
      ),
    );
    addTearDown(controller.dispose);

    final painter = ScenePainterV2(
      controller: controller,
      imageResolver: (_) => null,
    );
    final image = await _paintToImage(painter, width: 120, height: 80);
    final nonBackground = await _countNonBackgroundPixels(image, background);
    expect(nonBackground, 0);
  });

  test(
    'ScenePainterV2 uses textDirection for TextAlign.start and end',
    () async {
      const background = Color(0xFFFFFFFF);

      SceneSnapshot snapshotFor(TextAlign align) {
        return SceneSnapshot(
          background: const BackgroundSnapshot(color: background),
          layers: <LayerSnapshot>[
            LayerSnapshot(
              nodes: <NodeSnapshot>[
                TextNodeSnapshot(
                  id: 'text-$align',
                  text: 'StartEnd',
                  size: const Size(120, 28),
                  fontSize: 20,
                  color: const Color(0xFF000000),
                  align: align,
                  transform: Transform2D.translation(const Offset(80, 40)),
                ),
              ],
            ),
          ],
        );
      }

      final ltrController = SceneControllerV2(
        initialSnapshot: snapshotFor(TextAlign.start),
      );
      final rtlController = SceneControllerV2(
        initialSnapshot: snapshotFor(TextAlign.start),
      );
      addTearDown(ltrController.dispose);
      addTearDown(rtlController.dispose);

      final ltrImage = await _paintToImage(
        ScenePainterV2(
          controller: ltrController,
          imageResolver: (_) => null,
          textDirection: TextDirection.ltr,
        ),
        width: 160,
        height: 80,
      );
      final rtlImage = await _paintToImage(
        ScenePainterV2(
          controller: rtlController,
          imageResolver: (_) => null,
          textDirection: TextDirection.rtl,
        ),
        width: 160,
        height: 80,
      );
      final ltrCenterX = await _inkCentroidX(ltrImage, background);
      final rtlCenterX = await _inkCentroidX(rtlImage, background);
      expect(rtlCenterX, greaterThan(ltrCenterX));

      final ltrEndController = SceneControllerV2(
        initialSnapshot: snapshotFor(TextAlign.end),
      );
      final rtlEndController = SceneControllerV2(
        initialSnapshot: snapshotFor(TextAlign.end),
      );
      addTearDown(ltrEndController.dispose);
      addTearDown(rtlEndController.dispose);

      final ltrEndImage = await _paintToImage(
        ScenePainterV2(
          controller: ltrEndController,
          imageResolver: (_) => null,
          textDirection: TextDirection.ltr,
        ),
        width: 160,
        height: 80,
      );
      final rtlEndImage = await _paintToImage(
        ScenePainterV2(
          controller: rtlEndController,
          imageResolver: (_) => null,
          textDirection: TextDirection.rtl,
        ),
        width: 160,
        height: 80,
      );
      final ltrEndCenterX = await _inkCentroidX(ltrEndImage, background);
      final rtlEndCenterX = await _inkCentroidX(rtlEndImage, background);
      expect(rtlEndCenterX, lessThan(ltrEndCenterX));
    },
  );

  test(
    'ScenePainterV2 treats lineHeight as absolute logical units (legacy parity)',
    () async {
      const background = Color(0xFFFFFFFF);

      SceneSnapshot snapshotFor(double? lineHeight) {
        return SceneSnapshot(
          background: const BackgroundSnapshot(color: background),
          layers: <LayerSnapshot>[
            LayerSnapshot(
              nodes: <NodeSnapshot>[
                TextNodeSnapshot(
                  id: 'text-line-height',
                  text: 'One\nTwo',
                  size: const Size(180, 180),
                  fontSize: 12,
                  color: const Color(0xFF000000),
                  lineHeight: lineHeight,
                  transform: Transform2D.translation(const Offset(90, 90)),
                ),
              ],
            ),
          ],
        );
      }

      final defaultController = SceneControllerV2(
        initialSnapshot: snapshotFor(null),
      );
      final customController = SceneControllerV2(
        initialSnapshot: snapshotFor(24),
      );
      addTearDown(defaultController.dispose);
      addTearDown(customController.dispose);

      final defaultImage = await _paintToImage(
        ScenePainterV2(
          controller: defaultController,
          imageResolver: (_) => null,
        ),
        width: 180,
        height: 180,
      );
      final customImage = await _paintToImage(
        ScenePainterV2(
          controller: customController,
          imageResolver: (_) => null,
        ),
        width: 180,
        height: 180,
      );
      final defaultBounds = await _inkBounds(defaultImage, background);
      final customBounds = await _inkBounds(customImage, background);

      expect(customBounds.height, greaterThan(defaultBounds.height + 8));
      expect(customBounds.height, lessThan(80));
    },
  );

  test('ScenePainterV2 uses caches when provided', () async {
    const background = Color(0xFFFFFFFF);
    final strokeCache = SceneStrokePathCacheV2(maxEntries: 8);
    final textCache = SceneTextLayoutCacheV2(maxEntries: 8);
    final pathCache = ScenePathMetricsCacheV2(maxEntries: 8);
    final controller = SceneControllerV2(
      initialSnapshot: SceneSnapshot(
        background: const BackgroundSnapshot(color: background),
        layers: <LayerSnapshot>[
          LayerSnapshot(
            nodes: <NodeSnapshot>[
              StrokeNodeSnapshot(
                id: 'stroke',
                points: const <Offset>[Offset(10, 10), Offset(60, 10)],
                thickness: 6,
                color: const Color(0xFF000000),
              ),
              TextNodeSnapshot(
                id: 'text',
                text: 'cache',
                size: const Size(80, 24),
                fontSize: 14,
                color: const Color(0xFF000000),
                transform: Transform2D.translation(const Offset(50, 40)),
              ),
              PathNodeSnapshot(
                id: 'path',
                svgPathData: 'M0 0 H30 V20 H0 Z',
                strokeColor: const Color(0xFF000000),
                strokeWidth: 2,
                transform: Transform2D.translation(const Offset(50, 70)),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final painter = ScenePainterV2(
      controller: controller,
      imageResolver: (_) => null,
      strokePathCache: strokeCache,
      textLayoutCache: textCache,
      pathMetricsCache: pathCache,
    );

    await _paintToImage(painter, width: 120, height: 100);
    await _paintToImage(painter, width: 120, height: 100);

    expect(strokeCache.debugBuildCount, 1);
    expect(strokeCache.debugHitCount, greaterThanOrEqualTo(1));
    expect(textCache.debugBuildCount, 1);
    expect(textCache.debugHitCount, greaterThanOrEqualTo(1));
    expect(pathCache.debugBuildCount, 1);
    expect(pathCache.debugHitCount, greaterThanOrEqualTo(1));
  });

  test(
    'ScenePainterV2 can use static layer cache across camera updates',
    () async {
      final staticCache = SceneStaticLayerCacheV2();
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          background: BackgroundSnapshot(
            color: Color(0xFFFFFFFF),
            grid: GridSnapshot(
              isEnabled: true,
              cellSize: 20,
              color: Color(0xFF000000),
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);

      final painter = ScenePainterV2(
        controller: controller,
        imageResolver: (_) => null,
        staticLayerCache: staticCache,
      );

      await _paintToImage(painter, width: 120, height: 80);
      expect(staticCache.debugBuildCount, 1);

      controller.writeReplaceScene(
        SceneSnapshot(
          camera: CameraSnapshot(offset: Offset(7, 5)),
          background: BackgroundSnapshot(
            color: Color(0xFFFFFFFF),
            grid: GridSnapshot(
              isEnabled: true,
              cellSize: 20,
              color: Color(0xFF000000),
            ),
          ),
        ),
      );
      await _paintToImage(painter, width: 120, height: 80);
      expect(staticCache.debugBuildCount, 1);
    },
  );

  test(
    'ScenePainterV2 covers single-point stroke, image placeholder and text align branches',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          background: const BackgroundSnapshot(color: background),
          layers: <LayerSnapshot>[
            LayerSnapshot(
              nodes: <NodeSnapshot>[
                StrokeNodeSnapshot(
                  id: 'dot',
                  points: const <Offset>[Offset(20, 20)],
                  thickness: 8,
                  color: const Color(0xFF000000),
                ),
                const ImageNodeSnapshot(
                  id: 'image-missing',
                  imageId: 'missing',
                  size: Size(20, 16),
                  transform: Transform2D(
                    a: 1,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 55,
                    ty: 25,
                  ),
                ),
                TextNodeSnapshot(
                  id: 'text-right',
                  text: 'R',
                  size: const Size(40, 20),
                  fontSize: 14,
                  lineHeight: 1.4,
                  align: TextAlign.right,
                  color: const Color(0xFF000000),
                  transform: Transform2D.translation(const Offset(20, 55)),
                ),
                TextNodeSnapshot(
                  id: 'text-justify',
                  text: 'J',
                  size: const Size(40, 20),
                  fontSize: 14,
                  align: TextAlign.justify,
                  color: const Color(0xFF000000),
                  transform: Transform2D.translation(const Offset(55, 55)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final image = await _paintToImage(
        ScenePainterV2(controller: controller, imageResolver: (_) => null),
        width: 100,
        height: 80,
      );
      final nonBackground = await _countNonBackgroundPixels(image, background);
      expect(nonBackground, greaterThan(0));
    },
  );

  test(
    'ScenePainterV2 covers selection halo branches for image/text/stroke/path',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          background: const BackgroundSnapshot(color: background),
          layers: <LayerSnapshot>[
            LayerSnapshot(
              nodes: <NodeSnapshot>[
                const ImageNodeSnapshot(
                  id: 'img-sel',
                  imageId: 'missing',
                  size: Size(20, 16),
                  transform: Transform2D(
                    a: 1,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 20,
                    ty: 20,
                  ),
                ),
                TextNodeSnapshot(
                  id: 'txt-sel',
                  text: 'T',
                  size: const Size(30, 16),
                  color: const Color(0xFF000000),
                  transform: Transform2D.translation(const Offset(60, 20)),
                ),
                StrokeNodeSnapshot(
                  id: 'dot-sel',
                  points: <Offset>[Offset(40, 45)],
                  thickness: 6,
                  color: Color(0xFF000000),
                ),
                StrokeNodeSnapshot(
                  id: 'stroke-sel',
                  points: <Offset>[Offset(65, 40), Offset(78, 48)],
                  thickness: 4,
                  color: Color(0xFF000000),
                ),
                const PathNodeSnapshot(
                  id: 'path-open-sel',
                  svgPathData: 'M0 0 L30 0',
                  strokeColor: Color(0xFF000000),
                  strokeWidth: 3,
                  transform: Transform2D(
                    a: 1,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 20,
                    ty: 80,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.write((writer) {
        writer.writeSelectionReplace(const <NodeId>{
          'img-sel',
          'txt-sel',
          'dot-sel',
          'stroke-sel',
          'path-open-sel',
        });
      });

      final withoutCache = await _paintToImage(
        ScenePainterV2(controller: controller, imageResolver: (_) => null),
        width: 120,
        height: 120,
      );
      expect(
        await _countNonBackgroundPixels(withoutCache, background),
        greaterThan(0),
      );

      final withPathCache = await _paintToImage(
        ScenePainterV2(
          controller: controller,
          imageResolver: (_) => null,
          pathMetricsCache: ScenePathMetricsCacheV2(),
        ),
        width: 120,
        height: 120,
      );
      expect(
        await _countNonBackgroundPixels(withPathCache, background),
        greaterThan(0),
      );
    },
  );

  test('ScenePainterV2 shouldRepaint reflects individual fields', () {
    final c1 = SceneControllerV2();
    final c2 = SceneControllerV2();
    addTearDown(c1.dispose);
    addTearDown(c2.dispose);

    Image? resolverA(String _) => null;
    Image? resolverB(String _) => null;

    final base = ScenePainterV2(controller: c1, imageResolver: resolverA);
    final same = ScenePainterV2(controller: c1, imageResolver: resolverA);
    expect(base.shouldRepaint(same), isFalse);

    expect(
      ScenePainterV2(
        controller: c2,
        imageResolver: resolverA,
      ).shouldRepaint(base),
      isTrue,
    );
    expect(
      ScenePainterV2(
        controller: c1,
        imageResolver: resolverB,
      ).shouldRepaint(base),
      isTrue,
    );

    final staticCache = SceneStaticLayerCacheV2();
    expect(
      ScenePainterV2(
        controller: c1,
        imageResolver: resolverA,
        staticLayerCache: staticCache,
      ).shouldRepaint(base),
      isTrue,
    );

    final textCache = SceneTextLayoutCacheV2();
    expect(
      ScenePainterV2(
        controller: c1,
        imageResolver: resolverA,
        textLayoutCache: textCache,
      ).shouldRepaint(base),
      isTrue,
    );

    final strokeCache = SceneStrokePathCacheV2();
    expect(
      ScenePainterV2(
        controller: c1,
        imageResolver: resolverA,
        strokePathCache: strokeCache,
      ).shouldRepaint(base),
      isTrue,
    );

    final pathCache = ScenePathMetricsCacheV2();
    expect(
      ScenePainterV2(
        controller: c1,
        imageResolver: resolverA,
        pathMetricsCache: pathCache,
      ).shouldRepaint(base),
      isTrue,
    );

    expect(
      ScenePainterV2(
        controller: c1,
        imageResolver: resolverA,
        selectionColor: const Color(0xFFFF0000),
      ).shouldRepaint(base),
      isTrue,
    );
    expect(
      ScenePainterV2(
        controller: c1,
        imageResolver: resolverA,
        selectionStrokeWidth: 3,
      ).shouldRepaint(base),
      isTrue,
    );
    expect(
      ScenePainterV2(
        controller: c1,
        imageResolver: resolverA,
        gridStrokeWidth: 2,
      ).shouldRepaint(base),
      isTrue,
    );
    expect(
      ScenePainterV2(
        controller: c1,
        imageResolver: resolverA,
        textDirection: TextDirection.rtl,
      ).shouldRepaint(base),
      isTrue,
    );
  });

  test(
    'ScenePainterV2 applies preview delta resolver for nodes and selection',
    () async {
      const background = Color(0xFFFFFFFF);
      final controller = SceneControllerV2(
        initialSnapshot: SceneSnapshot(
          background: const BackgroundSnapshot(color: background),
          layers: <LayerSnapshot>[
            LayerSnapshot(
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'previewed',
                  size: const Size(20, 20),
                  fillColor: const Color(0xFF000000),
                  transform: Transform2D.translation(const Offset(20, 20)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      controller.write((writer) {
        writer.writeSelectionReplace(const <NodeId>{'previewed'});
      });

      final image = await _paintToImage(
        ScenePainterV2(
          controller: controller,
          imageResolver: (_) => null,
          nodePreviewOffsetResolver: (nodeId) {
            if (nodeId == 'previewed') return const Offset(30, 10);
            return Offset.zero;
          },
        ),
        width: 80,
        height: 80,
      );

      expect(
        await _countNonBackgroundPixels(image, background),
        greaterThan(0),
      );
    },
  );
}
