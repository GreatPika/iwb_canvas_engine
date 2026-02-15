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

  void clear() => _entries.clear();

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

    final fillType = _fillTypeFromSnapshot(node.fillRule);
    Path? closedContours;
    final openContours = <Path>[];
    for (final metric in localPath.computeMetrics()) {
      final contour = metric.extractPath(
        0,
        metric.length,
        startWithMoveTo: true,
      );
      contour.fillType = fillType;
      if (metric.isClosed) {
        contour.close();
        closedContours ??= Path()..fillType = fillType;
        closedContours.addPath(contour, Offset.zero);
      } else {
        openContours.add(contour);
      }
    }

    final contours = PathSelectionContours(
      closedContours: closedContours,
      openContours: openContours,
    );
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
  final V2PathFillRule fillRule;
  final PathSelectionContours contours;
}

class PathSelectionContours {
  const PathSelectionContours({
    required this.closedContours,
    required this.openContours,
  });

  final Path? closedContours;
  final List<Path> openContours;
}

PathFillType _fillTypeFromSnapshot(V2PathFillRule rule) {
  return rule == V2PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}
