part of 'scene_data_exception.dart';

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
