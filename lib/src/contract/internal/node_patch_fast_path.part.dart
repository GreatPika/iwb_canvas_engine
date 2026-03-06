part of '../node_patch.dart';

@internal
CommonNodePatch commonNodePatchFromValidated({
  PatchField<Transform2D> transform = const PatchField<Transform2D>.absent(),
  PatchField<double> opacity = const PatchField<double>.absent(),
  PatchField<double> hitPadding = const PatchField<double>.absent(),
  PatchField<bool> isVisible = const PatchField<bool>.absent(),
  PatchField<bool> isSelectable = const PatchField<bool>.absent(),
  PatchField<bool> isLocked = const PatchField<bool>.absent(),
  PatchField<bool> isDeletable = const PatchField<bool>.absent(),
  PatchField<bool> isTransformable = const PatchField<bool>.absent(),
}) {
  return CommonNodePatch._internal(
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
  );
}

@internal
ImageNodePatch imageNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  PatchField<String> imageId = const PatchField<String>.absent(),
  PatchField<Size> size = const PatchField<Size>.absent(),
  PatchField<Size?> naturalSize = const PatchField<Size?>.absent(),
}) {
  return ImageNodePatch._internal(
    id: id,
    common: common ?? const CommonNodePatch._internal(),
    imageId: imageId,
    size: size,
    naturalSize: naturalSize,
  );
}

@internal
TextNodePatch textNodePatchFromValidated({
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
}) {
  return TextNodePatch._internal(
    id: id,
    common: common ?? const CommonNodePatch._internal(),
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
  );
}

@internal
StrokeNodePatch strokeNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  PatchField<List<Offset>> points = const PatchField<List<Offset>>.absent(),
  PatchField<double> thickness = const PatchField<double>.absent(),
  PatchField<Color> color = const PatchField<Color>.absent(),
}) {
  // Fast paths skip primitive validation but still capture immutable ownership
  // for collection payloads so they match public boundary semantics.
  return StrokeNodePatch._internal(
    id: id,
    common: common ?? const CommonNodePatch._internal(),
    points: _snapshotOffsetListPatchField(points),
    thickness: thickness,
    color: color,
  );
}

@internal
LineNodePatch lineNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  PatchField<Offset> start = const PatchField<Offset>.absent(),
  PatchField<Offset> end = const PatchField<Offset>.absent(),
  PatchField<double> thickness = const PatchField<double>.absent(),
  PatchField<Color> color = const PatchField<Color>.absent(),
}) {
  return LineNodePatch._internal(
    id: id,
    common: common ?? const CommonNodePatch._internal(),
    start: start,
    end: end,
    thickness: thickness,
    color: color,
  );
}

@internal
RectNodePatch rectNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  PatchField<Size> size = const PatchField<Size>.absent(),
  PatchField<Color?> fillColor = const PatchField<Color?>.absent(),
  PatchField<Color?> strokeColor = const PatchField<Color?>.absent(),
  PatchField<double> strokeWidth = const PatchField<double>.absent(),
}) {
  return RectNodePatch._internal(
    id: id,
    common: common ?? const CommonNodePatch._internal(),
    size: size,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
  );
}

@internal
PathNodePatch pathNodePatchFromValidated({
  required NodeId id,
  CommonNodePatch? common,
  PatchField<String> svgPathData = const PatchField<String>.absent(),
  PatchField<Color?> fillColor = const PatchField<Color?>.absent(),
  PatchField<Color?> strokeColor = const PatchField<Color?>.absent(),
  PatchField<double> strokeWidth = const PatchField<double>.absent(),
  PatchField<PathFillRule> fillRule = const PatchField<PathFillRule>.absent(),
}) {
  return PathNodePatch._internal(
    id: id,
    common: common ?? const CommonNodePatch._internal(),
    svgPathData: svgPathData,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    fillRule: fillRule,
  );
}
