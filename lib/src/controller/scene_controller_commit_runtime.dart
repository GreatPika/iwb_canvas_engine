import 'dart:collection';

import '../contract/scene_write_txn.dart';
import '../core/nodes.dart' show NodeId;
import 'internal/repaint_flag.dart';
import 'internal/signal_event.dart';
import 'internal/signals_buffer.dart';
import 'internal/spatial_index_cache.dart';
import 'scene_controller_commit_debug.dart';
import 'scene_controller_commit_execution.dart';
import 'scene_controller_commit_plan.dart';
import 'scene_controller_commit_write_runner.dart';
import 'scene_controller_post_commit_lifecycle.dart';
import 'scene_write_txn_public_adapter.dart';
import 'scene_writer.dart';
import 'store.dart';
import 'txn_context.dart';

final class SceneControllerCommittedWrite<T> {
  const SceneControllerCommittedWrite({
    required this.result,
    required this.commitResult,
  });

  final T result;
  final SceneControllerWriteCommitResult commitResult;
}

final class SceneControllerCommitRuntime {
  SceneControllerCommitRuntime({
    required SceneStore store,
    required String? textFontFamilyByDefault,
    required void Function() notifyListeners,
  }) : _store = store,
       _selectedNodeIdsView = UnmodifiableSetView<NodeId>(
         store.selectedNodeIds,
       ),
       _selectedNodeIdsOwner = store.selectedNodeIds {
    _writeRunner = SceneControllerCommitWriteRunner(
      store: store,
      textFontFamilyByDefault: textFontFamilyByDefault,
      beforeTxnContextCreateHook: () {
        _debugState.beforeTxnContextCreateHook?.call();
      },
      txnSignalSink: _signalsBuffer.writeBufferSignal,
    );
    _postCommitLifecycle = SceneControllerPostCommitLifecycle(
      signalsBuffer: _signalsBuffer,
      notifyListeners: notifyListeners,
    );
  }

  final SceneStore _store;
  final SignalsBuffer _signalsBuffer = SignalsBuffer();
  final RepaintFlag _repaintFlag = RepaintFlag();
  final SpatialIndexCache _spatialIndexCache = SpatialIndexCache();
  final SceneControllerCommitDebugState _debugState =
      SceneControllerCommitDebugState();
  late final SceneControllerCommitWriteRunner _writeRunner;
  late final SceneControllerPostCommitLifecycle _postCommitLifecycle;

  UnmodifiableSetView<NodeId> _selectedNodeIdsView;
  Set<NodeId> _selectedNodeIdsOwner;
  bool _isDisposed = false;

  Set<NodeId> get selectedNodeIdsView => _selectedNodeIdsView;
  Stream<CommittedSignal> get signals => _signalsBuffer.signals;
  SceneControllerCommitDebugState get debugState => _debugState;
  SpatialIndexCache get spatialIndexCache => _spatialIndexCache;

  T write<T>(T Function(SceneWriteTxn txn) fn) {
    _throwIfDisposed();
    final committedWrite = _write<T>((writer) {
      return fn(SceneWriteTxnPublicAdapter(writer));
    });
    _postCommitLifecycle.dispatch(committedWrite.commitResult);
    return committedWrite.result;
  }

  void requestRepaint() {
    _throwIfDisposed();
    _postCommitLifecycle.requestRepaint(
      repaintFlag: _repaintFlag,
      writeInProgress: _writeRunner.writeInProgress,
    );
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _writeRunner.dispose();
    _signalsBuffer.dispose();
    _postCommitLifecycle.dispose();
    _isDisposed = true;
  }

  T writeWithSceneWriter<T>(T Function(SceneWriter writer) fn) {
    _throwIfDisposed();
    final committedWrite = _write(fn);
    _postCommitLifecycle.dispatch(committedWrite.commitResult);
    return committedWrite.result;
  }

  SceneControllerCommittedWrite<T> _write<T>(
    T Function(SceneWriter writer) fn,
  ) {
    late SceneControllerWriteCommitResult commitResult;
    try {
      final result = _writeRunner.run<T>(
        fn: fn,
        txnCommit: (ctx) => commitResult = _commitTxn(ctx),
      );
      _refreshSelectedNodeIdsView();
      return SceneControllerCommittedWrite<T>(
        result: result,
        commitResult: commitResult,
      );
    } catch (_) {
      _signalsBuffer.writeDiscardBuffered();
      _repaintFlag.writeDiscardPending();
      rethrow;
    }
  }

  SceneControllerWriteCommitResult _commitTxn(TxnContext ctx) {
    final commitPhases = deriveControllerCommitInitialPhases(
      changeSet: ctx.changeSet,
    );
    final plan = buildControllerCommitPlan(
      ctx: ctx,
      store: _store,
      initialPhases: commitPhases,
    );
    final result = executeControllerCommitPlan(
      plan: plan,
      context: SceneControllerCommitExecutionContext(
        store: _store,
        signalsBuffer: _signalsBuffer,
        repaintFlag: _repaintFlag,
        spatialIndexCache: _spatialIndexCache,
        debugState: _debugState,
      ),
    );
    _debugState.recordCommit(
      commitPhases: resolveControllerCommitPhases(
        plan: plan,
        hasCommittedSignals: result.committedSignals.isNotEmpty,
        needsNotify: result.needsNotify,
      ),
      changeSet: plan.changeSet,
    );
    _debugState.captureTxnCloneStats(ctx);
    return result;
  }

  void _refreshSelectedNodeIdsView() {
    if (identical(_selectedNodeIdsOwner, _store.selectedNodeIds)) {
      return;
    }
    _selectedNodeIdsOwner = _store.selectedNodeIds;
    _selectedNodeIdsView = UnmodifiableSetView<NodeId>(_selectedNodeIdsOwner);
  }

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('Controller is disposed.');
    }
  }
}
