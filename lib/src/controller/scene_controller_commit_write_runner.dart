import 'dart:collection';

import 'internal/signal_event.dart';
import 'mutation_executor.dart';
import 'scene_writer.dart';
import 'store.dart';
import 'txn_context.dart';

final class SceneControllerCommitWriteRunner {
  SceneControllerCommitWriteRunner({
    required SceneStore store,
    required String? textFontFamilyByDefault,
    required void Function()? beforeTxnContextCreateHook,
    required void Function(BufferedSignal signal) txnSignalSink,
  }) : _store = store,
       _beforeTxnContextCreateHook = beforeTxnContextCreateHook,
       _txnSignalSink = txnSignalSink,
       _mutationExecutor = MutationExecutor(
         textFontFamilyByDefault: textFontFamilyByDefault,
       );

  final SceneStore _store;
  final void Function()? _beforeTxnContextCreateHook;
  final void Function(BufferedSignal signal) _txnSignalSink;
  final MutationExecutor _mutationExecutor;

  bool _writeInProgress = false;
  bool _isDisposed = false;

  bool get writeInProgress => _writeInProgress;

  T run<T>({
    required T Function(SceneWriter writer) fn,
    required void Function(TxnContext ctx) txnCommit,
  }) {
    _throwIfDisposed();
    if (_writeInProgress) {
      throw StateError('Nested write(...) calls are not allowed.');
    }

    _writeInProgress = true;
    TxnContext? closeCtx;
    try {
      late final TxnContext ctx;
      final writer = _createSceneWriter(
        outCtx: (createdCtx) {
          ctx = createdCtx;
          closeCtx = createdCtx;
        },
      );
      final result = fn(writer);
      if (result is Future) {
        throw StateError(
          'Async write callbacks are not supported. '
          'Return synchronously from write(...).',
        );
      }
      txnCommit(ctx);
      return result;
    } finally {
      closeCtx?.txnClose();
      _writeInProgress = false;
    }
  }

  void dispose() {
    if (_writeInProgress) {
      throw StateError('dispose() is not allowed during active write(...).');
    }
    _isDisposed = true;
  }

  SceneWriter _createSceneWriter({
    required void Function(TxnContext ctx) outCtx,
  }) {
    _beforeTxnContextCreateHook?.call();
    final ctx = TxnContext(
      baseScene: _store.sceneDoc,
      workingSelection: HashSet.of(_store.selectedNodeIds),
      baseAllNodeIds: _store.allNodeIds,
      baseNodeLocator: _store.nodeLocator,
      idGeneratorState: _store.idGeneratorState,
      revisionState: _store.revisionState,
    );
    outCtx(ctx);
    return SceneWriter(
      ctx,
      mutationExecutor: _mutationExecutor,
      txnSignalSink: _txnSignalSink,
    );
  }

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('Controller is disposed.');
    }
  }
}
