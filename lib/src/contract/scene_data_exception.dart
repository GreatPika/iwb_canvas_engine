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
    final sanitizedDetails = _sanitizeSceneDataDetails(details);
    return SceneDataException._(
      code: code,
      path: path,
      details: sanitizedDetails,
      source: _sanitizeSceneDataSource(source),
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

Map<String, Object?> _sanitizeSceneDataDetails(Map<String, Object?>? details) {
  if (details == null || details.isEmpty) {
    return const <String, Object?>{};
  }
  final snapshot = <String, Object?>{};
  for (final entry in details.entries) {
    snapshot[entry.key] = _sanitizeSceneDataDetailValue(entry.value);
  }
  return Map<String, Object?>.unmodifiable(snapshot);
}

Object? _sanitizeSceneDataDetailValue(Object? value, {int depth = 0}) {
  if (value == null || value is num || value is bool) {
    return value;
  }
  if (value is String) {
    if (value.length <= _sceneDataDetailsPreviewMaxLength) {
      return value;
    }
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      'kind': 'string',
      'length': value.length,
      'preview': _truncatePreview(
        value,
        maxLength: _sceneDataDetailsPreviewMaxLength,
      ),
    });
  }
  if (depth >= _sceneDataDetailsPreviewMaxDepth) {
    return _objectPreview(value);
  }
  if (value is List) {
    if (value.length <= _sceneDataDetailsPreviewMaxItems) {
      return List<Object?>.unmodifiable(
        value
            .map(
              (item) => _sanitizeSceneDataDetailValue(item, depth: depth + 1),
            )
            .toList(growable: false),
      );
    }
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      'kind': 'list',
      'length': value.length,
      'preview': List<Object?>.unmodifiable(
        value
            .take(_sceneDataDetailsPreviewMaxItems)
            .map(
              (item) => _sanitizeSceneDataDetailValue(item, depth: depth + 1),
            )
            .toList(growable: false),
      ),
    });
  }
  if (value is Map) {
    final snapshot = <String, Object?>{};
    var count = 0;
    for (final entry in value.entries) {
      if (count >= _sceneDataDetailsPreviewMaxItems) {
        return Map<String, Object?>.unmodifiable(<String, Object?>{
          'kind': 'map',
          'length': value.length,
          'preview': Map<String, Object?>.unmodifiable(snapshot),
        });
      }
      snapshot[_previewMapKey(entry.key)] = _sanitizeSceneDataDetailValue(
        entry.value,
        depth: depth + 1,
      );
      count += 1;
    }
    return Map<String, Object?>.unmodifiable(snapshot);
  }
  if (value is Iterable) {
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      'kind': 'iterable',
      'preview': List<Object?>.unmodifiable(
        value
            .take(_sceneDataDetailsPreviewMaxItems)
            .map(
              (item) => _sanitizeSceneDataDetailValue(item, depth: depth + 1),
            )
            .toList(growable: false),
      ),
    });
  }
  return _objectPreview(value);
}

String _deriveSceneDataMessage({
  required SceneDataErrorCode code,
  required String? path,
  required Map<String, Object?> details,
}) {
  final template = details['template'];
  if (template is String) {
    switch (template) {
      case 'rootObject':
        return 'Root JSON must be an object.';
      case 'invalidJsonPayload':
        return 'Invalid scene JSON payload.';
      case 'jsonPayloadTooLarge':
        final maxLength = details['maxLength'] ?? '?';
        return 'Scene JSON payload must be <= $maxLength characters.';
      case 'missingField':
        return 'Missing required field ${path ?? '<unknown>'}.';
      case 'fieldType':
        final fieldName = details['fieldName'] ?? path ?? '<unknown>';
        final expected = details['expected'] ?? 'valid value';
        return 'Field $fieldName must be a $expected.';
      case 'fieldMustNotBeEmpty':
        return 'Field ${path ?? '<unknown>'} must not be empty.';
      case 'fieldMaxLength':
        final maxLength = details['maxLength'] ?? '?';
        return 'Field ${path ?? '<unknown>'} length must be <= $maxLength characters.';
      case 'fieldMustBeFinite':
        final fieldName = details['fieldName'] ?? path ?? '<unknown>';
        return 'Field $fieldName must be finite.';
      case 'fieldMustBeInt':
        final fieldName = details['fieldName'] ?? path ?? '<unknown>';
        return 'Field $fieldName must be an int.';
      case 'fieldMustBeGreaterThan':
        final limit = details['limit'] ?? '?';
        return 'Field ${path ?? '<unknown>'} must be > $limit.';
      case 'fieldMustBeAtLeast':
        final limit = details['limit'] ?? '?';
        return 'Field ${path ?? '<unknown>'} must be >= $limit.';
      case 'outOfRange':
        final min = details['min'] ?? '?';
        final max = details['max'] ?? '?';
        return 'Field ${path ?? '<unknown>'} must be within [$min, $max].';
      case 'duplicateNodeId':
        return 'Must be unique across scene layers.';
      case 'duplicateLayerId':
        return 'Field ${path ?? '<unknown>'} must be unique across content layers.';
      case 'maxItems':
        final maxItems = details['maxItems'] ?? '?';
        return 'Field ${path ?? '<unknown>'} must contain at most $maxItems items.';
      case 'maxNodes':
        final maxNodes = details['maxNodes'] ?? '?';
        return 'Scene must contain at most $maxNodes nodes.';
    }
  }
  if (path != null) {
    return 'Field $path is invalid.';
  }
  return switch (code) {
    SceneDataErrorCode.invalidJson => 'Invalid scene JSON payload.',
    SceneDataErrorCode.unsupportedSchemaVersion =>
      'Unsupported scene schema version.',
    SceneDataErrorCode.missingField => 'Missing required field.',
    SceneDataErrorCode.invalidFieldType => 'Field has an invalid type.',
    SceneDataErrorCode.invalidValue => 'Field value is invalid.',
    SceneDataErrorCode.duplicateNodeId => 'Duplicate node id is not allowed.',
    SceneDataErrorCode.duplicateLayerId =>
      'Duplicate content layer id is not allowed.',
    SceneDataErrorCode.outOfRange => 'Field value is out of range.',
  };
}

Object? _sanitizeSceneDataSource(Object? source, {int depth = 0}) {
  if (source == null || source is num || source is bool) {
    return source;
  }
  if (source is String) {
    if (source.length <= _sceneDataSourcePreviewMaxLength) {
      return source;
    }
    return <String, Object?>{
      'kind': 'string',
      'length': source.length,
      'preview': _truncatePreview(source),
    };
  }
  if (source is Error || source is Exception) {
    return _objectPreview(source);
  }
  if (depth >= _sceneDataSourcePreviewMaxDepth) {
    return _objectPreview(source);
  }
  if (source is List) {
    if (_canKeepSceneDataSourceVerbatim(source, depth: depth)) {
      return List<Object?>.unmodifiable(
        source
            .map((item) => _sanitizeSceneDataSource(item, depth: depth + 1))
            .toList(growable: false),
      );
    }
    return <String, Object?>{
      'kind': 'list',
      'length': source.length,
      'preview': source
          .take(_sceneDataSourcePreviewMaxItems)
          .map((item) => _sanitizeSceneDataSource(item, depth: depth + 1))
          .toList(growable: false),
    };
  }
  if (source is Set) {
    if (_canKeepSceneDataSourceVerbatim(source, depth: depth)) {
      return Set<Object?>.unmodifiable(
        source.map((item) => _sanitizeSceneDataSource(item, depth: depth + 1)),
      );
    }
    final values = source
        .take(_sceneDataSourcePreviewMaxItems)
        .toList(growable: false);
    return <String, Object?>{
      'kind': 'set',
      'length': source.length,
      'preview': values
          .map((item) => _sanitizeSceneDataSource(item, depth: depth + 1))
          .toList(growable: false),
    };
  }
  if (source is Map) {
    if (_canKeepSceneDataSourceVerbatim(source, depth: depth)) {
      final snapshot = <Object?, Object?>{};
      for (final entry in source.entries.cast<MapEntry<Object?, Object?>>()) {
        final key = entry.key;
        snapshot[key] = _sanitizeSceneDataSource(entry.value, depth: depth + 1);
      }
      return Map<Object?, Object?>.unmodifiable(snapshot);
    }
    final preview = <String, Object?>{};
    var count = 0;
    for (final entry in source.entries) {
      if (count >= _sceneDataSourcePreviewMaxItems) {
        break;
      }
      preview[_previewMapKey(entry.key)] = _sanitizeSceneDataSource(
        entry.value,
        depth: depth + 1,
      );
      count += 1;
    }
    return <String, Object?>{
      'kind': 'map',
      'length': source.length,
      'preview': preview,
    };
  }
  if (source is Iterable) {
    final preview = <Object?>[];
    var count = 0;
    for (final item in source) {
      if (count >= _sceneDataSourcePreviewMaxItems) {
        break;
      }
      preview.add(_sanitizeSceneDataSource(item, depth: depth + 1));
      count += 1;
    }
    return <String, Object?>{'kind': 'iterable', 'preview': preview};
  }
  return _objectPreview(source);
}

bool _canKeepSceneDataSourceVerbatim(Object? source, {int depth = 0}) {
  if (source == null || source is num || source is bool) {
    return true;
  }
  if (source is String) {
    return source.length <= _sceneDataSourcePreviewMaxLength;
  }
  if (depth >= _sceneDataSourcePreviewMaxDepth) {
    return false;
  }
  if (source is List) {
    return source.length <= _sceneDataSourcePreviewMaxItems &&
        source.every(
          (item) => _canKeepSceneDataSourceVerbatim(item, depth: depth + 1),
        );
  }
  if (source is Set) {
    return source.length <= _sceneDataSourcePreviewMaxItems &&
        source.every(
          (item) => _canKeepSceneDataSourceVerbatim(item, depth: depth + 1),
        );
  }
  if (source is Map) {
    if (source.length > _sceneDataSourcePreviewMaxItems) {
      return false;
    }
    for (final entry in source.entries) {
      if (!_canKeepSceneDataSourceMapKeyVerbatim(entry.key) ||
          !_canKeepSceneDataSourceVerbatim(entry.value, depth: depth + 1)) {
        return false;
      }
    }
    return true;
  }
  return false;
}

bool _canKeepSceneDataSourceMapKeyVerbatim(Object? key) {
  if (key == null || key is num || key is bool) {
    return true;
  }
  return key is String && key.length <= _sceneDataSourcePreviewMaxLength;
}

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
