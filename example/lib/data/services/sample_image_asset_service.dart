import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef AssetByteLoader = Future<ByteData> Function(String key);
typedef ImageCodecFactory = Future<ui.Codec> Function(Uint8List bytes);

class SampleImageAssetService {
  SampleImageAssetService({
    AssetByteLoader? assetLoader,
    ImageCodecFactory? codecFactory,
  }) : _assetLoader = assetLoader ?? rootBundle.load,
       _codecFactory = codecFactory ?? ui.instantiateImageCodec;

  static const String sampleCatPackageAssetKey =
      'packages/iwb_canvas_engine/image/cat.png';
  static const String sampleCatLocalAssetKey = 'image/cat.png';

  final AssetByteLoader _assetLoader;
  final ImageCodecFactory _codecFactory;

  Future<ui.Image> loadSampleCatImage() async {
    final data = await _loadSampleCatAssetBytes();
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await _codecFactory(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Future<ByteData> _loadSampleCatAssetBytes() async {
    final keys = <String>[sampleCatPackageAssetKey, sampleCatLocalAssetKey];
    Object? lastError;
    for (final key in keys) {
      try {
        return await _assetLoader(key);
      } catch (error) {
        lastError = error;
      }
    }

    throw FlutterError(
      'Unable to load sample cat image asset. Last error: $lastError',
    );
  }
}
