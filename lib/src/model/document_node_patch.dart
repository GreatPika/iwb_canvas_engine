import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/owned_collections.dart';
import '../contract/patch_field.dart';
import '../core/nodes.dart';
import '../core/text_layout.dart';

bool txnApplyNodePatch(SceneNode node, NodePatch patch, {bool dryRun = false}) {
  _txnValidatePatchTargetRuntimeSemantics(node: node, patch: patch);

  var changed = _txnApplyCommonPatch(node, patch.common, dryRun: dryRun);
  changed = _txnApplyTypedNodePatch(node, patch, dryRun: dryRun) || changed;
  return changed;
}

enum _TxnPatchTargetKind { image, text, stroke, line, rect, path }

_TxnPatchTargetKind _txnValidatePatchTargetRuntimeSemantics({
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
    return kind;
  }

  throw ArgumentError(
    'Patch type ${patch.runtimeType} does not match node ${node.runtimeType}.',
  );
}

bool _txnApplyCommonPatch(
  SceneNode node,
  CommonNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.transform, node.transform, (value) {
        node.transform = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.opacity, node.opacity, (value) {
        node.opacity = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.hitPadding, node.hitPadding, (value) {
        node.hitPadding = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isVisible, node.isVisible, (value) {
        node.isVisible = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isSelectable, node.isSelectable, (value) {
        node.isSelectable = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isLocked, node.isLocked, (value) {
        node.isLocked = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isDeletable, node.isDeletable, (value) {
        node.isDeletable = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isTransformable, node.isTransformable, (value) {
        node.isTransformable = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyTypedNodePatch(
  SceneNode node,
  NodePatch patch, {
  required bool dryRun,
}) {
  return switch ((node, patch)) {
    (ImageNode image, ImageNodePatch imagePatch) => _txnApplyImagePatch(
      image,
      imagePatch,
      dryRun: dryRun,
    ),
    (TextNode text, TextNodePatch textPatch) => _txnApplyTextPatch(
      text,
      textPatch,
      dryRun: dryRun,
    ),
    (StrokeNode stroke, StrokeNodePatch strokePatch) => _txnApplyStrokePatch(
      stroke,
      strokePatch,
      dryRun: dryRun,
    ),
    (LineNode line, LineNodePatch linePatch) => _txnApplyLinePatch(
      line,
      linePatch,
      dryRun: dryRun,
    ),
    (RectNode rect, RectNodePatch rectPatch) => _txnApplyRectPatch(
      rect,
      rectPatch,
      dryRun: dryRun,
    ),
    (PathNode path, PathNodePatch pathPatch) => _txnApplyPathPatch(
      path,
      pathPatch,
      dryRun: dryRun,
    ),
    _ => false,
  };
}

bool _txnApplyImagePatch(
  ImageNode image,
  ImageNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.imageId, image.imageId, (value) {
        image.imageId = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.size, image.size, (value) {
        image.size = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.naturalSize, image.naturalSize, (value) {
        image.naturalSize = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyTextPatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  var changed = _txnApplyTextContentPatch(text, patch, dryRun: dryRun);
  changed =
      _txnApplyTextLayoutStylePatch(text, patch, dryRun: dryRun) || changed;
  changed =
      _txnRecomputeTextSizeAfterPatch(text, patch, dryRun: dryRun) || changed;
  return changed;
}

bool _txnApplyStrokePatch(
  StrokeNode stroke,
  StrokeNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnApplyStrokePointsPatch(stroke, patch.points, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.thickness, stroke.thickness, (value) {
        stroke.thickness = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.color, stroke.color, (value) {
        stroke.color = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyLinePatch(
  LineNode line,
  LineNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.start, line.start, (value) {
        line.start = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.end, line.end, (value) {
        line.end = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.thickness, line.thickness, (value) {
        line.thickness = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.color, line.color, (value) {
        line.color = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyRectPatch(
  RectNode rect,
  RectNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.size, rect.size, (value) {
        rect.size = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.fillColor, rect.fillColor, (value) {
        rect.fillColor = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.strokeColor, rect.strokeColor, (value) {
        rect.strokeColor = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.strokeWidth, rect.strokeWidth, (value) {
        rect.strokeWidth = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyPathPatch(
  PathNode path,
  PathNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.svgPathData, path.svgPathData, (value) {
        path.svgPathData = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.fillColor, path.fillColor, (value) {
        path.fillColor = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.strokeColor, path.strokeColor, (value) {
        path.strokeColor = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.strokeWidth, path.strokeWidth, (value) {
        path.strokeWidth = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.fillRule, path.fillRule, (value) {
        path.fillRule = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyTextContentPatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.text, text.text, (value) {
        text.text = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.fontSize, text.fontSize, (value) {
        text.fontSize = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.color, text.color, (value) {
        text.color = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.align, text.align, (value) {
        text.align = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnApplyTextLayoutStylePatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  var changed = false;
  changed =
      _txnSet(patch.isBold, text.isBold, (value) {
        text.isBold = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isItalic, text.isItalic, (value) {
        text.isItalic = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSet(patch.isUnderline, text.isUnderline, (value) {
        text.isUnderline = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.fontFamily, text.fontFamily, (value) {
        text.fontFamily = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.maxWidth, text.maxWidth, (value) {
        text.maxWidth = value;
      }, dryRun: dryRun) ||
      changed;
  changed =
      _txnSetNullable(patch.lineHeight, text.lineHeight, (value) {
        text.lineHeight = value;
      }, dryRun: dryRun) ||
      changed;
  return changed;
}

bool _txnRecomputeTextSizeAfterPatch(
  TextNode text,
  TextNodePatch patch, {
  required bool dryRun,
}) {
  if (dryRun || !_txnTextPatchTouchesLayout(patch)) {
    return false;
  }
  final beforeSize = text.size;
  recomputeDerivedTextSize(text);
  return text.size != beforeSize;
}

bool _txnTextPatchTouchesLayout(TextNodePatch patch) {
  return !patch.text.isAbsent ||
      !patch.fontSize.isAbsent ||
      !patch.isBold.isAbsent ||
      !patch.isItalic.isAbsent ||
      !patch.isUnderline.isAbsent ||
      !patch.fontFamily.isAbsent ||
      !patch.lineHeight.isAbsent ||
      !patch.maxWidth.isAbsent;
}

bool _txnSet<T>(
  PatchField<T> patch,
  T current,
  void Function(T value) assign, {
  required bool dryRun,
}) {
  if (patch.isAbsent) {
    return false;
  }
  final next = patch.value;
  if (next == current) {
    return false;
  }
  if (!dryRun) {
    assign(next);
  }
  return true;
}

bool _txnSetNullable<T>(
  PatchField<T?> patch,
  T? current,
  void Function(T? value) assign, {
  required bool dryRun,
}) {
  if (patch.isAbsent) {
    return false;
  }
  final next = patch.isNullValue ? null : patch.value;
  if (next == current) {
    return false;
  }
  if (!dryRun) {
    assign(next);
  }
  return true;
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
