import '../contract/node_patch.dart';
import '../core/nodes.dart';
import 'document_node_patch_common.dart';

bool txnApplyImageNodePatch(
  ImageNode image,
  ImageNodePatch patch, {
  required bool dryRun,
}) {
  return txnApplyPatchPlan(
    image,
    patch,
    _imagePatchAssignments,
    dryRun: dryRun,
  );
}

final List<TxnPatchAssignment<ImageNode, ImageNodePatch>>
_imagePatchAssignments = <TxnPatchAssignment<ImageNode, ImageNodePatch>>[
  txnPatchValueAssignment(
    patchField: (patch) => patch.imageId,
    currentValue: (node) => node.imageId,
    assign: (node, value) => node.imageId = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.size,
    currentValue: (node) => node.size,
    assign: (node, value) => node.size = value,
  ),
  txnPatchNullableValueAssignment(
    patchField: (patch) => patch.naturalSize,
    currentValue: (node) => node.naturalSize,
    assign: (node, value) => node.naturalSize = value,
  ),
];
