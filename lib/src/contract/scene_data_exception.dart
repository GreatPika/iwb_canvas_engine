part 'scene_data_exception_details.part.dart';
part 'scene_data_exception_message.part.dart';
part 'scene_data_exception_source.part.dart';

/// Unified validation/format error raised by scene import/build boundaries.
class SceneDataException implements FormatException {
  /// Creates a structured scene data error.
  factory SceneDataException({
    required SceneDataErrorCode code,
    String? message,
    String? path,
    Map<String, Object?>? details,
    Object? source,
  }) {
    final rawDetails = details ?? const <String, Object?>{};
    final sanitizedDetails = _sanitizeSceneDataDetails(rawDetails);
    final sanitizedSource = _sanitizeSceneDataSource(source);
    return SceneDataException._(
      code: code,
      path: path,
      details: sanitizedDetails,
      source: sanitizedSource,
      message:
          message ??
          _deriveSceneDataMessage(code: code, path: path, details: rawDetails),
    );
  }

  SceneDataException._({
    required this.code,
    required this.message,
    required this.path,
    required this.details,
    required this.source,
  });

  /// Canonical constructor used by boundary helpers.
  factory SceneDataException.boundary({
    required SceneDataErrorCode code,
    String? message,
    String? path,
    Map<String, Object?>? details,
    Object? source,
  }) {
    return SceneDataException(
      code: code,
      message: message,
      path: path,
      details: details,
      source: source,
    );
  }

  /// Reports that the JSON root must be an object.
  factory SceneDataException.invalidJsonRoot({Object? source}) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidJson,
      details: const <String, Object?>{'template': 'rootObject'},
      source: source,
    );
  }

  /// Reports a generic malformed scene JSON payload at the transport boundary.
  factory SceneDataException.invalidJsonPayload({Object? source}) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidJson,
      details: const <String, Object?>{'template': 'invalidJsonPayload'},
      source: source,
    );
  }

  /// Reports that the raw JSON string exceeds the supported boundary length.
  factory SceneDataException.jsonPayloadTooLarge({
    required int maxLength,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidJson,
      details: <String, Object?>{
        'template': 'jsonPayloadTooLarge',
        'maxLength': maxLength,
      },
      source: source,
    );
  }

  /// Reports a missing required field.
  factory SceneDataException.missingField({
    required String path,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.missingField,
      path: path,
      details: <String, Object?>{'template': 'missingField'},
      source: source,
    );
  }

  /// Reports that a field has the wrong JSON type.
  factory SceneDataException.invalidFieldType({
    required String path,
    required String fieldName,
    required String expected,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      details: <String, Object?>{
        'template': 'fieldType',
        'fieldName': fieldName,
        'expected': expected,
      },
      source: source,
    );
  }

  /// Reports that a string field must not be empty.
  factory SceneDataException.fieldMustNotBeEmpty({
    required String path,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      details: const <String, Object?>{'template': 'fieldMustNotBeEmpty'},
      source: source,
    );
  }

  /// Reports that a string field exceeds the max allowed length.
  factory SceneDataException.fieldMaxLength({
    required String path,
    required int maxLength,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      details: <String, Object?>{
        'template': 'fieldMaxLength',
        'maxLength': maxLength,
      },
      source: source,
    );
  }

  /// Reports that a numeric field must be finite.
  factory SceneDataException.fieldMustBeFinite({
    required String path,
    required String fieldName,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      details: <String, Object?>{
        'template': 'fieldMustBeFinite',
        'fieldName': fieldName,
      },
      source: source,
    );
  }

  /// Reports that a field must be an integer.
  factory SceneDataException.fieldMustBeInt({
    required String path,
    required String fieldName,
    required SceneDataErrorCode code,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: code,
      path: path,
      details: <String, Object?>{
        'template': 'fieldMustBeInt',
        'fieldName': fieldName,
      },
      source: source,
    );
  }

  /// Reports that a numeric field must be greater than a lower bound.
  factory SceneDataException.fieldMustBeGreaterThan({
    required String path,
    required num limit,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      details: <String, Object?>{
        'template': 'fieldMustBeGreaterThan',
        'limit': limit,
      },
      source: source,
    );
  }

  /// Reports that a numeric field must be at least a lower bound.
  factory SceneDataException.fieldMustBeAtLeast({
    required String path,
    required num limit,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      details: <String, Object?>{
        'template': 'fieldMustBeAtLeast',
        'limit': limit,
      },
      source: source,
    );
  }

  /// Reports that a field must stay within the accepted range.
  factory SceneDataException.outOfRange({
    required String path,
    required num min,
    required num max,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.outOfRange,
      path: path,
      details: <String, Object?>{
        'template': 'outOfRange',
        'min': min,
        'max': max,
      },
      source: source,
    );
  }

  /// Reports a duplicate node id across scene layers.
  factory SceneDataException.duplicateNodeId({
    required String path,
    required Object? nodeId,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.duplicateNodeId,
      path: path,
      details: const <String, Object?>{'template': 'duplicateNodeId'},
      source: nodeId,
    );
  }

  /// Reports a duplicate content layer id.
  factory SceneDataException.duplicateLayerId({
    required String path,
    required Object? layerId,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.duplicateLayerId,
      path: path,
      details: const <String, Object?>{'template': 'duplicateLayerId'},
      source: layerId,
    );
  }

  /// Reports that a collection exceeded the allowed number of items.
  factory SceneDataException.maxItems({
    required String path,
    required int maxItems,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      details: <String, Object?>{'template': 'maxItems', 'maxItems': maxItems},
      source: source,
    );
  }

  /// Reports that the scene exceeded the allowed number of nodes.
  factory SceneDataException.maxNodes({
    required String path,
    required int maxNodes,
    Object? source,
  }) {
    return SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      details: <String, Object?>{'template': 'maxNodes', 'maxNodes': maxNodes},
      source: source,
    );
  }

  /// Machine-readable error category.
  final SceneDataErrorCode code;

  /// Human-readable message derived from [code], [path], and [details].
  @override
  final String message;

  /// Optional field-path in the input payload.
  final String? path;

  /// Machine-readable immutable diagnostics payload for boundary parity.
  final Map<String, Object?> details;

  /// Optional source object passed through from the failing boundary.
  @override
  final Object? source;

  /// `SceneDataException` does not currently track a character offset.
  @override
  int? get offset => null;

  @override
  String toString() {
    final pathPart = path == null ? '' : ' path=$path';
    final detailsPart = details.isEmpty ? '' : ', details: $details';
    return 'SceneDataException(code: $code$pathPart, message: $message$detailsPart)';
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

  /// The payload contains duplicate content layer ids.
  duplicateLayerId,

  /// A numeric or indexed value is outside the accepted range.
  outOfRange,
}

const int _sceneDataDetailsPreviewMaxLength = 128;
const int _sceneDataDetailsPreviewMaxItems = 10;
const int _sceneDataDetailsPreviewMaxDepth = 3;
const int _sceneDataSourcePreviewMaxLength = 256;
const int _sceneDataSourcePreviewMaxItems = 5;
const int _sceneDataSourcePreviewMaxDepth = 2;

Map<String, Object?> _objectPreview(Object source) {
  return <String, Object?>{
    'kind': 'object',
    'type': source.runtimeType.toString(),
    'preview': _truncatePreview(source.toString()),
  };
}

String _previewMapKey(Object? key) {
  if (key is String && key.length <= _sceneDataSourcePreviewMaxLength) {
    return key;
  }
  return _truncatePreview('$key');
}

String _truncatePreview(
  String value, {
  int maxLength = _sceneDataSourcePreviewMaxLength,
}) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength)}...';
}
