import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/render/scene_painter.dart';
import 'package:iwb_canvas_engine/core/scene.dart';

void main() {
  test('SceneStaticLayerCache reuses picture for same key', () {
    final cache = SceneStaticLayerCache();
    final background = Background(
      color: const Color(0xFFFFFFFF),
      grid: GridSettings(
        isEnabled: true,
        cellSize: 20,
        color: const Color(0xFFCCCCCC),
      ),
    );
    const size = Size(120, 80);

    final recorder1 = PictureRecorder();
    cache.draw(
      Canvas(recorder1),
      size,
      background: background,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder1.endRecording();
    expect(cache.debugBuildCount, 1);
    expect(cache.debugKeyHashCode, isNotNull);

    final recorder2 = PictureRecorder();
    cache.draw(
      Canvas(recorder2),
      size,
      background: background,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder2.endRecording();
    expect(cache.debugBuildCount, 1);

    final recorder3 = PictureRecorder();
    cache.draw(
      Canvas(recorder3),
      const Size(140, 80),
      background: background,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder3.endRecording();
    expect(cache.debugBuildCount, 2);
  });
}
