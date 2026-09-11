import 'canvas_contract_limits.dart';
import 'canvas_errors.dart';

/// Validates the nullable stored or runtime-default text family value.
///
/// This remains package-internal despite living beside the public text
/// declarations: element construction, element updates, and runtime config
/// must retain one error contract without exporting a new public helper.
String? validateCanvasTextFontFamily(String? value) {
  if (value != null &&
      (value.isEmpty || value.length > canvasMaxFontFamilyLength)) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMaxLength,
      message: 'font family length is invalid.',
      path: 'text.fontFamily',
    );
  }

  return value;
}
