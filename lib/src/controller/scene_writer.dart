import 'dart:collection';
import 'dart:ui';

import 'internal/signal_event.dart';
import 'scene_writer_scene.dart';
import 'scene_writer_selection.dart';
import 'scene_writer_signals.dart';
import 'scene_writer_types.dart';
import 'scene_writer_runtime.dart';
import 'mutation_executor.dart';
import 'txn_context.dart';

class SceneWriter implements SceneWriteTxn {
  SceneWriter(
    TxnContext ctx, {
    required MutationExecutor mutationExecutor,
    required void Function(BufferedSignal signal) txnSignalSink,
  }) : _runtime = SceneWriterRuntime(
         ctx: ctx,
         mutationExecutor: mutationExecutor,
         txnSignalSink: txnSignalSink,
       ),
       _selectedNodeIdsView = UnmodifiableSetView<NodeId>(ctx.workingSelection);

  final SceneWriterRuntime _runtime;
  final UnmodifiableSetView<NodeId> _selectedNodeIdsView;

  @override
  SceneSnapshot get snapshot => txnSceneToSnapshot(_runtime.ctx.workingScene);

  @override
  Set<NodeId> get selectedNodeIds => _selectedNodeIdsView;

  @override
  NodeId writeNodeInsert(NodeSpec spec, {LayerId? layerId, int? insertIndex}) {
    return _runtime.writeNodeInsert(
      spec,
      layerId: layerId,
      insertIndex: insertIndex,
    );
  }

  @override
  bool writeLayerEnsure(LayerId layerId, {int? index}) {
    return _runtime.writeLayerEnsure(layerId, index: index);
  }

  @override
  bool writeNodeErase(NodeId nodeId) {
    return _runtime.writeNodeErase(nodeId);
  }

  @override
  bool writeNodePatch(NodePatch patch) {
    return _runtime.writeNodePatch(patch);
  }

  @override
  bool writeNodeTransformSet(NodeId id, Transform2D transform) {
    return _runtime.writeNodeTransformSet(id, transform);
  }

  @override
  bool writeSelectionReplace(Iterable<NodeId> ids) {
    return sceneWriterWriteSelectionReplaceResult(this, ids) != null;
  }

  @override
  bool writeSelectionToggle(NodeId id) {
    return sceneWriterWriteSelectionToggle(this, id);
  }

  @override
  bool writeSelectionClear() {
    return sceneWriterWriteSelectionClear(this);
  }

  @override
  int writeSelectionSelectAll({bool onlySelectable = true}) {
    return sceneWriterWriteSelectionSelectAllResult(
      this,
      onlySelectable: onlySelectable,
    ).selectedCount;
  }

  @override
  int writeSelectionTranslate(Offset delta) {
    return _runtime.writeSelectionTranslate(delta);
  }

  @override
  int writeSelectionTransform(Transform2D delta) {
    return _runtime.writeSelectionTransform(delta);
  }

  @override
  int writeDeleteSelection() {
    return sceneWriterWriteDeleteSelectionResult(this).length;
  }

  @override
  List<NodeId> writeClearSceneKeepBackground() {
    return writeClearSceneKeepBackgroundResult().removedNodeIds;
  }

  @override
  ClearSceneResult writeClearSceneKeepBackgroundResult() {
    return _runtime.writeClearSceneKeepBackgroundResult();
  }

  @override
  void writeCameraOffset(Offset offset) {
    sceneWriterWriteCameraOffsetChanged(this, offset);
  }

  @override
  void writeGridEnable(bool enabled) {
    sceneWriterWriteGridEnableChanged(this, enabled);
  }

  @override
  void writeGridCellSize(double cellSize) {
    sceneWriterWriteGridCellSizeChanged(this, cellSize);
  }

  @override
  void writeBackgroundColor(Color color) {
    sceneWriterWriteBackgroundColorChanged(this, color);
  }

  @override
  void writeDocumentReplace(SceneSnapshot snapshot) {
    sceneWriterWriteDocumentReplace(this, snapshot);
  }

  @override
  void writeSignalEnqueue({
    required String type,
    Iterable<NodeId> nodeIds = const <NodeId>[],
    Map<String, Object?>? payload,
  }) {
    sceneWriterWriteSignalEnqueue(
      this,
      type: type,
      nodeIds: nodeIds,
      payload: payload,
    );
  }

  SceneWriterRuntime get runtime => _runtime;
}
