import 'dart:ui';

import '../core/transform2d.dart';
import 'patch_field.dart';
import 'snapshot.dart';

/// Patch for common node fields shared by all node variants.
class CommonNodePatch {
  const CommonNodePatch({
    this.transform = const PatchField<Transform2D>.absent(),
    this.opacity = const PatchField<double>.absent(),
    this.hitPadding = const PatchField<double>.absent(),
    this.isVisible = const PatchField<bool>.absent(),
    this.isSelectable = const PatchField<bool>.absent(),
    this.isLocked = const PatchField<bool>.absent(),
    this.isDeletable = const PatchField<bool>.absent(),
    this.isTransformable = const PatchField<bool>.absent(),
  });

  final PatchField<Transform2D> transform;
  final PatchField<double> opacity;
  final PatchField<double> hitPadding;
  final PatchField<bool> isVisible;
  final PatchField<bool> isSelectable;
  final PatchField<bool> isLocked;
  final PatchField<bool> isDeletable;
  final PatchField<bool> isTransformable;
}

/// Partial node update request for v2 write APIs.
sealed class NodePatch {
  const NodePatch({required this.id, CommonNodePatch? common})
    : common = common ?? const CommonNodePatch();

  final NodeId id;
  final CommonNodePatch common;
}

class ImageNodePatch extends NodePatch {
  const ImageNodePatch({
    required super.id,
    super.common,
    this.imageId = const PatchField<String>.absent(),
    this.size = const PatchField<Size>.absent(),
    this.naturalSize = const PatchField<Size?>.absent(),
  });

  final PatchField<String> imageId;
  final PatchField<Size> size;
  final PatchField<Size?> naturalSize;
}

class TextNodePatch extends NodePatch {
  const TextNodePatch({
    required super.id,
    super.common,
    this.text = const PatchField<String>.absent(),
    this.fontSize = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
    this.align = const PatchField<TextAlign>.absent(),
    this.isBold = const PatchField<bool>.absent(),
    this.isItalic = const PatchField<bool>.absent(),
    this.isUnderline = const PatchField<bool>.absent(),
    this.fontFamily = const PatchField<String?>.absent(),
    this.maxWidth = const PatchField<double?>.absent(),
    this.lineHeight = const PatchField<double?>.absent(),
  });

  final PatchField<String> text;
  final PatchField<double> fontSize;
  final PatchField<Color> color;
  final PatchField<TextAlign> align;
  final PatchField<bool> isBold;
  final PatchField<bool> isItalic;
  final PatchField<bool> isUnderline;
  final PatchField<String?> fontFamily;
  final PatchField<double?> maxWidth;
  final PatchField<double?> lineHeight;
}

class StrokeNodePatch extends NodePatch {
  const StrokeNodePatch({
    required super.id,
    super.common,
    this.points = const PatchField<List<Offset>>.absent(),
    this.thickness = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
  });

  final PatchField<List<Offset>> points;
  final PatchField<double> thickness;
  final PatchField<Color> color;
}

class LineNodePatch extends NodePatch {
  const LineNodePatch({
    required super.id,
    super.common,
    this.start = const PatchField<Offset>.absent(),
    this.end = const PatchField<Offset>.absent(),
    this.thickness = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
  });

  final PatchField<Offset> start;
  final PatchField<Offset> end;
  final PatchField<double> thickness;
  final PatchField<Color> color;
}

class RectNodePatch extends NodePatch {
  const RectNodePatch({
    required super.id,
    super.common,
    this.size = const PatchField<Size>.absent(),
    this.fillColor = const PatchField<Color?>.absent(),
    this.strokeColor = const PatchField<Color?>.absent(),
    this.strokeWidth = const PatchField<double>.absent(),
  });

  final PatchField<Size> size;
  final PatchField<Color?> fillColor;
  final PatchField<Color?> strokeColor;
  final PatchField<double> strokeWidth;
}

class PathNodePatch extends NodePatch {
  const PathNodePatch({
    required super.id,
    super.common,
    this.svgPathData = const PatchField<String>.absent(),
    this.fillColor = const PatchField<Color?>.absent(),
    this.strokeColor = const PatchField<Color?>.absent(),
    this.strokeWidth = const PatchField<double>.absent(),
    this.fillRule = const PatchField<V2PathFillRule>.absent(),
  });

  final PatchField<String> svgPathData;
  final PatchField<Color?> fillColor;
  final PatchField<Color?> strokeColor;
  final PatchField<double> strokeWidth;
  final PatchField<V2PathFillRule> fillRule;
}
