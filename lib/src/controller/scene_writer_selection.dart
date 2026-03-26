import 'dart:collection';

import '../core/nodes.dart';
import '../core/selection_policy.dart';
import '../model/document.dart';
import 'txn_context.dart';
import 'mutation_op.dart';
import 'scene_writer.dart';
import 'scene_writer_support.dart';

List<NodeId>? sceneWriterWriteSelectionReplaceResult(
  SceneWriter writer,
  Iterable<NodeId> ids,
) {
  writer.runtime.ensureTxnActive();
  final ctx = writer.runtime.ctx;
  final nextSelection = txnNormalizeSelection(
    rawSelection: ids.toSet(),
    scene: ctx.workingScene,
    nodeLocator: ctx.txnNodeLocatorView(),
  );
  if (nextSelection.isEmpty ||
      _sceneWriterSetsEqual(ctx.workingSelection, nextSelection)) {
    return null;
  }
  _sceneWriterReplaceSelection(writer, nextSelection);
  return sortWriterNodeIds(ctx.workingSelection);
}

bool sceneWriterWriteSelectionToggle(SceneWriter writer, NodeId id) {
  writer.runtime.ensureTxnActive();
  final ctx = writer.runtime.ctx;
  if (!txnIsSelectionCandidateId(
    scene: ctx.workingScene,
    nodeId: id,
    nodeLocator: ctx.txnNodeLocatorView(),
  )) {
    return false;
  }
  if (ctx.workingSelection.contains(id)) {
    ctx.workingSelection.remove(id);
  } else {
    ctx.workingSelection.add(id);
  }
  ctx.changeSet.txnMarkSelectionChanged();
  return true;
}

bool sceneWriterWriteSelectionClear(SceneWriter writer) {
  writer.runtime.ensureTxnActive();
  final selection = writer.runtime.ctx.workingSelection;
  if (selection.isEmpty) {
    return false;
  }
  selection.clear();
  writer.runtime.ctx.changeSet.txnMarkSelectionChanged();
  return true;
}

({int selectedCount, bool changed}) sceneWriterWriteSelectionSelectAllResult(
  SceneWriter writer, {
  bool onlySelectable = true,
}) {
  writer.runtime.ensureTxnActive();
  final ctx = writer.runtime.ctx;
  final targetSelection = HashSet<NodeId>();
  for (final layer in ctx.workingScene.layers) {
    for (final node in layer.nodes) {
      if (isNodeInteractiveForSelection(node, onlySelectable: onlySelectable)) {
        targetSelection.add(node.id);
      }
    }
  }
  if (_sceneWriterSetsEqual(ctx.workingSelection, targetSelection)) {
    return (selectedCount: 0, changed: false);
  }
  _sceneWriterReplaceSelection(writer, targetSelection);
  return (selectedCount: targetSelection.length, changed: true);
}

List<NodeId> sceneWriterWriteDeleteSelectionResult(SceneWriter writer) {
  final removedIds = writer.runtime
      .execute(DeleteNodesBulkOp.borrowed(writer.runtime.ctx.workingSelection))
      .value;
  return sortWriterNodeIds(removedIds);
}

void _sceneWriterReplaceSelection(
  SceneWriter writer,
  Set<NodeId> nextSelection,
) {
  final ctx = writer.runtime.ctx;
  ctx.workingSelection
    ..clear()
    ..addAll(nextSelection);
  ctx.changeSet.txnMarkSelectionChanged();
}

bool _sceneWriterSetsEqual(Set<NodeId> left, Set<NodeId> right) {
  return left.length == right.length && left.containsAll(right);
}
