import 'dart:ui';

import 'mutation_op.dart';
import 'scene_writer.dart';
import 'scene_writer_support.dart';
import 'scene_writer_types.dart';

List<NodeId>? sceneWriterWriteSelectionReplaceResult(
  SceneWriter writer,
  Iterable<NodeId> ids,
) {
  return writer.runtime.execute(ReplaceSelectionOp(ids)).value;
}

bool sceneWriterWriteSelectionToggle(SceneWriter writer, NodeId id) {
  return writer.runtime.execute(ToggleSelectionOp(id)).value;
}

bool sceneWriterWriteSelectionClear(SceneWriter writer) {
  return writer.runtime.execute(const ClearSelectionOp()).value;
}

({int selectedCount, bool changed}) sceneWriterWriteSelectionSelectAllResult(
  SceneWriter writer, {
  bool onlySelectable = true,
}) {
  return writer.runtime
      .execute(SelectAllSelectionOp(onlySelectable: onlySelectable))
      .value;
}

List<NodeId> sceneWriterWriteDeleteSelectionResult(SceneWriter writer) {
  final removedIds = writer.runtime
      .execute(DeleteNodesBulkOp.borrowed(writer.runtime.ctx.workingSelection))
      .value;
  return sortWriterNodeIds(removedIds);
}

int sceneWriterWriteSelectionTranslate(SceneWriter writer, Offset delta) {
  return writer.runtime.execute(TranslateSelectionOp(delta)).value;
}

int sceneWriterWriteSelectionTransform(SceneWriter writer, Transform2D delta) {
  return writer.runtime.execute(TransformSelectionOp(delta)).value;
}
