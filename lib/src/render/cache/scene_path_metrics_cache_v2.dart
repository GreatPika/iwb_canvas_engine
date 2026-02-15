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

class ScenePathMetricsCacheV2 {
  ScenePathMetricsCacheV2({int maxEntries = 512})
    : maxEntries = _requirePositiveCacheEntries(maxEntries);

  final int maxEntries;
  final LinkedHashMap<_NodeInstanceKeyV2, _PathMetricsEntryV2> _entries =
      LinkedHashMap<_NodeInstanceKeyV2, _PathMetricsEntryV2>();

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

  PathSelectionContoursV2 getOrBuild({
    required PathNodeSnapshot node,
    required Path localPath,
  }) {
    final key = _NodeInstanceKeyV2(
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

    final contours = PathSelectionContoursV2(
      closedContours: closedContours,
      openContours: openContours,
    );
    _entries[key] = _PathMetricsEntryV2(
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

class _PathMetricsEntryV2 {
  const _PathMetricsEntryV2({
    required this.svgPathData,
    required this.fillRule,
    required this.contours,
  });

  final String svgPathData;
  final V2PathFillRule fillRule;
  final PathSelectionContoursV2 contours;
}

class PathSelectionContoursV2 {
  const PathSelectionContoursV2({
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
