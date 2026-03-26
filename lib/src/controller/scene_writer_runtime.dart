import 'dart:ui';

import 'scene_writer_types.dart';
import 'mutation_executor.dart';
import 'mutation_op.dart';
import 'txn_context.dart';
import 'internal/signal_event.dart';

final class SceneWriterRuntime {
  SceneWriterRuntime({
    required this.ctx,
    required this.mutationExecutor,
    required this.txnSignalSink,
  });

  final TxnContext ctx;
  final MutationExecutor mutationExecutor;
  final void Function(BufferedSignal signal) txnSignalSink;

  MutationApplyResult<TValue> execute<TValue extends Object?>(
    TypedMutationOp<TValue> op,
  ) {
    ensureTxnActive();
    return mutationExecutor.execute(ctx, op);
  }

  NodeId writeNodeInsert(NodeSpec spec, {LayerId? layerId, int? insertIndex}) {
    return execute(
      InsertNodeOp(spec, layerId: layerId, insertIndex: insertIndex),
    ).value;
  }

  bool writeLayerEnsure(LayerId layerId, {int? index}) {
    return execute(EnsureLayerOp(layerId, index: index)).value;
  }

  bool writeNodeErase(NodeId nodeId) {
    return execute(DeleteNodeOp(nodeId)).value;
  }

  bool writeNodePatch(NodePatch patch) {
    return execute(PatchNodeOp(patch)).value;
  }

  bool writeNodeTransformSet(NodeId id, Transform2D transform) {
    return execute(SetNodeTransformOp(id, transform)).value;
  }

  int writeSelectionTranslate(Offset delta) {
    return execute(TranslateSelectionOp(delta)).value;
  }

  int writeSelectionTransform(Transform2D delta) {
    return execute(TransformSelectionOp(delta)).value;
  }

  ClearSceneResult writeClearSceneKeepBackgroundResult() {
    return execute(const ClearSceneKeepBackgroundOp()).value;
  }

  void ensureTxnActive() {
    ctx.txnEnsureActive();
  }
}
