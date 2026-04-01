import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'internal/node_boundary_schema.dart';
import 'internal/node_patch_backing.dart';
import 'internal/node_patch_materialization.dart';
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
    return CommonNodePatch._validated(
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
  }

  factory CommonNodePatch._validated({NodePatchCommonSchemaFields? fields}) {
    return CommonNodePatch._materialized(
      commonNodePatchBackingFromValidated(fields: fields),
    );
  }

  @internal
  factory CommonNodePatch.materialize(CommonNodePatchBacking backing) =
      CommonNodePatch._materialized;

  const CommonNodePatch._materialized(this._backing);

  final CommonNodePatchBacking _backing;

  @internal
  CommonNodePatchBacking get internalBacking => _backing;

  PatchField<Transform2D> get transform => _backing.transform;
  PatchField<double> get opacity => _backing.opacity;
  PatchField<double> get hitPadding => _backing.hitPadding;
  PatchField<bool> get isVisible => _backing.isVisible;
  PatchField<bool> get isSelectable => _backing.isSelectable;
  PatchField<bool> get isLocked => _backing.isLocked;
  PatchField<bool> get isDeletable => _backing.isDeletable;
  PatchField<bool> get isTransformable => _backing.isTransformable;
}

/// Partial node update request for transactional write APIs.
sealed class NodePatch {
  NodePatch._materialized(this._backing);

  final NodePatchBacking _backing;

  @internal
  NodePatchBacking get internalBacking => _backing;

  late final CommonNodePatch _common = materializeCommonNodePatch(
    _backing.common,
  );

  NodeId get id => _backing.id;
  CommonNodePatch get common => _common;
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
  }) : this._materialized(
         imageNodePatchBackingFromValidated(
           id: id,
           common: common.internalBacking,
           fields: fields,
         ),
       );

  @internal
  factory ImageNodePatch.materialize(ImageNodePatchBacking backing) =
      ImageNodePatch._materialized;

  ImageNodePatch._materialized(super._backing) : super._materialized();

  ImageNodePatchBacking get _imageBacking =>
      internalBacking as ImageNodePatchBacking;

  PatchField<String> get imageId => _imageBacking.imageId;
  PatchField<Size> get size => _imageBacking.size;
  PatchField<Size?> get naturalSize => _imageBacking.naturalSize;
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
    required NodeId id,
    required CommonNodePatch common,
    required TextNodePatchSchemaFields fields,
  }) : this._materialized(
         textNodePatchBackingFromValidated(
           id: id,
           common: common.internalBacking,
           fields: fields,
         ),
       );

  @internal
  factory TextNodePatch.materialize(TextNodePatchBacking backing) =
      TextNodePatch._materialized;

  TextNodePatch._materialized(super._backing) : super._materialized();

  TextNodePatchBacking get _textBacking =>
      internalBacking as TextNodePatchBacking;

  PatchField<String> get text => _textBacking.text;
  PatchField<double> get fontSize => _textBacking.fontSize;
  PatchField<Color> get color => _textBacking.color;
  PatchField<TextAlign> get align => _textBacking.align;
  PatchField<TextDirection> get textDirection => _textBacking.textDirection;
  PatchField<bool> get isBold => _textBacking.isBold;
  PatchField<bool> get isItalic => _textBacking.isItalic;
  PatchField<bool> get isUnderline => _textBacking.isUnderline;
  PatchField<String?> get fontFamily => _textBacking.fontFamily;
  PatchField<double?> get maxWidth => _textBacking.maxWidth;
  PatchField<double?> get lineHeight => _textBacking.lineHeight;
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
  }) : this._materialized(
         strokeNodePatchBackingFromValidated(
           id: id,
           common: common.internalBacking,
           fields: fields,
         ),
       );

  @internal
  factory StrokeNodePatch.materialize(StrokeNodePatchBacking backing) =
      StrokeNodePatch._materialized;

  StrokeNodePatch._materialized(super._backing) : super._materialized();

  StrokeNodePatchBacking get _strokeBacking =>
      internalBacking as StrokeNodePatchBacking;

  PatchField<List<Offset>> get points => _strokeBacking.points;
  PatchField<double> get thickness => _strokeBacking.thickness;
  PatchField<Color> get color => _strokeBacking.color;
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
  }) : this._materialized(
         lineNodePatchBackingFromValidated(
           id: id,
           common: common.internalBacking,
           fields: fields,
         ),
       );

  @internal
  factory LineNodePatch.materialize(LineNodePatchBacking backing) =
      LineNodePatch._materialized;

  LineNodePatch._materialized(super._backing) : super._materialized();

  LineNodePatchBacking get _lineBacking =>
      internalBacking as LineNodePatchBacking;

  PatchField<Offset> get start => _lineBacking.start;
  PatchField<Offset> get end => _lineBacking.end;
  PatchField<double> get thickness => _lineBacking.thickness;
  PatchField<Color> get color => _lineBacking.color;
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
  }) : this._materialized(
         rectNodePatchBackingFromValidated(
           id: id,
           common: common.internalBacking,
           fields: fields,
         ),
       );

  @internal
  factory RectNodePatch.materialize(RectNodePatchBacking backing) =
      RectNodePatch._materialized;

  RectNodePatch._materialized(super._backing) : super._materialized();

  RectNodePatchBacking get _rectBacking =>
      internalBacking as RectNodePatchBacking;

  PatchField<Size> get size => _rectBacking.size;
  PatchField<Color?> get fillColor => _rectBacking.fillColor;
  PatchField<Color?> get strokeColor => _rectBacking.strokeColor;
  PatchField<double> get strokeWidth => _rectBacking.strokeWidth;
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
  }) : this._materialized(
         pathNodePatchBackingFromValidated(
           id: id,
           common: common.internalBacking,
           fields: fields,
         ),
       );

  @internal
  factory PathNodePatch.materialize(PathNodePatchBacking backing) =
      PathNodePatch._materialized;

  PathNodePatch._materialized(super._backing) : super._materialized();

  PathNodePatchBacking get _pathBacking =>
      internalBacking as PathNodePatchBacking;

  PatchField<String> get svgPathData => _pathBacking.svgPathData;
  PatchField<Color?> get fillColor => _pathBacking.fillColor;
  PatchField<Color?> get strokeColor => _pathBacking.strokeColor;
  PatchField<double> get strokeWidth => _pathBacking.strokeWidth;
  PatchField<PathFillRule> get fillRule => _pathBacking.fillRule;
}
