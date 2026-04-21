import '../core/id_generator.dart' show IdGeneratorState;
import 'change_set.dart';
import 'scene_controller_commit_runtime.dart';
import 'store.dart';
import 'txn_context.dart';

final class SceneControllerCommitDebugState {
  void Function()? beforeInvariantPrecheckHook;
  void Function()? beforeSpatialPrepareCommitHook;
  void Function()? beforeTxnContextCreateHook;

  List<String> _lastCommitPhases = const <String>[];
  ChangeSet _lastChangeSet = ChangeSet();
  int _lastSceneShallowClones = 0;
  int _lastLayerShallowClones = 0;
  int _lastNodeClones = 0;
  int _lastNodeIdSetMaterializations = 0;
  int _lastNodeLocatorMaterializations = 0;

  List<String> get lastCommitPhases => _lastCommitPhases;
  ChangeSet get lastChangeSet => _lastChangeSet.txnClone();
  int get lastSceneShallowClones => _lastSceneShallowClones;
  int get lastLayerShallowClones => _lastLayerShallowClones;
  int get lastNodeClones => _lastNodeClones;
  int get lastNodeIdSetMaterializations => _lastNodeIdSetMaterializations;
  int get lastNodeLocatorMaterializations => _lastNodeLocatorMaterializations;

  void recordCommit({
    required List<String> commitPhases,
    required ChangeSet changeSet,
  }) {
    _lastCommitPhases = commitPhases;
    _lastChangeSet = changeSet;
  }

  void captureTxnCloneStats(TxnContext ctx) {
    _lastSceneShallowClones = ctx.debugSceneShallowClones;
    _lastLayerShallowClones = ctx.debugLayerShallowClones;
    _lastNodeClones = ctx.debugNodeClones;
    _lastNodeIdSetMaterializations = ctx.debugNodeIdSetMaterializations;
    _lastNodeLocatorMaterializations = ctx.debugNodeLocatorMaterializations;
  }
}

final class SceneStoreControllerDebugAccess {
  const SceneStoreControllerDebugAccess({
    required SceneStore store,
    required SceneControllerCommitRuntime runtime,
  }) : _store = store,
       _runtime = runtime;

  final SceneStore _store;
  final SceneControllerCommitRuntime _runtime;

  void Function()? get beforeInvariantPrecheckHook =>
      _runtime.debugState.beforeInvariantPrecheckHook;
  set beforeInvariantPrecheckHook(void Function()? value) {
    _runtime.debugState.beforeInvariantPrecheckHook = value;
  }

  void Function()? get beforeSpatialPrepareCommitHook =>
      _runtime.debugState.beforeSpatialPrepareCommitHook;
  set beforeSpatialPrepareCommitHook(void Function()? value) {
    _runtime.debugState.beforeSpatialPrepareCommitHook = value;
  }

  void Function()? get beforeTxnContextCreateHook =>
      _runtime.debugState.beforeTxnContextCreateHook;
  set beforeTxnContextCreateHook(void Function()? value) {
    _runtime.debugState.beforeTxnContextCreateHook = value;
  }

  List<String> get lastCommitPhases => _runtime.debugState.lastCommitPhases;
  ChangeSet get lastChangeSet => _runtime.debugState.lastChangeSet;
  int get spatialIndexBuildCount => _runtime.spatialIndexCache.debugBuildCount;
  int get spatialIndexIncrementalApplyCount =>
      _runtime.spatialIndexCache.debugIncrementalApplyCount;
  int get sceneShallowClones => _runtime.debugState.lastSceneShallowClones;
  int get layerShallowClones => _runtime.debugState.lastLayerShallowClones;
  int get nodeClones => _runtime.debugState.lastNodeClones;
  int get nodeIdSetMaterializations =>
      _runtime.debugState.lastNodeIdSetMaterializations;
  int get nodeLocatorMaterializations =>
      _runtime.debugState.lastNodeLocatorMaterializations;
  int get currentCommitRevision => _store.commitRevision;
  IdGeneratorState get idGeneratorState => _store.idGeneratorState.copy();
}
