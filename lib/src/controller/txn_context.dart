import '../core/nodes.dart';
import '../core/scene.dart';
import '../model/document_clone.dart';
import 'change_set.dart';

class TxnContext {
  TxnContext({
    required this.workingScene,
    required this.workingSelection,
    required this.workingNodeIds,
    required this.nodeIdSeed,
    ChangeSet? changeSet,
  }) : changeSet = changeSet ?? ChangeSet();

  Scene workingScene;
  Set<NodeId> workingSelection;
  Set<NodeId> workingNodeIds;
  int nodeIdSeed;
  final ChangeSet changeSet;

  bool txnHasNodeId(NodeId nodeId) => workingNodeIds.contains(nodeId);

  void txnRememberNodeId(NodeId nodeId) {
    workingNodeIds = <NodeId>{...workingNodeIds, nodeId};
  }

  void txnForgetNodeId(NodeId nodeId) {
    workingNodeIds = <NodeId>{
      for (final candidate in workingNodeIds)
        if (candidate != nodeId) candidate,
    };
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
    workingScene = scene;
    workingNodeIds = txnCollectNodeIds(scene);
    nodeIdSeed = txnInitialNodeIdSeed(scene);
  }
}
