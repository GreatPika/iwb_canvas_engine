import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

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
      scene: scene,
      imageResolver: (_) => null,
      selectedNodeIds: const {'rect-1'},
      selectionRect: const Rect.fromLTWH(10, 10, 50, 40),
    );

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(300, 300));
    recorder.endRecording();
  });

  test('ScenePainter draws grid, selection bounds, and marquee', () async {
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
      scene: scene,
      imageResolver: (_) => null,
      selectedNodeIds: const {'a', 'b'},
      selectionRect: const Rect.fromLTRB(70, 70, 30, 50),
      selectionColor: const Color(0xFFFF0000),
    );

    final image = await _paintToImage(painter);
    final nonBg = await _countNonBackgroundPixels(image, background);
    expect(nonBg, greaterThan(0));
  });

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
        scene: scene,
        imageResolver: resolver,
        selectedNodeIds: const {'rect'},
        selectionRect: const Rect.fromLTRB(10, 90, 30, 80),
      );

      final image = await _paintToImage(painter);
      final nonBg = await _countNonBackgroundPixels(image, background);
      expect(nonBg, greaterThan(0));
      expect(resolveCalls, 2);
    },
  );

  test('ScenePainter.shouldRepaint is safe without repaint notifier', () {
    final scene = Scene();
    Image? resolveNullImage(String _) => null;
    final painterA = ScenePainter(
      scene: scene,
      imageResolver: resolveNullImage,
    );
    final painterB = ScenePainter(
      scene: scene,
      imageResolver: resolveNullImage,
    );

    expect(painterB.shouldRepaint(painterA), isTrue);
  });

  test(
    'ScenePainter.shouldRepaint uses set equality when repaint is provided',
    () {
      final scene = Scene();
      Image? resolveNullImage(String _) => null;
      final notifier = ChangeNotifier();
      addTearDown(notifier.dispose);

      final painterA = ScenePainter(
        scene: scene,
        imageResolver: resolveNullImage,
        selectedNodeIds: {'a'},
        repaint: notifier,
      );

      final painterB = ScenePainter(
        scene: scene,
        imageResolver: resolveNullImage,
        selectedNodeIds: {'a'},
        repaint: notifier,
      );

      expect(painterB.shouldRepaint(painterA), isFalse);

      final painterC = ScenePainter(
        scene: scene,
        imageResolver: resolveNullImage,
        selectedNodeIds: {'b'},
        repaint: notifier,
      );

      expect(painterC.shouldRepaint(painterA), isTrue);
    },
  );
}
