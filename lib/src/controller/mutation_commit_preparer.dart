import 'dart:collection';

import '../contract/ids.dart';
import 'mutation_op.dart';
import 'txn_context.dart';

MutationPreparedCommitResult prepareMutationPreparedCommitResult(
  TxnContext ctx,
) {
  ctx.txnEnsureActive();
  return MutationPreparedCommitResult(
    changeSet: ctx.changeSet.txnClone(),
    commitCandidate: _prepareMutationCommitCandidate(ctx),
  );
}

MutationCommitCandidate? _prepareMutationCommitCandidate(TxnContext ctx) {
  if (!ctx.changeSet.txnHasAnyChange) {
    return null;
  }
  return MutationCommitCandidate(
    scene: ctx.txnSceneForCommit(),
    selection: HashSet<NodeId>.of(ctx.workingSelection),
    allNodeIds: ctx.txnAllNodeIdsForCommit(
      structuralChanged: ctx.changeSet.structuralChanged,
    ),
    nodeLocator: ctx.txnNodeLocatorForCommit(
      structuralChanged: ctx.changeSet.structuralChanged,
    ),
    idGeneratorState: ctx.idGeneratorState.copy(),
    revisionState: ctx.revisionState.copy(),
  );
}
