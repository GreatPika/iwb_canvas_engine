import 'dart:ui' as ui;

import '../contracts/public/canvas_ids.dart';

const int kMaxResolvedResourceImagesPerSession = 1024;

typedef _ImageResolveCacheKey = ({
  int resolverGeneration,
  CanvasResourceId resourceId,
  int resourceRevision,
});

final class ImageResolveCache {
  ImageResolveCache({int capacity = kMaxResolvedResourceImagesPerSession})
    : _capacity = capacity;

  final int _capacity;
  final Map<_ImageResolveCacheKey, ui.Image> _entries = {};

  int get length => _entries.length;

  ui.Image? read({
    required int resolverGeneration,
    required CanvasResourceId resourceId,
    required int resourceRevision,
  }) {
    final key = (
      resolverGeneration: resolverGeneration,
      resourceId: resourceId,
      resourceRevision: resourceRevision,
    );
    final image = _entries.remove(key);
    if (image == null) {
      return null;
    }

    _entries[key] = image;

    return image;
  }

  void write({
    required int resolverGeneration,
    required CanvasResourceId resourceId,
    required int resourceRevision,
    required ui.Image image,
  }) {
    final key = (
      resolverGeneration: resolverGeneration,
      resourceId: resourceId,
      resourceRevision: resourceRevision,
    );
    _entries.remove(key);
    _entries[key] = image;

    while (_entries.length > _capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void invalidateResource(CanvasResourceId id) {
    _entries.removeWhere((key, _) => key.resourceId == id);
  }

  void clear() {
    _entries.clear();
  }
}
