import '../core/nodes.dart';
import '../core/scene.dart';
import '../model/document.dart';
import '../model/document_clone.dart';

class SceneStore {
  SceneStore({required this.sceneDoc, Set<NodeId>? selectedNodeIds})
    : selectedNodeIds = selectedNodeIds == null
          ? <NodeId>{}
          : Set<NodeId>.from(selectedNodeIds),
      allNodeIds = txnCollectNodeIds(sceneDoc),
      nodeLocator = txnBuildNodeLocator(sceneDoc),
      nodeIdSeed = txnInitialNodeIdSeed(sceneDoc),
      nextInstanceRevision = txnInitialNodeInstanceRevisionSeed(sceneDoc);

  Scene sceneDoc;
  Set<NodeId> selectedNodeIds;
  Set<NodeId> allNodeIds;
  Map<NodeId, NodeLocatorEntry> nodeLocator;

  int controllerEpoch = 0;
  int structuralRevision = 0;
  int boundsRevision = 0;
  int visualRevision = 0;
  int commitRevision = 0;

  int nodeIdSeed;
  int nextInstanceRevision;
}
