import 'dart:ui' as ui;

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

final class SampleImageResolver implements CanvasResourceResolver {
  const SampleImageResolver({required ui.Image? sampleCatImage})
    : _sampleCatImage = sampleCatImage;

  static final sampleCatResourceId = CanvasResourceId('sample-cat');

  final ui.Image? _sampleCatImage;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    if (resource.id == sampleCatResourceId) {
      return _sampleCatImage;
    }

    return null;
  }
}
