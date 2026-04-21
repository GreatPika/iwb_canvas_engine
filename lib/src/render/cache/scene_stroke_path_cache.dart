import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/snapshot.dart';

int _requirePositiveCacheEntries(int maxEntries) {
  if (maxEntries <= 0) {
    throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be > 0.');
  }
  return maxEntries;
}

class SceneStrokePathCache {
  SceneStrokePathCache({int maxEntries = 512})
    : maxEntries = _requirePositiveCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<_NodeInstanceKey, _StrokePathEntry> _entries =
      LinkedHashMap<_NodeInstanceKey, _StrokePathEntry>();

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

  /// Owner-level invalidation for controller epoch/document boundaries.
  ///
  /// Keys stay scoped to `(nodeId, instanceRevision)` and local stroke inputs;
  /// `epoch` is intentionally not part of this cache key.
  void clear() => _entries.clear();

  /// Returns a borrowed render path for [node].
  ///
  /// Degenerate 0/1-point cases stay uncached and callers must treat cached
  /// paths as read-only render payload.
  Path getOrBuild(StrokeNodeSnapshot node) {
    if (node.points.isEmpty) {
      return Path();
    }
    if (node.points.length == 1) {
      return Path()
        ..addOval(Rect.fromCircle(center: node.points.first, radius: 0));
    }

    final key = _NodeInstanceKey(
      nodeId: node.id,
      instanceRevision: node.instanceRevision,
    );
    final cached = _entries.remove(key);
    if (cached != null && identical(cached.points, node.points)) {
      _entries[key] = cached;
      _debugHitCount += 1;
      return cached.path;
    }

    final path = buildStrokePath(node.points);
    _entries[key] = _StrokePathEntry(
      path: path,
      // Equivalent public stroke snapshots share one canonical immutable points
      // owner, so identity is an exact O(1) freshness check here.
      points: node.points,
    );
    _debugBuildCount += 1;
    _evictIfNeeded();
    return path;
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
      _debugEvictCount += 1;
    }
  }
}

class _StrokePathEntry {
  const _StrokePathEntry({required this.path, required this.points});

  final Path path;
  final List<Offset> points;
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

Path buildStrokePath(List<Offset> points) {
  final path = Path()..fillType = PathFillType.nonZero;
  final first = points.first;
  path.moveTo(first.dx, first.dy);
  for (var i = 1; i < points.length; i++) {
    final p = points[i];
    path.lineTo(p.dx, p.dy);
  }
  return path;
}
