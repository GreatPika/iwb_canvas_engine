import 'dart:ui' show Image;

import '../contracts/public/canvas_ids.dart';
import '../resources/resource_resolver_adapter.dart';
import 'frame_paint_output.dart';

Map<CanvasResourceId, Image> resolvedMainFrameImages(
  MainFramePaintOutput output,
) {
  return {
    for (final entry in output.assetBindings.images.entries)
      if (entry.value is ResolvedResourceImage)
        entry.key: (entry.value as ResolvedResourceImage).image,
  };
}
