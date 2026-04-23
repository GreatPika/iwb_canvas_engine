import 'dart:ui';

import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import 'document_locator.dart' as document_locator;
import 'document_node_patch.dart' as document_node_patch;
import 'document_scene_edit.dart' as document_scene_edit;
import 'document_scene_insert.dart' as document_scene_insert;
import 'document_selection.dart' as document_selection;
import 'scene_node_boundary_mapping.dart';
import 'scene_from_snapshot.dart';
import 'scene_snapshot_from_scene.dart';

typedef NodeLocatorEntry = ({LayerId? contentLayerId, int nodeIndex});
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
  return document_locator.txnFindNodeById(scene, id);
}

Map<NodeId, NodeLocatorEntry> txnBuildNodeLocator(Scene scene) {
  return document_locator.txnBuildNodeLocator(scene);
}

Map<LayerId, int> txnBuildLayerIndexById(Scene scene) {
  return document_locator.txnBuildLayerIndexById(scene);
}

({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeByLocator({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  Map<LayerId, int>? layerIndexById,
  required NodeId nodeId,
}) {
  return document_locator.txnFindNodeByLocator(
    scene: scene,
    nodeLocator: nodeLocator,
    layerIndexById: layerIndexById,
    nodeId: nodeId,
  );
}

SceneSnapshot txnSceneToSnapshot(Scene scene) {
  return sceneSnapshotFromScene(scene);
}

Scene txnSceneFromSnapshot(
  SceneSnapshot snapshot, {
  int Function()? nextInstanceRevision,
}) {
  return sceneImportFromSnapshot(
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
  return document_node_patch.txnApplyNodePatch(node, patch, dryRun: dryRun);
}

bool txnInsertNodeInScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required SceneNode node,
  required int layerIndex,
  int? insertIndex,
}) {
  return document_scene_insert.txnInsertNodeInScene(
    scene: scene,
    nodeLocator: nodeLocator,
    node: node,
    layerIndex: layerIndex,
    insertIndex: insertIndex,
  );
}

bool txnEnsureContentLayerInScene({
  required Scene scene,
  required LayerId layerId,
  required Map<LayerId, int> layerIndexById,
  int? insertIndex,
}) {
  return document_scene_insert.txnEnsureContentLayerInScene(
    scene: scene,
    layerId: layerId,
    layerIndexById: layerIndexById,
    insertIndex: insertIndex,
  );
}

int txnInsertContentLayerInScene({
  required Scene scene,
  required LayerId layerId,
  Map<LayerId, int>? layerIndexById,
  int? insertIndex,
}) {
  return document_scene_insert.txnInsertContentLayerInScene(
    scene: scene,
    layerId: layerId,
    layerIndexById: layerIndexById,
    insertIndex: insertIndex,
  );
}

void txnReplaceContentLayerInScene({
  required Scene scene,
  required int layerIndex,
  required ContentLayer layer,
  Map<NodeId, NodeLocatorEntry>? nodeLocator,
  Map<LayerId, int>? layerIndexById,
}) {
  document_scene_insert.txnReplaceContentLayerInScene(
    scene: scene,
    layerIndex: layerIndex,
    layer: layer,
    nodeLocator: nodeLocator,
    layerIndexById: layerIndexById,
  );
}

void txnReplaceContentLayerSlotInScene({
  required Scene scene,
  required int layerIndex,
  required ContentLayer layer,
}) {
  document_scene_insert.txnReplaceContentLayerSlotInScene(
    scene: scene,
    layerIndex: layerIndex,
    layer: layer,
  );
}

SceneNode? txnEraseNodeFromScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  Map<LayerId, int>? layerIndexById,
  required NodeId nodeId,
}) {
  return document_scene_edit.txnEraseNodeFromScene(
    scene: scene,
    nodeLocator: nodeLocator,
    layerIndexById: layerIndexById,
    nodeId: nodeId,
  );
}

List<NodeId> txnErasePreparedNodesFromScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required PreparedNodeRemovalsByLayer removalsByLayer,
}) {
  return document_scene_edit.txnErasePreparedNodesFromScene(
    scene: scene,
    nodeLocator: nodeLocator,
    removalsByLayer: removalsByLayer,
  );
}

List<NodeId> txnEraseNodesFromScene({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  Map<LayerId, int>? layerIndexById,
  required Set<NodeId> nodeIds,
}) {
  return document_scene_edit.txnEraseNodesFromScene(
    scene: scene,
    nodeLocator: nodeLocator,
    layerIndexById: layerIndexById,
    nodeIds: nodeIds,
  );
}

TxnClearSceneKeepBackgroundResult txnClearSceneKeepBackground({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  Map<LayerId, int>? layerIndexById,
}) {
  final result = document_scene_edit.txnClearSceneKeepBackground(
    scene: scene,
    nodeLocator: nodeLocator,
    layerIndexById: layerIndexById,
  );
  return TxnClearSceneKeepBackgroundResult(
    removedNodeIds: result.removedNodeIds,
    didStructuralClear: result.didStructuralClear,
  );
}

int txnResolveInsertLayerIndex({
  required Scene scene,
  LayerId? layerId,
  LayerId Function()? nextLayerId,
  Map<LayerId, int>? layerIndexById,
}) {
  return document_scene_insert.txnResolveInsertLayerIndex(
    scene: scene,
    layerId: layerId,
    nextLayerId: nextLayerId,
    layerIndexById: layerIndexById,
  );
}

int? txnFindContentLayerIndexById({
  required Scene scene,
  required LayerId layerId,
}) {
  return document_scene_insert.txnFindContentLayerIndexById(
    scene: scene,
    layerId: layerId,
  );
}

Set<NodeId> txnNormalizeSelection({
  required Set<NodeId> rawSelection,
  required Scene scene,
  Map<NodeId, NodeLocatorEntry>? nodeLocator,
  Map<LayerId, int>? layerIndexById,
}) {
  return document_selection.txnNormalizeSelection(
    rawSelection: rawSelection,
    scene: scene,
    nodeLocator: nodeLocator,
    layerIndexById: layerIndexById,
  );
}

bool txnIsSelectionCandidateId({
  required Scene scene,
  required NodeId nodeId,
  Map<NodeId, NodeLocatorEntry>? nodeLocator,
  Map<LayerId, int>? layerIndexById,
}) {
  return document_selection.txnIsSelectionCandidateId(
    scene: scene,
    nodeId: nodeId,
    nodeLocator: nodeLocator,
    layerIndexById: layerIndexById,
  );
}

Set<NodeId> txnTranslateSelection({
  required Scene scene,
  required Set<NodeId> selectedNodeIds,
  required Offset delta,
}) {
  return document_selection.txnTranslateSelection(
    scene: scene,
    selectedNodeIds: selectedNodeIds,
    delta: delta,
  );
}
