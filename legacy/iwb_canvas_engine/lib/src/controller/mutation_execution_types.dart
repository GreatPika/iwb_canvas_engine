import '../contract/ids.dart';
import '../core/id_generator.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../model/document.dart';
import 'change_set.dart';
import 'mutation_op.dart';

class MutationCommitCandidate {
  const MutationCommitCandidate({
    required this.scene,
    required this.selection,
    required this.allNodeIds,
    required this.nodeLocator,
    required this.layerIndexById,
    required this.idGeneratorState,
    required this.revisionState,
  });

  final Scene scene;
  final Set<NodeId> selection;
  final Set<NodeId> allNodeIds;
  final Map<NodeId, NodeLocatorEntry> nodeLocator;
  final Map<LayerId, int> layerIndexById;
  final IdGeneratorState idGeneratorState;
  final RevisionAllocatorState revisionState;
}

class MutationExecutionResult<TValue extends Object?> {
  const MutationExecutionResult({
    required this.applyResult,
    required this.changeSet,
    required this.commitCandidate,
  });

  final MutationApplyResult<TValue> applyResult;
  final ChangeSet changeSet;
  final MutationCommitCandidate? commitCandidate;
}

class MutationPreparedCommitResult {
  const MutationPreparedCommitResult({
    required this.changeSet,
    required this.commitCandidate,
  });

  final ChangeSet changeSet;
  final MutationCommitCandidate? commitCandidate;
}
