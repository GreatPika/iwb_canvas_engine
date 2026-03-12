import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'node_geometry.dart';
import 'nodes.dart';
import 'scene.dart';
import 'scene_limits.dart';

const int kMaxCellsPerNode = 1024;
const int kMaxQueryCells = 50000;
const double _defaultSpatialCellSize = 256;

typedef SpatialNodeLocation = ({int layerIndex, int nodeIndex});
typedef _CellSpan = ({int startX, int endX, int startY, int endY});

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
  int _debugFallbackQueryCount = 0;
  bool _isValid = true;

  Scene? _scene;
  Map<NodeId, SpatialNodeLocation> _nodeLocator =
      const <NodeId, SpatialNodeLocation>{};

  // Test-only counters for validating index routing decisions.
  int get debugLargeCandidateCount => _largeNodeIds.length;
  int get debugCellCount => _cells.length;
  int get debugFallbackQueryCount => _debugFallbackQueryCount;
  bool get isValid => _isValid;

  /// Returns de-duplicated candidates whose coarse bounds intersect [worldRect].
  List<SceneSpatialCandidate> query(Rect worldRect) {
    if (!isFiniteRect(worldRect)) return const <SceneSpatialCandidate>[];
    final scene = _scene;
    if (scene == null) return const <SceneSpatialCandidate>[];
    if (!_isValid) {
      return _queryLinearFallback(scene, worldRect);
    }

    try {
      if (_entriesById.isEmpty) return const <SceneSpatialCandidate>[];
      final candidateIds = _queryCandidateIds(worldRect);
      if (candidateIds == null) {
        return _queryLinearFallback(scene, worldRect);
      }
      return _resolveCandidates(candidateIds, worldRect);
    } catch (_) {
      _markInvalid();
      return _queryLinearFallback(scene, worldRect);
    }
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
    if (!_isValid) {
      return false;
    }
    final changeSet = _IncrementalChangeSet(
      addedNodeIds: addedNodeIds,
      removedNodeIds: removedNodeIds,
      hitGeometryChangedIds: hitGeometryChangedIds,
    );
    if (_hasNoIncrementalChanges(changeSet)) {
      return true;
    }

    try {
      _removeEntries(changeSet.removedNodeIds);
      return _applyIncrementalUpserts(changeSet);
    } catch (_) {
      _markInvalid();
      return false;
    }
  }

  /// Returns an independent candidate index for atomic incremental updates.
  ///
  /// The returned index does not share mutable containers with this instance.
  SceneSpatialIndex cloneForIncrementalUpdate({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
  }) {
    final clone = SceneSpatialIndex._(_cellSize);
    clone._isValid = _isValid;
    clone._debugFallbackQueryCount = _debugFallbackQueryCount;
    clone._bindState(scene: scene, nodeLocator: nodeLocator);

    for (final entry in _cells.entries) {
      clone._cells[entry.key] = <NodeId>{...entry.value};
    }
    for (final entry in _entriesById.entries) {
      clone._entriesById[entry.key] = entry.value._clone();
    }
    clone._largeNodeIds.addAll(_largeNodeIds);
    return clone;
  }

  void _rebuild({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
  }) {
    _bindState(scene: scene, nodeLocator: nodeLocator);
    _isValid = true;
    _clearIndexData();
    try {
      for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
        final layer = scene.layers[layerIndex];
        for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
          final node = layer.nodes[nodeIndex];
          if (!_upsertResolvedNode(
            nodeId: node.id,
            node: node,
            layerIndex: layerIndex,
            nodeIndex: nodeIndex,
          )) {
            return;
          }
        }
      }
    } catch (_) {
      _markInvalid();
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
    return _upsertResolvedNode(
      nodeId: nodeId,
      node: resolved.node,
      layerIndex: resolved.layerIndex,
      nodeIndex: resolved.nodeIndex,
    );
  }

  bool _upsertResolvedNode({
    required NodeId nodeId,
    required SceneNode node,
    required int layerIndex,
    required int nodeIndex,
  }) {
    _removeEntry(nodeId);
    final scene = _scene;
    if (scene == null) return true;
    if (layerIndex < 0 || layerIndex >= scene.layers.length) return true;
    if (nodeIndex < 0 || nodeIndex >= scene.layers[layerIndex].nodes.length) {
      return true;
    }

    final candidateBounds = nodeGeometryCandidateBoundsWorld(node);
    if (!isFiniteRect(candidateBounds)) return true;

    final entry = _SpatialEntry(
      nodeId: nodeId,
      candidateBoundsWorld: candidateBounds,
    );
    _entriesById[nodeId] = entry;
    if (_placeEntry(entry)) {
      return true;
    }
    _entriesById.remove(nodeId);
    return false;
  }

  bool _placeEntry(_SpatialEntry entry) {
    final span = _tryCellSpanForRect(entry.candidateBoundsWorld);
    if (span == null) {
      _markInvalid();
      return false;
    }
    if (_isLargeSpan(span, maxCells: kMaxCellsPerNode)) {
      entry.isLarge = true;
      _largeNodeIds.add(entry.nodeId);
      return true;
    }

    for (var x = span.startX; x <= span.endX; x++) {
      for (var y = span.startY; y <= span.endY; y++) {
        final key = _CellKey(x, y);
        final cell = _cells.putIfAbsent(key, () => <NodeId>{});
        cell.add(entry.nodeId);
        entry.coveredCells.add(key);
      }
    }
    return true;
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
    if (layerIndex == -1) return null;
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

  _CellSpan? _tryCellSpanForRect(Rect rect) {
    final minX = math.min(rect.left, rect.right);
    final maxX = math.max(rect.left, rect.right);
    final minY = math.min(rect.top, rect.bottom);
    final maxY = math.max(rect.top, rect.bottom);
    if (!_isCoordinateInIndexBounds(minX) ||
        !_isCoordinateInIndexBounds(maxX) ||
        !_isCoordinateInIndexBounds(minY) ||
        !_isCoordinateInIndexBounds(maxY)) {
      return null;
    }
    return (
      startX: _cellIndexFor(minX),
      endX: _cellIndexFor(maxX),
      startY: _cellIndexFor(minY),
      endY: _cellIndexFor(maxY),
    );
  }

  List<SceneSpatialCandidate> _queryLinear(Scene scene, Rect worldRect) {
    final out = <SceneSpatialCandidate>[];
    for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
      final layer = scene.layers[layerIndex];
      for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
        final node = layer.nodes[nodeIndex];
        final candidateBounds = nodeGeometryCandidateBoundsWorld(node);
        if (!isFiniteRect(candidateBounds)) continue;
        if (!_rectsIntersectInclusive(candidateBounds, worldRect)) continue;
        out.add(
          SceneSpatialCandidate(
            layerIndex: layerIndex,
            nodeIndex: nodeIndex,
            node: node,
            candidateBoundsWorld: candidateBounds,
          ),
        );
      }
    }
    return out.toList(growable: false);
  }

  List<SceneSpatialCandidate> _queryLinearFallback(
    Scene scene,
    Rect worldRect,
  ) {
    _debugFallbackQueryCount = _debugFallbackQueryCount + 1;
    return _queryLinear(scene, worldRect);
  }

  Set<NodeId>? _queryCandidateIds(Rect worldRect) {
    final span = _tryCellSpanForRect(worldRect);
    if (span == null) {
      return null;
    }
    if (_isLargeSpan(span, maxCells: kMaxQueryCells)) {
      _debugFallbackQueryCount = _debugFallbackQueryCount + 1;
      return _entriesById.keys.toSet();
    }
    return _collectGridCandidateIds(span);
  }

  Set<NodeId> _collectGridCandidateIds(_CellSpan span) {
    final uniqueIds = <NodeId>{};
    for (var x = span.startX; x <= span.endX; x++) {
      for (var y = span.startY; y <= span.endY; y++) {
        final cell = _cells[_CellKey(x, y)];
        if (cell == null) continue;
        uniqueIds.addAll(cell);
      }
    }
    uniqueIds.addAll(_largeNodeIds);
    return uniqueIds;
  }

  List<SceneSpatialCandidate> _resolveCandidates(
    Set<NodeId> candidateIds,
    Rect worldRect,
  ) {
    final out = <SceneSpatialCandidate>[];
    for (final nodeId in candidateIds) {
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

  bool _hasNoIncrementalChanges(_IncrementalChangeSet changeSet) {
    return changeSet.addedNodeIds.isEmpty &&
        changeSet.removedNodeIds.isEmpty &&
        changeSet.hitGeometryChangedIds.isEmpty;
  }

  void _removeEntries(Set<NodeId> nodeIds) {
    for (final nodeId in nodeIds) {
      _removeEntry(nodeId);
    }
  }

  bool _applyIncrementalUpserts(_IncrementalChangeSet changeSet) {
    if (!_upsertNodeIds(changeSet.addedNodeIds)) {
      return false;
    }
    return _refreshChangedNodeIds(changeSet);
  }

  bool _upsertNodeIds(Set<NodeId> nodeIds) {
    for (final nodeId in nodeIds) {
      if (!_upsertNodeById(nodeId)) {
        return false;
      }
    }
    return true;
  }

  bool _refreshChangedNodeIds(_IncrementalChangeSet changeSet) {
    for (final nodeId in changeSet.hitGeometryChangedIds) {
      if (changeSet.removedNodeIds.contains(nodeId) ||
          changeSet.addedNodeIds.contains(nodeId)) {
        continue;
      }
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

  bool _isCoordinateInIndexBounds(double value) {
    return value >= sceneCoordMin && value <= sceneCoordMax;
  }

  void _markInvalid() {
    if (!_isValid) return;
    _isValid = false;
    _clearIndexData();
  }

  void _clearIndexData() {
    _cells.clear();
    _entriesById.clear();
    _largeNodeIds.clear();
  }

  bool _isLargeSpan(_CellSpan span, {required int maxCells}) {
    final dx = span.endX - span.startX + 1;
    final dy = span.endY - span.startY + 1;
    if (dx <= 0 || dy <= 0) return true;
    if (dx > maxCells || dy > maxCells) return true;
    return dx * dy > maxCells;
  }
}

class _IncrementalChangeSet {
  const _IncrementalChangeSet({
    required this.addedNodeIds,
    required this.removedNodeIds,
    required this.hitGeometryChangedIds,
  });

  final Set<NodeId> addedNodeIds;
  final Set<NodeId> removedNodeIds;
  final Set<NodeId> hitGeometryChangedIds;
}

class _SpatialEntry {
  _SpatialEntry({required this.nodeId, required this.candidateBoundsWorld});

  final NodeId nodeId;
  final Rect candidateBoundsWorld;
  final Set<_CellKey> coveredCells = <_CellKey>{};
  bool isLarge = false;

  _SpatialEntry _clone() {
    final clone = _SpatialEntry(
      nodeId: nodeId,
      candidateBoundsWorld: candidateBoundsWorld,
    );
    clone.coveredCells.addAll(coveredCells);
    clone.isLarge = isLarge;
    return clone;
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

bool _rectsIntersectInclusive(Rect a, Rect b) {
  return a.left <= b.right &&
      a.right >= b.left &&
      a.top <= b.bottom &&
      a.bottom >= b.top;
}
