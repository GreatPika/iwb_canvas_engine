import 'dart:math' as math;
import 'dart:ui';

import 'hit_test.dart';
import 'nodes.dart';
import 'scene.dart';

const int kMaxCellsPerNode = 1024;
const double _defaultSpatialCellSize = 256;

typedef SpatialNodeLocation = ({int layerIndex, int nodeIndex});

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

  factory SceneSpatialIndex.build(
    Scene scene, {
    Map<NodeId, SpatialNodeLocation>? nodeLocator,
  }) {
    final index = SceneSpatialIndex._(_defaultSpatialCellSize);
    index._rebuild(
      scene: scene,
      nodeLocator: nodeLocator ?? _buildNodeLocator(scene),
    );
    return index;
  }

  final double _cellSize;
  final Map<_CellKey, Set<NodeId>> _cells = <_CellKey, Set<NodeId>>{};
  final Map<NodeId, _SpatialEntry> _entriesById = <NodeId, _SpatialEntry>{};
  final Set<NodeId> _largeNodeIds = <NodeId>{};

  Scene? _scene;
  Map<NodeId, SpatialNodeLocation> _nodeLocator =
      const <NodeId, SpatialNodeLocation>{};

  // Test-only counters for validating index routing decisions.
  int get debugLargeCandidateCount => _largeNodeIds.length;
  int get debugCellCount => _cells.length;

  /// Returns de-duplicated candidates whose coarse bounds intersect [worldRect].
  List<SceneSpatialCandidate> query(Rect worldRect) {
    if (!_isFiniteRect(worldRect)) return const <SceneSpatialCandidate>[];
    if (_entriesById.isEmpty) return const <SceneSpatialCandidate>[];

    final minX = math.min(worldRect.left, worldRect.right);
    final maxX = math.max(worldRect.left, worldRect.right);
    final minY = math.min(worldRect.top, worldRect.bottom);
    final maxY = math.max(worldRect.top, worldRect.bottom);
    final startX = _cellIndexFor(minX);
    final endX = _cellIndexFor(maxX);
    final startY = _cellIndexFor(minY);
    final endY = _cellIndexFor(maxY);

    final uniqueIds = <NodeId>{};
    for (var x = startX; x <= endX; x++) {
      for (var y = startY; y <= endY; y++) {
        final cell = _cells[_CellKey(x, y)];
        if (cell == null) continue;
        uniqueIds.addAll(cell);
      }
    }
    uniqueIds.addAll(_largeNodeIds);
    if (uniqueIds.isEmpty) return const <SceneSpatialCandidate>[];

    final out = <SceneSpatialCandidate>[];
    for (final nodeId in uniqueIds) {
      final entry = _entriesById[nodeId];
      if (entry == null) continue;
      if (!_rectsIntersectInclusive(entry.candidateBoundsWorld, worldRect)) {
        continue;
      }
      final resolved = _resolveNodeById(nodeId);
      if (resolved == null) continue;
      out.add(
        SceneSpatialCandidate(
          layerIndex: resolved.layerIndex,
          nodeIndex: resolved.nodeIndex,
          node: resolved.node,
          candidateBoundsWorld: entry.candidateBoundsWorld,
        ),
      );
    }
    return out.toList(growable: false);
  }

  /// Applies commit deltas without full scene rebuild.
  ///
  /// Returns `false` when index state cannot be updated safely and caller
  /// should invalidate and rebuild on next query.
  bool applyIncremental({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
    required Set<NodeId> addedNodeIds,
    required Set<NodeId> removedNodeIds,
    required Set<NodeId> hitGeometryChangedIds,
  }) {
    _bindState(scene: scene, nodeLocator: nodeLocator);
    if (addedNodeIds.isEmpty &&
        removedNodeIds.isEmpty &&
        hitGeometryChangedIds.isEmpty) {
      return true;
    }

    for (final nodeId in removedNodeIds) {
      _removeEntry(nodeId);
    }

    for (final nodeId in addedNodeIds) {
      if (!_upsertNodeById(nodeId)) {
        return false;
      }
    }

    for (final nodeId in hitGeometryChangedIds) {
      if (removedNodeIds.contains(nodeId)) continue;
      if (addedNodeIds.contains(nodeId)) continue;
      if (!_nodeLocator.containsKey(nodeId)) {
        return false;
      }
      _removeEntry(nodeId);
      if (!_upsertNodeById(nodeId)) {
        return false;
      }
    }

    return true;
  }

  void _rebuild({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
  }) {
    _bindState(scene: scene, nodeLocator: nodeLocator);
    _cells.clear();
    _entriesById.clear();
    _largeNodeIds.clear();

    for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
      final layer = scene.layers[layerIndex];
      if (layer.isBackground) continue;
      for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
        final node = layer.nodes[nodeIndex];
        _upsertResolvedNode(
          nodeId: node.id,
          node: node,
          layerIndex: layerIndex,
          nodeIndex: nodeIndex,
        );
      }
    }
  }

  void _bindState({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
  }) {
    _scene = scene;
    _nodeLocator = nodeLocator;
  }

  bool _upsertNodeById(NodeId nodeId) {
    final resolved = _resolveNodeById(nodeId);
    if (resolved == null) {
      return false;
    }
    _upsertResolvedNode(
      nodeId: nodeId,
      node: resolved.node,
      layerIndex: resolved.layerIndex,
      nodeIndex: resolved.nodeIndex,
    );
    return true;
  }

  void _upsertResolvedNode({
    required NodeId nodeId,
    required SceneNode node,
    required int layerIndex,
    required int nodeIndex,
  }) {
    _removeEntry(nodeId);
    final scene = _scene;
    if (scene == null) return;
    if (layerIndex < 0 || layerIndex >= scene.layers.length) return;
    if (scene.layers[layerIndex].isBackground) return;
    if (nodeIndex < 0 || nodeIndex >= scene.layers[layerIndex].nodes.length) {
      return;
    }

    final candidateBounds = nodeHitTestCandidateBoundsWorld(node);
    if (!_isFiniteRect(candidateBounds)) return;

    final entry = _SpatialEntry(
      nodeId: nodeId,
      candidateBoundsWorld: candidateBounds,
    );
    _entriesById[nodeId] = entry;
    _placeEntry(entry);
  }

  void _placeEntry(_SpatialEntry entry) {
    final startX = _cellIndexFor(entry.candidateBoundsWorld.left);
    final endX = _cellIndexFor(entry.candidateBoundsWorld.right);
    final startY = _cellIndexFor(entry.candidateBoundsWorld.top);
    final endY = _cellIndexFor(entry.candidateBoundsWorld.bottom);
    if (_isLargeSpan(startX: startX, endX: endX, startY: startY, endY: endY)) {
      entry.isLarge = true;
      _largeNodeIds.add(entry.nodeId);
      return;
    }

    for (var x = startX; x <= endX; x++) {
      for (var y = startY; y <= endY; y++) {
        final key = _CellKey(x, y);
        final cell = _cells.putIfAbsent(key, () => <NodeId>{});
        cell.add(entry.nodeId);
        entry.coveredCells.add(key);
      }
    }
  }

  void _removeEntry(NodeId nodeId) {
    final entry = _entriesById.remove(nodeId);
    if (entry == null) return;

    if (entry.isLarge) {
      _largeNodeIds.remove(nodeId);
      return;
    }

    for (final key in entry.coveredCells) {
      final cell = _cells[key];
      if (cell == null) continue;
      cell.remove(nodeId);
      if (cell.isEmpty) {
        _cells.remove(key);
      }
    }
  }

  ({SceneNode node, int layerIndex, int nodeIndex})? _resolveNodeById(
    NodeId nodeId,
  ) {
    final scene = _scene;
    if (scene == null) return null;
    final location = _nodeLocator[nodeId];
    if (location == null) return null;
    final layerIndex = location.layerIndex;
    if (layerIndex < 0 || layerIndex >= scene.layers.length) return null;
    final layer = scene.layers[layerIndex];
    final nodeIndex = location.nodeIndex;
    if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) return null;
    final node = layer.nodes[nodeIndex];
    if (node.id != nodeId) return null;
    return (node: node, layerIndex: layerIndex, nodeIndex: nodeIndex);
  }

  int _cellIndexFor(double coordinate) {
    return (coordinate / _cellSize).floor();
  }

  bool _isLargeSpan({
    required int startX,
    required int endX,
    required int startY,
    required int endY,
  }) {
    final dx = endX - startX + 1;
    final dy = endY - startY + 1;
    if (dx <= 0 || dy <= 0) return true;
    if (dx > kMaxCellsPerNode || dy > kMaxCellsPerNode) return true;
    return dx * dy > kMaxCellsPerNode;
  }
}

class _SpatialEntry {
  _SpatialEntry({required this.nodeId, required this.candidateBoundsWorld});

  final NodeId nodeId;
  final Rect candidateBoundsWorld;
  final Set<_CellKey> coveredCells = <_CellKey>{};
  bool isLarge = false;
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

Map<NodeId, SpatialNodeLocation> _buildNodeLocator(Scene scene) {
  final out = <NodeId, SpatialNodeLocation>{};
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final layer = scene.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final node = layer.nodes[nodeIndex];
      out[node.id] = (layerIndex: layerIndex, nodeIndex: nodeIndex);
    }
  }
  return out;
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
