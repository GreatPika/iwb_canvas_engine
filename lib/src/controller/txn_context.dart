import '../core/nodes.dart';
import '../core/scene.dart';
import '../model/document_clone.dart';
import 'change_set.dart';

class TxnContext {
  TxnContext({
    required Scene baseScene,
    required this.workingSelection,
    required this.workingNodeIds,
    required this.nodeIdSeed,
    ChangeSet? changeSet,
  }) : _baseScene = baseScene,
       changeSet = changeSet ?? ChangeSet();

  final Scene _baseScene;
  Scene? _mutableScene;

  Scene get workingScene => _mutableScene ?? _baseScene;
  Scene txnSceneForCommit() => _mutableScene ?? _baseScene;

  Set<NodeId> workingSelection;
  final Set<NodeId> workingNodeIds;
  int nodeIdSeed;
  final ChangeSet changeSet;

  Scene txnEnsureMutableScene() {
    final existing = _mutableScene;
    if (existing != null) return existing;
    final cloned = txnCloneScene(_baseScene);
    _mutableScene = cloned;
    return cloned;
  }

  bool txnHasNodeId(NodeId nodeId) => workingNodeIds.contains(nodeId);

  void txnRememberNodeId(NodeId nodeId) {
    workingNodeIds.add(nodeId);
  }

  void txnForgetNodeId(NodeId nodeId) {
    workingNodeIds.remove(nodeId);
  }

  String txnNextNodeId() {
    while (true) {
      final candidate = 'node-$nodeIdSeed';
      nodeIdSeed = nodeIdSeed + 1;
      if (!txnHasNodeId(candidate)) {
        txnRememberNodeId(candidate);
        return candidate;
      }
    }
  }

  void txnAdoptScene(Scene scene) {
    _mutableScene = scene;
    workingNodeIds
      ..clear()
      ..addAll(txnCollectNodeIds(scene));
    nodeIdSeed = txnInitialNodeIdSeed(scene);
  }
}
