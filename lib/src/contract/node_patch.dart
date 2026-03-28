import 'dart:ui';

import 'internal/node_boundary_schema.dart';
import 'patch_field.dart';
import 'path_fill_rule.dart';
import 'snapshot.dart' hide PathFillRule;
import 'transform2d.dart';

/// Patch for common node fields shared by all node variants.
class CommonNodePatch {
  factory CommonNodePatch({
    PatchField<Transform2D> transform = const PatchField<Transform2D>.absent(),
    PatchField<double> opacity = const PatchField<double>.absent(),
    PatchField<double> hitPadding = const PatchField<double>.absent(),
    PatchField<bool> isVisible = const PatchField<bool>.absent(),
    PatchField<bool> isSelectable = const PatchField<bool>.absent(),
    PatchField<bool> isLocked = const PatchField<bool>.absent(),
    PatchField<bool> isDeletable = const PatchField<bool>.absent(),
    PatchField<bool> isTransformable = const PatchField<bool>.absent(),
  }) {
    final fields = validatePatchCommonSchemaFields((
      transform: transform,
      opacity: opacity,
      hitPadding: hitPadding,
      isVisible: isVisible,
      isSelectable: isSelectable,
      isLocked: isLocked,
      isDeletable: isDeletable,
      isTransformable: isTransformable,
    ));
    return CommonNodePatch._validated(fields: fields);
  }

  factory CommonNodePatch._validated({NodePatchCommonSchemaFields? fields}) {
    final resolved = patchCommonSchemaFieldsFromValidated(
      fields ?? _defaultNodePatchCommonSchemaFields(),
    );
    return CommonNodePatch._internal(
      transform: resolved.transform,
      opacity: resolved.opacity,
      hitPadding: resolved.hitPadding,
      isVisible: resolved.isVisible,
      isSelectable: resolved.isSelectable,
      isLocked: resolved.isLocked,
      isDeletable: resolved.isDeletable,
      isTransformable: resolved.isTransformable,
    );
  }

  const CommonNodePatch._internal({
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

/// Partial node update request for transactional write APIs.
sealed class NodePatch {
  const NodePatch._internal({required this.id, required this.common});

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
    required NodeId id,
    required CommonNodePatch common,
    required ImageNodePatchSchemaFields fields,
  }) : this._internal(
         id: id,
         common: common,
         imageId: fields.imageId,
         size: fields.size,
         naturalSize: fields.naturalSize,
       );

  const ImageNodePatch._internal({
    required super.id,
    required super.common,
    this.imageId = const PatchField<String>.absent(),
    this.size = const PatchField<Size>.absent(),
    this.naturalSize = const PatchField<Size?>.absent(),
  }) : super._internal();

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
           isBold: isBold,
           isItalic: isItalic,
           isUnderline: isUnderline,
           fontFamily: fontFamily,
           maxWidth: maxWidth,
           lineHeight: lineHeight,
         )),
       );

  TextNodePatch._validated({
    required NodeId id,
    required CommonNodePatch common,
    required TextNodePatchSchemaFields fields,
  }) : this._internal(
         id: id,
         common: common,
         text: fields.text,
         fontSize: fields.fontSize,
         color: fields.color,
         align: fields.align,
         isBold: fields.isBold,
         isItalic: fields.isItalic,
         isUnderline: fields.isUnderline,
         fontFamily: fields.fontFamily,
         maxWidth: fields.maxWidth,
         lineHeight: fields.lineHeight,
       );

  const TextNodePatch._internal({
    required super.id,
    required super.common,
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
  }) : super._internal();

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
    required NodeId id,
    required CommonNodePatch common,
    required StrokeNodePatchSchemaFields fields,
  }) : this._internal(
         id: id,
         common: common,
         points: fields.points,
         thickness: fields.thickness,
         color: fields.color,
       );

  StrokeNodePatch._internal({
    required super.id,
    required super.common,
    PatchField<List<Offset>> points = const PatchField<List<Offset>>.absent(),
    this.thickness = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
  }) : points = snapshotOffsetListPatchField(points),
       super._internal();

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
    required NodeId id,
    required CommonNodePatch common,
    required LineNodePatchSchemaFields fields,
  }) : this._internal(
         id: id,
         common: common,
         start: fields.start,
         end: fields.end,
         thickness: fields.thickness,
         color: fields.color,
       );

  const LineNodePatch._internal({
    required super.id,
    required super.common,
    this.start = const PatchField<Offset>.absent(),
    this.end = const PatchField<Offset>.absent(),
    this.thickness = const PatchField<double>.absent(),
    this.color = const PatchField<Color>.absent(),
  }) : super._internal();

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
    required NodeId id,
    required CommonNodePatch common,
    required RectNodePatchSchemaFields fields,
  }) : this._internal(
         id: id,
         common: common,
         size: fields.size,
         fillColor: fields.fillColor,
         strokeColor: fields.strokeColor,
         strokeWidth: fields.strokeWidth,
       );

  const RectNodePatch._internal({
    required super.id,
    required super.common,
    this.size = const PatchField<Size>.absent(),
    this.fillColor = const PatchField<Color?>.absent(),
    this.strokeColor = const PatchField<Color?>.absent(),
    this.strokeWidth = const PatchField<double>.absent(),
  }) : super._internal();

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
    required NodeId id,
    required CommonNodePatch common,
    required PathNodePatchSchemaFields fields,
  }) : this._internal(
         id: id,
         common: common,
         svgPathData: fields.svgPathData,
         fillColor: fields.fillColor,
         strokeColor: fields.strokeColor,
         strokeWidth: fields.strokeWidth,
         fillRule: fields.fillRule,
       );

  const PathNodePatch._internal({
    required super.id,
    required super.common,
    this.svgPathData = const PatchField<String>.absent(),
    this.fillColor = const PatchField<Color?>.absent(),
    this.strokeColor = const PatchField<Color?>.absent(),
    this.strokeWidth = const PatchField<double>.absent(),
    this.fillRule = const PatchField<PathFillRule>.absent(),
  }) : super._internal();

  final PatchField<String> svgPathData;
  final PatchField<Color?> fillColor;
  final PatchField<Color?> strokeColor;
  final PatchField<double> strokeWidth;
  final PatchField<PathFillRule> fillRule;
}

NodePatchCommonSchemaFields _defaultNodePatchCommonSchemaFields() => (
  transform: const PatchField<Transform2D>.absent(),
  opacity: const PatchField<double>.absent(),
  hitPadding: const PatchField<double>.absent(),
  isVisible: const PatchField<bool>.absent(),
  isSelectable: const PatchField<bool>.absent(),
  isLocked: const PatchField<bool>.absent(),
  isDeletable: const PatchField<bool>.absent(),
  isTransformable: const PatchField<bool>.absent(),
);
