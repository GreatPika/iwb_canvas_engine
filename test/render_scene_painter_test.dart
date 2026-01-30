import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
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

  test('ScenePainter.shouldRepaint is safe without repaint notifier', () {
    final scene = Scene();
    Image? resolveNullImage(String _) => null;
    final painterA = ScenePainter(scene: scene, imageResolver: resolveNullImage);
    final painterB = ScenePainter(scene: scene, imageResolver: resolveNullImage);

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
