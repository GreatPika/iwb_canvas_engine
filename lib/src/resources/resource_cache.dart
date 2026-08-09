import '../contracts/public/canvas_ids.dart';
import 'resource_resolver_adapter.dart';

const int kMaxResolvedResourceAssetsPerSession = 1024;
const int kMaxResolvedResourceImageBytesPerSession = 64 * 1024 * 1024;

typedef _ResourceAssetCacheKey = ({
  int resolverGeneration,
  CanvasResourceId resourceId,
  int resourceRevision,
});

final class ResourceAssetCache {
  ResourceAssetCache({
    int capacity = kMaxResolvedResourceAssetsPerSession,
    int maximumSizeBytes = kMaxResolvedResourceImageBytesPerSession,
  }) : _capacity = capacity,
       _maximumSizeBytes = maximumSizeBytes;

  final int _capacity;
  final int _maximumSizeBytes;
  final Map<_ResourceAssetCacheKey, _ResourceAssetCacheEntry> _entries = {};
  int _currentSizeBytes = 0;

  int get length => _entries.length;
  int get currentSizeBytes => _currentSizeBytes;

  ResourceAsset? read({
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

    return entry.asset;
  }

  void write({
    required int resolverGeneration,
    required CanvasResourceId resourceId,
    required int resourceRevision,
    required ResourceAsset asset,
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

    final estimatedBytes = asset.cacheWeightBytes;
    if (estimatedBytes > _maximumSizeBytes) {
      return;
    }

    _entries[key] = _ResourceAssetCacheEntry(
      asset: asset,
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
    invalidateResources({id});
  }

  void invalidateResources(Set<CanvasResourceId> ids) {
    if (ids.isEmpty) {
      return;
    }
    _entries.removeWhere((key, entry) {
      if (!ids.contains(key.resourceId)) {
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
}

final class _ResourceAssetCacheEntry {
  const _ResourceAssetCacheEntry({
    required this.asset,
    required this.estimatedBytes,
  });

  final ResourceAsset asset;
  final int estimatedBytes;
}
