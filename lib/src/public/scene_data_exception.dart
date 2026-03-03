/// Unified validation/format error raised by scene import/build boundaries.
class SceneDataException implements FormatException {
  /// Creates a structured scene data error.
  const SceneDataException({
    required this.code,
    required this.message,
    this.path,
    this.source,
  });

  /// Machine-readable error category.
  final SceneDataErrorCode code;

  /// Human-readable error message.
  @override
  final String message;

  /// Optional field-path in the input payload.
  final String? path;

  /// Optional source object passed through from the failing boundary.
  @override
  final Object? source;

  /// `SceneDataException` does not currently track a character offset.
  @override
  int? get offset => null;

  @override
  String toString() {
    final pathPart = path == null ? '' : ' path=$path';
    return 'SceneDataException(code: $code$pathPart, message: $message)';
  }
}

/// Stable error categories for scene import/build/serialization failures.
enum SceneDataErrorCode {
  /// The JSON string is syntactically invalid or has the wrong root shape.
  invalidJson,

  /// The payload schema version is not supported by the current package.
  unsupportedSchemaVersion,

  /// A required field is missing.
  missingField,

  /// A field exists but has the wrong type.
  invalidFieldType,

  /// A field value fails semantic validation.
  invalidValue,

  /// The payload contains duplicate node ids.
  duplicateNodeId,

  /// The payload encodes more than one background layer.
  multipleBackgroundLayers,

  /// A numeric or indexed value is outside the accepted range.
  outOfRange,
}
