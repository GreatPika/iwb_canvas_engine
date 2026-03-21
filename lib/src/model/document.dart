import 'dart:ui';

import '../core/grid_safety_limits.dart';
import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../core/selection_policy.dart';
import '../core/text_layout.dart';
import '../contract/node_patch.dart';
import '../contract/owned_collections.dart';
import '../contract/node_spec.dart';
import '../contract/patch_field.dart';
import '../contract/snapshot.dart';
import 'scene_builder.dart' as model_builder;
import 'scene_node_boundary_mapping.dart';
import 'scene_snapshot_from_scene.dart';

typedef NodeLocatorEntry = ({int layerIndex, int nodeIndex});
typedef PreparedNodeRemoval = ({NodeId nodeId, int nodeIndex});
typedef PreparedNodeRemovalsByLayer = Map<int, List<PreparedNodeRemoval>>;

class TxnClearSceneKeepBackgroundResult {
  TxnClearSceneKeepBackgroundResult({
    required List<NodeId> removedNodeIds,
    required this.didStructuralClear,
  }) : removedNodeIds = List<NodeId>.unmodifiable(
         List<NodeId>.from(removedNodeIds),
       );

  final List<NodeId> removedNodeIds;
  final bool didStructuralClear;
}

({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeById(
  Scene scene,
  NodeId id,
) {
  final backgroundLayer = scene.backgroundLayer;
  if (backgroundLayer != null) {
    for (
      var nodeIndex = 0;
      nodeIndex < backgroundLayer.nodes.length;
      nodeIndex++
    ) {
      final node = backgroundLayer.nodes[nodeIndex];
      if (node.id == id) {
        return (node: node, layerIndex: -1, nodeIndex: nodeIndex);
      }
    }
  }
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final layer = scene.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final node = layer.nodes[nodeIndex];
      if (node.id == id) {
        return (node: node, layerIndex: layerIndex, nodeIndex: nodeIndex);
      }
    }
  }
  return null;
}

Map<NodeId, NodeLocatorEntry> txnBuildNodeLocator(Scene scene) {
  final locator = <NodeId, NodeLocatorEntry>{};
  final backgroundLayer = scene.backgroundLayer;
  if (backgroundLayer != null) {
    for (
      var nodeIndex = 0;
      nodeIndex < backgroundLayer.nodes.length;
      nodeIndex++
    ) {
      final node = backgroundLayer.nodes[nodeIndex];
      locator[node.id] = (layerIndex: -1, nodeIndex: nodeIndex);
    }
  }
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final layer = scene.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final node = layer.nodes[nodeIndex];
      locator[node.id] = (layerIndex: layerIndex, nodeIndex: nodeIndex);
    }
  }
  return locator;
}

({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeByLocator({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required NodeId nodeId,
}) {
  final entry = nodeLocator[nodeId];
  if (entry == null) {
    return null;
  }
  if (entry.layerIndex == -1) {
    final backgroundLayer = scene.backgroundLayer;
    if (backgroundLayer == null) return null;
    final nodeIndex = entry.nodeIndex;
    if (nodeIndex < 0 || nodeIndex >= backgroundLayer.nodes.length) {
      return null;
    }
    final node = backgroundLayer.nodes[nodeIndex];
    if (node.id != nodeId) {
      return null;
    }
    return (node: node, layerIndex: -1, nodeIndex: nodeIndex);
  }
  final layerIndex = entry.layerIndex;
  if (layerIndex < 0 || layerIndex >= scene.layers.length) {
    return null;
  }
  final layer = scene.layers[layerIndex];
  final nodeIndex = entry.nodeIndex;
  if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
    return null;
  }
  final node = layer.nodes[nodeIndex];
  if (node.id != nodeId) {
    return null;
  }
  return (node: node, layerIndex: layerIndex, nodeIndex: nodeIndex);
}

void txnShiftNodeLocatorLayersFrom({
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required int startLayerIndex,
}) {
  for (final entry in nodeLocator.entries.toList(growable: false)) {
    final location = entry.value;
    if (location.layerIndex == -1 || location.layerIndex < startLayerIndex) {
      continue;
    }
    nodeLocator[entry.key] = (
      layerIndex: location.layerIndex + 1,
      nodeIndex: location.nodeIndex,
    );
  }
}

SceneSnapshot txnSceneToSnapshot(Scene scene) {
  return sceneSnapshotFromScene(scene);
}

Scene txnSceneFromSnapshot(
  SceneSnapshot snapshot, {
  int Function()? nextInstanceRevision,
}) {
  return model_builder.sceneBuildFromSnapshot(
    snapshot,
    nextInstanceRevision: nextInstanceRevision,
  );
}

SceneNode txnNodeFromSnapshot(
  NodeSnapshot node, {
  int Function()? nextInstanceRevision,
}) {
  final instanceRevision = resolveSnapshotInstanceRevision(
    node.instanceRevision,
    nextInstanceRevision: nextInstanceRevision,
  );
  return sceneNodeFromSnapshotViaBoundarySchema(
    node,
    instanceRevision: instanceRevision,
    textSizePolicy: TextNodeSnapshotSizePolicy.recomputeFromLayout,
  );
}

NodeSnapshot txnNodeToSnapshot(SceneNode node) {
  return sceneNodeSnapshotFromScene(node);
}

SceneNode txnNodeFromSpec(
  NodeSpec spec, {
  required NodeId fallbackId,
  int Function()? nextInstanceRevision,
}) {
  final instanceRevision = _txnResolveSpecInstanceRevision(
    nextInstanceRevision: nextInstanceRevision,
  );
  return sceneNodeFromSpecViaBoundarySchema(
    spec,
    fallbackId: fallbackId,
    instanceRevision: instanceRevision,
  );
}

int _txnResolveSpecInstanceRevision({int Function()? nextInstanceRevision}) {
  final allocator = nextInstanceRevision;
  if (allocator != null) {
    return allocator();
  }
  return 1;
}

bool txnApplyNodePatch(SceneNode node, NodePatch patch, {bool dryRun = false}) {
  _txnValidatePatchTargetRuntimeSemantics(node: node, patch: patch);

  var changed = _txnApplyCommonPatch(node, patch.common, dryRun: dryRun);
  changed = _txnApplyTypedNodePatch(node, patch, dryRun: dryRun) || changed;
  return changed;
}

enum _TxnPatchTargetKind { image, text, stroke, line, rect, path }

_TxnPatchTargetKind _txnValidatePatchTargetRuntimeSemantics({
  required SceneNode node,
  required NodePatch patch,
}) {
  if (node.id != patch.id) {
    throw ArgumentError.value(
      patch.id,
      'patch.id',
      'NodePatch id does not match target node id ${node.id}.',
    );
  }

  final kind = switch ((node, patch)) {
    (ImageNode _, ImageNodePatch _) => _TxnPatchTargetKind.image,
    (TextNode _, TextNodePatch _) => _TxnPatchTargetKind.text,
    (StrokeNode _, StrokeNodePatch _) => _TxnPatchTargetKind.stroke,
    (LineNode _, LineNodePatch _) => _TxnPatchTargetKind.line,
    (RectNode _, RectNodePatch _) => _TxnPatchTargetKind.rect,
    (PathNode _, PathNodePatch _) => _TxnPatchTargetKind.path,
    _ => null,
  };
  if (kind != null) {
    return kind;
  }

  throw ArgumentError(
    'Patch type ${patch.runtimeType} does not match node ${node.runtimeType}.',
  );
}

bool _txnTextPatchTouchesLayout(TextNodePatch patch) {
  return !patch.text.isAbsent ||
      !patch.fontSize.isAbsent ||
      !patch.isBold.isAbsent ||
      !patch.isItalic.isAbsent ||
      !patch.isUnderline.isAbsent ||
      !patch.fontFamily.isAbsent ||
      !patch.lineHeight.isAbsent ||
      !patch.maxWidth.isAbsent;
}

bool txnInsertNodeInScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required SceneNode node,
  required int layerIndex,
  int? insertIndex,
}) {
  if (nodeLocator.containsKey(node.id)) {
    throw StateError('Node id must be unique: ${node.id}');
  }
  final targetLayerIndex = layerIndex;
  if (targetLayerIndex < 0 || targetLayerIndex >= scene.layers.length) {
    throw RangeError.range(
      targetLayerIndex,
      0,
      scene.layers.length - 1,
      'layerIndex',
    );
  }
  final targetLayer = scene.layers[targetLayerIndex];
  final insertedNodeIndex = insertIndex ?? targetLayer.nodes.length;
  if (insertedNodeIndex < 0 || insertedNodeIndex > targetLayer.nodes.length) {
    throw RangeError.range(
      insertedNodeIndex,
      0,
      targetLayer.nodes.length,
      'insertIndex',
    );
  }
  if (insertedNodeIndex == targetLayer.nodes.length) {
    targetLayer.nodes.add(node);
  } else {
    targetLayer.nodes.insert(insertedNodeIndex, node);
  }
  nodeLocator[node.id] = (
    layerIndex: targetLayerIndex,
    nodeIndex: insertedNodeIndex,
  );
  for (
    var nodeIndex = insertedNodeIndex + 1;
    nodeIndex < targetLayer.nodes.length;
    nodeIndex++
  ) {
    final shiftedNode = targetLayer.nodes[nodeIndex];
    nodeLocator[shiftedNode.id] = (
      layerIndex: targetLayerIndex,
      nodeIndex: nodeIndex,
    );
  }
  return true;
}

SceneNode? txnEraseNodeFromScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required NodeId nodeId,
}) {
  final found = txnFindNodeByLocator(
    scene: scene,
    nodeLocator: nodeLocator,
    nodeId: nodeId,
  );
  if (found == null) {
    return null;
  }
  final removed = found.node;
  final removedNodeIds = txnErasePreparedNodesFromScene(
    scene: scene,
    nodeLocator: nodeLocator,
    removalsByLayer: <int, List<PreparedNodeRemoval>>{
      found.layerIndex: <PreparedNodeRemoval>[
        (nodeId: nodeId, nodeIndex: found.nodeIndex),
      ],
    },
  );
  if (removedNodeIds.isEmpty) {
    return null;
  }
  return removed;
}

List<NodeId> txnErasePreparedNodesFromScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required PreparedNodeRemovalsByLayer removalsByLayer,
}) {
  if (removalsByLayer.isEmpty) {
    return const <NodeId>[];
  }

  final removedNodeIds = <NodeId>[];
  final sortedLayerIndexes = removalsByLayer.keys.toList(growable: false)
    ..sort();
  for (final layerIndex in sortedLayerIndexes) {
    removedNodeIds.addAll(
      _txnErasePreparedNodesFromLayer(
        scene: scene,
        nodeLocator: nodeLocator,
        layerIndex: layerIndex,
        preparedRemovals: removalsByLayer[layerIndex],
      ),
    );
  }

  if (removedNodeIds.isEmpty) {
    return const <NodeId>[];
  }
  return List<NodeId>.unmodifiable(removedNodeIds);
}

List<NodeId> txnEraseNodesFromScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required Set<NodeId> nodeIds,
}) {
  if (nodeIds.isEmpty) {
    return const <NodeId>[];
  }

  final removalsByLayer = <int, List<PreparedNodeRemoval>>{};
  for (final nodeId in nodeIds) {
    final found = txnFindNodeByLocator(
      scene: scene,
      nodeLocator: nodeLocator,
      nodeId: nodeId,
    );
    if (found == null ||
        found.layerIndex == -1 ||
        !isNodeDeletableInLayer(found.node)) {
      continue;
    }
    removalsByLayer
        .putIfAbsent(found.layerIndex, () => <PreparedNodeRemoval>[])
        .add((nodeId: found.node.id, nodeIndex: found.nodeIndex));
  }
  return txnErasePreparedNodesFromScene(
    scene: scene,
    nodeLocator: nodeLocator,
    removalsByLayer: removalsByLayer,
  );
}

TxnClearSceneKeepBackgroundResult txnClearSceneKeepBackground({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
}) {
  final removedNodeIds = <NodeId>[
    for (final layer in scene.layers) ...layer.nodes.map((node) => node.id),
  ];
  var didStructuralClear = false;

  if (scene.backgroundLayer == null) {
    scene.backgroundLayer = BackgroundLayer();
    didStructuralClear = true;
  }
  if (scene.layers.isNotEmpty) {
    scene.layers.clear();
    didStructuralClear = true;
  }
  if (removedNodeIds.isNotEmpty) {
    for (final nodeId in removedNodeIds) {
      nodeLocator.remove(nodeId);
    }
  }

  return TxnClearSceneKeepBackgroundResult(
    removedNodeIds: removedNodeIds,
    didStructuralClear: didStructuralClear,
  );
}

int txnResolveInsertLayerIndex({
  required Scene scene,
  LayerId? layerId,
  LayerId Function()? nextLayerId,
}) {
  // Runtime hot-path uses TxnContext layer index fast-path.
  // This helper remains for tests and model-level utilities.
  if (layerId != null) {
    final index = txnFindContentLayerIndexById(scene: scene, layerId: layerId);
    if (index == null) {
      throw ArgumentError.value(
        layerId,
        'layerId',
        'Unknown content layer id.',
      );
    }
    return index;
  }
  if (scene.layers.isEmpty) {
    final generatedId = nextLayerId == null ? 'layer-0' : nextLayerId();
    scene.layers.add(ContentLayer(id: generatedId));
    return 0;
  }
  return scene.layers.length - 1;
}

int? txnFindContentLayerIndexById({
  required Scene scene,
  required LayerId layerId,
}) {
  for (var index = 0; index < scene.layers.length; index++) {
    if (scene.layers[index].id == layerId) {
      return index;
    }
  }
  return null;
}

Set<NodeId> txnNormalizeSelection({
  required Set<NodeId> rawSelection,
  required Scene scene,
  Map<NodeId, NodeLocatorEntry>? nodeLocator,
}) {
  return <NodeId>{
    for (final id in rawSelection)
      if (txnIsSelectionCandidateId(
        scene: scene,
        nodeId: id,
        nodeLocator: nodeLocator,
      ))
        id,
  };
}

bool txnIsSelectionCandidateId({
  required Scene scene,
  required NodeId nodeId,
  Map<NodeId, NodeLocatorEntry>? nodeLocator,
}) {
  final found = nodeLocator == null
      ? txnFindNodeById(scene, nodeId)
      : txnFindNodeByLocator(
          scene: scene,
          nodeLocator: nodeLocator,
          nodeId: nodeId,
        );
  if (found == null) {
    return false;
  }
  if (found.layerIndex == -1) {
    return false;
  }
  return found.node.isVisible;
}

Set<NodeId> txnTranslateSelection({
  required Scene scene,
  required Set<NodeId> selectedNodeIds,
  required Offset delta,
}) {
  if (delta == Offset.zero) {
    return const <NodeId>{};
  }

  final moved = <NodeId>{};
  for (final layer in scene.layers) {
    for (final node in layer.nodes) {
      if (!selectedNodeIds.contains(node.id)) continue;
      if (node.isLocked || !node.isTransformable) continue;
      node.position = node.position + delta;
      moved.add(node.id);
    }
  }
  return moved;
}

bool txnNormalizeGrid(Scene scene) {
  final grid = scene.background.grid;
  if (grid.isEnabled && grid.cellSize < kMinGridCellSize) {
    grid.cellSize = kMinGridCellSize;
    return true;
  }
  return false;
}

bool _txnApplyCommonPatch(
  SceneNode node,
  CommonNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.transform, node.transform, (value) {
        node.transform = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.opacity, node.opacity, (value) {
        node.opacity = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.hitPadding, node.hitPadding, (value) {
        node.hitPadding = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isVisible, node.isVisible, (value) {
        node.isVisible = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isSelectable, node.isSelectable, (value) {
        node.isSelectable = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isLocked, node.isLocked, (value) {
        node.isLocked = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isDeletable, node.isDeletable, (value) {
        node.isDeletable = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isTransformable, node.isTransformable, (value) {
        node.isTransformable = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyImagePatch(
  ImageNode image,
  ImageNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.imageId, image.imageId, (value) {
        image.imageId = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.size, image.size, (value) {
        image.size = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.naturalSize, image.naturalSize, (value) {
        image.naturalSize = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyTypedNodePatch(
  SceneNode node,
  NodePatch patch, {
  required bool dryRun,
}) {
  return switch ((node, patch)) {
    (ImageNode image, ImageNodePatch imagePatch) => _txnApplyImagePatch(
      image,
      imagePatch,
      dryRun: dryRun,
    ),
    (TextNode text, TextNodePatch textPatch) => _txnApplyTextPatch(
      text,
      textPatch,
      dryRun: dryRun,
    ),
    (StrokeNode stroke, StrokeNodePatch strokePatch) => _txnApplyStrokePatch(
      stroke,
      strokePatch,
      dryRun: dryRun,
    ),
    (LineNode line, LineNodePatch linePatch) => _txnApplyLinePatch(
      line,
      linePatch,
      dryRun: dryRun,
    ),
    (RectNode rect, RectNodePatch rectPatch) => _txnApplyRectPatch(
      rect,
      rectPatch,
      dryRun: dryRun,
    ),
    (PathNode path, PathNodePatch pathPatch) => _txnApplyPathPatch(
      path,
      pathPatch,
      dryRun: dryRun,
    ),
    _ => false,
  };
}

bool _txnApplyTextPatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  var changed = _txnApplyTextContentPatch(text, patch, dryRun: dryRun);
  changed =
      _txnApplyTextLayoutStylePatch(text, patch, dryRun: dryRun) || changed;
  changed =
      _txnRecomputeTextSizeAfterPatch(text, patch, dryRun: dryRun) || changed;
  return changed;
}

bool _txnApplyStrokePatch(
  StrokeNode stroke,
  StrokeNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnApplyStrokePointsPatch(stroke, patch.points, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.thickness, stroke.thickness, (value) {
        stroke.thickness = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.color, stroke.color, (value) {
        stroke.color = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyLinePatch(
  LineNode line,
  LineNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.start, line.start, (value) {
        line.start = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.end, line.end, (value) {
        line.end = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.thickness, line.thickness, (value) {
        line.thickness = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.color, line.color, (value) {
        line.color = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyRectPatch(
  RectNode rect,
  RectNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.size, rect.size, (value) {
        rect.size = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.fillColor, rect.fillColor, (value) {
        rect.fillColor = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.strokeColor, rect.strokeColor, (value) {
        rect.strokeColor = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.strokeWidth, rect.strokeWidth, (value) {
        rect.strokeWidth = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyPathPatch(
  PathNode path,
  PathNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.svgPathData, path.svgPathData, (value) {
        path.svgPathData = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.fillColor, path.fillColor, (value) {
        path.fillColor = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.strokeColor, path.strokeColor, (value) {
        path.strokeColor = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.strokeWidth, path.strokeWidth, (value) {
        path.strokeWidth = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.fillRule, path.fillRule, (value) {
        path.fillRule = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnSet<T>(
  PatchField<T> patch,
  T current,
  void Function(T value) assign, {
  required bool dryRun,
}) {
  if (patch.isAbsent) return false;
  final next = patch.value;
  if (next == current) return false;
  if (!dryRun) {
    assign(next);
  }
  return true;
}

bool _txnSetNullable<T>(
  PatchField<T?> patch,
  T? current,
  void Function(T? value) assign, {
  required bool dryRun,
}) {
  if (patch.isAbsent) return false;

  final next = patch.isNullValue ? null : patch.value;
  if (next == current) return false;
  if (!dryRun) {
    assign(next);
  }
  return true;
}

bool _txnApplyStrokePointsPatch(
  StrokeNode stroke,
  PatchField<List<Offset>> patch, {
  required bool dryRun,
}) {
  if (patch.isAbsent) return false;
  final next = patch.value as OwnedList<Offset>;
  if (!_txnHasDifferentStrokePoints(next, stroke.points)) return false;
  if (!dryRun) {
    stroke.points.replaceRange(0, stroke.points.length, next);
  }
  return true;
}

bool _txnHasDifferentStrokePoints(
  OwnedList<Offset> next,
  List<Offset> current,
) {
  if (next.length != current.length) {
    return true;
  }
  for (var index = 0; index < current.length; index++) {
    if (next[index] != current[index]) {
      return true;
    }
  }
  return false;
}

List<PreparedNodeRemoval> _txnCollectValidPreparedRemovals({
  required List<SceneNode> layerNodes,
  required List<PreparedNodeRemoval> preparedRemovals,
}) {
  final validRemovals = <PreparedNodeRemoval>[];
  final seenRemovalKeys = <(NodeId, int)>{};
  var hasDuplicateRemovals = false;
  for (final removal in preparedRemovals) {
    final nodeIndex = removal.nodeIndex;
    if (nodeIndex < 0 || nodeIndex >= layerNodes.length) {
      continue;
    }
    if (layerNodes[nodeIndex].id != removal.nodeId) {
      continue;
    }
    final removalKey = (removal.nodeId, nodeIndex);
    if (!seenRemovalKeys.add(removalKey)) {
      hasDuplicateRemovals = true;
      continue;
    }
    validRemovals.add(removal);
  }
  assert(
    !hasDuplicateRemovals,
    'Prepared node removals must not contain duplicate nodeId/nodeIndex pairs.',
  );
  validRemovals.sort(
    (left, right) => left.nodeIndex.compareTo(right.nodeIndex),
  );
  return validRemovals;
}

List<NodeId> _txnErasePreparedNodesFromLayer({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required int layerIndex,
  required List<PreparedNodeRemoval>? preparedRemovals,
}) {
  if (preparedRemovals == null || preparedRemovals.isEmpty) {
    return const <NodeId>[];
  }
  final layerNodes = _txnResolveLayerNodesForErase(
    scene: scene,
    layerIndex: layerIndex,
  );
  if (layerNodes == null) {
    return const <NodeId>[];
  }
  final validRemovals = _txnCollectValidPreparedRemovals(
    layerNodes: layerNodes,
    preparedRemovals: preparedRemovals,
  );
  if (validRemovals.isEmpty) {
    return const <NodeId>[];
  }
  final removedNodeIds = _txnEraseValidatedRemovals(
    nodeLocator: nodeLocator,
    layerNodes: layerNodes,
    validRemovals: validRemovals,
  );
  _txnReindexLayerNodesAfterErase(
    nodeLocator: nodeLocator,
    layerIndex: layerIndex,
    layerNodes: layerNodes,
  );
  return removedNodeIds;
}

List<NodeId> _txnEraseValidatedRemovals({
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required List<SceneNode> layerNodes,
  required List<PreparedNodeRemoval> validRemovals,
}) {
  final removedNodeIds = validRemovals
      .map((removal) => removal.nodeId)
      .toList(growable: false);
  for (final removal in validRemovals.reversed) {
    layerNodes.removeAt(removal.nodeIndex);
    nodeLocator.remove(removal.nodeId);
  }
  return removedNodeIds;
}

bool _txnApplyTextContentPatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.text, text.text, (value) {
        text.text = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.fontSize, text.fontSize, (value) {
        text.fontSize = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.color, text.color, (value) {
        text.color = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.align, text.align, (value) {
        text.align = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyTextLayoutStylePatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.isBold, text.isBold, (value) {
        text.isBold = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isItalic, text.isItalic, (value) {
        text.isItalic = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isUnderline, text.isUnderline, (value) {
        text.isUnderline = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.fontFamily, text.fontFamily, (value) {
        text.fontFamily = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.maxWidth, text.maxWidth, (value) {
        text.maxWidth = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.lineHeight, text.lineHeight, (value) {
        text.lineHeight = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnRecomputeTextSizeAfterPatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  if (dryRun || !_txnTextPatchTouchesLayout(patch)) {
    return false;
  }
  final beforeSize = text.size;
  recomputeDerivedTextSize(text);
  return text.size != beforeSize;
}

List<SceneNode>? _txnResolveLayerNodesForErase({
  required Scene scene,
  required int layerIndex,
}) {
  if (layerIndex == -1) {
    return scene.backgroundLayer?.nodes;
  }
  if (layerIndex < 0 || layerIndex >= scene.layers.length) {
    return null;
  }
  return scene.layers[layerIndex].nodes;
}

void _txnReindexLayerNodesAfterErase({
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required int layerIndex,
  required List<SceneNode> layerNodes,
}) {
  for (var nodeIndex = 0; nodeIndex < layerNodes.length; nodeIndex++) {
    final node = layerNodes[nodeIndex];
    nodeLocator[node.id] = (layerIndex: layerIndex, nodeIndex: nodeIndex);
  }
}
