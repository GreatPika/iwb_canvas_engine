/// Unified validation/format error raised by scene import/build boundaries.
class SceneDataException implements FormatException {
  const SceneDataException({
    required this.code,
    required this.message,
    this.path,
    this.source,
  });

  final SceneDataErrorCode code;

  @override
  final String message;

  /// Optional field-path in the input payload.
  final String? path;

  @override
  final Object? source;

  @override
  int? get offset => null;

  @override
  String toString() {
    final pathPart = path == null ? '' : ' path=$path';
    return 'SceneDataException(code: $code$pathPart, message: $message)';
  }
}

enum SceneDataErrorCode {
  invalidJson,
  unsupportedSchemaVersion,
  missingField,
  invalidFieldType,
  invalidValue,
  duplicateNodeId,
  multipleBackgroundLayers,
  outOfRange,
}
