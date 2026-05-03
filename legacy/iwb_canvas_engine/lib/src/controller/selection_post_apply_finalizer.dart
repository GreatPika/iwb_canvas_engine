import '../contract/ids.dart';
import '../model/document.dart';
import 'txn_context.dart';

void finalizePostApplySelection(TxnContext ctx) {
  final normalizedSelection = txnNormalizeSelection(
    rawSelection: ctx.workingSelection,
    scene: ctx.workingScene,
    nodeLocator: ctx.txnNodeLocatorView(),
    layerIndexById: ctx.txnLayerIndexByIdView(),
  );
  if (_selectionSetsEqual(ctx.workingSelection, normalizedSelection)) {
    return;
  }

  ctx.workingSelection
    ..clear()
    ..addAll(normalizedSelection);
  ctx.changeSet.txnMarkSelectionChanged();
}

bool _selectionSetsEqual(Set<NodeId> left, Set<NodeId> right) {
  return left.length == right.length && left.containsAll(right);
}
