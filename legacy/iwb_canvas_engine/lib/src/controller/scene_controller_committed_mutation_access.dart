import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import 'commands/draw_commands.dart';
import 'commands/scene_commands.dart';
import 'scene_controller_commit_runtime.dart';
import 'scene_store_controller.dart';

typedef SceneControllerCommittedMutationWriteResult<T> = ({
  T value,
  bool didChangeRenderState,
});

abstract interface class SceneControllerCommittedMutationAccess {
  T write<T>(T Function(SceneWriteTxn writer) fn);

  SceneControllerCommittedMutationWriteResult<T> writeExact<T>(
    T Function(SceneWriteTxn writer) fn,
  );

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex});

  bool ensureLayer(LayerId layerId, {int? index});

  bool patchNode(NodePatch patch);

  bool removeNode(NodeId id);

  bool setBackgroundColor(Color value);

  bool setGridEnabled(bool value);

  bool setGridCellSize(double value);

  bool setCameraOffset(Offset value);

  ClearSceneResult clearSceneExactResult();

  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  });

  void requestRepaint();

  bool replaceSelection(Iterable<NodeId> nodeIds);

  bool toggleSelection(NodeId nodeId);

  bool clearSelection();

  ({int selectedCount, bool changed}) selectAll({bool onlySelectable = true});

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
  late final SceneCommands _commands = SceneCommands(
    _storeController.writeWithSceneWriter,
  );
  late final DrawCommands _draw = DrawCommands(
    _storeController.writeWithSceneWriter,
  );

  @override
  T write<T>(T Function(SceneWriteTxn writer) fn) {
    return _storeController.write(fn);
  }

  @override
  SceneControllerCommittedMutationWriteResult<T> writeExact<T>(
    T Function(SceneWriteTxn writer) fn,
  ) {
    final committedWrite = _storeController.writeCommitted(fn);
    return (
      value: committedWrite.result,
      didChangeRenderState: _didChangeRenderState(committedWrite),
    );
  }

  @override
  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    return _commands.writeAddNode(
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
    return _commands.writePatchNode(patch);
  }

  @override
  bool removeNode(NodeId id) {
    return _commands.writeDeleteNode(id);
  }

  @override
  bool setBackgroundColor(Color value) {
    return _commands.writeBackgroundColorSetExactChange(value);
  }

  @override
  bool setGridEnabled(bool value) {
    return _commands.writeGridEnabledSetExactChange(value);
  }

  @override
  bool setGridCellSize(double value) {
    return _commands.writeGridCellSizeSetExactChange(value);
  }

  @override
  bool setCameraOffset(Offset value) {
    return _commands.writeCameraOffsetSetExactChange(value);
  }

  @override
  ClearSceneResult clearSceneExactResult() {
    return _commands.writeClearSceneExactResult();
  }

  @override
  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  }) {
    _storeController.writeWithSceneWriter<void>((writer) {
      writer.runtime.writeStagedDocumentReplace(
        snapshot,
        stageCommit: (writeDocumentReplaceNow) {
          beforeApply();
          writeDocumentReplaceNow();
        },
      );
    });
  }

  @override
  void requestRepaint() {
    _storeController.requestRepaint();
  }

  @override
  bool replaceSelection(Iterable<NodeId> nodeIds) {
    return _commands.writeSelectionReplaceExactResult(nodeIds) != null;
  }

  @override
  bool toggleSelection(NodeId nodeId) {
    return _commands.writeSelectionToggleExactChange(nodeId);
  }

  @override
  bool clearSelection() {
    return _commands.writeSelectionClearExactChange();
  }

  @override
  ({int selectedCount, bool changed}) selectAll({bool onlySelectable = true}) {
    return _commands.writeSelectionSelectAllExactResult(
      onlySelectable: onlySelectable,
    );
  }

  @override
  int transformSelection(Transform2D delta) {
    return _commands.writeSelectionTransform(delta);
  }

  @override
  int deleteSelection() {
    return _commands.writeDeleteSelection();
  }

  @override
  NodeId commitDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  }) {
    return _draw.writeDrawStroke(
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
    return _draw.writeDrawLineFromWorldSegment(
      start: start,
      end: end,
      thickness: thickness,
      color: color,
      opacity: opacity,
    );
  }

  @override
  int commitEraseNodes(Iterable<NodeId> ids) {
    return _draw.writeEraseNodes(ids);
  }

  @override
  SceneSnapshot get snapshot => _storeController.snapshot;

  @override
  Set<NodeId> get selectedNodeIds => _storeController.selectedNodeIds;

  @override
  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) {
    return _storeController.centerWorldForNodeSnapshots(snapshots);
  }

  bool _didChangeRenderState(SceneControllerCommittedWrite<Object?> result) {
    return result.commitResult.needsNotify;
  }
}
