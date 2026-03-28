import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/validated/font_family_value.dart';
import '../contract/validated/text_content_value.dart';
import '../contract/validated/validated_value_support.dart';
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

TextNodeSnapshotBacking sceneBuilderDecodeTextSnapshot(
  Map<String, Object?> json, {
  required String nodePath,
  required NodeSnapshotCommonSchemaFields common,
}) {
  final fields = _decodeTextFields(json, nodePath: nodePath);
  return textNodeSnapshotBackingFromValidated(common: common, fields: fields);
}

TextNodeSnapshotSchemaFields _decodeTextFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final textFields = _decodeTextSpecFields(json, nodePath: nodePath);
  return textNodeSnapshotSchemaFieldsFromValidated((
    text: textFields.text,
    size: sceneBuilderRequireSize(json, 'size', pathPrefix: nodePath),
    fontSize: textFields.fontSize,
    color: textFields.color,
    align: textFields.align,
    isBold: textFields.isBold,
    isItalic: textFields.isItalic,
    isUnderline: textFields.isUnderline,
    fontFamily: textFields.fontFamily,
    maxWidth: textFields.maxWidth,
    lineHeight: textFields.lineHeight,
  ));
}

TextNodeSpecSchemaFields _decodeTextSpecFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final flags = _decodeTextFlags(json, nodePath: nodePath);
  final optionals = _decodeTextOptionals(json, nodePath: nodePath);
  return textNodeSpecSchemaFieldsFromValidated((
    text: _decodeRequiredTextContent(json, nodePath: nodePath),
    fontSize: validatedRequireJsonPositiveFiniteDouble(
      sceneBuilderRequireField(json, 'fontSize', pathPrefix: nodePath),
      path: sceneBuilderPathAt(nodePath, 'fontSize'),
      fieldName: 'fontSize',
    ),
    color: sceneBuilderParseColor(
      sceneBuilderRequireTypedField<String>(
        json,
        'color',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      path: sceneBuilderPathAt(nodePath, 'color'),
    ),
    align: sceneBuilderParseTextAlign(
      sceneBuilderRequireTypedField<String>(
        json,
        'align',
        pathPrefix: nodePath,
        typeLabel: 'string',
      ),
      pathPrefix: nodePath,
    ),
    isBold: flags.isBold,
    isItalic: flags.isItalic,
    isUnderline: flags.isUnderline,
    fontFamily: optionals.fontFamily,
    maxWidth: optionals.maxWidth,
    lineHeight: optionals.lineHeight,
  ));
}

String _decodeRequiredTextContent(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return TextContentValue.fromJson(
    sceneBuilderRequireTypedField<String>(
      json,
      'text',
      pathPrefix: nodePath,
      typeLabel: 'string',
    ),
    path: sceneBuilderPathAt(nodePath, 'text'),
    fieldName: 'text',
  ).value;
}

({bool isBold, bool isItalic, bool isUnderline}) _decodeTextFlags(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return (
    isBold: sceneBuilderRequireTypedField<bool>(
      json,
      'isBold',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isItalic: sceneBuilderRequireTypedField<bool>(
      json,
      'isItalic',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
    isUnderline: sceneBuilderRequireTypedField<bool>(
      json,
      'isUnderline',
      pathPrefix: nodePath,
      typeLabel: 'bool',
    ),
  );
}

({String? fontFamily, double? maxWidth, double? lineHeight})
_decodeTextOptionals(Map<String, Object?> json, {required String nodePath}) {
  return (
    fontFamily: sceneBuilderOptionalValidatedField(
      json,
      'fontFamily',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          FontFamilyValue.fromJson(
            value,
            path: path,
            fieldName: fieldName,
          ).value,
    ),
    maxWidth: sceneBuilderOptionalValidatedField(
      json,
      'maxWidth',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonPositiveFiniteDouble(
            value,
            path: path,
            fieldName: fieldName,
          ),
    ),
    lineHeight: sceneBuilderOptionalValidatedField(
      json,
      'lineHeight',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonPositiveFiniteDouble(
            value,
            path: path,
            fieldName: fieldName,
          ),
    ),
  );
}
