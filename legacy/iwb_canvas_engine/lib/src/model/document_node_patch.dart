import '../contract/node_patch.dart';
import '../core/nodes.dart';
import 'document_node_patch_common.dart';
import 'document_node_patch_image.dart';
import 'document_node_patch_line.dart';
import 'document_node_patch_path.dart';
import 'document_node_patch_rect.dart';
import 'document_node_patch_stroke.dart';
import 'document_node_patch_text.dart';

bool txnApplyNodePatch(SceneNode node, NodePatch patch, {bool dryRun = false}) {
  txnValidatePatchTargetRuntimeSemantics(node: node, patch: patch);

  var changed = txnApplyCommonNodePatch(node, patch.common, dryRun: dryRun);
  changed = _txnApplyTypedNodePatch(node, patch, dryRun: dryRun) || changed;
  return changed;
}

enum _TxnPatchTargetKind { image, text, stroke, line, rect, path }

void txnValidatePatchTargetRuntimeSemantics({
  required SceneNode node,
  required NodePatch patch,
}) {
  if (node.id != patch.id) {
    throw ArgumentError.value(
      patch.id,
      'patch.id',
      'NodePatch id does not match target node id ${node.id}.',
    );
  }

  final kind = switch ((node, patch)) {
    (ImageNode _, ImageNodePatch _) => _TxnPatchTargetKind.image,
    (TextNode _, TextNodePatch _) => _TxnPatchTargetKind.text,
    (StrokeNode _, StrokeNodePatch _) => _TxnPatchTargetKind.stroke,
    (LineNode _, LineNodePatch _) => _TxnPatchTargetKind.line,
    (RectNode _, RectNodePatch _) => _TxnPatchTargetKind.rect,
    (PathNode _, PathNodePatch _) => _TxnPatchTargetKind.path,
    _ => null,
  };
  if (kind != null) {
    return;
  }

  throw ArgumentError(
    'Patch type ${patch.runtimeType} does not match node ${node.runtimeType}.',
  );
}

bool _txnApplyTypedNodePatch(
  SceneNode node,
  NodePatch patch, {
  required bool dryRun,
}) {
  return switch ((node, patch)) {
    (ImageNode image, ImageNodePatch imagePatch) => txnApplyImageNodePatch(
      image,
      imagePatch,
      dryRun: dryRun,
    ),
    (TextNode text, TextNodePatch textPatch) => txnApplyTextNodePatch(
      text,
      textPatch,
      dryRun: dryRun,
    ),
    (StrokeNode stroke, StrokeNodePatch strokePatch) => txnApplyStrokeNodePatch(
      stroke,
      strokePatch,
      dryRun: dryRun,
    ),
    (LineNode line, LineNodePatch linePatch) => txnApplyLineNodePatch(
      line,
      linePatch,
      dryRun: dryRun,
    ),
    (RectNode rect, RectNodePatch rectPatch) => txnApplyRectNodePatch(
      rect,
      rectPatch,
      dryRun: dryRun,
    ),
    (PathNode path, PathNodePatch pathPatch) => txnApplyPathNodePatch(
      path,
      pathPatch,
      dryRun: dryRun,
    ),
    _ => false,
  };
}
