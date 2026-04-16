import 'package:flutter/foundation.dart';

import '../contract/snapshot.dart';
import 'mutation_executor.dart';
import 'mutation_op.dart';
import 'scene_snapshot_materializer.dart';
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
  final PreparedSceneReplacementOwner _sceneReplacementOwner =
      createPreparedSceneReplacementOwner();

  MutationApplyResult<TValue> execute<TValue extends Object?>(
    TypedMutationOp<TValue> op,
  ) {
    ensureTxnActive();
    return mutationExecutor.execute(ctx, op);
  }

  void writeStagedDocumentReplace(
    SceneSnapshot snapshot, {
    required void Function(VoidCallback writeDocumentReplaceNow) stageCommit,
  }) {
    ensureTxnActive();
    final replacement = materializeSceneReplacement(
      snapshot: snapshot,
      nextInstanceRevisionSeed: ctx.nextInstanceRevision,
      owner: _sceneReplacementOwner,
    );
    stageCommit(() {
      execute(ReplaceSceneOp(replacement, _sceneReplacementOwner));
    });
  }

  void ensureTxnActive() {
    ctx.txnEnsureActive();
  }
}
