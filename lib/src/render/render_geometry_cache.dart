import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/text_layout.dart';
import '../contract/snapshot.dart';
import 'render_geometry_entry.dart';
import 'render_geometry_builder.dart';
export 'render_geometry_entry.dart';

int _requirePositiveGeometryCacheEntries(int maxEntries) {
  if (maxEntries <= 0) {
    throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be > 0.');
  }
  return maxEntries;
}

/// Per-node geometry cache injected into `ScenePainter`.
///
/// Memory is bounded via LRU eviction (`maxEntries`), while `invalidateAll()`
/// remains available for explicit full cache reset on owner epoch/document
/// boundaries. `epoch` is intentionally not part of per-entry keys.
class RenderGeometryCache {
  RenderGeometryCache({int maxEntries = 512})
    : maxEntries = _requirePositiveGeometryCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<_NodeInstanceKey, _GeometryCacheRecord> _entries =
      LinkedHashMap<_NodeInstanceKey, _GeometryCacheRecord>();

  int _debugBuildCount = 0;
  int _debugHitCount = 0;
  int _debugEvictCount = 0;

  @visibleForTesting
  int get debugBuildCount => _debugBuildCount;
  @visibleForTesting
  int get debugHitCount => _debugHitCount;
  @visibleForTesting
  int get debugEvictCount => _debugEvictCount;
  @visibleForTesting
  int get debugSize => _entries.length;

  GeometryEntry get(
    NodeSnapshot node, {
    ResolvedTextLayout? resolvedTextLayout,
  }) {
    final key = buildRenderGeometryValidityKey(node);
    final entryKey = _NodeInstanceKey(
      nodeId: node.id,
      instanceRevision: node.instanceRevision,
    );
    final cached = _entries.remove(entryKey);
    if (cached != null && cached.key == key) {
      _entries[entryKey] = cached;
      _debugHitCount += 1;
      return cached.entry;
    }

    final entry = buildRenderGeometryEntry(
      node,
      resolvedTextLayout: resolvedTextLayout,
    );
    _entries[entryKey] = _GeometryCacheRecord(key: key, entry: entry);
    _debugBuildCount += 1;
    _evictIfNeeded();
    return entry;
  }

  void invalidateAll() => _entries.clear();

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
      _debugEvictCount += 1;
    }
  }
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
