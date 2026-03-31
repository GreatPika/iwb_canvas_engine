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

  MutationApplyResult<TValue> execute<TValue extends Object?>(
    TypedMutationOp<TValue> op,
  ) {
    ensureTxnActive();
    return mutationExecutor.execute(ctx, op);
  }

  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot) {
    ensureTxnActive();
    return materializeSceneReplacement(
      snapshot: snapshot,
      nextInstanceRevisionSeed: ctx.nextInstanceRevision,
    );
  }

  void ensureTxnActive() {
    ctx.txnEnsureActive();
  }
}
