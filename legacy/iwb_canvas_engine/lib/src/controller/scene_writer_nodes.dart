import 'scene_writer.dart';
import 'mutation_op.dart';
import 'scene_writer_types.dart';

NodeId sceneWriterWriteNodeInsert(
  SceneWriter writer,
  NodeSpec spec, {
  LayerId? layerId,
  int? insertIndex,
}) {
  return writer.runtime
      .execute(InsertNodeOp(spec, layerId: layerId, insertIndex: insertIndex))
      .value;
}

bool sceneWriterWriteLayerEnsure(
  SceneWriter writer,
  LayerId layerId, {
  int? index,
}) {
  return writer.runtime.execute(EnsureLayerOp(layerId, index: index)).value;
}

bool sceneWriterWriteNodeErase(SceneWriter writer, NodeId nodeId) {
  return writer.runtime.execute(DeleteNodeOp(nodeId)).value;
}

bool sceneWriterWriteNodePatch(SceneWriter writer, NodePatch patch) {
  return writer.runtime.execute(PatchNodeOp(patch)).value;
}

bool sceneWriterWriteNodeTransformSet(
  SceneWriter writer,
  NodeId id,
  Transform2D transform,
) {
  return writer.runtime.execute(SetNodeTransformOp(id, transform)).value;
}
