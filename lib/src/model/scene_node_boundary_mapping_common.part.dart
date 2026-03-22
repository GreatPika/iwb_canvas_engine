part of 'scene_node_boundary_mapping.dart';

typedef _SceneNodeFromSchema<FieldsT> =
    SceneNode Function({
      required _RuntimeNodeCommonFields common,
      required FieldsT fields,
    });

typedef _NodeSnapshotFromSchema<FieldsT, SnapshotT extends NodeSnapshot> =
    SnapshotT Function({
      required NodeSnapshotCommonSchemaFields common,
      required FieldsT fields,
    });

NodeSnapshotCommonSchemaFields _snapshotCommonFromNodeSnapshot(
  NodeSnapshot node,
) {
  return NodeBoundarySchema.snapshotCommonFromValidated((
    id: node.id,
    instanceRevision: node.instanceRevision,
    transform: node.transform,
    opacity: node.opacity,
    hitPadding: node.hitPadding,
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
    isLocked: node.isLocked,
    isDeletable: node.isDeletable,
    isTransformable: node.isTransformable,
  ));
}

NodeSpecCommonSchemaFields _specCommonFromNodeSpec(NodeSpec spec) {
  return NodeBoundarySchema.specCommonFromValidated((
    id: spec.id,
    transform: spec.transform,
    opacity: spec.opacity,
    hitPadding: spec.hitPadding,
    isVisible: spec.isVisible,
    isSelectable: spec.isSelectable,
    isLocked: spec.isLocked,
    isDeletable: spec.isDeletable,
    isTransformable: spec.isTransformable,
  ));
}

NodeSnapshotCommonSchemaFields _snapshotCommonFromSceneNode(SceneNode node) {
  return NodeBoundarySchema.snapshotCommonFromValidated((
    id: node.id,
    instanceRevision: node.instanceRevision,
    transform: node.transform,
    opacity: node.opacity,
    hitPadding: node.hitPadding,
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
    isLocked: node.isLocked,
    isDeletable: node.isDeletable,
    isTransformable: node.isTransformable,
  ));
}

_RuntimeNodeCommonFields _runtimeCommonFromSnapshot(
  NodeSnapshotCommonSchemaFields common, {
  required int instanceRevision,
}) {
  return (
    id: common.id,
    instanceRevision: instanceRevision,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

_RuntimeNodeCommonFields _runtimeCommonFromSpec(
  NodeSpecCommonSchemaFields common, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  return (
    id: common.id ?? fallbackId,
    instanceRevision: instanceRevision,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

ImageNode _imageNodeFromSchema({
  required _RuntimeNodeCommonFields common,
  required ImageNodeSchemaFields fields,
}) {
  return ImageNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    imageId: fields.imageId,
    size: fields.size,
    naturalSize: fields.naturalSize,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

TextNode _textNodeFromSnapshotSchema({
  required _RuntimeNodeCommonFields common,
  required TextNodeSnapshotSchemaFields fields,
  required TextNodeSnapshotSizePolicy textSizePolicy,
}) {
  final node = TextNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    size: textSizePolicy == TextNodeSnapshotSizePolicy.preserveBoundarySize
        ? fields.size
        : Size.zero,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: fields.fontFamily,
    maxWidth: fields.maxWidth,
    lineHeight: fields.lineHeight,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
  if (textSizePolicy == TextNodeSnapshotSizePolicy.recomputeFromLayout) {
    recomputeDerivedTextSize(node);
  }
  return node;
}

TextNode _textNodeFromSpecSchema({
  required _RuntimeNodeCommonFields common,
  required TextNodeSpecSchemaFields fields,
}) {
  final node = TextNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    size: Size.zero,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: fields.fontFamily,
    maxWidth: fields.maxWidth,
    lineHeight: fields.lineHeight,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
  recomputeDerivedTextSize(node);
  return node;
}

StrokeNode _strokeNodeFromSnapshotSchema({
  required _RuntimeNodeCommonFields common,
  required StrokeNodeSnapshotSchemaFields fields,
}) {
  return StrokeNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
    pointsRevision: fields.pointsRevision,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

StrokeNode _strokeNodeFromSpecSchema({
  required _RuntimeNodeCommonFields common,
  required StrokeNodeSpecSchemaFields fields,
}) {
  return StrokeNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

LineNode _lineNodeFromSchema({
  required _RuntimeNodeCommonFields common,
  required LineNodeSchemaFields fields,
}) {
  return LineNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    start: fields.start,
    end: fields.end,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

RectNode _rectNodeFromSchema({
  required _RuntimeNodeCommonFields common,
  required RectNodeSchemaFields fields,
}) {
  return RectNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

PathNode _pathNodeFromSchema({
  required _RuntimeNodeCommonFields common,
  required PathNodeSchemaFields fields,
}) {
  return PathNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

ImageNodeSnapshot _imageSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required ImageNodeSchemaFields fields,
}) {
  return imageNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    imageId: fields.imageId,
    size: fields.size,
    naturalSize: fields.naturalSize,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

TextNodeSnapshot _textSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required TextNodeSnapshotSchemaFields fields,
}) {
  return textNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    size: fields.size,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: fields.fontFamily,
    maxWidth: fields.maxWidth,
    lineHeight: fields.lineHeight,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

StrokeNodeSnapshot _strokeSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required StrokeNodeSnapshotSchemaFields fields,
}) {
  return strokeNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
    pointsRevision: fields.pointsRevision,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

LineNodeSnapshot _lineSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required LineNodeSchemaFields fields,
}) {
  return lineNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    start: fields.start,
    end: fields.end,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

RectNodeSnapshot _rectSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required RectNodeSchemaFields fields,
}) {
  return rectNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

PathNodeSnapshot _pathSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required PathNodeSchemaFields fields,
}) {
  return pathNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}
