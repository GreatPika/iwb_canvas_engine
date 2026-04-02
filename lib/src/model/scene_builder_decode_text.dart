import 'dart:ui';

import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/scene_data_exception.dart';
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
  _rejectLegacyTextSizeField(json, nodePath: nodePath);
  final textFields = _decodeTextSpecFields(json, nodePath: nodePath);
  return textNodeSnapshotSchemaFieldsFromValidated((
    text: textFields.text,
    fontSize: textFields.fontSize,
    color: textFields.color,
    align: textFields.align,
    textDirection: textFields.textDirection,
    isBold: textFields.isBold,
    isItalic: textFields.isItalic,
    isUnderline: textFields.isUnderline,
    fontFamily: textFields.fontFamily,
    maxWidth: textFields.maxWidth,
    lineHeight: textFields.lineHeight,
  ));
}

void _rejectLegacyTextSizeField(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  if (!json.containsKey('size')) {
    return;
  }
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: sceneBuilderPathAt(nodePath, 'size'),
    message: 'Text nodes must not contain the size field in schemaVersion 7.',
    source: json['size'],
  );
}

TextNodeSpecSchemaFields _decodeTextSpecFields(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final flags = _decodeTextFlags(json, nodePath: nodePath);
  final optionals = _decodeTextOptionals(json, nodePath: nodePath);
  return textNodeSpecSchemaFieldsFromValidated((
    text: _decodeRequiredTextContent(json, nodePath: nodePath),
    fontSize: sceneBuilderRequireValidatedField(
      json,
      'fontSize',
      pathPrefix: nodePath,
      parse: (value, {required path, required fieldName}) =>
          validatedRequireJsonPositiveFiniteDouble(
            value,
            path: path,
            fieldName: fieldName,
          ),
    ),
    color: sceneBuilderDecodeRequiredColor(json, 'color', pathPrefix: nodePath),
    align: sceneBuilderParseTextAlign(
      sceneBuilderRequireStringField(json, 'align', pathPrefix: nodePath),
      pathPrefix: nodePath,
    ),
    textDirection: _decodeTextDirection(json, nodePath: nodePath),
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
  return sceneBuilderRequireValidatedField(
    json,
    'text',
    pathPrefix: nodePath,
    parse: (value, {required path, required fieldName}) =>
        TextContentValue.fromJson(
          value,
          path: path,
          fieldName: fieldName,
        ).value,
  );
}

TextDirection _decodeTextDirection(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  final rawDirection = sceneBuilderRequireTypedField<String>(
    json,
    'textDirection',
    pathPrefix: nodePath,
    typeLabel: 'string',
  );
  return sceneBuilderParseTextDirection(
    rawDirection,
    pathPrefix: nodePath,
    fieldName: 'textDirection',
  );
}

({bool isBold, bool isItalic, bool isUnderline}) _decodeTextFlags(
  Map<String, Object?> json, {
  required String nodePath,
}) {
  return (
    isBold: sceneBuilderRequireBoolField(json, 'isBold', pathPrefix: nodePath),
    isItalic: sceneBuilderRequireBoolField(
      json,
      'isItalic',
      pathPrefix: nodePath,
    ),
    isUnderline: sceneBuilderRequireBoolField(
      json,
      'isUnderline',
      pathPrefix: nodePath,
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
