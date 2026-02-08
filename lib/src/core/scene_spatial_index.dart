import 'dart:math' as math;
import 'dart:ui';

import 'hit_test.dart';
import 'nodes.dart';
import 'scene.dart';

/// Scene node candidate returned by [SceneSpatialIndex.query].
class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.layerIndex,
    required this.nodeIndex,
    required this.node,
    required this.candidateBoundsWorld,
  });

  final int layerIndex;
  final int nodeIndex;
  final SceneNode node;
  final Rect candidateBoundsWorld;
}

/// Uniform-grid spatial index for coarse scene candidate lookup.
class SceneSpatialIndex {
  SceneSpatialIndex._(this._cellSize);

  factory SceneSpatialIndex.build(Scene scene, {double cellSize = 256}) {
    final resolvedCellSize = cellSize.isFinite && cellSize > 0
        ? cellSize
        : 256.0;
    final index = SceneSpatialIndex._(resolvedCellSize);
    index._build(scene);
    return index;
  }

  final double _cellSize;
  final Map<_CellKey, List<SceneSpatialCandidate>> _cells =
      <_CellKey, List<SceneSpatialCandidate>>{};

  /// Returns de-duplicated candidates whose coarse bounds intersect [worldRect].
  List<SceneSpatialCandidate> query(Rect worldRect) {
    if (!_isFiniteRect(worldRect)) return const <SceneSpatialCandidate>[];
    if (_cells.isEmpty) return const <SceneSpatialCandidate>[];

    final minX = math.min(worldRect.left, worldRect.right);
    final maxX = math.max(worldRect.left, worldRect.right);
    final minY = math.min(worldRect.top, worldRect.bottom);
    final maxY = math.max(worldRect.top, worldRect.bottom);
    final startX = _cellIndexFor(minX);
    final endX = _cellIndexFor(maxX);
    final startY = _cellIndexFor(minY);
    final endY = _cellIndexFor(maxY);

    final unique = <SceneSpatialCandidate>{};
    for (var x = startX; x <= endX; x++) {
      for (var y = startY; y <= endY; y++) {
        final cell = _cells[_CellKey(x, y)];
        if (cell == null) continue;
        for (final candidate in cell) {
          if (!_rectsIntersectInclusive(
            candidate.candidateBoundsWorld,
            worldRect,
          )) {
            continue;
          }
          unique.add(candidate);
        }
      }
    }
    return unique.toList(growable: false);
  }

  void _build(Scene scene) {
    for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
      final layer = scene.layers[layerIndex];
      if (layer.isBackground) continue;
      for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
        final node = layer.nodes[nodeIndex];
        final candidateBounds = nodeHitTestCandidateBoundsWorld(node);
        if (!_isFiniteRect(candidateBounds)) continue;

        final candidate = SceneSpatialCandidate(
          layerIndex: layerIndex,
          nodeIndex: nodeIndex,
          node: node,
          candidateBoundsWorld: candidateBounds,
        );
        final startX = _cellIndexFor(candidateBounds.left);
        final endX = _cellIndexFor(candidateBounds.right);
        final startY = _cellIndexFor(candidateBounds.top);
        final endY = _cellIndexFor(candidateBounds.bottom);
        for (var x = startX; x <= endX; x++) {
          for (var y = startY; y <= endY; y++) {
            final key = _CellKey(x, y);
            final cell = _cells.putIfAbsent(
              key,
              () => <SceneSpatialCandidate>[],
            );
            cell.add(candidate);
          }
        }
      }
    }
  }

  int _cellIndexFor(double coordinate) {
    return (coordinate / _cellSize).floor();
  }
}

class _CellKey {
  const _CellKey(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) {
    return other is _CellKey && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

bool _isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

bool _rectsIntersectInclusive(Rect a, Rect b) {
  return a.left <= b.right &&
      a.right >= b.left &&
      a.top <= b.bottom &&
      a.bottom >= b.top;
}
