import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../contract/ids.dart' show LayerId;
import '../core/id_generator.dart';
import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../model/document.dart';
import '../model/document_clone.dart';
import 'change_set.dart';

part 'txn_workspace.dart';
part 'txn_derived_state.dart';

class TxnContext {
  TxnContext({
    required Scene baseScene,
    required Set<NodeId> workingSelection,
    required Set<NodeId> baseAllNodeIds,
    Map<NodeId, NodeLocatorEntry>? baseNodeLocator,
    int? nodeIdSeed,
    int? layerIdSeed,
    IdGeneratorState? idGeneratorState,
    RevisionAllocatorState? revisionState,
    int nextInstanceRevision = 1,
    ChangeSet? changeSet,
  }) : workingSelection = HashSet<NodeId>.of(workingSelection),
       idGeneratorState =
           idGeneratorState?.copy() ??
           createIdGeneratorStateForTesting(
             nextNodeCounter: _normalizeLegacySeed(nodeIdSeed),
             nextLayerCounter: _normalizeLegacySeed(layerIdSeed),
           ),
       revisionState =
           revisionState?.copy() ??
           createInitialRevisionAllocatorState(
             nextInstanceRevision: nextInstanceRevision,
           ),
       changeSet = changeSet ?? ChangeSet(),
       _debugStats = _TxnDebugStats(),
       _derivedState = _TxnDerivedState(
         baseAllNodeIds: baseAllNodeIds,
         baseNodeLocator: baseNodeLocator ?? txnBuildNodeLocator(baseScene),
       ),
       _workspace = _TxnWorkspace(baseScene: baseScene);

  final Set<NodeId> workingSelection;
  IdGeneratorState idGeneratorState;
  RevisionAllocatorState revisionState;
  final ChangeSet changeSet;
  final _TxnDebugStats _debugStats;
  final _TxnDerivedState _derivedState;
  final _TxnWorkspace _workspace;
  bool _isActive = true;

  Scene get workingScene => _workspace.workingScene;
  Scene txnSceneForCommit() => _workspace.sceneForCommit();

  int get debugSceneShallowClones => _debugStats.sceneShallowClones;
  int get debugLayerShallowClones => _debugStats.layerShallowClones;
  int get debugNodeClones => _debugStats.nodeClones;
  int get debugNodeIdSetMaterializations =>
      _debugStats.nodeIdSetMaterializations;
  int get debugNodeLocatorMaterializations =>
      _debugStats.nodeLocatorMaterializations;
  int get debugLayerIdIndexMaterializations =>
      _debugStats.layerIdIndexMaterializations;

  int get nodeIdSeed => idGeneratorState.nextNodeCounter;
  set nodeIdSeed(int value) {
    idGeneratorState.nextNodeCounter = value;
  }

  int get layerIdSeed => idGeneratorState.nextLayerCounter;
  set layerIdSeed(int value) {
    idGeneratorState.nextLayerCounter = value;
  }

  int get nextInstanceRevision => revisionState.nextInstanceRevision;
  set nextInstanceRevision(int value) {
    revisionState.nextInstanceRevision = requireRevisionCounter(
      value,
      name: 'nextInstanceRevision',
    );
  }

  void txnClose() {
    _isActive = false;
  }

  void txnEnsureActive() {
    if (_isActive) {
      return;
    }
    throw StateError('Transaction is closed.');
  }

  ContentLayer txnEnsureMutableLayer(int layerIndex) {
    return _workspace.ensureMutableLayer(
      ctx: this,
      derivedState: _derivedState,
      layerIndex: layerIndex,
    );
  }

  BackgroundLayer txnEnsureMutableBackgroundLayer() {
    return _workspace.ensureMutableBackgroundLayer(
      ctx: this,
      debugStats: _debugStats,
    );
  }

  ({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeById(
    NodeId id,
  ) {
    return txnFindNodeByLocator(
      scene: workingScene,
      nodeLocator: _derivedState.workingNodeLocator,
      nodeId: id,
    );
  }

  String txnNextNodeId() {
    txnEnsureActive();
    final candidate = generateNextNodeId(
      idGeneratorState,
      containsNodeId: txnHasNodeId,
    );
    txnRememberNodeId(candidate);
    return candidate;
  }

  LayerId txnNextLayerId() {
    txnEnsureActive();
    return generateNextLayerId(
      idGeneratorState,
      containsLayerId: txnHasLayerId,
    );
  }

  int txnNextInstanceRevision() {
    txnEnsureActive();
    return allocateNextInstanceRevision(revisionState);
  }
}

class _TxnDebugStats {
  int sceneShallowClones = 0;
  int layerShallowClones = 0;
  int nodeClones = 0;
  int nodeIdSetMaterializations = 0;
  int nodeLocatorMaterializations = 0;
  int layerIdIndexMaterializations = 0;
}

int _normalizeLegacySeed(int? value) {
  if (value == null || value < 1) {
    return 1;
  }
  return value;
}
