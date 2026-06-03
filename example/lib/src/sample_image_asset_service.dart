import 'dart:ui' as ui;

import 'package:flutter/services.dart';

typedef AssetByteLoader = Future<ByteData> Function(String key);
typedef ImageCodecFactory = Future<ui.Codec> Function(Uint8List bytes);

final class SampleImageAssetService {
  SampleImageAssetService({
    AssetByteLoader? assetLoader,
    ImageCodecFactory? codecFactory,
  }) : _assetLoader = assetLoader ?? rootBundle.load,
       _codecFactory = codecFactory ?? ui.instantiateImageCodec;

  static const sampleCatAssetKey = 'image/cat.png';

  final AssetByteLoader _assetLoader;
  final ImageCodecFactory _codecFactory;

  Future<ui.Image> loadSampleCatImage() async {
    final data = await _assetLoader(sampleCatAssetKey);
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
}
