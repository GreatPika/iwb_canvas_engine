part of 'scene_data_exception.dart';

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
