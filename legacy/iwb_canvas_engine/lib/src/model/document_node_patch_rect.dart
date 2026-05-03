import '../contract/node_patch.dart';
import '../core/nodes.dart';
import 'document_node_patch_common.dart';

bool txnApplyRectNodePatch(
  RectNode rect,
  RectNodePatch patch, {
  required bool dryRun,
}) {
  return txnApplyPatchPlan(rect, patch, _rectPatchAssignments, dryRun: dryRun);
}

final List<TxnPatchAssignment<RectNode, RectNodePatch>> _rectPatchAssignments =
    <TxnPatchAssignment<RectNode, RectNodePatch>>[
      txnPatchValueAssignment(
        patchField: (patch) => patch.size,
        currentValue: (node) => node.size,
        assign: (node, value) => node.size = value,
      ),
      txnPatchNullableValueAssignment(
        patchField: (patch) => patch.fillColor,
        currentValue: (node) => node.fillColor,
        assign: (node, value) => node.fillColor = value,
      ),
      txnPatchNullableValueAssignment(
        patchField: (patch) => patch.strokeColor,
        currentValue: (node) => node.strokeColor,
        assign: (node, value) => node.strokeColor = value,
      ),
      txnPatchValueAssignment(
        patchField: (patch) => patch.strokeWidth,
        currentValue: (node) => node.strokeWidth,
        assign: (node, value) => node.strokeWidth = value,
      ),
    ];
