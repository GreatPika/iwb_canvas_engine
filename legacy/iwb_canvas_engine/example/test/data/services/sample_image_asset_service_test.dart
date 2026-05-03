import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine_example/data/services/sample_image_asset_service.dart';
import 'dart:ui' as ui;

void main() {
  test('loads sample image from package asset key first', () async {
    final attemptedKeys = <String>[];
    late Uint8List decodedBytes;
    final service = SampleImageAssetService(
      assetLoader: (key) async {
        attemptedKeys.add(key);
        if (key == SampleImageAssetService.sampleCatPackageAssetKey) {
          return _byteDataFrom(Uint8List.fromList(<int>[1, 2, 3]));
        }
        throw FlutterError('unexpected fallback');
      },
      codecFactory: (bytes) async {
        decodedBytes = bytes;
        return _FakeCodec(await _createTestImage());
      },
    );

    final image = await service.loadSampleCatImage();
    addTearDown(image.dispose);

    expect(attemptedKeys, <String>[
      SampleImageAssetService.sampleCatPackageAssetKey,
    ]);
    expect(decodedBytes, Uint8List.fromList(<int>[1, 2, 3]));
    expect(image.width, 1);
    expect(image.height, 1);
  });

  test(
    'falls back to local asset key when package asset is unavailable',
    () async {
      final attemptedKeys = <String>[];
      late Uint8List decodedBytes;
      final service = SampleImageAssetService(
        assetLoader: (key) async {
          attemptedKeys.add(key);
          if (key == SampleImageAssetService.sampleCatLocalAssetKey) {
            return _byteDataFrom(Uint8List.fromList(<int>[4, 5, 6]));
          }
          throw FlutterError('missing $key');
        },
        codecFactory: (bytes) async {
          decodedBytes = bytes;
          return _FakeCodec(await _createTestImage());
        },
      );

      final image = await service.loadSampleCatImage();
      addTearDown(image.dispose);

      expect(attemptedKeys, <String>[
        SampleImageAssetService.sampleCatPackageAssetKey,
        SampleImageAssetService.sampleCatLocalAssetKey,
      ]);
      expect(decodedBytes, Uint8List.fromList(<int>[4, 5, 6]));
      expect(image.width, 1);
      expect(image.height, 1);
    },
  );

  test('throws after exhausting both asset keys', () async {
    final attemptedKeys = <String>[];
    final service = SampleImageAssetService(
      assetLoader: (key) async {
        attemptedKeys.add(key);
        throw FlutterError('missing $key');
      },
    );

    await expectLater(
      service.loadSampleCatImage(),
      throwsA(isA<FlutterError>()),
    );
    expect(attemptedKeys, <String>[
      SampleImageAssetService.sampleCatPackageAssetKey,
      SampleImageAssetService.sampleCatLocalAssetKey,
    ]);
  });
}

ByteData _byteDataFrom(Uint8List bytes) {
  return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
}

Future<ui.Image> _createTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  final picture = recorder.endRecording();
  return picture.toImage(1, 1);
}

class _FakeCodec implements ui.Codec {
  _FakeCodec(this._image);

  final ui.Image _image;

  @override
  int get frameCount => 1;

  @override
  int get repetitionCount => 0;

  @override
  Future<ui.FrameInfo> getNextFrame() async => _FakeFrameInfo(_image);

  @override
  void dispose() {}
}

class _FakeFrameInfo implements ui.FrameInfo {
  _FakeFrameInfo(this.image);

  @override
  final ui.Image image;

  @override
  Duration get duration => Duration.zero;
}
