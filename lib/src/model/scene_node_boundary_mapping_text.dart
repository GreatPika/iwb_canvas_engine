import 'dart:ui';

import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import '../core/text_layout.dart';
import 'scene_node_boundary_mapping_common.dart';

TextNodeSnapshotSchemaFields textNodeSchemaFieldsFromSnapshot(
  TextNodeSnapshot text,
) {
  return NodeBoundarySchema.textSnapshotFieldsFromValidated((
    text: text.text,
    size: text.size,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
}

TextNodeSpecSchemaFields textNodeSchemaFieldsFromSpec(TextNodeSpec text) {
  return NodeBoundarySchema.textSpecFieldsFromValidated((
    text: text.text,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
}

TextNodeSnapshotSchemaFields textNodeSchemaFieldsFromNode(TextNode text) {
  return NodeBoundarySchema.textSnapshotFieldsFromValidated((
    text: text.text,
    size: text.size,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
}

TextNode textNodeFromSnapshot(
  TextNodeSnapshot text,
  int instanceRevision,
  TextNodeSnapshotSizePolicy textSizePolicy,
) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: text,
        instanceRevision: instanceRevision,
        extractFields: textNodeSchemaFieldsFromSnapshot,
        buildNode: ({required common, required fields}) =>
            textNodeFromSnapshotSchema(
              common: common,
              fields: fields,
              textSizePolicy: textSizePolicy,
            ),
      )
      as TextNode;
}

TextNode textNodeFromSpec(
  TextNodeSpec text,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: text,
        runtimeContext: runtimeContext,
        extractFields: textNodeSchemaFieldsFromSpec,
        buildNode: textNodeFromSpecSchema,
      )
      as TextNode;
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
