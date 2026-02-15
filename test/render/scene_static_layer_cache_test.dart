import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/public/snapshot.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';

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
  test('SceneStaticLayerCache disposes picture on key change', () {
    final cache = SceneStaticLayerCache();
    const background = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
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

  test('SceneStaticLayerCache does not rebuild grid picture on camera pan', () {
    final cache = SceneStaticLayerCache();
    const background = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
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
    final cache = SceneStaticLayerCache();
    const background = BackgroundSnapshot(
      color: Color(0x00000000),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 10,
        color: Color(0xFF000000),
      ),
    );

    final recorder = PictureRecorder();
    cache.draw(
      Canvas(recorder),
      const Size(20, 20),
      background: background,
      cameraOffset: const Offset(-5, 0),
      gridStrokeWidth: 1,
    );
    final image = await recorder.endRecording().toImage(40, 40);
    final outsidePixel = await _pixelAt(image, 25, 10);
    expect(outsidePixel.a, equals(0));
  });

  test('SceneStaticLayerCache handles invalid numeric inputs', () {
    final cache = SceneStaticLayerCache();
    const background = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: double.nan,
        color: Color(0xFFCCCCCC),
      ),
    );

    final recorder1 = PictureRecorder();
    cache.draw(
      Canvas(recorder1),
      const Size(120, 80),
      background: background,
      cameraOffset: const Offset(double.nan, double.infinity),
      gridStrokeWidth: double.nan,
    );
    recorder1.endRecording();
    expect(cache.debugBuildCount, 0);
    expect(cache.debugKeyHashCode, isNull);

    final recorder2 = PictureRecorder();
    cache.draw(
      Canvas(recorder2),
      const Size(120, 80),
      background: background,
      cameraOffset: const Offset(double.nan, double.infinity),
      gridStrokeWidth: double.nan,
    );
    recorder2.endRecording();
    expect(cache.debugBuildCount, 0);
    expect(cache.debugDisposeCount, 0);
    expect(cache.debugKeyHashCode, isNull);
  });

  test(
    'SceneStaticLayerCache skips picture recording when grid is disabled',
    () {
      final cache = SceneStaticLayerCache();
      const background = BackgroundSnapshot(
        color: Color(0xFFFFFFFF),
        grid: GridSnapshot(
          isEnabled: false,
          cellSize: 20,
          color: Color(0xFFCCCCCC),
        ),
      );

      final recorder = PictureRecorder();
      cache.draw(
        Canvas(recorder),
        const Size(120, 80),
        background: background,
        cameraOffset: Offset.zero,
        gridStrokeWidth: 1,
      );
      recorder.endRecording();

      expect(cache.debugBuildCount, 0);
      expect(cache.debugDisposeCount, 0);
      expect(cache.debugKeyHashCode, isNull);
    },
  );

  test('SceneStaticLayerCache applies stride for dense grid line counts', () {
    final cache = SceneStaticLayerCache();
    const background = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 1,
        color: Color(0xFFCCCCCC),
      ),
    );

    final recorder = PictureRecorder();
    cache.draw(
      Canvas(recorder),
      const Size(600, 400),
      background: background,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder.endRecording();

    expect(cache.debugBuildCount, 1);
    expect(cache.debugKeyHashCode, isNotNull);
  });

  test('SceneStaticLayerCache releases picture when grid becomes disabled', () {
    final cache = SceneStaticLayerCache();
    const enabledBackground = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
      ),
    );
    const disabledBackground = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: false,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
      ),
    );

    final enabledRecorder = PictureRecorder();
    cache.draw(
      Canvas(enabledRecorder),
      const Size(120, 80),
      background: enabledBackground,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    enabledRecorder.endRecording();

    expect(cache.debugBuildCount, 1);
    expect(cache.debugDisposeCount, 0);
    expect(cache.debugKeyHashCode, isNotNull);

    final disabledRecorder = PictureRecorder();
    cache.draw(
      Canvas(disabledRecorder),
      const Size(120, 80),
      background: disabledBackground,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    disabledRecorder.endRecording();

    expect(cache.debugBuildCount, 1);
    expect(cache.debugDisposeCount, 1);
    expect(cache.debugKeyHashCode, isNull);

    final disabledRecorderAgain = PictureRecorder();
    cache.draw(
      Canvas(disabledRecorderAgain),
      const Size(120, 80),
      background: disabledBackground,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    disabledRecorderAgain.endRecording();

    expect(cache.debugBuildCount, 1);
    expect(cache.debugDisposeCount, 1);
    expect(cache.debugKeyHashCode, isNull);
  });

  test('SceneStaticLayerCache clear and dispose release cached picture', () {
    final cache = SceneStaticLayerCache();
    const background = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
      ),
    );

    final recorder = PictureRecorder();
    cache.draw(
      Canvas(recorder),
      const Size(120, 80),
      background: background,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder.endRecording();

    expect(cache.debugBuildCount, 1);
    cache.clear();
    expect(cache.debugDisposeCount, 1);

    cache.dispose();
    expect(cache.debugDisposeCount, 1);
  });
}
