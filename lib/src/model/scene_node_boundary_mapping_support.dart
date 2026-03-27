import 'dart:ui';

import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../core/nodes.dart';
import '../core/text_layout.dart';

enum TextNodeSnapshotSizePolicy { preserveBoundarySize, recomputeFromLayout }

typedef RuntimeNodeCommonFields = ({
  NodeId id,
  int instanceRevision,
  Transform2D transform,
  double opacity,
  double hitPadding,
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
});

typedef SpecRuntimeNodeContext = ({NodeId fallbackId, int instanceRevision});

typedef SceneNodeFromSchema<FieldsT> =
    SceneNode Function({
      required RuntimeNodeCommonFields common,
      required FieldsT fields,
    });

typedef NodeSnapshotFromSchema<FieldsT, SnapshotT extends NodeSnapshot> =
    SnapshotT Function({
      required NodeSnapshotCommonSchemaFields common,
      required FieldsT fields,
    });

NodeSnapshotCommonSchemaFields snapshotCommonFromNodeSnapshot(
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

NodeSpecCommonSchemaFields specCommonFromNodeSpec(NodeSpec spec) {
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

NodeSnapshotCommonSchemaFields snapshotCommonFromSceneNode(SceneNode node) {
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

RuntimeNodeCommonFields runtimeCommonFromSnapshot(
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

RuntimeNodeCommonFields runtimeCommonFromSpec(
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

SceneNode
sceneNodeFromSnapshotViaSchema<SnapshotT extends NodeSnapshot, FieldsT>({
  required SnapshotT snapshot,
  required int instanceRevision,
  required FieldsT Function(SnapshotT snapshot) extractFields,
  required SceneNodeFromSchema<FieldsT> buildNode,
}) {
  final common = runtimeCommonFromSnapshot(
    snapshotCommonFromNodeSnapshot(snapshot),
    instanceRevision: instanceRevision,
  );
  final fields = extractFields(snapshot);
  return buildNode(common: common, fields: fields);
}

SceneNode sceneNodeFromSpecViaSchema<SpecT extends NodeSpec, FieldsT>({
  required SpecT spec,
  required SpecRuntimeNodeContext runtimeContext,
  required FieldsT Function(SpecT spec) extractFields,
  required SceneNodeFromSchema<FieldsT> buildNode,
}) {
  final common = runtimeCommonFromSpec(
    specCommonFromNodeSpec(spec),
    fallbackId: runtimeContext.fallbackId,
    instanceRevision: runtimeContext.instanceRevision,
  );
  final fields = extractFields(spec);
  return buildNode(common: common, fields: fields);
}

NodeSnapshot sceneNodeSnapshotFromViaSchema<
  NodeT extends SceneNode,
  FieldsT,
  SnapshotT extends NodeSnapshot
>({
  required NodeT node,
  required FieldsT Function(NodeT node) extractFields,
  required NodeSnapshotFromSchema<FieldsT, SnapshotT> buildSnapshot,
}) {
  final common = snapshotCommonFromSceneNode(node);
  final fields = extractFields(node);
  return buildSnapshot(common: common, fields: fields);
}

ImageNode imageNodeFromSchema({
  required RuntimeNodeCommonFields common,
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

TextNode textNodeFromSnapshotSchema({
  required RuntimeNodeCommonFields common,
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

TextNode textNodeFromSpecSchema({
  required RuntimeNodeCommonFields common,
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

StrokeNode strokeNodeFromSnapshotSchema({
  required RuntimeNodeCommonFields common,
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

StrokeNode strokeNodeFromSpecSchema({
  required RuntimeNodeCommonFields common,
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

LineNode lineNodeFromSchema({
  required RuntimeNodeCommonFields common,
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

RectNode rectNodeFromSchema({
  required RuntimeNodeCommonFields common,
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

PathNode pathNodeFromSchema({
  required RuntimeNodeCommonFields common,
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

ImageNodeSnapshot imageSnapshotFromSchema({
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

TextNodeSnapshot textSnapshotFromSchema({
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

StrokeNodeSnapshot strokeSnapshotFromSchema({
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

LineNodeSnapshot lineSnapshotFromSchema({
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

RectNodeSnapshot rectSnapshotFromSchema({
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

PathNodeSnapshot pathSnapshotFromSchema({
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
