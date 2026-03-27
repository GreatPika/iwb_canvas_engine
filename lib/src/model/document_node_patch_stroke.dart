import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/owned_collections.dart';
import '../contract/patch_field.dart';
import '../core/nodes.dart';
import 'document_node_patch_common.dart';

bool txnApplyStrokeNodePatch(
  StrokeNode stroke,
  StrokeNodePatch patch, {
  required bool dryRun,
}) {
  var changed = _txnApplyStrokePointsPatch(
    stroke,
    patch.points,
    dryRun: dryRun,
  );
  changed =
      txnApplyPatchPlan(
        stroke,
        patch,
        _strokeStylePatchAssignments,
        dryRun: dryRun,
      ) ||
      changed;
  return changed;
}

bool _txnApplyStrokePointsPatch(
  StrokeNode stroke,
  PatchField<List<Offset>> patch, {
  required bool dryRun,
}) {
  if (patch.isAbsent) {
    return false;
  }
  final next = patch.value as OwnedList<Offset>;
  if (!_txnHasDifferentStrokePoints(next, stroke.points)) {
    return false;
  }
  if (!dryRun) {
    stroke.points.replaceRange(0, stroke.points.length, next);
  }
  return true;
}

bool _txnHasDifferentStrokePoints(
  OwnedList<Offset> next,
  List<Offset> current,
) {
  if (next.length != current.length) {
    return true;
  }
  for (var index = 0; index < current.length; index++) {
    if (next[index] != current[index]) {
      return true;
    }
  }
  return false;
}

final List<TxnPatchAssignment<StrokeNode, StrokeNodePatch>>
_strokeStylePatchAssignments =
    <TxnPatchAssignment<StrokeNode, StrokeNodePatch>>[
      txnPatchValueAssignment(
        patchField: (patch) => patch.thickness,
        currentValue: (node) => node.thickness,
        assign: (node, value) => node.thickness = value,
      ),
      txnPatchValueAssignment(
        patchField: (patch) => patch.color,
        currentValue: (node) => node.color,
        assign: (node, value) => node.color = value,
      ),
    ];
