import 'committed_store_state.dart';
import '../core/revision_policy.dart';
import 'change_set.dart';
import 'mutation_commit_preparer.dart';
import 'store.dart';
import 'txn_context.dart';

List<String> deriveControllerCommitInitialPhases({
  required ChangeSet changeSet,
}) {
  if (_requiresSelectionCommitPhase(changeSet)) {
    return const <String>['selection'];
  }
  return const <String>[];
}

ControllerCommitPlan buildControllerCommitPlan({
  required TxnContext ctx,
  required SceneStore store,
  required List<String> initialPhases,
}) {
  final preparedCommit = prepareMutationPreparedCommitResult(ctx);
  final changeSet = preparedCommit.changeSet;
  final commitCandidate = preparedCommit.commitCandidate;

  if (commitCandidate == null) {
    return ControllerEffectsOnlyCommitPlan(
      changeSet: changeSet,
      initialPhases: initialPhases,
      nextCommitRevision: store.commitRevision + 1,
    );
  }

  final committedSelection = changeSet.selectionChanged
      ? commitCandidate.selection
      : store.selectedNodeIds;
  final committedRevisionState = resolvedCommittedRevisionAllocatorState(
    commitCandidate.revisionState,
  );

  return ControllerStateCommitPlan(
    changeSet: changeSet,
    initialPhases: initialPhases,
    committedStoreState: CommittedStoreState.fromMutationCommitCandidate(
      candidate: commitCandidate,
      selectedNodeIds: committedSelection,
      revisionState: committedRevisionState,
      controllerEpoch: resolveNextControllerEpoch(
        currentEpoch: store.controllerEpoch,
        documentReplaced: changeSet.documentReplaced,
        revisionState: commitCandidate.revisionState,
      ),
      structuralRevision:
          store.structuralRevision + (changeSet.structuralChanged ? 1 : 0),
      selectionRevision:
          store.selectionRevision + (changeSet.selectionChanged ? 1 : 0),
      boundsRevision: store.boundsRevision + (changeSet.boundsChanged ? 1 : 0),
      visualRevision: store.visualRevision + 1,
      commitRevision: store.commitRevision + 1,
    ),
  );
}

bool _requiresSelectionCommitPhase(ChangeSet changeSet) {
  return changeSet.selectionChanged ||
      changeSet.structuralChanged ||
      changeSet.documentReplaced;
}

List<String> resolveControllerCommitPhases({
  required ControllerCommitPlan plan,
  required bool hasCommittedSignals,
  required bool needsNotify,
}) {
  var phases = plan.initialPhases;
  if (plan is ControllerStateCommitPlan) {
    phases = <String>[...phases, 'spatial_index', 'signals'];
  } else if (hasCommittedSignals) {
    phases = <String>[...phases, 'signals'];
  }
  if (needsNotify) {
    phases = <String>[...phases, 'repaint'];
  }
  return phases;
}

sealed class ControllerCommitPlan {
  const ControllerCommitPlan({
    required this.changeSet,
    required this.initialPhases,
  });

  final ChangeSet changeSet;
  final List<String> initialPhases;
}

final class ControllerEffectsOnlyCommitPlan extends ControllerCommitPlan {
  const ControllerEffectsOnlyCommitPlan({
    required super.changeSet,
    required super.initialPhases,
    required this.nextCommitRevision,
  });

  final int nextCommitRevision;
}

final class ControllerStateCommitPlan extends ControllerCommitPlan {
  const ControllerStateCommitPlan({
    required super.changeSet,
    required super.initialPhases,
    required this.committedStoreState,
  });

  final CommittedStoreState committedStoreState;
}
