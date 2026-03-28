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

Map<String, Object?> _sanitizeSceneDataDetails(Map<String, Object?> details) {
  if (details.isEmpty) {
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
    return _sanitizeSceneDataDetailString(value);
  }
  if (depth >= _sceneDataDetailsPreviewMaxDepth) {
    return _sanitizeSceneDataDetailAtDepthLimit(value);
  }
  if (value is List) {
    return _sanitizeSceneDataDetailList(value, depth: depth);
  }
  if (value is Map) {
    return _sanitizeSceneDataDetailMap(value, depth: depth);
  }
  if (value is Iterable) {
    return _sanitizeSceneDataDetailIterable(value, depth: depth);
  }
  return _objectPreview(value);
}

Object _sanitizeSceneDataDetailString(String value) {
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

Object _sanitizeSceneDataDetailAtDepthLimit(Object value) {
  return _objectPreview(value);
}

Object _sanitizeSceneDataDetailList(List<Object?> value, {required int depth}) {
  if (value.length <= _sceneDataDetailsPreviewMaxItems) {
    return List<Object?>.unmodifiable(
      value
          .map((item) => _sanitizeSceneDataDetailValue(item, depth: depth + 1))
          .toList(growable: false),
    );
  }
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    'kind': 'list',
    'length': value.length,
    'preview': List<Object?>.unmodifiable(
      value
          .take(_sceneDataDetailsPreviewMaxItems)
          .map((item) => _sanitizeSceneDataDetailValue(item, depth: depth + 1))
          .toList(growable: false),
    ),
  });
}

Object _sanitizeSceneDataDetailMap(
  Map<Object?, Object?> value, {
  required int depth,
}) {
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

Object _sanitizeSceneDataDetailIterable(
  Iterable<Object?> value, {
  required int depth,
}) {
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    'kind': 'iterable',
    'preview': List<Object?>.unmodifiable(
      value
          .take(_sceneDataDetailsPreviewMaxItems)
          .map((item) => _sanitizeSceneDataDetailValue(item, depth: depth + 1))
          .toList(growable: false),
    ),
  });
}

String _deriveSceneDataMessage({
  required SceneDataErrorCode code,
  required String? path,
  required Map<String, Object?> details,
}) {
  final templateMessage = _deriveSceneDataTemplateMessage(
    template: details['template'],
    path: path,
    details: details,
  );
  if (templateMessage != null) {
    return templateMessage;
  }
  return _deriveSceneDataFallbackMessage(code: code, path: path);
}

String? _deriveSceneDataTemplateMessage({
  required Object? template,
  required String? path,
  required Map<String, Object?> details,
}) {
  if (template is! String) {
    return null;
  }
  return _deriveSceneDataJsonTemplateMessage(
        template: template,
        details: details,
      ) ??
      _deriveSceneDataFieldTemplateMessage(
        template: template,
        path: path,
        details: details,
      ) ??
      _deriveSceneDataDuplicateTemplateMessage(
        template: template,
        path: path,
      ) ??
      _deriveSceneDataLimitTemplateMessage(
        template: template,
        path: path,
        details: details,
      );
}

String? _deriveSceneDataJsonTemplateMessage({
  required String template,
  required Map<String, Object?> details,
}) {
  return switch (template) {
    'rootObject' => 'Root JSON must be an object.',
    'invalidJsonPayload' => 'Invalid scene JSON payload.',
    'jsonPayloadTooLarge' =>
      'Scene JSON payload must be <= ${details['maxLength'] ?? '?'} characters.',
    _ => null,
  };
}

String? _deriveSceneDataFieldTemplateMessage({
  required String template,
  required String? path,
  required Map<String, Object?> details,
}) {
  final pathLabel = _sceneDataPathLabel(path);
  final fieldName = details['fieldName'] ?? pathLabel;
  return _deriveSceneDataFieldShapeTemplateMessage(
        template: template,
        pathLabel: pathLabel,
        fieldName: fieldName,
        details: details,
      ) ??
      _deriveSceneDataFieldRangeTemplateMessage(
        template: template,
        pathLabel: pathLabel,
        details: details,
      );
}

String? _deriveSceneDataFieldShapeTemplateMessage({
  required String template,
  required String pathLabel,
  required Object fieldName,
  required Map<String, Object?> details,
}) {
  return switch (template) {
    'missingField' => 'Missing required field $pathLabel.',
    'fieldType' =>
      'Field $fieldName must be a ${details['expected'] ?? 'valid value'}.',
    'fieldMustNotBeEmpty' => 'Field $pathLabel must not be empty.',
    'fieldMaxLength' =>
      'Field $pathLabel length must be <= ${details['maxLength'] ?? '?'} characters.',
    'fieldMustBeFinite' => 'Field $fieldName must be finite.',
    'fieldMustBeInt' => 'Field $fieldName must be an int.',
    _ => null,
  };
}

String? _deriveSceneDataFieldRangeTemplateMessage({
  required String template,
  required String pathLabel,
  required Map<String, Object?> details,
}) {
  return switch (template) {
    'fieldMustBeGreaterThan' =>
      'Field $pathLabel must be > ${details['limit'] ?? '?'}.',
    'fieldMustBeAtLeast' =>
      'Field $pathLabel must be >= ${details['limit'] ?? '?'}.',
    'outOfRange' =>
      'Field $pathLabel must be within '
          '[${details['min'] ?? '?'}, ${details['max'] ?? '?'}].',
    _ => null,
  };
}

String? _deriveSceneDataDuplicateTemplateMessage({
  required String template,
  required String? path,
}) {
  return switch (template) {
    'duplicateNodeId' => 'Must be unique across scene layers.',
    'duplicateLayerId' =>
      'Field ${_sceneDataPathLabel(path)} must be unique across content layers.',
    _ => null,
  };
}

String? _deriveSceneDataLimitTemplateMessage({
  required String template,
  required String? path,
  required Map<String, Object?> details,
}) {
  return switch (template) {
    'maxItems' =>
      'Field ${_sceneDataPathLabel(path)} must contain at most '
          "${details['maxItems'] ?? '?'} items.",
    'maxNodes' =>
      'Scene must contain at most ${details['maxNodes'] ?? '?'} nodes.',
    _ => null,
  };
}

String _deriveSceneDataFallbackMessage({
  required SceneDataErrorCode code,
  required String? path,
}) {
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

String _sceneDataPathLabel(String? path) => path ?? '<unknown>';

Object? _sanitizeSceneDataSource(Object? source, {int depth = 0}) {
  if (source == null || source is num || source is bool) {
    return source;
  }
  if (source is String) {
    return _sanitizeSceneDataSourceString(source);
  }
  if (source is Error || source is Exception) {
    return _objectPreview(source);
  }
  if (depth >= _sceneDataSourcePreviewMaxDepth) {
    return _objectPreview(source);
  }
  return _sanitizeSceneDataStructuredSource(source, depth: depth);
}

Object _sanitizeSceneDataSourceString(String source) {
  if (source.length <= _sceneDataSourcePreviewMaxLength) {
    return source;
  }
  return <String, Object?>{
    'kind': 'string',
    'length': source.length,
    'preview': _truncatePreview(source),
  };
}

Object _sanitizeSceneDataSourceList(
  List<Object?> source, {
  required int depth,
}) {
  if (_canKeepSceneDataSourceVerbatim(source, depth: depth)) {
    return _snapshotSceneDataSourceListVerbatim(source, depth: depth);
  }
  return _previewSceneDataSourceList(source, depth: depth);
}

Object _sanitizeSceneDataSourceSet(Set<Object?> source, {required int depth}) {
  if (_canKeepSceneDataSourceVerbatim(source, depth: depth)) {
    return _snapshotSceneDataSourceSetVerbatim(source, depth: depth);
  }
  return _previewSceneDataSourceSet(source, depth: depth);
}

Object _sanitizeSceneDataSourceMap(
  Map<Object?, Object?> source, {
  required int depth,
}) {
  if (_canKeepSceneDataSourceVerbatim(source, depth: depth)) {
    return _snapshotSceneDataSourceMapVerbatim(source, depth: depth);
  }
  return _previewSceneDataSourceMap(source, depth: depth);
}

List<Object?> _snapshotSceneDataSourceListVerbatim(
  List<Object?> source, {
  required int depth,
}) {
  return List<Object?>.unmodifiable(
    source
        .map((item) => _sanitizeSceneDataSource(item, depth: depth + 1))
        .toList(growable: false),
  );
}

Set<Object?> _snapshotSceneDataSourceSetVerbatim(
  Set<Object?> source, {
  required int depth,
}) {
  return Set<Object?>.unmodifiable(
    source.map((item) => _sanitizeSceneDataSource(item, depth: depth + 1)),
  );
}

Map<Object?, Object?> _snapshotSceneDataSourceMapVerbatim(
  Map<Object?, Object?> source, {
  required int depth,
}) {
  final snapshot = <Object?, Object?>{};
  for (final entry in source.entries) {
    snapshot[entry.key] = _sanitizeSceneDataSource(
      entry.value,
      depth: depth + 1,
    );
  }
  return Map<Object?, Object?>.unmodifiable(snapshot);
}

Map<String, Object?> _previewSceneDataSourceList(
  List<Object?> source, {
  required int depth,
}) {
  return <String, Object?>{
    'kind': 'list',
    'length': source.length,
    'preview': source
        .take(_sceneDataSourcePreviewMaxItems)
        .map((item) => _sanitizeSceneDataSource(item, depth: depth + 1))
        .toList(growable: false),
  };
}

Map<String, Object?> _previewSceneDataSourceSet(
  Set<Object?> source, {
  required int depth,
}) {
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

Map<String, Object?> _previewSceneDataSourceMap(
  Map<Object?, Object?> source, {
  required int depth,
}) {
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

Map<String, Object?> _previewSceneDataSourceIterable(
  Iterable<Object?> source, {
  required int depth,
}) {
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

Object _sanitizeSceneDataStructuredSource(Object source, {required int depth}) {
  if (source is List<Object?>) {
    return _sanitizeSceneDataSourceList(source, depth: depth);
  }
  if (source is Set<Object?>) {
    return _sanitizeSceneDataSourceSet(source, depth: depth);
  }
  if (source is Map<Object?, Object?>) {
    return _sanitizeSceneDataSourceMap(source, depth: depth);
  }
  if (source is Iterable<Object?>) {
    return _previewSceneDataSourceIterable(source, depth: depth);
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
  if (source case final List<Object?> values) {
    return _canKeepSceneDataSourceListVerbatim(values, depth: depth);
  }
  if (source case final Set<Object?> values) {
    return _canKeepSceneDataSourceSetVerbatim(values, depth: depth);
  }
  if (source case final Map<Object?, Object?> values) {
    return _canKeepSceneDataSourceMapVerbatim(values, depth: depth);
  }
  return false;
}

bool _canKeepSceneDataSourceListVerbatim(
  List<Object?> source, {
  required int depth,
}) {
  return source.length <= _sceneDataSourcePreviewMaxItems &&
      source.every(
        (item) => _canKeepSceneDataSourceVerbatim(item, depth: depth + 1),
      );
}

bool _canKeepSceneDataSourceSetVerbatim(
  Set<Object?> source, {
  required int depth,
}) {
  return source.length <= _sceneDataSourcePreviewMaxItems &&
      source.every(
        (item) => _canKeepSceneDataSourceVerbatim(item, depth: depth + 1),
      );
}

bool _canKeepSceneDataSourceMapVerbatim(
  Map<Object?, Object?> source, {
  required int depth,
}) {
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

bool _canKeepSceneDataSourceMapKeyVerbatim(Object? key) {
  if (key == null || key is num || key is bool) {
    return true;
  }
  return key is String && key.length <= _sceneDataSourcePreviewMaxLength;
}
