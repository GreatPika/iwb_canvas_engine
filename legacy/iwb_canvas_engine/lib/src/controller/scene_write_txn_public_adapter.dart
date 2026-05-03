import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import 'scene_writer.dart';

final class SceneWriteTxnPublicAdapter implements SceneWriteTxn {
  SceneWriteTxnPublicAdapter(this._writer);

  final SceneWriter _writer;

  @override
  SceneSnapshot get snapshot => _writer.snapshot;

  @override
  Set<NodeId> get selectedNodeIds => _writer.selectedNodeIds;

  @override
  NodeId writeNodeInsert(NodeSpec spec, {LayerId? layerId, int? insertIndex}) {
    return _writer.writeNodeInsert(
      spec,
      layerId: layerId,
      insertIndex: insertIndex,
    );
  }

  @override
  bool writeLayerEnsure(LayerId layerId, {int? index}) {
    return _writer.writeLayerEnsure(layerId, index: index);
  }

  @override
  bool writeNodeErase(NodeId nodeId) {
    return _writer.writeNodeErase(nodeId);
  }

  @override
  bool writeNodePatch(NodePatch patch) {
    return _writer.writeNodePatch(patch);
  }

  @override
  bool writeNodeTransformSet(NodeId id, Transform2D transform) {
    return _writer.writeNodeTransformSet(id, transform);
  }

  @override
  bool writeSelectionReplace(Iterable<NodeId> ids) {
    return _writer.writeSelectionReplace(ids);
  }

  @override
  bool writeSelectionToggle(NodeId id) {
    return _writer.writeSelectionToggle(id);
  }

  @override
  bool writeSelectionClear() {
    return _writer.writeSelectionClear();
  }

  @override
  int writeSelectionSelectAll({bool onlySelectable = true}) {
    return _writer.writeSelectionSelectAll(onlySelectable: onlySelectable);
  }

  @override
  int writeSelectionTranslate(Offset delta) {
    return _writer.writeSelectionTranslate(delta);
  }

  @override
  int writeSelectionTransform(Transform2D delta) {
    return _writer.writeSelectionTransform(delta);
  }

  @override
  int writeDeleteSelection() {
    return _writer.writeDeleteSelection();
  }

  @override
  ClearSceneResult writeClearSceneKeepBackgroundResult() {
    return _writer.writeClearSceneKeepBackgroundResult();
  }

  @override
  List<NodeId> writeClearSceneKeepBackground() {
    return _writer.writeClearSceneKeepBackground();
  }

  @override
  void writeCameraOffset(Offset offset) {
    _writer.writeCameraOffset(offset);
  }

  @override
  void writeGridEnable(bool enabled) {
    _writer.writeGridEnable(enabled);
  }

  @override
  void writeGridCellSize(double cellSize) {
    _writer.writeGridCellSize(cellSize);
  }

  @override
  void writeBackgroundColor(Color color) {
    _writer.writeBackgroundColor(color);
  }

  @override
  void writeDocumentReplace(SceneSnapshot snapshot) {
    _writer.writeDocumentReplace(snapshot);
  }
}
