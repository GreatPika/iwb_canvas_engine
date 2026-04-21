import '../contract/node_patch.dart';
import '../core/nodes.dart';
import 'document_node_patch_common.dart';

bool txnApplyPathNodePatch(
  PathNode path,
  PathNodePatch patch, {
  required bool dryRun,
}) {
  return txnApplyPatchPlan(path, patch, _pathPatchAssignments, dryRun: dryRun);
}

final List<TxnPatchAssignment<PathNode, PathNodePatch>> _pathPatchAssignments =
    <TxnPatchAssignment<PathNode, PathNodePatch>>[
      txnPatchValueAssignment(
        patchField: (patch) => patch.svgPathData,
        currentValue: (node) => node.svgPathData,
        assign: (node, value) => node.svgPathData = value,
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
      txnPatchValueAssignment(
        patchField: (patch) => patch.fillRule,
        currentValue: (node) => node.fillRule,
        assign: (node, value) => node.fillRule = value,
      ),
    ];
