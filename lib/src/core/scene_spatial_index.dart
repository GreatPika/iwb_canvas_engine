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
typedef _ResolvedSpatialNode = ({
  SceneNode node,
  int layerIndex,
  int nodeIndex,
});

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
    _rebuildSpatialIndex(
      index,
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
    return _querySceneSpatialIndex(this, worldRect);
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
    return _applySceneSpatialIndexIncremental(
      this,
      scene: scene,
      nodeLocator: nodeLocator,
      changeSet: _IncrementalChangeSet(
        addedNodeIds: addedNodeIds,
        removedNodeIds: removedNodeIds,
        hitGeometryChangedIds: hitGeometryChangedIds,
      ),
    );
  }

  /// Returns an independent candidate index for atomic incremental updates.
  ///
  /// The returned index does not share mutable containers with this instance.
  SceneSpatialIndex cloneForIncrementalUpdate({
    required Scene scene,
    required Map<NodeId, SpatialNodeLocation> nodeLocator,
  }) {
    return _cloneSceneSpatialIndex(
      this,
      scene: scene,
      nodeLocator: nodeLocator,
    );
  }
}

List<SceneSpatialCandidate> _querySceneSpatialIndex(
  SceneSpatialIndex index,
  Rect worldRect,
) {
  if (!isFiniteRect(worldRect)) return const <SceneSpatialCandidate>[];
  final scene = index._scene;
  if (scene == null) return const <SceneSpatialCandidate>[];
  if (!index._isValid) {
    return _queryLinearFallback(index, scene, worldRect);
  }

  try {
    if (index._entriesById.isEmpty) return const <SceneSpatialCandidate>[];
    final candidateIds = _queryCandidateIds(index, worldRect);
    if (candidateIds == null) {
      return _queryLinearFallback(index, scene, worldRect);
    }
    return _resolveCandidates(index, candidateIds, worldRect);
  } catch (_) {
    _markSpatialIndexInvalid(index);
    return _queryLinearFallback(index, scene, worldRect);
  }
}

bool _applySceneSpatialIndexIncremental(
  SceneSpatialIndex index, {
  required Scene scene,
  required Map<NodeId, SpatialNodeLocation> nodeLocator,
  required _IncrementalChangeSet changeSet,
}) {
  _bindSpatialIndexState(index, scene: scene, nodeLocator: nodeLocator);
  if (!index._isValid) {
    return false;
  }
  if (_hasNoIncrementalChanges(changeSet)) {
    return true;
  }

  try {
    _removeEntries(index, changeSet.removedNodeIds);
    return _applyIncrementalUpserts(index, changeSet);
  } catch (_) {
    _markSpatialIndexInvalid(index);
    return false;
  }
}

SceneSpatialIndex _cloneSceneSpatialIndex(
  SceneSpatialIndex source, {
  required Scene scene,
  required Map<NodeId, SpatialNodeLocation> nodeLocator,
}) {
  final clone = SceneSpatialIndex._(source._cellSize);
  clone._isValid = source._isValid;
  clone._debugFallbackQueryCount = source._debugFallbackQueryCount;
  _bindSpatialIndexState(clone, scene: scene, nodeLocator: nodeLocator);

  for (final entry in source._cells.entries) {
    clone._cells[entry.key] = <NodeId>{...entry.value};
  }
  for (final entry in source._entriesById.entries) {
    clone._entriesById[entry.key] = entry.value._clone();
  }
  clone._largeNodeIds.addAll(source._largeNodeIds);
  return clone;
}

void _rebuildSpatialIndex(
  SceneSpatialIndex index, {
  required Scene scene,
  required Map<NodeId, SpatialNodeLocation> nodeLocator,
}) {
  _bindSpatialIndexState(index, scene: scene, nodeLocator: nodeLocator);
  index._isValid = true;
  _clearSpatialIndexData(index);
  try {
    _visitResolvedNodes(scene, (resolved) {
      if (!_upsertResolvedSpatialNode(index, resolved: resolved)) {
        throw const _SceneSpatialIndexTraversalAbort();
      }
    });
  } catch (_) {
    _markSpatialIndexInvalid(index);
  }
}

void _bindSpatialIndexState(
  SceneSpatialIndex index, {
  required Scene scene,
  required Map<NodeId, SpatialNodeLocation> nodeLocator,
}) {
  index._scene = scene;
  index._nodeLocator = nodeLocator;
}

bool _upsertNodeById(SceneSpatialIndex index, NodeId nodeId) {
  final resolved = _resolveSpatialNodeById(index, nodeId);
  if (resolved == null) {
    return false;
  }
  return _upsertResolvedSpatialNode(index, resolved: resolved);
}

bool _upsertResolvedSpatialNode(
  SceneSpatialIndex index, {
  required _ResolvedSpatialNode resolved,
}) {
  final nodeId = resolved.node.id;
  _removeSpatialEntry(index, nodeId);
  final scene = index._scene;
  if (scene == null) return true;
  if (resolved.layerIndex < 0 || resolved.layerIndex >= scene.layers.length) {
    return true;
  }
  if (resolved.nodeIndex < 0 ||
      resolved.nodeIndex >= scene.layers[resolved.layerIndex].nodes.length) {
    return true;
  }

  final candidateBounds = nodeGeometryCandidateBoundsWorld(resolved.node);
  if (!isFiniteRect(candidateBounds)) return true;

  final entry = _SpatialEntry(
    nodeId: nodeId,
    candidateBoundsWorld: candidateBounds,
  );
  index._entriesById[nodeId] = entry;
  if (_placeSpatialEntry(index, entry)) {
    return true;
  }
  index._entriesById.remove(nodeId);
  return false;
}

bool _placeSpatialEntry(SceneSpatialIndex index, _SpatialEntry entry) {
  final span = _tryCellSpanForRect(index, entry.candidateBoundsWorld);
  if (span == null) {
    _markSpatialIndexInvalid(index);
    return false;
  }
  if (_isLargeSpan(span, maxCells: kMaxCellsPerNode)) {
    entry.isLarge = true;
    index._largeNodeIds.add(entry.nodeId);
    return true;
  }

  for (var x = span.startX; x <= span.endX; x++) {
    for (var y = span.startY; y <= span.endY; y++) {
      final key = _CellKey(x, y);
      final cell = index._cells.putIfAbsent(key, () => <NodeId>{});
      cell.add(entry.nodeId);
      entry.coveredCells.add(key);
    }
  }
  return true;
}

void _removeSpatialEntry(SceneSpatialIndex index, NodeId nodeId) {
  final entry = index._entriesById.remove(nodeId);
  if (entry == null) return;

  if (entry.isLarge) {
    index._largeNodeIds.remove(nodeId);
    return;
  }

  for (final key in entry.coveredCells) {
    final cell = index._cells[key];
    if (cell == null) continue;
    cell.remove(nodeId);
    if (cell.isEmpty) {
      index._cells.remove(key);
    }
  }
}

_ResolvedSpatialNode? _resolveSpatialNodeById(
  SceneSpatialIndex index,
  NodeId nodeId,
) {
  final scene = index._scene;
  if (scene == null) return null;
  final location = index._nodeLocator[nodeId];
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

int _cellIndexFor(SceneSpatialIndex index, double coordinate) {
  return (coordinate / index._cellSize).floor();
}

_CellSpan? _tryCellSpanForRect(SceneSpatialIndex index, Rect rect) {
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
    startX: _cellIndexFor(index, minX),
    endX: _cellIndexFor(index, maxX),
    startY: _cellIndexFor(index, minY),
    endY: _cellIndexFor(index, maxY),
  );
}

List<SceneSpatialCandidate> _queryLinear(Scene scene, Rect worldRect) {
  final out = <SceneSpatialCandidate>[];
  _visitResolvedNodes(scene, (resolved) {
    final candidateBounds = nodeGeometryCandidateBoundsWorld(resolved.node);
    if (!isFiniteRect(candidateBounds)) {
      return;
    }
    if (!_rectsIntersectInclusive(candidateBounds, worldRect)) {
      return;
    }
    out.add(
      SceneSpatialCandidate(
        layerIndex: resolved.layerIndex,
        nodeIndex: resolved.nodeIndex,
        node: resolved.node,
        candidateBoundsWorld: candidateBounds,
      ),
    );
  });
  return out.toList(growable: false);
}

List<SceneSpatialCandidate> _queryLinearFallback(
  SceneSpatialIndex index,
  Scene scene,
  Rect worldRect,
) {
  index._debugFallbackQueryCount = index._debugFallbackQueryCount + 1;
  return _queryLinear(scene, worldRect);
}

Set<NodeId>? _queryCandidateIds(SceneSpatialIndex index, Rect worldRect) {
  final span = _tryCellSpanForRect(index, worldRect);
  if (span == null) {
    return null;
  }
  if (_isLargeSpan(span, maxCells: kMaxQueryCells)) {
    index._debugFallbackQueryCount = index._debugFallbackQueryCount + 1;
    return index._entriesById.keys.toSet();
  }
  return _collectGridCandidateIds(index, span);
}

Set<NodeId> _collectGridCandidateIds(SceneSpatialIndex index, _CellSpan span) {
  final uniqueIds = <NodeId>{};
  for (var x = span.startX; x <= span.endX; x++) {
    for (var y = span.startY; y <= span.endY; y++) {
      final cell = index._cells[_CellKey(x, y)];
      if (cell == null) continue;
      uniqueIds.addAll(cell);
    }
  }
  uniqueIds.addAll(index._largeNodeIds);
  return uniqueIds;
}

List<SceneSpatialCandidate> _resolveCandidates(
  SceneSpatialIndex index,
  Set<NodeId> candidateIds,
  Rect worldRect,
) {
  final out = <SceneSpatialCandidate>[];
  for (final nodeId in candidateIds) {
    final entry = index._entriesById[nodeId];
    if (entry == null) continue;
    if (!_rectsIntersectInclusive(entry.candidateBoundsWorld, worldRect)) {
      continue;
    }
    final resolved = _resolveSpatialNodeById(index, nodeId);
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

void _removeEntries(SceneSpatialIndex index, Set<NodeId> nodeIds) {
  for (final nodeId in nodeIds) {
    _removeSpatialEntry(index, nodeId);
  }
}

bool _applyIncrementalUpserts(
  SceneSpatialIndex index,
  _IncrementalChangeSet changeSet,
) {
  if (!_upsertNodeIds(index, changeSet.addedNodeIds)) {
    return false;
  }
  return _refreshChangedNodeIds(index, changeSet);
}

bool _upsertNodeIds(SceneSpatialIndex index, Set<NodeId> nodeIds) {
  for (final nodeId in nodeIds) {
    if (!_upsertNodeById(index, nodeId)) {
      return false;
    }
  }
  return true;
}

bool _refreshChangedNodeIds(
  SceneSpatialIndex index,
  _IncrementalChangeSet changeSet,
) {
  for (final nodeId in changeSet.hitGeometryChangedIds) {
    if (changeSet.removedNodeIds.contains(nodeId) ||
        changeSet.addedNodeIds.contains(nodeId)) {
      continue;
    }
    if (!index._nodeLocator.containsKey(nodeId)) {
      return false;
    }
    _removeSpatialEntry(index, nodeId);
    if (!_upsertNodeById(index, nodeId)) {
      return false;
    }
  }
  return true;
}

bool _isCoordinateInIndexBounds(double value) {
  return value >= sceneCoordMin && value <= sceneCoordMax;
}

void _markSpatialIndexInvalid(SceneSpatialIndex index) {
  if (!index._isValid) return;
  index._isValid = false;
  _clearSpatialIndexData(index);
}

void _clearSpatialIndexData(SceneSpatialIndex index) {
  index._cells.clear();
  index._entriesById.clear();
  index._largeNodeIds.clear();
}

bool _isLargeSpan(_CellSpan span, {required int maxCells}) {
  final dx = span.endX - span.startX + 1;
  final dy = span.endY - span.startY + 1;
  if (dx <= 0 || dy <= 0) return true;
  if (dx > maxCells || dy > maxCells) return true;
  return dx * dy > maxCells;
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
  _visitResolvedNodes(scene, (resolved) {
    out[resolved.node.id] = (
      layerIndex: resolved.layerIndex,
      nodeIndex: resolved.nodeIndex,
    );
  });
  return out;
}

void _visitResolvedNodes(
  Scene scene,
  void Function(_ResolvedSpatialNode resolved) visit,
) {
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final layer = scene.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      visit((
        node: layer.nodes[nodeIndex],
        layerIndex: layerIndex,
        nodeIndex: nodeIndex,
      ));
    }
  }
}

bool _rectsIntersectInclusive(Rect a, Rect b) {
  return a.left <= b.right &&
      a.right >= b.left &&
      a.top <= b.bottom &&
      a.bottom >= b.top;
}

class _SceneSpatialIndexTraversalAbort {
  const _SceneSpatialIndexTraversalAbort();
}
