import 'dart:ui';

import '../contract/scene_write_txn.dart';
import '../core/nodes.dart';
import 'mutation_op.dart';
import 'scene_writer.dart';
import 'scene_writer_scene.dart';
import 'scene_writer_selection.dart';
import 'scene_writer_signals.dart';
import 'scene_writer_support.dart';

List<NodeId> sceneWriterWriteDeleteNodesResult(
  SceneWriter writer,
  Iterable<NodeId> nodeIds,
) {
  final removedIds = writer.runtime.execute(DeleteNodesBulkOp(nodeIds)).value;
  return sortWriterNodeIds(removedIds);
}

List<NodeId>? sceneWriterWriteSelectionReplaceExactResult(
  SceneWriter writer,
  Iterable<NodeId> ids,
) {
  return sceneWriterWriteSelectionReplaceResult(writer, ids);
}

({int selectedCount, bool changed})
sceneWriterWriteSelectionSelectAllExactResult(
  SceneWriter writer, {
  bool onlySelectable = true,
}) {
  return sceneWriterWriteSelectionSelectAllResult(
    writer,
    onlySelectable: onlySelectable,
  );
}

List<NodeId> sceneWriterWriteDeleteSelectionExactResult(SceneWriter writer) {
  return sceneWriterWriteDeleteSelectionResult(writer);
}

ClearSceneResult sceneWriterWriteClearSceneExactResult(SceneWriter writer) {
  return sceneWriterWriteClearSceneKeepBackgroundResult(writer);
}

bool sceneWriterWriteCameraOffsetExactChange(
  SceneWriter writer,
  Offset offset,
) {
  return sceneWriterWriteCameraOffsetChanged(writer, offset);
}

bool sceneWriterWriteGridEnableExactChange(SceneWriter writer, bool enabled) {
  return sceneWriterWriteGridEnableChanged(writer, enabled);
}

bool sceneWriterWriteGridCellSizeExactChange(
  SceneWriter writer,
  double cellSize,
) {
  return sceneWriterWriteGridCellSizeChanged(writer, cellSize);
}

bool sceneWriterWriteBackgroundColorExactChange(
  SceneWriter writer,
  Color color,
) {
  return sceneWriterWriteBackgroundColorChanged(writer, color);
}

void sceneWriterWriteOwnedSignalExactEnqueue(
  SceneWriter writer, {
  required String type,
  List<NodeId> nodeIds = const <NodeId>[],
  Map<String, Object?>? payload,
}) {
  sceneWriterWriteOwnedSignalEnqueue(
    writer,
    type: type,
    nodeIds: nodeIds,
    payload: payload,
  );
}
