import 'dart:collection';
import 'dart:ui';

import 'scene_writer_nodes.dart';
import 'scene_writer_scene.dart';
import 'scene_writer_selection.dart';
import 'scene_writer_signals.dart';
import 'scene_snapshot_materializer.dart';
import 'scene_writer_types.dart';
import 'scene_writer_runtime.dart';

class SceneWriter {
  SceneWriter(SceneWriterRuntime runtime)
    : _runtime = runtime,
      _selectedNodeIdsView = UnmodifiableSetView<NodeId>(
        runtime.ctx.workingSelection,
      );

  final SceneWriterRuntime _runtime;
  final UnmodifiableSetView<NodeId> _selectedNodeIdsView;

  SceneSnapshot get snapshot => txnSceneToSnapshot(_runtime.ctx.workingScene);

  Set<NodeId> get selectedNodeIds => _selectedNodeIdsView;

  NodeId writeNodeInsert(NodeSpec spec, {LayerId? layerId, int? insertIndex}) {
    return sceneWriterWriteNodeInsert(
      this,
      spec,
      layerId: layerId,
      insertIndex: insertIndex,
    );
  }

  bool writeLayerEnsure(LayerId layerId, {int? index}) {
    return sceneWriterWriteLayerEnsure(this, layerId, index: index);
  }

  bool writeNodeErase(NodeId nodeId) {
    return sceneWriterWriteNodeErase(this, nodeId);
  }

  bool writeNodePatch(NodePatch patch) {
    return sceneWriterWriteNodePatch(this, patch);
  }

  bool writeNodeTransformSet(NodeId id, Transform2D transform) {
    return sceneWriterWriteNodeTransformSet(this, id, transform);
  }

  bool writeSelectionReplace(Iterable<NodeId> ids) {
    return sceneWriterWriteSelectionReplaceResult(this, ids) != null;
  }

  bool writeSelectionToggle(NodeId id) {
    return sceneWriterWriteSelectionToggle(this, id);
  }

  bool writeSelectionClear() {
    return sceneWriterWriteSelectionClear(this);
  }

  int writeSelectionSelectAll({bool onlySelectable = true}) {
    return sceneWriterWriteSelectionSelectAllResult(
      this,
      onlySelectable: onlySelectable,
    ).selectedCount;
  }

  int writeSelectionTranslate(Offset delta) {
    return sceneWriterWriteSelectionTranslate(this, delta);
  }

  int writeSelectionTransform(Transform2D delta) {
    return sceneWriterWriteSelectionTransform(this, delta);
  }

  int writeDeleteSelection() {
    return sceneWriterWriteDeleteSelectionResult(this).length;
  }

  List<NodeId> writeClearSceneKeepBackground() {
    return writeClearSceneKeepBackgroundResult().removedNodeIds;
  }

  ClearSceneResult writeClearSceneKeepBackgroundResult() {
    return sceneWriterWriteClearSceneKeepBackgroundResult(this);
  }

  void writeCameraOffset(Offset offset) {
    sceneWriterWriteCameraOffsetChanged(this, offset);
  }

  void writeGridEnable(bool enabled) {
    sceneWriterWriteGridEnableChanged(this, enabled);
  }

  void writeGridCellSize(double cellSize) {
    sceneWriterWriteGridCellSizeChanged(this, cellSize);
  }

  void writeBackgroundColor(Color color) {
    sceneWriterWriteBackgroundColorChanged(this, color);
  }

  void writeDocumentReplace(SceneSnapshot snapshot) {
    sceneWriterWriteDocumentReplace(this, snapshot);
  }

  void writePreparedDocumentReplace(PreparedSceneReplacement replacement) {
    sceneWriterWritePreparedDocumentReplace(this, replacement);
  }

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
