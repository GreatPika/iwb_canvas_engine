import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';

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
