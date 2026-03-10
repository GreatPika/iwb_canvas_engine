import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/id_generator.dart';
import '../core/revision_policy.dart';
import '../model/document.dart';
import '../model/document_clone.dart';

class SceneStore {
  SceneStore({required this.sceneDoc, Set<NodeId>? selectedNodeIds})
    : selectedNodeIds = selectedNodeIds == null
          ? <NodeId>{}
          : Set<NodeId>.from(selectedNodeIds),
      allNodeIds = txnCollectNodeIds(sceneDoc),
      nodeLocator = txnBuildNodeLocator(sceneDoc),
      idGeneratorState = createInitialIdGeneratorState(),
      revisionState = createInitialRevisionAllocatorState();

  Scene sceneDoc;
  Set<NodeId> selectedNodeIds;
  Set<NodeId> allNodeIds;
  Map<NodeId, NodeLocatorEntry> nodeLocator;
  IdGeneratorState idGeneratorState;
  RevisionAllocatorState revisionState;

  int controllerEpoch = 0;
  int structuralRevision = 0;
  int boundsRevision = 0;
  int visualRevision = 0;
  int commitRevision = 0;

  int get nextInstanceRevision => revisionState.nextInstanceRevision;
  set nextInstanceRevision(int value) {
    revisionState.nextInstanceRevision = requireRevisionCounter(
      value,
      name: 'nextInstanceRevision',
    );
  }

  int get nodeIdSeed => idGeneratorState.nextNodeCounter;
  set nodeIdSeed(int value) {
    idGeneratorState.nextNodeCounter = value;
  }

  int get layerIdSeed => idGeneratorState.nextLayerCounter;
  set layerIdSeed(int value) {
    idGeneratorState.nextLayerCounter = value;
  }
}
