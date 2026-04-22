import '../contract/snapshot.dart';
import '../contract/validated/font_family_value.dart';
import '../contract/validated/text_content_value.dart';
import '../core/nodes.dart';
import '../core/scene_limits.dart';
import '../core/text_layout.dart' show TextLayoutRequest;
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidateTextNodeSnapshot(
  TextNodeSnapshot text, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateTextNodeFields(
    textValue: text.text,
    fontSize: text.fontSize,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
    field: field,
    onError: onError,
  );
  _sceneValidateTextSnapshotDerivedBounds(text, field: field, onError: onError);
}

void sceneValidateTextNode(
  TextNode text, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateTextNodeFields(
    textValue: text.text,
    fontSize: text.fontSize,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
    field: field,
    onError: onError,
  );
}

void _sceneValidateTextNodeFields({
  required String textValue,
  required double fontSize,
  required String? fontFamily,
  required double? maxWidth,
  required double? lineHeight,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateArgumentBoundary(
    field: '$field.text',
    value: textValue,
    onError: onError,
    validate: () => TextContentValue.of(textValue, name: '$field.text'),
  );
  sceneValidatePositiveDouble(
    fontSize,
    field: '$field.fontSize',
    onError: onError,
  );
  sceneValidateDoubleInRange(
    fontSize,
    field: '$field.fontSize',
    min: 0,
    max: sceneSizeMax,
    onError: onError,
  );
  sceneValidateOptionalValue<String>(
    fontFamily,
    field: '$field.fontFamily',
    onError: onError,
    validateValue: _sceneValidateFontFamilyField,
  );
  sceneValidateOptionalValue<double>(
    maxWidth,
    field: '$field.maxWidth',
    onError: onError,
    validateValue: sceneValidatePositiveDouble,
  );
  if (maxWidth != null) {
    sceneValidateDoubleInRange(
      maxWidth,
      field: '$field.maxWidth',
      min: 0,
      max: sceneSizeMax,
      onError: onError,
    );
  }
  sceneValidateOptionalValue<double>(
    lineHeight,
    field: '$field.lineHeight',
    onError: onError,
    validateValue: sceneValidatePositiveDouble,
  );
  if (lineHeight != null) {
    sceneValidateDoubleInRange(
      lineHeight,
      field: '$field.lineHeight',
      min: 0,
      max: sceneSizeMax,
      onError: onError,
    );
  }
}

void _sceneValidateFontFamilyField(
  String value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => FontFamilyValue.of(value, name: field),
  );
}

void _sceneValidateTextSnapshotDerivedBounds(
  TextNodeSnapshot text, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  final derivedBounds = TextLayoutRequest.forSnapshot(text).measure();
  sceneValidateDoubleInRange(
    derivedBounds.width,
    field: '$field.derivedBounds.w',
    min: 0,
    max: sceneSizeMax,
    onError: onError,
  );
  sceneValidateDoubleInRange(
    derivedBounds.height,
    field: '$field.derivedBounds.h',
    min: 0,
    max: sceneSizeMax,
    onError: onError,
  );
}
