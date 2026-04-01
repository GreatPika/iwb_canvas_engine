import 'dart:ui';

import 'internal/node_boundary_schema.dart';
import 'patch_field.dart';
import 'path_fill_rule.dart';
import 'snapshot.dart' hide PathFillRule;
import 'transform2d.dart';

/// Patch for common node fields shared by all node variants.
class CommonNodePatch {
  CommonNodePatch({
    PatchField<Transform2D> transform = const PatchField<Transform2D>.absent(),
    PatchField<double> opacity = const PatchField<double>.absent(),
    PatchField<double> hitPadding = const PatchField<double>.absent(),
    PatchField<bool> isVisible = const PatchField<bool>.absent(),
    PatchField<bool> isSelectable = const PatchField<bool>.absent(),
    PatchField<bool> isLocked = const PatchField<bool>.absent(),
    PatchField<bool> isDeletable = const PatchField<bool>.absent(),
    PatchField<bool> isTransformable = const PatchField<bool>.absent(),
  }) : this._validated(
         fields: validatePatchCommonSchemaFields((
           transform: transform,
           opacity: opacity,
           hitPadding: hitPadding,
           isVisible: isVisible,
           isSelectable: isSelectable,
           isLocked: isLocked,
           isDeletable: isDeletable,
           isTransformable: isTransformable,
         )),
       );

  CommonNodePatch._validated({NodePatchCommonSchemaFields? fields})
    : transform = fields?.transform ?? const PatchField<Transform2D>.absent(),
      opacity = fields?.opacity ?? const PatchField<double>.absent(),
      hitPadding = fields?.hitPadding ?? const PatchField<double>.absent(),
      isVisible = fields?.isVisible ?? const PatchField<bool>.absent(),
      isSelectable = fields?.isSelectable ?? const PatchField<bool>.absent(),
      isLocked = fields?.isLocked ?? const PatchField<bool>.absent(),
      isDeletable = fields?.isDeletable ?? const PatchField<bool>.absent(),
      isTransformable =
          fields?.isTransformable ?? const PatchField<bool>.absent();

  final PatchField<Transform2D> transform;
  final PatchField<double> opacity;
  final PatchField<double> hitPadding;
  final PatchField<bool> isVisible;
  final PatchField<bool> isSelectable;
  final PatchField<bool> isLocked;
  final PatchField<bool> isDeletable;
  final PatchField<bool> isTransformable;
}

/// Partial node update request for transactional write APIs.
abstract class NodePatch {
  const NodePatch({required this.id, required this.common});

  final NodeId id;
  final CommonNodePatch common;
}

class ImageNodePatch extends NodePatch {
  ImageNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<String> imageId = const PatchField<String>.absent(),
    PatchField<Size> size = const PatchField<Size>.absent(),
    PatchField<Size?> naturalSize = const PatchField<Size?>.absent(),
  }) : this._validated(
         id: validateRequiredNodeId(id),
         common: common ?? CommonNodePatch._validated(),
         fields: validateImageNodePatchSchemaFields((
           imageId: imageId,
           size: size,
           naturalSize: naturalSize,
         )),
       );

  ImageNodePatch._validated({
    required super.id,
    required super.common,
    required ImageNodePatchSchemaFields fields,
  }) : imageId = fields.imageId,
       size = fields.size,
       naturalSize = fields.naturalSize,
       super();

  final PatchField<String> imageId;
  final PatchField<Size> size;
  final PatchField<Size?> naturalSize;
}

class TextNodePatch extends NodePatch {
  TextNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<String> text = const PatchField<String>.absent(),
    PatchField<double> fontSize = const PatchField<double>.absent(),
    PatchField<Color> color = const PatchField<Color>.absent(),
    PatchField<TextAlign> align = const PatchField<TextAlign>.absent(),
    PatchField<TextDirection> textDirection =
        const PatchField<TextDirection>.absent(),
    PatchField<bool> isBold = const PatchField<bool>.absent(),
    PatchField<bool> isItalic = const PatchField<bool>.absent(),
    PatchField<bool> isUnderline = const PatchField<bool>.absent(),
    PatchField<String?> fontFamily = const PatchField<String?>.absent(),
    PatchField<double?> maxWidth = const PatchField<double?>.absent(),
    PatchField<double?> lineHeight = const PatchField<double?>.absent(),
  }) : this._validated(
         id: validateRequiredNodeId(id),
         common: common ?? CommonNodePatch._validated(),
         fields: validateTextNodePatchSchemaFields((
           text: text,
           fontSize: fontSize,
           color: color,
           align: align,
           textDirection: textDirection,
           isBold: isBold,
           isItalic: isItalic,
           isUnderline: isUnderline,
           fontFamily: fontFamily,
           maxWidth: maxWidth,
           lineHeight: lineHeight,
         )),
       );

  TextNodePatch._validated({
    required super.id,
    required super.common,
    required TextNodePatchSchemaFields fields,
  }) : text = fields.text,
       fontSize = fields.fontSize,
       color = fields.color,
       align = fields.align,
       textDirection = fields.textDirection,
       isBold = fields.isBold,
       isItalic = fields.isItalic,
       isUnderline = fields.isUnderline,
       fontFamily = fields.fontFamily,
       maxWidth = fields.maxWidth,
       lineHeight = fields.lineHeight,
       super();

  final PatchField<String> text;
  final PatchField<double> fontSize;
  final PatchField<Color> color;
  final PatchField<TextAlign> align;
  final PatchField<TextDirection> textDirection;
  final PatchField<bool> isBold;
  final PatchField<bool> isItalic;
  final PatchField<bool> isUnderline;
  final PatchField<String?> fontFamily;
  final PatchField<double?> maxWidth;
  final PatchField<double?> lineHeight;
}

class StrokeNodePatch extends NodePatch {
  StrokeNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<List<Offset>> points = const PatchField<List<Offset>>.absent(),
    PatchField<double> thickness = const PatchField<double>.absent(),
    PatchField<Color> color = const PatchField<Color>.absent(),
  }) : this._validated(
         id: validateRequiredNodeId(id),
         common: common ?? CommonNodePatch._validated(),
         fields: validateStrokeNodePatchSchemaFields((
           points: points,
           thickness: thickness,
           color: color,
         )),
       );

  StrokeNodePatch._validated({
    required super.id,
    required super.common,
    required StrokeNodePatchSchemaFields fields,
  }) : points = fields.points,
       thickness = fields.thickness,
       color = fields.color,
       super();

  final PatchField<List<Offset>> points;
  final PatchField<double> thickness;
  final PatchField<Color> color;
}

class LineNodePatch extends NodePatch {
  LineNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<Offset> start = const PatchField<Offset>.absent(),
    PatchField<Offset> end = const PatchField<Offset>.absent(),
    PatchField<double> thickness = const PatchField<double>.absent(),
    PatchField<Color> color = const PatchField<Color>.absent(),
  }) : this._validated(
         id: validateRequiredNodeId(id),
         common: common ?? CommonNodePatch._validated(),
         fields: validateLineNodePatchSchemaFields((
           start: start,
           end: end,
           thickness: thickness,
           color: color,
         )),
       );

  LineNodePatch._validated({
    required super.id,
    required super.common,
    required LineNodePatchSchemaFields fields,
  }) : start = fields.start,
       end = fields.end,
       thickness = fields.thickness,
       color = fields.color,
       super();

  final PatchField<Offset> start;
  final PatchField<Offset> end;
  final PatchField<double> thickness;
  final PatchField<Color> color;
}

class RectNodePatch extends NodePatch {
  RectNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<Size> size = const PatchField<Size>.absent(),
    PatchField<Color?> fillColor = const PatchField<Color?>.absent(),
    PatchField<Color?> strokeColor = const PatchField<Color?>.absent(),
    PatchField<double> strokeWidth = const PatchField<double>.absent(),
  }) : this._validated(
         id: validateRequiredNodeId(id),
         common: common ?? CommonNodePatch._validated(),
         fields: validateRectNodePatchSchemaFields((
           size: size,
           fillColor: fillColor,
           strokeColor: strokeColor,
           strokeWidth: strokeWidth,
         )),
       );

  RectNodePatch._validated({
    required super.id,
    required super.common,
    required RectNodePatchSchemaFields fields,
  }) : size = fields.size,
       fillColor = fields.fillColor,
       strokeColor = fields.strokeColor,
       strokeWidth = fields.strokeWidth,
       super();

  final PatchField<Size> size;
  final PatchField<Color?> fillColor;
  final PatchField<Color?> strokeColor;
  final PatchField<double> strokeWidth;
}

class PathNodePatch extends NodePatch {
  PathNodePatch({
    required NodeId id,
    CommonNodePatch? common,
    PatchField<String> svgPathData = const PatchField<String>.absent(),
    PatchField<Color?> fillColor = const PatchField<Color?>.absent(),
    PatchField<Color?> strokeColor = const PatchField<Color?>.absent(),
    PatchField<double> strokeWidth = const PatchField<double>.absent(),
    PatchField<PathFillRule> fillRule = const PatchField<PathFillRule>.absent(),
  }) : this._validated(
         id: validateRequiredNodeId(id),
         common: common ?? CommonNodePatch._validated(),
         fields: validatePathNodePatchSchemaFields((
           svgPathData: svgPathData,
           fillColor: fillColor,
           strokeColor: strokeColor,
           strokeWidth: strokeWidth,
           fillRule: fillRule,
         )),
       );

  PathNodePatch._validated({
    required super.id,
    required super.common,
    required PathNodePatchSchemaFields fields,
  }) : svgPathData = fields.svgPathData,
       fillColor = fields.fillColor,
       strokeColor = fields.strokeColor,
       strokeWidth = fields.strokeWidth,
       fillRule = fields.fillRule,
       super();

  final PatchField<String> svgPathData;
  final PatchField<Color?> fillColor;
  final PatchField<Color?> strokeColor;
  final PatchField<double> strokeWidth;
  final PatchField<PathFillRule> fillRule;
}
