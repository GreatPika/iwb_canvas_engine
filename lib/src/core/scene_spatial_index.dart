import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'hit_test.dart';
import 'node_geometry.dart';
import 'nodes.dart';
import 'scene.dart';
import 'scene_limits.dart';

const int kMaxCellsPerNode = 1024;
const int kMaxQueryCells = 50000;
const double _defaultSpatialCellSize = 256;

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  NodeId nodeId,
  int layerIndex,
  int nodeIndex,
});
typedef _CellSpan = ({int startX, int endX, int startY, int endY});
typedef _ResolvedSpatialNode = ({
  SceneNode node,
  int layerIndex,
  int nodeIndex,
});

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
}

/// Incremental scene delta applied to [SceneSpatialIndex].
class SceneSpatialIndexChangeSet {
  const SceneSpatialIndexChangeSet({
    required this.addedNodeIds,
    required this.removedNodeIds,
    required this.spatialGeometryChangedIds,
  });

  final Set<NodeId> addedNodeIds;
  final Set<NodeId> removedNodeIds;
  final Set<NodeId> spatialGeometryChangedIds;
}

/// Uniform-grid spatial index for coarse scene candidate lookup.
class SceneSpatialIndex {
  SceneSpatialIndex._(this._cellSize);

  factory SceneSpatialIndex.build(
    Scene scene, {
    Map<NodeId, SceneSpatialCandidateLocation>? nodeLocator,
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
  final Map<_CellKey, Set<NodeId>> _hitTestCells = <_CellKey, Set<NodeId>>{};
  final Map<_CellKey, Set<NodeId>> _paintCells = <_CellKey, Set<NodeId>>{};
  final Map<NodeId, _SpatialEntry> _entriesById = <NodeId, _SpatialEntry>{};
  final Set<NodeId> _largeHitTestNodeIds = <NodeId>{};
  final Set<NodeId> _largePaintNodeIds = <NodeId>{};
  int _debugFallbackQueryCount = 0;
  bool _isValid = true;

  Scene? _scene;
  Map<NodeId, SceneSpatialCandidateLocation> _nodeLocator =
      const <NodeId, SceneSpatialCandidateLocation>{};

  int get debugLargeCandidateCount =>
      <NodeId>{..._largeHitTestNodeIds, ..._largePaintNodeIds}.length;
  int get debugCellCount =>
      <_CellKey>{..._hitTestCells.keys, ..._paintCells.keys}.length;
  int get debugFallbackQueryCount => _debugFallbackQueryCount;
  bool get isValid => _isValid;

  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldRect) {
    return _querySceneSpatialIndexHitTest(this, worldRect);
  }

  List<ScenePaintSpatialCandidate> queryPaintCandidates(Rect worldRect) {
    return _querySceneSpatialIndexPaint(this, worldRect);
  }

  bool applyIncremental({
    required Scene scene,
    required Map<NodeId, SceneSpatialCandidateLocation> nodeLocator,
    required SceneSpatialIndexChangeSet changeSet,
  }) {
    return _applySceneSpatialIndexIncremental(
      this,
      scene: scene,
      nodeLocator: nodeLocator,
      changeSet: changeSet,
    );
  }

  SceneSpatialIndex cloneForIncrementalUpdate({
    required Scene scene,
    required Map<NodeId, SceneSpatialCandidateLocation> nodeLocator,
  }) {
    return _cloneSceneSpatialIndex(
      this,
      scene: scene,
      nodeLocator: nodeLocator,
    );
  }
}

List<SceneHitTestSpatialCandidate> _querySceneSpatialIndexHitTest(
  SceneSpatialIndex index,
  Rect worldRect,
) {
  if (!isFiniteRect(worldRect)) return const <SceneHitTestSpatialCandidate>[];
  final scene = index._scene;
  if (scene == null) return const <SceneHitTestSpatialCandidate>[];
  if (!index._isValid) {
    return _queryLinearFallbackHitTest(index, scene, worldRect);
  }

  try {
    if (index._entriesById.isEmpty) {
      return const <SceneHitTestSpatialCandidate>[];
    }
    final candidateIds = _queryCandidateIds(
      index,
      worldRect,
      cells: index._hitTestCells,
      largeNodeIds: index._largeHitTestNodeIds,
    );
    if (candidateIds == null) {
      return _queryLinearFallbackHitTest(index, scene, worldRect);
    }
    return _resolveHitTestCandidates(index, candidateIds, worldRect);
  } catch (_) {
    _markSpatialIndexInvalid(index);
    return _queryLinearFallbackHitTest(index, scene, worldRect);
  }
}

List<ScenePaintSpatialCandidate> _querySceneSpatialIndexPaint(
  SceneSpatialIndex index,
  Rect worldRect,
) {
  if (!isFiniteRect(worldRect)) return const <ScenePaintSpatialCandidate>[];
  final scene = index._scene;
  if (scene == null) return const <ScenePaintSpatialCandidate>[];
  if (!index._isValid) {
    return _queryLinearFallbackPaint(index, scene, worldRect);
  }

  try {
    if (index._entriesById.isEmpty) return const <ScenePaintSpatialCandidate>[];
    final candidateIds = _queryCandidateIds(
      index,
      worldRect,
      cells: index._paintCells,
      largeNodeIds: index._largePaintNodeIds,
    );
    if (candidateIds == null) {
      return _queryLinearFallbackPaint(index, scene, worldRect);
    }
    return _resolvePaintCandidates(index, candidateIds, worldRect);
  } catch (_) {
    _markSpatialIndexInvalid(index);
    return _queryLinearFallbackPaint(index, scene, worldRect);
  }
}

bool _applySceneSpatialIndexIncremental(
  SceneSpatialIndex index, {
  required Scene scene,
  required Map<NodeId, SceneSpatialCandidateLocation> nodeLocator,
  required SceneSpatialIndexChangeSet changeSet,
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
  required Map<NodeId, SceneSpatialCandidateLocation> nodeLocator,
}) {
  final clone = SceneSpatialIndex._(source._cellSize);
  clone._isValid = source._isValid;
  clone._debugFallbackQueryCount = source._debugFallbackQueryCount;
  _bindSpatialIndexState(clone, scene: scene, nodeLocator: nodeLocator);

  for (final entry in source._hitTestCells.entries) {
    clone._hitTestCells[entry.key] = <NodeId>{...entry.value};
  }
  for (final entry in source._paintCells.entries) {
    clone._paintCells[entry.key] = <NodeId>{...entry.value};
  }
  for (final entry in source._entriesById.entries) {
    clone._entriesById[entry.key] = entry.value._clone();
  }
  clone._largeHitTestNodeIds.addAll(source._largeHitTestNodeIds);
  clone._largePaintNodeIds.addAll(source._largePaintNodeIds);
  return clone;
}

void _rebuildSpatialIndex(
  SceneSpatialIndex index, {
  required Scene scene,
  required Map<NodeId, SceneSpatialCandidateLocation> nodeLocator,
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
  required Map<NodeId, SceneSpatialCandidateLocation> nodeLocator,
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

  final hitTestBounds = nodeHitTestCandidateBoundsWorld(resolved.node);
  final paintBounds = nodePaintBoundsWorld(resolved.node);
  if (!isFiniteRect(hitTestBounds) || !isFiniteRect(paintBounds)) {
    return true;
  }

  final entry = _SpatialEntry(
    nodeId: nodeId,
    hitTestBoundsWorld: hitTestBounds,
    paintBoundsWorld: paintBounds,
  );
  index._entriesById[nodeId] = entry;
  if (_placeSpatialEntry(index, entry)) {
    return true;
  }
  index._entriesById.remove(nodeId);
  return false;
}

bool _placeSpatialEntry(SceneSpatialIndex index, _SpatialEntry entry) {
  final hitSpan = _tryCellSpanForRect(index, entry.hitTestBoundsWorld);
  final paintSpan = _tryCellSpanForRect(index, entry.paintBoundsWorld);
  if (hitSpan == null || paintSpan == null) {
    _markSpatialIndexInvalid(index);
    return false;
  }
  _placeRoleSpatialEntry(
    entry: entry,
    span: hitSpan,
    cells: index._hitTestCells,
    largeNodeIds: index._largeHitTestNodeIds,
    coveredCells: entry.hitTestCoveredCells,
    markLarge: () => entry.isLargeHitTest = true,
  );
  _placeRoleSpatialEntry(
    entry: entry,
    span: paintSpan,
    cells: index._paintCells,
    largeNodeIds: index._largePaintNodeIds,
    coveredCells: entry.paintCoveredCells,
    markLarge: () => entry.isLargePaint = true,
  );
  return true;
}

void _placeRoleSpatialEntry({
  required _SpatialEntry entry,
  required _CellSpan span,
  required Map<_CellKey, Set<NodeId>> cells,
  required Set<NodeId> largeNodeIds,
  required Set<_CellKey> coveredCells,
  required void Function() markLarge,
}) {
  if (_isLargeSpan(span, maxCells: kMaxCellsPerNode)) {
    markLarge();
    largeNodeIds.add(entry.nodeId);
    return;
  }

  for (var x = span.startX; x <= span.endX; x++) {
    for (var y = span.startY; y <= span.endY; y++) {
      final key = _CellKey(x, y);
      final cell = cells.putIfAbsent(key, () => <NodeId>{});
      cell.add(entry.nodeId);
      coveredCells.add(key);
    }
  }
}

void _removeSpatialEntry(SceneSpatialIndex index, NodeId nodeId) {
  final entry = index._entriesById.remove(nodeId);
  if (entry == null) return;

  _removeRoleSpatialEntry(
    nodeId: nodeId,
    cells: index._hitTestCells,
    largeNodeIds: index._largeHitTestNodeIds,
    coveredCells: entry.hitTestCoveredCells,
    isLarge: entry.isLargeHitTest,
  );
  _removeRoleSpatialEntry(
    nodeId: nodeId,
    cells: index._paintCells,
    largeNodeIds: index._largePaintNodeIds,
    coveredCells: entry.paintCoveredCells,
    isLarge: entry.isLargePaint,
  );
}

void _removeRoleSpatialEntry({
  required NodeId nodeId,
  required Map<_CellKey, Set<NodeId>> cells,
  required Set<NodeId> largeNodeIds,
  required Set<_CellKey> coveredCells,
  required bool isLarge,
}) {
  if (isLarge) {
    largeNodeIds.remove(nodeId);
    return;
  }

  for (final key in coveredCells) {
    final cell = cells[key];
    if (cell == null) continue;
    cell.remove(nodeId);
    if (cell.isEmpty) {
      cells.remove(key);
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

List<SceneHitTestSpatialCandidate> _queryLinearHitTest(
  Scene scene,
  Rect worldRect,
) {
  final out = <SceneHitTestSpatialCandidate>[];
  _visitResolvedNodes(scene, (resolved) {
    final hitTestBounds = nodeHitTestCandidateBoundsWorld(resolved.node);
    if (!isFiniteRect(hitTestBounds)) {
      return;
    }
    if (!_rectsIntersectInclusive(hitTestBounds, worldRect)) {
      return;
    }
    out.add(
      SceneHitTestSpatialCandidate(
        nodeId: resolved.node.id,
        layerIndex: resolved.layerIndex,
        nodeIndex: resolved.nodeIndex,
        hitTestBoundsWorld: hitTestBounds,
      ),
    );
  });
  return out.toList(growable: false);
}

List<ScenePaintSpatialCandidate> _queryLinearPaint(
  Scene scene,
  Rect worldRect,
) {
  final out = <ScenePaintSpatialCandidate>[];
  _visitResolvedNodes(scene, (resolved) {
    final paintBounds = nodePaintBoundsWorld(resolved.node);
    if (!isFiniteRect(paintBounds)) {
      return;
    }
    if (!_rectsIntersectInclusive(paintBounds, worldRect)) {
      return;
    }
    out.add(
      ScenePaintSpatialCandidate(
        nodeId: resolved.node.id,
        layerIndex: resolved.layerIndex,
        nodeIndex: resolved.nodeIndex,
        paintBoundsWorld: paintBounds,
      ),
    );
  });
  return out.toList(growable: false);
}

List<SceneHitTestSpatialCandidate> _queryLinearFallbackHitTest(
  SceneSpatialIndex index,
  Scene scene,
  Rect worldRect,
) {
  index._debugFallbackQueryCount = index._debugFallbackQueryCount + 1;
  return _queryLinearHitTest(scene, worldRect);
}

List<ScenePaintSpatialCandidate> _queryLinearFallbackPaint(
  SceneSpatialIndex index,
  Scene scene,
  Rect worldRect,
) {
  index._debugFallbackQueryCount = index._debugFallbackQueryCount + 1;
  return _queryLinearPaint(scene, worldRect);
}

Set<NodeId>? _queryCandidateIds(
  SceneSpatialIndex index,
  Rect worldRect, {
  required Map<_CellKey, Set<NodeId>> cells,
  required Set<NodeId> largeNodeIds,
}) {
  final span = _tryCellSpanForRect(index, worldRect);
  if (span == null) {
    return null;
  }
  if (_isLargeSpan(span, maxCells: kMaxQueryCells)) {
    index._debugFallbackQueryCount = index._debugFallbackQueryCount + 1;
    return <NodeId>{...cells.values.expand((value) => value), ...largeNodeIds};
  }
  return _collectGridCandidateIds(cells, largeNodeIds, span);
}

Set<NodeId> _collectGridCandidateIds(
  Map<_CellKey, Set<NodeId>> cells,
  Set<NodeId> largeNodeIds,
  _CellSpan span,
) {
  final uniqueIds = <NodeId>{};
  for (var x = span.startX; x <= span.endX; x++) {
    for (var y = span.startY; y <= span.endY; y++) {
      final cell = cells[_CellKey(x, y)];
      if (cell == null) continue;
      uniqueIds.addAll(cell);
    }
  }
  uniqueIds.addAll(largeNodeIds);
  return uniqueIds;
}

List<SceneHitTestSpatialCandidate> _resolveHitTestCandidates(
  SceneSpatialIndex index,
  Set<NodeId> candidateIds,
  Rect worldRect,
) {
  final out = <SceneHitTestSpatialCandidate>[];
  for (final nodeId in candidateIds) {
    final entry = index._entriesById[nodeId];
    if (entry == null) continue;
    if (!_rectsIntersectInclusive(entry.hitTestBoundsWorld, worldRect)) {
      continue;
    }
    final resolved = _resolveSpatialNodeById(index, nodeId);
    if (resolved == null) continue;
    out.add(
      SceneHitTestSpatialCandidate(
        nodeId: resolved.node.id,
        layerIndex: resolved.layerIndex,
        nodeIndex: resolved.nodeIndex,
        hitTestBoundsWorld: entry.hitTestBoundsWorld,
      ),
    );
  }
  return out.toList(growable: false);
}

List<ScenePaintSpatialCandidate> _resolvePaintCandidates(
  SceneSpatialIndex index,
  Set<NodeId> candidateIds,
  Rect worldRect,
) {
  final out = <ScenePaintSpatialCandidate>[];
  for (final nodeId in candidateIds) {
    final entry = index._entriesById[nodeId];
    if (entry == null) continue;
    if (!_rectsIntersectInclusive(entry.paintBoundsWorld, worldRect)) {
      continue;
    }
    final resolved = _resolveSpatialNodeById(index, nodeId);
    if (resolved == null) continue;
    out.add(
      ScenePaintSpatialCandidate(
        nodeId: resolved.node.id,
        layerIndex: resolved.layerIndex,
        nodeIndex: resolved.nodeIndex,
        paintBoundsWorld: entry.paintBoundsWorld,
      ),
    );
  }
  return out.toList(growable: false);
}

bool _hasNoIncrementalChanges(SceneSpatialIndexChangeSet changeSet) {
  return changeSet.addedNodeIds.isEmpty &&
      changeSet.removedNodeIds.isEmpty &&
      changeSet.spatialGeometryChangedIds.isEmpty;
}

void _removeEntries(SceneSpatialIndex index, Set<NodeId> nodeIds) {
  for (final nodeId in nodeIds) {
    _removeSpatialEntry(index, nodeId);
  }
}

bool _applyIncrementalUpserts(
  SceneSpatialIndex index,
  SceneSpatialIndexChangeSet changeSet,
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
  SceneSpatialIndexChangeSet changeSet,
) {
  for (final nodeId in changeSet.spatialGeometryChangedIds) {
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
  index._hitTestCells.clear();
  index._paintCells.clear();
  index._entriesById.clear();
  index._largeHitTestNodeIds.clear();
  index._largePaintNodeIds.clear();
}

bool _isLargeSpan(_CellSpan span, {required int maxCells}) {
  final dx = span.endX - span.startX + 1;
  final dy = span.endY - span.startY + 1;
  if (dx <= 0 || dy <= 0) return true;
  if (dx > maxCells || dy > maxCells) return true;
  return dx * dy > maxCells;
}

class _SpatialEntry {
  _SpatialEntry({
    required this.nodeId,
    required this.hitTestBoundsWorld,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final Rect hitTestBoundsWorld;
  final Rect paintBoundsWorld;
  final Set<_CellKey> hitTestCoveredCells = <_CellKey>{};
  final Set<_CellKey> paintCoveredCells = <_CellKey>{};
  bool isLargeHitTest = false;
  bool isLargePaint = false;

  _SpatialEntry _clone() {
    final clone = _SpatialEntry(
      nodeId: nodeId,
      hitTestBoundsWorld: hitTestBoundsWorld,
      paintBoundsWorld: paintBoundsWorld,
    );
    clone.hitTestCoveredCells.addAll(hitTestCoveredCells);
    clone.paintCoveredCells.addAll(paintCoveredCells);
    clone.isLargeHitTest = isLargeHitTest;
    clone.isLargePaint = isLargePaint;
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

Map<NodeId, SceneSpatialCandidateLocation> _buildNodeLocator(Scene scene) {
  final out = <NodeId, SceneSpatialCandidateLocation>{};
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

class _SceneSpatialIndexTraversalAbort implements Exception {
  const _SceneSpatialIndexTraversalAbort();
}
