import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_node_boundary_mapping_common.dart';

TextNodeSnapshotSchemaFields textNodeSchemaFieldsFromSnapshot(
  TextNodeSnapshot text,
) {
  return textNodeSnapshotSchemaFieldsFromValidated((
    text: text.text,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    textDirection: text.textDirection,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
}

TextNodeSpecSchemaFields textNodeSchemaFieldsFromSpec(TextNodeSpec text) {
  return textNodeSpecSchemaFieldsFromValidated((
    text: text.text,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    textDirection: text.textDirection,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
}

TextNodeSnapshotSchemaFields textNodeSchemaFieldsFromNode(TextNode text) {
  return textNodeSnapshotSchemaFieldsFromValidated((
    text: text.text,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    textDirection: text.textDirection,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
}

TextNode textNodeFromSnapshot(TextNodeSnapshot text, int instanceRevision) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: text,
        instanceRevision: instanceRevision,
        extractFields: textNodeSchemaFieldsFromSnapshot,
        buildNode: ({required common, required fields}) =>
            textNodeFromSnapshotSchema(common: common, fields: fields),
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
}) {
  return TextNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    textDirection: fields.textDirection,
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

TextNode textNodeFromSpecSchema({
  required RuntimeNodeCommonFields common,
  required TextNodeSpecSchemaFields fields,
}) {
  return TextNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    textDirection: fields.textDirection,
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

TextNode cloneRuntimeTextNode(TextNode text) {
  return TextNode(
    id: text.id,
    instanceRevision: text.instanceRevision,
    text: text.text,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    textDirection: text.textDirection,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
    transform: text.transform,
    opacity: text.opacity,
    hitPadding: text.hitPadding,
    isVisible: text.isVisible,
    isSelectable: text.isSelectable,
    isLocked: text.isLocked,
    isDeletable: text.isDeletable,
    isTransformable: text.isTransformable,
  );
}

TextNodeSnapshotBacking textSnapshotBackingFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required TextNodeSnapshotSchemaFields fields,
}) {
  return textNodeSnapshotBackingFromValidated(common: common, fields: fields);
}
