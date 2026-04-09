import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import 'scene_snapshot_materializer.dart';
import 'scene_store_controller.dart';

abstract interface class SceneControllerCommittedMutationAccess {
  T write<T>(T Function(SceneWriteTxn writer) fn);

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex});

  bool ensureLayer(LayerId layerId, {int? index});

  bool patchNode(NodePatch patch);

  bool removeNode(NodeId id);

  void setBackgroundColor(Color value);

  void setGridEnabled(bool value);

  void setGridCellSize(double value);

  void setCameraOffset(Offset value);

  ClearSceneResult clearSceneExactResult();

  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot);

  void writePreparedSceneReplacement(PreparedSceneReplacement replacement);

  void requestRepaint();

  void replaceSelection(Iterable<NodeId> nodeIds);

  void toggleSelection(NodeId nodeId);

  void clearSelection();

  int selectAll({bool onlySelectable = true});

  int transformSelection(Transform2D delta);

  int deleteSelection();

  NodeId commitDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  });

  NodeId commitDrawLineFromWorldSegment({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  });

  int commitEraseNodes(Iterable<NodeId> ids);

  SceneSnapshot get snapshot;

  Set<NodeId> get selectedNodeIds;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots);
}

final class SceneStoreControllerCommittedMutationAccess
    implements SceneControllerCommittedMutationAccess {
  SceneStoreControllerCommittedMutationAccess(this._storeController);

  final SceneStoreController _storeController;

  @override
  T write<T>(T Function(SceneWriteTxn writer) fn) {
    return _storeController.write(fn);
  }

  @override
  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    return _storeController.commands.writeAddNode(
      node,
      layerId: layerId,
      insertIndex: insertIndex,
    );
  }

  @override
  bool ensureLayer(LayerId layerId, {int? index}) {
    return _storeController.write((writer) {
      return writer.writeLayerEnsure(layerId, index: index);
    });
  }

  @override
  bool patchNode(NodePatch patch) {
    return _storeController.commands.writePatchNode(patch);
  }

  @override
  bool removeNode(NodeId id) {
    return _storeController.commands.writeDeleteNode(id);
  }

  @override
  void setBackgroundColor(Color value) {
    _storeController.commands.writeBackgroundColorSet(value);
  }

  @override
  void setGridEnabled(bool value) {
    _storeController.commands.writeGridEnabledSet(value);
  }

  @override
  void setGridCellSize(double value) {
    _storeController.commands.writeGridCellSizeSet(value);
  }

  @override
  void setCameraOffset(Offset value) {
    _storeController.commands.writeCameraOffsetSet(value);
  }

  @override
  ClearSceneResult clearSceneExactResult() {
    return _storeController.commands.writeClearSceneExactResult();
  }

  @override
  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot) {
    return _storeController.prepareSceneReplacement(snapshot);
  }

  @override
  void writePreparedSceneReplacement(PreparedSceneReplacement replacement) {
    _storeController.writePreparedSceneReplacement(replacement);
  }

  @override
  void requestRepaint() {
    _storeController.requestRepaint();
  }

  @override
  void replaceSelection(Iterable<NodeId> nodeIds) {
    _storeController.commands.writeSelectionReplace(nodeIds);
  }

  @override
  void toggleSelection(NodeId nodeId) {
    _storeController.commands.writeSelectionToggle(nodeId);
  }

  @override
  void clearSelection() {
    _storeController.commands.writeSelectionClear();
  }

  @override
  int selectAll({bool onlySelectable = true}) {
    return _storeController.commands.writeSelectionSelectAll(
      onlySelectable: onlySelectable,
    );
  }

  @override
  int transformSelection(Transform2D delta) {
    return _storeController.commands.writeSelectionTransform(delta);
  }

  @override
  int deleteSelection() {
    return _storeController.commands.writeDeleteSelection();
  }

  @override
  NodeId commitDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  }) {
    return _storeController.draw.writeDrawStroke(
      points: points,
      thickness: thickness,
      color: color,
      opacity: opacity,
    );
  }

  @override
  NodeId commitDrawLineFromWorldSegment({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  }) {
    return _storeController.draw.writeDrawLineFromWorldSegment(
      start: start,
      end: end,
      thickness: thickness,
      color: color,
      opacity: opacity,
    );
  }

  @override
  int commitEraseNodes(Iterable<NodeId> ids) {
    return _storeController.draw.writeEraseNodes(ids);
  }

  @override
  SceneSnapshot get snapshot => _storeController.snapshot;

  @override
  Set<NodeId> get selectedNodeIds => _storeController.selectedNodeIds;

  @override
  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) {
    return _storeController.centerWorldForNodeSnapshots(snapshots);
  }
}
