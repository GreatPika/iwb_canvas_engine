import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/snapshot.dart';
import 'scan_resistant_cache.dart';

class ScenePathMetricsCache {
  ScenePathMetricsCache({int maxEntries = 512})
    : maxEntries = requirePositiveScanResistantCacheEntries(maxEntries),
      _entries = ScanResistantCache<_NodeInstanceKey, _PathMetricsEntry>(
        maxEntries: maxEntries,
      );

  final int maxEntries;
  final ScanResistantCache<_NodeInstanceKey, _PathMetricsEntry> _entries;

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
    return _entries
        .getOrBuild(
          key: key,
          isValid: (_PathMetricsEntry cached) =>
              cached.svgPathData == node.svgPathData &&
              cached.fillRule == node.fillRule,
          build: () {
            final contours = buildPathSelectionContours(
              localPath,
              node.fillRule,
            );
            return _PathMetricsEntry(
              svgPathData: node.svgPathData,
              fillRule: node.fillRule,
              contours: contours,
            );
          },
        )
        .contours;
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

PathSelectionContours buildPathSelectionContours(
  Path localPath,
  PathFillRule fillRule,
) {
  final pathFillType = _fillTypeFromSnapshot(fillRule);
  Path? closedContours;
  final openContours = <Path>[];
  for (final metric in localPath.computeMetrics()) {
    final contour = metric.extractPath(0, metric.length, startWithMoveTo: true);
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

PathFillType _fillTypeFromSnapshot(PathFillRule rule) {
  return rule == PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
}
