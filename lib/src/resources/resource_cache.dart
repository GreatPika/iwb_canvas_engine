import 'dart:ui' as ui;

import '../contracts/public/canvas_ids.dart';

const int kMaxResolvedResourceImagesPerSession = 1024;
const int kMaxResolvedResourceImageBytesPerSession = 64 * 1024 * 1024;

typedef _ImageResolveCacheKey = ({
  int resolverGeneration,
  CanvasResourceId resourceId,
  int resourceRevision,
});

final class ImageResolveCache {
  ImageResolveCache({
    int capacity = kMaxResolvedResourceImagesPerSession,
    int maximumSizeBytes = kMaxResolvedResourceImageBytesPerSession,
  }) : _capacity = capacity,
       _maximumSizeBytes = maximumSizeBytes;

  final int _capacity;
  final int _maximumSizeBytes;
  final Map<_ImageResolveCacheKey, _ImageResolveCacheEntry> _entries = {};
  int _currentSizeBytes = 0;

  int get length => _entries.length;
  int get currentSizeBytes => _currentSizeBytes;

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
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }

    _entries[key] = entry;

    return entry.image;
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
    final replaced = _entries.remove(key);
    if (replaced != null) {
      _currentSizeBytes -= replaced.estimatedBytes;
    }

    final estimatedBytes = _estimateDecodedBytes(image);
    if (estimatedBytes > _maximumSizeBytes) {
      return;
    }

    _entries[key] = _ImageResolveCacheEntry(
      image: image,
      estimatedBytes: estimatedBytes,
    );
    _currentSizeBytes += estimatedBytes;

    while (_entries.length > _capacity ||
        _currentSizeBytes > _maximumSizeBytes) {
      final removed = _entries.remove(_entries.keys.first);
      if (removed != null) {
        _currentSizeBytes -= removed.estimatedBytes;
      }
    }
  }

  void invalidateResource(CanvasResourceId id) {
    _entries.removeWhere((key, entry) {
      if (key.resourceId != id) {
        return false;
      }
      _currentSizeBytes -= entry.estimatedBytes;

      return true;
    });
  }

  void clear() {
    _entries.clear();
    _currentSizeBytes = 0;
  }

  int _estimateDecodedBytes(ui.Image image) {
    return image.width * image.height * 4;
  }
}

final class _ImageResolveCacheEntry {
  const _ImageResolveCacheEntry({
    required this.image,
    required this.estimatedBytes,
  });

  final ui.Image image;
  final int estimatedBytes;
}
