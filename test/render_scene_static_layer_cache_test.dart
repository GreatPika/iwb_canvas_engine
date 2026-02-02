import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  test('A6-1: SceneStaticLayerCache disposes picture on key change', () {
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
    expect(cache.debugDisposeCount, 0);
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
    expect(cache.debugDisposeCount, 0);

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
    expect(cache.debugDisposeCount, 1);
  });
}
