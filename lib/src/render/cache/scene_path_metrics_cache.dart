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

class ScenePathMetricsCache {
  ScenePathMetricsCache({int maxEntries = 512})
    : maxEntries = _requirePositiveCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<_NodeInstanceKey, _PathMetricsEntry> _entries =
      LinkedHashMap<_NodeInstanceKey, _PathMetricsEntry>();

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
  /// Keys stay scoped to `(nodeId, instanceRevision)` and local path inputs;
  /// `epoch` is intentionally not part of this cache key.
  void clear() => _entries.clear();

  /// Returns borrowed render contours for [node]'s geometry-owner [localPath].
  ///
  /// Callers must pass the path built for the same [PathNodeSnapshot] and must
  /// not mutate the returned contour objects.
  PathSelectionContours getOrBuild({
    required PathNodeSnapshot node,
    required Path localPath,
  }) {
    final key = _NodeInstanceKey(
      nodeId: node.id,
      instanceRevision: node.instanceRevision,
    );
    final cached = _entries.remove(key);
    if (cached != null &&
        cached.svgPathData == node.svgPathData &&
        cached.fillRule == node.fillRule) {
      _entries[key] = cached;
      _debugHitCount += 1;
      return cached.contours;
    }

    final contours = _buildContours(localPath, node.fillRule);
    _entries[key] = _PathMetricsEntry(
      svgPathData: node.svgPathData,
      fillRule: node.fillRule,
      contours: contours,
    );
    _debugBuildCount += 1;
    _evictIfNeeded();
    return contours;
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
      _debugEvictCount += 1;
    }
  }

  PathSelectionContours _buildContours(Path localPath, PathFillRule fillRule) {
    final pathFillType = _fillTypeFromSnapshot(fillRule);
    Path? closedContours;
    final openContours = <Path>[];
    for (final metric in localPath.computeMetrics()) {
      final contour = metric.extractPath(
        0,
        metric.length,
        startWithMoveTo: true,
      );
      contour.fillType = pathFillType;
      if (metric.isClosed) {
        contour.close();
        closedContours ??= Path()..fillType = pathFillType;
        closedContours.addPath(contour, Offset.zero);
        continue;
      }
      openContours.add(contour);
    }
    return PathSelectionContours(
      closedContours: closedContours,
      openContours: List<Path>.unmodifiable(openContours),
    );
  }
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

class _PathMetricsEntry {
  const _PathMetricsEntry({
    required this.svgPathData,
    required this.fillRule,
    required this.contours,
  });

  final String svgPathData;
  final PathFillRule fillRule;
  final PathSelectionContours contours;
}

class PathSelectionContours {
  const PathSelectionContours({
    required this.closedContours,
    required this.openContours,
  });

  /// Borrowed closed contour payload. Callers must treat it as read-only.
  final Path? closedContours;

  /// Borrowed open contour payload. The list shape is immutable, but contained
  /// paths remain borrowed render objects and must not be mutated.
  final List<Path> openContours;
}

PathFillType _fillTypeFromSnapshot(PathFillRule rule) {
  return rule == PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}
