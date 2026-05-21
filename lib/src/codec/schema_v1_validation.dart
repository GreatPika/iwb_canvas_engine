import '../api/canvas_errors.dart';

const Set<String> canvasSchemaV1RootFields = {
  'schemaVersion',
  'camera',
  'background',
  'palette',
  'resources',
  'backgroundLayer',
  'layers',
  'metadata',
};

void validateSchemaV1Root(Map<String, Object?> json) {
  final version = json['schemaVersion'];
  if (version is! int || version != 1) {
    throw CanvasDataException(
      code: version == null
          ? CanvasDataErrorCode.missingField
          : CanvasDataErrorCode.unsupportedSchemaVersion,
      message: 'schemaVersion must be 1.',
      path: r'$.schemaVersion',
      details: {'actual': version},
    );
  }
}
