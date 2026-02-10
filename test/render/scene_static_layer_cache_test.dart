import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/legacy_api.dart';

Future<Color> _pixelAt(Image image, int x, int y) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
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

  test(
    'SceneStaticLayerCache key is stable for non-finite grid/camera inputs',
    () {
      // INV:INV-CORE-RUNTIME-NUMERIC-SANITIZATION
      final cache = SceneStaticLayerCache();
      final background = Background(
        color: const Color(0xFFFFFFFF),
        grid: GridSettings(
          isEnabled: true,
          cellSize: double.nan,
          color: const Color(0xFFCCCCCC),
        ),
      );
      const size = Size(120, 80);

      final recorder1 = PictureRecorder();
      cache.draw(
        Canvas(recorder1),
        size,
        background: background,
        cameraOffset: const Offset(double.nan, double.infinity),
        gridStrokeWidth: double.nan,
      );
      recorder1.endRecording();
      expect(cache.debugBuildCount, 1);

      final recorder2 = PictureRecorder();
      cache.draw(
        Canvas(recorder2),
        size,
        background: background,
        cameraOffset: const Offset(double.nan, double.infinity),
        gridStrokeWidth: double.nan,
      );
      recorder2.endRecording();
      expect(cache.debugBuildCount, 1);
    },
  );

  test('SceneStaticLayerCache does not rebuild grid picture on camera pan', () {
    // INV:INV-RENDER-STATIC-CACHE-CAMERA-INDEPENDENT
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
      cameraOffset: const Offset(0, 0),
      gridStrokeWidth: 1,
    );
    recorder1.endRecording();
    expect(cache.debugBuildCount, 1);

    final recorder2 = PictureRecorder();
    cache.draw(
      Canvas(recorder2),
      size,
      background: background,
      cameraOffset: const Offset(13, 7),
      gridStrokeWidth: 1,
    );
    recorder2.endRecording();
    expect(cache.debugBuildCount, 1);
    expect(cache.debugDisposeCount, 0);
  });

  test('SceneStaticLayerCache clips translated grid to scene bounds', () async {
    // INV:INV-RENDER-STATIC-CACHE-CAMERA-INDEPENDENT
    final cache = SceneStaticLayerCache();
    final background = Background(
      color: const Color(0x00000000),
      grid: GridSettings(
        isEnabled: true,
        cellSize: 10,
        color: const Color(0xFF000000),
      ),
    );
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    cache.draw(
      canvas,
      const Size(20, 20),
      background: background,
      cameraOffset: const Offset(-5, 0),
      gridStrokeWidth: 1,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(40, 40);
    final outsidePixel = await _pixelAt(image, 25, 10);
    expect(outsidePixel.a, equals(0));
  });
}
