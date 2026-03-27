import '../contract/node_patch.dart';
import '../core/nodes.dart';
import 'document_node_patch_common.dart';

bool txnApplyLineNodePatch(
  LineNode line,
  LineNodePatch patch, {
  required bool dryRun,
}) {
  return txnApplyPatchPlan(line, patch, _linePatchAssignments, dryRun: dryRun);
}

final List<TxnPatchAssignment<LineNode, LineNodePatch>> _linePatchAssignments =
    <TxnPatchAssignment<LineNode, LineNodePatch>>[
      txnPatchValueAssignment(
        patchField: (patch) => patch.start,
        currentValue: (node) => node.start,
        assign: (node, value) => node.start = value,
      ),
      txnPatchValueAssignment(
        patchField: (patch) => patch.end,
        currentValue: (node) => node.end,
        assign: (node, value) => node.end = value,
      ),
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
