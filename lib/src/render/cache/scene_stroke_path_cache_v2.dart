import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../public/snapshot.dart';

int _requirePositiveCacheEntries(int maxEntries) {
  if (maxEntries <= 0) {
    throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be > 0.');
  }
  return maxEntries;
}

class SceneStrokePathCacheV2 {
  SceneStrokePathCacheV2({int maxEntries = 512})
    : maxEntries = _requirePositiveCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<_NodeInstanceKeyV2, _StrokePathEntryV2> _entries =
      LinkedHashMap<_NodeInstanceKeyV2, _StrokePathEntryV2>();

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

  void clear() => _entries.clear();

  Path getOrBuild(StrokeNodeSnapshot node) {
    if (node.points.isEmpty) {
      return Path();
    }
    if (node.points.length == 1) {
      return Path()
        ..addOval(Rect.fromCircle(center: node.points.first, radius: 0));
    }

    final key = _NodeInstanceKeyV2(
      nodeId: node.id,
      instanceRevision: node.instanceRevision,
    );
    final cached = _entries.remove(key);
    if (cached != null && cached.pointsRevision == node.pointsRevision) {
      _entries[key] = cached;
      _debugHitCount += 1;
      return cached.path;
    }

    final path = _buildStrokePath(node.points);
    _entries[key] = _StrokePathEntryV2(
      path: path,
      pointsRevision: node.pointsRevision,
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

class _StrokePathEntryV2 {
  const _StrokePathEntryV2({required this.path, required this.pointsRevision});

  final Path path;
  final int pointsRevision;
}

class _NodeInstanceKeyV2 {
  const _NodeInstanceKeyV2({
    required this.nodeId,
    required this.instanceRevision,
  });

  final NodeId nodeId;
  final int instanceRevision;

  @override
  bool operator ==(Object other) {
    return other is _NodeInstanceKeyV2 &&
        other.nodeId == nodeId &&
        other.instanceRevision == instanceRevision;
  }

  @override
  int get hashCode => Object.hash(nodeId, instanceRevision);
}

Path _buildStrokePath(List<Offset> points) {
  final path = Path()..fillType = PathFillType.nonZero;
  final first = points.first;
  path.moveTo(first.dx, first.dy);
  for (var i = 1; i < points.length; i++) {
    final p = points[i];
    path.lineTo(p.dx, p.dy);
  }
  return path;
}
