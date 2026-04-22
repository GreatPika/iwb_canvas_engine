import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/unsafe_snapshot_materialization.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/render/scene_grid_renderer.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter.dart';

import '../support/committed_scene_view_render_state.dart';

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

Future<Image> _paintScene(ScenePainter painter, Size size) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  return recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
}

void _drawStaticLayer(
  SceneStaticLayerCache cache,
  PictureRecorder recorder, {
  required BackgroundSnapshot background,
  required Size size,
  required Offset cameraOffset,
  required double gridStrokeWidth,
}) {
  cache.draw(
    Canvas(recorder),
    SceneGridRenderRequest(
      grid: background.grid,
      size: size,
      cameraOffset: cameraOffset,
      gridStrokeWidth: gridStrokeWidth,
    ),
    backgroundColor: background.color,
  );
}

Future<int> _countDarkPixelsOnRow(Image image, int y, Color background) async {
  final data = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Failed to encode image to raw RGBA.');
  }

  var count = 0;
  final bytes = data.buffer.asUint8List();
  final argb = background.toARGB32();
  final bgA = (argb >> 24) & 0xFF;
  final bgR = (argb >> 16) & 0xFF;
  final bgG = (argb >> 8) & 0xFF;
  final bgB = argb & 0xFF;
  for (var x = 0; x < image.width; x++) {
    final index = (y * image.width + x) * 4;
    if (bytes[index] != bgR ||
        bytes[index + 1] != bgG ||
        bytes[index + 2] != bgB ||
        bytes[index + 3] != bgA) {
      count++;
    }
  }
  return count;
}

void main() {
  test('SceneStaticLayerCache disposes picture on key change', () {
    final cache = SceneStaticLayerCache();
    final background = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
      ),
    );
    const size = Size(120, 80);

    final recorder1 = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder1,
      background: background,
      size: size,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder1.endRecording();
    expect(cache.debugBuildCount, 1);
    expect(cache.debugDisposeCount, 0);
    expect(cache.debugKeyHashCode, isNotNull);

    final recorder2 = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder2,
      background: background,
      size: size,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder2.endRecording();
    expect(cache.debugBuildCount, 1);
    expect(cache.debugDisposeCount, 0);

    final recorder3 = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder3,
      background: background,
      size: const Size(140, 80),
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder3.endRecording();
    expect(cache.debugBuildCount, 2);
    expect(cache.debugDisposeCount, 1);
  });

  test('SceneStaticLayerCache does not rebuild grid picture on camera pan', () {
    final cache = SceneStaticLayerCache();
    final background = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
      ),
    );
    const size = Size(120, 80);

    final recorder1 = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder1,
      background: background,
      size: size,
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder1.endRecording();
    expect(cache.debugBuildCount, 1);

    final recorder2 = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder2,
      background: background,
      size: size,
      cameraOffset: const Offset(13, 7),
      gridStrokeWidth: 1,
    );
    recorder2.endRecording();
    expect(cache.debugBuildCount, 1);
    expect(cache.debugDisposeCount, 0);
  });

  test('SceneStaticLayerCache clips translated grid to scene bounds', () async {
    final cache = SceneStaticLayerCache();
    final background = BackgroundSnapshot(
      color: Color(0x00000000),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 10,
        color: Color(0xFF000000),
      ),
    );

    final recorder = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder,
      background: background,
      size: const Size(20, 20),
      cameraOffset: const Offset(-5, 0),
      gridStrokeWidth: 1,
    );
    final image = await recorder.endRecording().toImage(40, 40);
    final outsidePixel = await _pixelAt(image, 25, 10);
    expect(outsidePixel.a, equals(0));
  });

  test('SceneStaticLayerCache handles invalid numeric inputs', () {
    final cache = SceneStaticLayerCache();
    final background = unsafeMaterializeSceneSnapshot(
      SceneSnapshotBacking(
        background: BackgroundSnapshotBacking(
          color: Color(0xFFFFFFFF),
          grid: GridSnapshotBacking(
            isEnabled: true,
            cellSize: double.nan,
            color: Color(0xFFCCCCCC),
          ),
        ),
      ),
    ).background;

    final recorder1 = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder1,
      background: background,
      size: const Size(120, 80),
      cameraOffset: const Offset(double.nan, double.infinity),
      gridStrokeWidth: double.nan,
    );
    recorder1.endRecording();
    expect(cache.debugBuildCount, 0);
    expect(cache.debugKeyHashCode, isNull);

    final recorder2 = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder2,
      background: background,
      size: const Size(120, 80),
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
      final background = BackgroundSnapshot(
        color: Color(0xFFFFFFFF),
        grid: GridSnapshot(
          isEnabled: false,
          cellSize: 20,
          color: Color(0xFFCCCCCC),
        ),
      );

      final recorder = PictureRecorder();
      _drawStaticLayer(
        cache,
        recorder,
        background: background,
        size: const Size(120, 80),
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
    final background = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 1,
        color: Color(0xFFCCCCCC),
      ),
    );

    final recorder = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder,
      background: background,
      size: const Size(600, 400),
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    recorder.endRecording();

    expect(cache.debugBuildCount, 1);
    expect(cache.debugKeyHashCode, isNotNull);
  });

  test('SceneStaticLayerCache releases picture when grid becomes disabled', () {
    final cache = SceneStaticLayerCache();
    final enabledBackground = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
      ),
    );
    final disabledBackground = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: false,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
      ),
    );

    final enabledRecorder = PictureRecorder();
    _drawStaticLayer(
      cache,
      enabledRecorder,
      background: enabledBackground,
      size: const Size(120, 80),
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    enabledRecorder.endRecording();

    expect(cache.debugBuildCount, 1);
    expect(cache.debugDisposeCount, 0);
    expect(cache.debugKeyHashCode, isNotNull);

    final disabledRecorder = PictureRecorder();
    _drawStaticLayer(
      cache,
      disabledRecorder,
      background: disabledBackground,
      size: const Size(120, 80),
      cameraOffset: Offset.zero,
      gridStrokeWidth: 1,
    );
    disabledRecorder.endRecording();

    expect(cache.debugBuildCount, 1);
    expect(cache.debugDisposeCount, 1);
    expect(cache.debugKeyHashCode, isNull);

    final disabledRecorderAgain = PictureRecorder();
    _drawStaticLayer(
      cache,
      disabledRecorderAgain,
      background: disabledBackground,
      size: const Size(120, 80),
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
    final background = BackgroundSnapshot(
      color: Color(0xFFFFFFFF),
      grid: GridSnapshot(
        isEnabled: true,
        cellSize: 20,
        color: Color(0xFFCCCCCC),
      ),
    );

    final recorder = PictureRecorder();
    _drawStaticLayer(
      cache,
      recorder,
      background: background,
      size: const Size(120, 80),
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

  test('SceneStaticLayerCache matches painter grid output', () async {
    final scene = SceneSnapshot(
      camera: CameraSnapshot(offset: Offset(5, 0)),
      background: BackgroundSnapshot(
        color: Color(0xFFFFFFFF),
        grid: GridSnapshot(
          isEnabled: true,
          cellSize: 20,
          color: Color(0xFF000000),
        ),
      ),
    );
    const size = Size(3980, 80);
    final controller = SceneStoreController(initialSnapshot: scene);
    final renderState = CommittedSceneViewRenderState.mirror(controller);
    addTearDown(controller.dispose);
    addTearDown(renderState.dispose);

    final directPainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
    );
    final cachedPainter = ScenePainter(
      controller: renderState,
      imageResolver: (_) => null,
      staticLayerCache: SceneStaticLayerCache(),
    );

    final directImage = await _paintScene(directPainter, size);
    final cachedImage = await _paintScene(cachedPainter, size);

    final cachedGridPixels = await _countDarkPixelsOnRow(
      cachedImage,
      10,
      const Color(0xFFFFFFFF),
    );
    final directGridPixels = await _countDarkPixelsOnRow(
      directImage,
      10,
      const Color(0xFFFFFFFF),
    );

    expect((cachedGridPixels - directGridPixels).abs(), lessThanOrEqualTo(1));
  });
}
