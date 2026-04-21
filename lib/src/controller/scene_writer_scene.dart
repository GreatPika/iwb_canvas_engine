import 'dart:ui';

import 'mutation_op.dart';
import 'scene_writer.dart';
import 'scene_writer_types.dart';

bool sceneWriterWriteCameraOffsetChanged(SceneWriter writer, Offset offset) {
  return writer.runtime.execute(SetCameraOffsetOp(offset)).changed;
}

bool sceneWriterWriteGridEnableChanged(SceneWriter writer, bool enabled) {
  return writer.runtime.execute(SetGridEnabledOp(enabled)).changed;
}

bool sceneWriterWriteGridCellSizeChanged(SceneWriter writer, double cellSize) {
  return writer.runtime.execute(SetGridCellSizeOp(cellSize)).changed;
}

bool sceneWriterWriteBackgroundColorChanged(SceneWriter writer, Color color) {
  return writer.runtime.execute(SetBackgroundColorOp(color)).changed;
}

void sceneWriterWriteDocumentReplace(
  SceneWriter writer,
  SceneSnapshot snapshot,
) {
  writer.runtime.writeStagedDocumentReplace(
    snapshot,
    stageCommit: (writeDocumentReplaceNow) {
      writeDocumentReplaceNow();
    },
  );
}

ClearSceneResult sceneWriterWriteClearSceneKeepBackgroundResult(
  SceneWriter writer,
) {
  return writer.runtime.execute(const ClearSceneKeepBackgroundOp()).value;
}
