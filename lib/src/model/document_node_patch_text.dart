import '../contract/node_patch.dart';
import '../core/nodes.dart';
import 'document_node_patch_common.dart';

bool txnApplyTextNodePatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  var changed = _txnApplyTextContentPatch(text, patch, dryRun: dryRun);
  changed =
      _txnApplyTextLayoutStylePatch(text, patch, dryRun: dryRun) || changed;
  return changed;
}

bool _txnApplyTextContentPatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  return txnApplyPatchPlan(
    text,
    patch,
    _textContentPatchAssignments,
    dryRun: dryRun,
  );
}

bool _txnApplyTextLayoutStylePatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  return txnApplyPatchPlan(
    text,
    patch,
    _textLayoutPatchAssignments,
    dryRun: dryRun,
  );
}

final List<TxnPatchAssignment<TextNode, TextNodePatch>>
_textContentPatchAssignments = <TxnPatchAssignment<TextNode, TextNodePatch>>[
  txnPatchValueAssignment(
    patchField: (patch) => patch.text,
    currentValue: (node) => node.text,
    assign: (node, value) => node.text = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.fontSize,
    currentValue: (node) => node.fontSize,
    assign: (node, value) => node.fontSize = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.color,
    currentValue: (node) => node.color,
    assign: (node, value) => node.color = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.align,
    currentValue: (node) => node.align,
    assign: (node, value) => node.align = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.textDirection,
    currentValue: (node) => node.textDirection,
    assign: (node, value) => node.textDirection = value,
  ),
];

final List<TxnPatchAssignment<TextNode, TextNodePatch>>
_textLayoutPatchAssignments = <TxnPatchAssignment<TextNode, TextNodePatch>>[
  txnPatchValueAssignment(
    patchField: (patch) => patch.isBold,
    currentValue: (node) => node.isBold,
    assign: (node, value) => node.isBold = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.isItalic,
    currentValue: (node) => node.isItalic,
    assign: (node, value) => node.isItalic = value,
  ),
  txnPatchValueAssignment(
    patchField: (patch) => patch.isUnderline,
    currentValue: (node) => node.isUnderline,
    assign: (node, value) => node.isUnderline = value,
  ),
  txnPatchNullableValueAssignment(
    patchField: (patch) => patch.fontFamily,
    currentValue: (node) => node.fontFamily,
    assign: (node, value) => node.fontFamily = value,
  ),
  txnPatchNullableValueAssignment(
    patchField: (patch) => patch.maxWidth,
    currentValue: (node) => node.maxWidth,
    assign: (node, value) => node.maxWidth = value,
  ),
  txnPatchNullableValueAssignment(
    patchField: (patch) => patch.lineHeight,
    currentValue: (node) => node.lineHeight,
    assign: (node, value) => node.lineHeight = value,
  ),
];
