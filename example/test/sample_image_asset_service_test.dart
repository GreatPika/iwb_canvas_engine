import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine_example/src/sample_image_asset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sample cat image loads from the copied app asset key', () async {
    final requestedKeys = <String>[];
    final service = SampleImageAssetService(
      assetLoader: (key) async {
        requestedKeys.add(key);
        if (key != SampleImageAssetService.sampleCatAssetKey) {
          throw StateError('unexpected asset key: $key');
        }

        return _byteDataForFile(File('image/cat.png'));
      },
    );

    final image = await service.loadSampleCatImage();
    addTearDown(image.dispose);

    expect(requestedKeys, [SampleImageAssetService.sampleCatAssetKey]);
    expect(image.width, greaterThan(0));
    expect(image.height, greaterThan(0));
  });
}

Future<ByteData> _byteDataForFile(File file) async {
  final bytes = await file.readAsBytes();
  final data = Uint8List.fromList(bytes);

  return ByteData.sublistView(data);
}
