import '../core/id_generator.dart';
import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../model/document.dart';
import 'mutation_op.dart';

final class CommittedStoreState {
  const CommittedStoreState({
    required this.scene,
    required this.selectedNodeIds,
    required this.allNodeIds,
    required this.nodeLocator,
    required this.idGeneratorState,
    required this.revisionState,
    required this.controllerEpoch,
    required this.structuralRevision,
    required this.boundsRevision,
    required this.visualRevision,
    required this.commitRevision,
  });

  factory CommittedStoreState.fromMutationCommitCandidate({
    required MutationCommitCandidate candidate,
    required Set<NodeId> selectedNodeIds,
    required RevisionAllocatorState revisionState,
    required int controllerEpoch,
    required int structuralRevision,
    required int boundsRevision,
    required int visualRevision,
    required int commitRevision,
  }) {
    return CommittedStoreState(
      scene: candidate.scene,
      selectedNodeIds: selectedNodeIds,
      allNodeIds: candidate.allNodeIds,
      nodeLocator: candidate.nodeLocator,
      idGeneratorState: candidate.idGeneratorState,
      revisionState: revisionState,
      controllerEpoch: controllerEpoch,
      structuralRevision: structuralRevision,
      boundsRevision: boundsRevision,
      visualRevision: visualRevision,
      commitRevision: commitRevision,
    );
  }

  final Scene scene;
  final Set<NodeId> selectedNodeIds;
  final Set<NodeId> allNodeIds;
  final Map<NodeId, NodeLocatorEntry> nodeLocator;
  final IdGeneratorState idGeneratorState;
  final RevisionAllocatorState revisionState;
  final int controllerEpoch;
  final int structuralRevision;
  final int boundsRevision;
  final int visualRevision;
  final int commitRevision;
}
