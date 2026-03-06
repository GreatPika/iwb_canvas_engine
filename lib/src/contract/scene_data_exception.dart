/// Unified validation/format error raised by scene import/build boundaries.
class SceneDataException implements FormatException {
  /// Creates a structured scene data error.
  SceneDataException({
    required this.code,
    required this.message,
    this.path,
    Object? source,
  }) : source = _sanitizeSceneDataSource(source);

  /// Canonical constructor used by boundary helpers.
  factory SceneDataException.boundary({
    required SceneDataErrorCode code,
    required String message,
    String? path,
    Object? source,
  }) {
    return SceneDataException(
      code: code,
      message: message,
      path: path,
      source: source,
    );
  }

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

const int _sceneDataSourcePreviewMaxLength = 256;
const int _sceneDataSourcePreviewMaxItems = 5;
const int _sceneDataSourcePreviewMaxDepth = 2;

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
      for (final entry in source.entries) {
        snapshot[entry.key] = _sanitizeSceneDataSource(
          entry.value,
          depth: depth + 1,
        );
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

String _truncatePreview(String value) {
  if (value.length <= _sceneDataSourcePreviewMaxLength) {
    return value;
  }
  return '${value.substring(0, _sceneDataSourcePreviewMaxLength)}...';
}
