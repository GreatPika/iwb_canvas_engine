import '../../core/nodes.dart';
import '../../core/scene.dart';
import '../model/document_clone.dart';

class V2Store {
  V2Store({required this.sceneDoc, Set<NodeId>? selectedNodeIds})
    : selectedNodeIds = selectedNodeIds == null
          ? <NodeId>{}
          : Set<NodeId>.from(selectedNodeIds),
      allNodeIds = txnCollectNodeIds(sceneDoc),
      nodeIdSeed = txnInitialNodeIdSeed(sceneDoc);

  Scene sceneDoc;
  Set<NodeId> selectedNodeIds;
  Set<NodeId> allNodeIds;

  int controllerEpoch = 0;
  int structuralRevision = 0;
  int boundsRevision = 0;
  int visualRevision = 0;
  int commitRevision = 0;

  int nodeIdSeed;
}
