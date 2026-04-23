import 'package:flutter/foundation.dart';

import '../core/text_layout.dart';
import '../contract/snapshot.dart';
import 'cache/scan_resistant_cache.dart';
import 'render_geometry_entry.dart';
import 'render_geometry_builder.dart';
export 'render_geometry_entry.dart';

/// Per-node geometry cache injected into `ScenePainter`.
///
/// Retention is bounded via a shared scan-resistant policy, while
/// `invalidateAll()` remains available for explicit full cache reset on owner
/// epoch/document boundaries. `epoch` is intentionally not part of per-entry
/// keys.
class RenderGeometryCache {
  RenderGeometryCache({int maxEntries = 512})
    : maxEntries = requirePositiveScanResistantCacheEntries(maxEntries),
      _entries = ScanResistantCache<_NodeInstanceKey, _GeometryCacheRecord>(
        maxEntries: maxEntries,
      );

  final int maxEntries;
  final ScanResistantCache<_NodeInstanceKey, _GeometryCacheRecord> _entries;

  @visibleForTesting
  int get debugBuildCount => _entries.debugBuildCount;
  @visibleForTesting
  int get debugHitCount => _entries.debugHitCount;
  @visibleForTesting
  int get debugEvictCount => _entries.debugEvictCount;
  @visibleForTesting
  int get debugSize => _entries.debugSize;

  ({int buildCount, int hitCount, int evictCount}) captureProbe() {
    return (
      buildCount: debugBuildCount,
      hitCount: debugHitCount,
      evictCount: debugEvictCount,
    );
  }

  GeometryEntry get(
    NodeSnapshot node, {
    ResolvedTextLayout? resolvedTextLayout,
  }) {
    final key = buildRenderGeometryValidityKey(node);
    final entryKey = _NodeInstanceKey(
      nodeId: node.id,
      instanceRevision: node.instanceRevision,
    );
    return _entries
        .getOrBuild(
          key: entryKey,
          isValid: (_GeometryCacheRecord cached) => cached.key == key,
          build: () {
            final entry = buildRenderGeometryEntry(
              node,
              resolvedTextLayout: resolvedTextLayout,
            );
            return _GeometryCacheRecord(key: key, entry: entry);
          },
        )
        .entry;
  }

  void invalidateAll() => _entries.clear();
}

class _GeometryCacheRecord {
  const _GeometryCacheRecord({required this.key, required this.entry});

  final Object key;
  final GeometryEntry entry;
}

class _NodeInstanceKey {
  const _NodeInstanceKey({
    required this.nodeId,
    required this.instanceRevision,
  });

  final NodeId nodeId;
  final int instanceRevision;

  @override
  bool operator ==(Object other) {
    return other is _NodeInstanceKey &&
        other.nodeId == nodeId &&
        other.instanceRevision == instanceRevision;
  }

  @override
  int get hashCode => Object.hash(nodeId, instanceRevision);
}
