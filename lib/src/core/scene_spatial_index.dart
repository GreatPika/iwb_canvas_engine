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

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

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
  final Map<NodeId, _HitTestSpatialEntry> _hitTestEntriesById =
      <NodeId, _HitTestSpatialEntry>{};
  final Map<NodeId, _PaintSpatialEntry> _paintEntriesById =
      <NodeId, _PaintSpatialEntry>{};
  final Set<NodeId> _largeHitTestNodeIds = <NodeId>{};
  final Set<NodeId> _largePaintNodeIds = <NodeId>{};
  int _debugHitTestFallbackQueryCount = 0;
  int _debugPaintFallbackQueryCount = 0;
  bool _isHitTestValid = true;
  bool _isPaintValid = true;

  Scene? _scene;
  Map<NodeId, SceneSpatialCandidateLocation> _nodeLocator =
      const <NodeId, SceneSpatialCandidateLocation>{};

  int get debugLargeCandidateCount =>
      <NodeId>{..._largeHitTestNodeIds, ..._largePaintNodeIds}.length;
  int get debugCellCount =>
      <_CellKey>{..._hitTestCells.keys, ..._paintCells.keys}.length;
  int get debugFallbackQueryCount =>
      _debugHitTestFallbackQueryCount + _debugPaintFallbackQueryCount;
  bool get isValid => _isHitTestValid && _isPaintValid;

  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldRect) {
    return _querySceneSpatialIndexHitTest(this, worldRect);
  }

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldRect, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) {
    return _querySceneSpatialIndexPaint(this, worldRect, scope: scope);
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
  if (!index._isHitTestValid) {
    return _queryLinearFallbackHitTest(index, scene, worldRect);
  }

  try {
    if (index._hitTestEntriesById.isEmpty) {
      return const <SceneHitTestSpatialCandidate>[];
    }
    final candidateIds = _queryCandidateIds(
      index,
      worldRect,
      cells: index._hitTestCells,
      largeNodeIds: index._largeHitTestNodeIds,
      incrementFallbackCount: () {
        index._debugHitTestFallbackQueryCount =
            index._debugHitTestFallbackQueryCount + 1;
      },
    );
    if (candidateIds == null) {
      return _queryLinearFallbackHitTest(index, scene, worldRect);
    }
    return _resolveHitTestCandidates(index, candidateIds, worldRect);
  } catch (_) {
    _markHitTestInvalid(index);
    return _queryLinearFallbackHitTest(index, scene, worldRect);
  }
}

List<ScenePaintSpatialCandidate> _querySceneSpatialIndexPaint(
  SceneSpatialIndex index,
  Rect worldRect, {
  required ScenePaintSpatialQueryScope scope,
}) {
  if (!isFiniteRect(worldRect)) return const <ScenePaintSpatialCandidate>[];
  final scene = index._scene;
  if (scene == null) return const <ScenePaintSpatialCandidate>[];
  if (!index._isPaintValid) {
    return _queryLinearFallbackPaint(index, scene, worldRect, scope: scope);
  }

  try {
    if (index._paintEntriesById.isEmpty) {
      return const <ScenePaintSpatialCandidate>[];
    }
    final candidateIds = _queryCandidateIds(
      index,
      worldRect,
      cells: index._paintCells,
      largeNodeIds: index._largePaintNodeIds,
      incrementFallbackCount: () {
        index._debugPaintFallbackQueryCount =
            index._debugPaintFallbackQueryCount + 1;
      },
    );
    if (candidateIds == null) {
      return _queryLinearFallbackPaint(index, scene, worldRect, scope: scope);
    }
    return _resolvePaintCandidates(
      index,
      candidateIds,
      worldRect,
      scope: scope,
    );
  } catch (_) {
    _markPaintInvalid(index);
    return _queryLinearFallbackPaint(index, scene, worldRect, scope: scope);
  }
}

bool _applySceneSpatialIndexIncremental(
  SceneSpatialIndex index, {
  required Scene scene,
  required Map<NodeId, SceneSpatialCandidateLocation> nodeLocator,
  required SceneSpatialIndexChangeSet changeSet,
}) {
  _bindSpatialIndexState(index, scene: scene, nodeLocator: nodeLocator);
  if (_hasNoIncrementalChanges(changeSet)) {
    return true;
  }

  try {
    _removeEntries(index, changeSet.removedNodeIds);
    return _applyIncrementalUpserts(index, changeSet);
  } catch (_) {
    _markHitTestInvalid(index);
    _markPaintInvalid(index);
    return false;
  }
}

SceneSpatialIndex _cloneSceneSpatialIndex(
  SceneSpatialIndex source, {
  required Scene scene,
  required Map<NodeId, SceneSpatialCandidateLocation> nodeLocator,
}) {
  final clone = SceneSpatialIndex._(source._cellSize);
  clone._isHitTestValid = source._isHitTestValid;
  clone._isPaintValid = source._isPaintValid;
  clone._debugHitTestFallbackQueryCount =
      source._debugHitTestFallbackQueryCount;
  clone._debugPaintFallbackQueryCount = source._debugPaintFallbackQueryCount;
  _bindSpatialIndexState(clone, scene: scene, nodeLocator: nodeLocator);

  for (final entry in source._hitTestCells.entries) {
    clone._hitTestCells[entry.key] = <NodeId>{...entry.value};
  }
  for (final entry in source._paintCells.entries) {
    clone._paintCells[entry.key] = <NodeId>{...entry.value};
  }
  for (final entry in source._hitTestEntriesById.entries) {
    clone._hitTestEntriesById[entry.key] = entry.value._clone();
  }
  for (final entry in source._paintEntriesById.entries) {
    clone._paintEntriesById[entry.key] = entry.value._clone();
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
  index._isHitTestValid = true;
  index._isPaintValid = true;
  _clearHitTestData(index);
  _clearPaintData(index);

  try {
    _visitResolvedContentNodes(scene, (resolved) {
      if (!_upsertResolvedHitTestNode(index, resolved: resolved)) {
        throw const _SceneSpatialIndexTraversalAbort();
      }
    });
  } catch (_) {
    _markHitTestInvalid(index);
  }

  try {
    _visitResolvedPaintableNodes(scene, (resolved) {
      if (!_upsertResolvedPaintNode(index, resolved: resolved)) {
        throw const _SceneSpatialIndexTraversalAbort();
      }
    });
  } catch (_) {
    _markPaintInvalid(index);
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
  final hitTestApplied = resolved.layerIndex >= 0
      ? _upsertResolvedHitTestNode(index, resolved: resolved)
      : true;
  final paintApplied = _upsertResolvedPaintNode(index, resolved: resolved);
  return hitTestApplied && paintApplied;
}

bool _upsertResolvedHitTestNode(
  SceneSpatialIndex index, {
  required _ResolvedSpatialNode resolved,
}) {
  final nodeId = resolved.node.id;
  _removeHitTestSpatialEntry(index, nodeId);
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
  if (!isFiniteRect(hitTestBounds)) {
    return true;
  }

  final entry = _HitTestSpatialEntry(
    nodeId: nodeId,
    hitTestBoundsWorld: hitTestBounds,
  );
  index._hitTestEntriesById[nodeId] = entry;
  if (_placeHitTestSpatialEntry(index, entry)) {
    return true;
  }
  index._hitTestEntriesById.remove(nodeId);
  return false;
}

bool _upsertResolvedPaintNode(
  SceneSpatialIndex index, {
  required _ResolvedSpatialNode resolved,
}) {
  final nodeId = resolved.node.id;
  _removePaintSpatialEntry(index, nodeId);
  final scene = index._scene;
  if (scene == null) return true;
  if (!_isResolvedPaintNodeInScene(scene, resolved)) {
    return true;
  }

  final paintBounds = nodePaintBoundsWorld(resolved.node);
  if (!isFiniteRect(paintBounds)) {
    return true;
  }

  final entry = _PaintSpatialEntry(
    nodeId: nodeId,
    paintBoundsWorld: paintBounds,
  );
  index._paintEntriesById[nodeId] = entry;
  if (_placePaintSpatialEntry(index, entry)) {
    return true;
  }
  index._paintEntriesById.remove(nodeId);
  return false;
}

bool _isResolvedPaintNodeInScene(Scene scene, _ResolvedSpatialNode resolved) {
  if (resolved.layerIndex == -1) {
    final backgroundNodes = scene.backgroundLayer?.nodes;
    if (backgroundNodes == null) {
      return false;
    }
    return resolved.nodeIndex >= 0 &&
        resolved.nodeIndex < backgroundNodes.length;
  }
  if (resolved.layerIndex < 0 || resolved.layerIndex >= scene.layers.length) {
    return false;
  }
  return resolved.nodeIndex >= 0 &&
      resolved.nodeIndex < scene.layers[resolved.layerIndex].nodes.length;
}

bool _placeHitTestSpatialEntry(
  SceneSpatialIndex index,
  _HitTestSpatialEntry entry,
) {
  final hitSpan = _tryCellSpanForRect(index, entry.hitTestBoundsWorld);
  if (hitSpan == null) {
    _markHitTestInvalid(index);
    return false;
  }
  _placeRoleSpatialEntry(
    nodeId: entry.nodeId,
    span: hitSpan,
    cells: index._hitTestCells,
    largeNodeIds: index._largeHitTestNodeIds,
    coveredCells: entry.hitTestCoveredCells,
    markLarge: () => entry.isLargeHitTest = true,
  );
  return true;
}

bool _placePaintSpatialEntry(
  SceneSpatialIndex index,
  _PaintSpatialEntry entry,
) {
  final paintSpan = _tryCellSpanForRect(index, entry.paintBoundsWorld);
  if (paintSpan == null) {
    _markPaintInvalid(index);
    return false;
  }
  _placeRoleSpatialEntry(
    nodeId: entry.nodeId,
    span: paintSpan,
    cells: index._paintCells,
    largeNodeIds: index._largePaintNodeIds,
    coveredCells: entry.paintCoveredCells,
    markLarge: () => entry.isLargePaint = true,
  );
  return true;
}

void _placeRoleSpatialEntry({
  required NodeId nodeId,
  required _CellSpan span,
  required Map<_CellKey, Set<NodeId>> cells,
  required Set<NodeId> largeNodeIds,
  required Set<_CellKey> coveredCells,
  required void Function() markLarge,
}) {
  if (_isLargeSpan(span, maxCells: kMaxCellsPerNode)) {
    markLarge();
    largeNodeIds.add(nodeId);
    return;
  }

  for (var x = span.startX; x <= span.endX; x++) {
    for (var y = span.startY; y <= span.endY; y++) {
      final key = _CellKey(x, y);
      final cell = cells.putIfAbsent(key, () => <NodeId>{});
      cell.add(nodeId);
      coveredCells.add(key);
    }
  }
}

void _removeEntries(SceneSpatialIndex index, Set<NodeId> nodeIds) {
  for (final nodeId in nodeIds) {
    _removeHitTestSpatialEntry(index, nodeId);
    _removePaintSpatialEntry(index, nodeId);
  }
}

void _removeHitTestSpatialEntry(SceneSpatialIndex index, NodeId nodeId) {
  final entry = index._hitTestEntriesById.remove(nodeId);
  if (entry == null) return;
  _removeRoleSpatialEntry(
    nodeId: nodeId,
    cells: index._hitTestCells,
    largeNodeIds: index._largeHitTestNodeIds,
    coveredCells: entry.hitTestCoveredCells,
    isLarge: entry.isLargeHitTest,
  );
}

void _removePaintSpatialEntry(SceneSpatialIndex index, NodeId nodeId) {
  final entry = index._paintEntriesById.remove(nodeId);
  if (entry == null) return;
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
  final nodeIndex = location.nodeIndex;
  if (layerIndex == -1) {
    final backgroundNodes = scene.backgroundLayer?.nodes;
    if (backgroundNodes == null) return null;
    if (nodeIndex < 0 || nodeIndex >= backgroundNodes.length) return null;
    final node = backgroundNodes[nodeIndex];
    if (node.id != nodeId) return null;
    return (node: node, layerIndex: -1, nodeIndex: nodeIndex);
  }
  if (layerIndex < 0 || layerIndex >= scene.layers.length) return null;
  final layer = scene.layers[layerIndex];
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
  _visitResolvedContentNodes(scene, (resolved) {
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
  Rect worldRect, {
  required ScenePaintSpatialQueryScope scope,
}) {
  final out = <ScenePaintSpatialCandidate>[];
  final visit = scope == ScenePaintSpatialQueryScope.backgroundAndContentLayers
      ? _visitResolvedPaintableNodes
      : _visitResolvedContentNodes;
  visit(scene, (resolved) {
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
  index._debugHitTestFallbackQueryCount =
      index._debugHitTestFallbackQueryCount + 1;
  return _queryLinearHitTest(scene, worldRect);
}

List<ScenePaintSpatialCandidate> _queryLinearFallbackPaint(
  SceneSpatialIndex index,
  Scene scene,
  Rect worldRect, {
  required ScenePaintSpatialQueryScope scope,
}) {
  index._debugPaintFallbackQueryCount = index._debugPaintFallbackQueryCount + 1;
  return _queryLinearPaint(scene, worldRect, scope: scope);
}

Set<NodeId>? _queryCandidateIds(
  SceneSpatialIndex index,
  Rect worldRect, {
  required Map<_CellKey, Set<NodeId>> cells,
  required Set<NodeId> largeNodeIds,
  required void Function() incrementFallbackCount,
}) {
  final span = _tryCellSpanForRect(index, worldRect);
  if (span == null) {
    return null;
  }
  if (_isLargeSpan(span, maxCells: kMaxQueryCells)) {
    incrementFallbackCount();
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
    final entry = index._hitTestEntriesById[nodeId];
    if (entry == null) continue;
    if (!_rectsIntersectInclusive(entry.hitTestBoundsWorld, worldRect)) {
      continue;
    }
    final resolved = _resolveSpatialNodeById(index, nodeId);
    if (resolved == null || resolved.layerIndex < 0) continue;
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
  Rect worldRect, {
  required ScenePaintSpatialQueryScope scope,
}) {
  final out = <ScenePaintSpatialCandidate>[];
  for (final nodeId in candidateIds) {
    final entry = index._paintEntriesById[nodeId];
    if (entry == null) continue;
    if (!_rectsIntersectInclusive(entry.paintBoundsWorld, worldRect)) {
      continue;
    }
    final resolved = _resolveSpatialNodeById(index, nodeId);
    if (resolved == null) continue;
    if (scope == ScenePaintSpatialQueryScope.contentLayersOnly &&
        resolved.layerIndex < 0) {
      continue;
    }
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
    _removeHitTestSpatialEntry(index, nodeId);
    _removePaintSpatialEntry(index, nodeId);
    if (!_upsertNodeById(index, nodeId)) {
      return false;
    }
  }
  return true;
}

bool _isCoordinateInIndexBounds(double value) {
  return value >= sceneCoordMin && value <= sceneCoordMax;
}

void _markHitTestInvalid(SceneSpatialIndex index) {
  if (!index._isHitTestValid) return;
  index._isHitTestValid = false;
  _clearHitTestData(index);
}

void _markPaintInvalid(SceneSpatialIndex index) {
  if (!index._isPaintValid) return;
  index._isPaintValid = false;
  _clearPaintData(index);
}

void _clearHitTestData(SceneSpatialIndex index) {
  index._hitTestEntriesById.clear();
  index._hitTestCells.clear();
  index._largeHitTestNodeIds.clear();
}

void _clearPaintData(SceneSpatialIndex index) {
  index._paintEntriesById.clear();
  index._paintCells.clear();
  index._largePaintNodeIds.clear();
}

bool _isLargeSpan(_CellSpan span, {required int maxCells}) {
  final dx = span.endX - span.startX + 1;
  final dy = span.endY - span.startY + 1;
  if (dx <= 0 || dy <= 0) return true;
  if (dx > maxCells || dy > maxCells) return true;
  return dx * dy > maxCells;
}

class _HitTestSpatialEntry {
  _HitTestSpatialEntry({
    required this.nodeId,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final Rect hitTestBoundsWorld;
  final Set<_CellKey> hitTestCoveredCells = <_CellKey>{};
  bool isLargeHitTest = false;

  _HitTestSpatialEntry _clone() {
    final clone = _HitTestSpatialEntry(
      nodeId: nodeId,
      hitTestBoundsWorld: hitTestBoundsWorld,
    );
    clone.hitTestCoveredCells.addAll(hitTestCoveredCells);
    clone.isLargeHitTest = isLargeHitTest;
    return clone;
  }
}

class _PaintSpatialEntry {
  _PaintSpatialEntry({required this.nodeId, required this.paintBoundsWorld});

  final NodeId nodeId;
  final Rect paintBoundsWorld;
  final Set<_CellKey> paintCoveredCells = <_CellKey>{};
  bool isLargePaint = false;

  _PaintSpatialEntry _clone() {
    final clone = _PaintSpatialEntry(
      nodeId: nodeId,
      paintBoundsWorld: paintBoundsWorld,
    );
    clone.paintCoveredCells.addAll(paintCoveredCells);
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
  _visitResolvedPaintableNodes(scene, (resolved) {
    out[resolved.node.id] = (
      layerIndex: resolved.layerIndex,
      nodeIndex: resolved.nodeIndex,
    );
  });
  return out;
}

void _visitResolvedContentNodes(
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

void _visitResolvedPaintableNodes(
  Scene scene,
  void Function(_ResolvedSpatialNode resolved) visit,
) {
  final backgroundNodes = scene.backgroundLayer?.nodes;
  if (backgroundNodes != null) {
    for (var nodeIndex = 0; nodeIndex < backgroundNodes.length; nodeIndex++) {
      visit((
        node: backgroundNodes[nodeIndex],
        layerIndex: -1,
        nodeIndex: nodeIndex,
      ));
    }
  }
  _visitResolvedContentNodes(scene, visit);
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
