List<T> freezeList<T>(Iterable<T> values) {
  return List<T>.unmodifiable(List<T>.from(values));
}

Map<String, Object?>? freezePayloadMap(Map<String, Object?>? payload) {
  if (payload == null) return null;
  final out = <String, Object?>{};
  for (final entry in payload.entries) {
    out[entry.key] = _freezeValue(entry.value);
  }
  return Map<String, Object?>.unmodifiable(out);
}

Object? _freezeValue(Object? value) {
  if (value is Map<String, Object?>) {
    return freezePayloadMap(value);
  }
  if (value is Map) {
    final out = <Object?, Object?>{};
    for (final entry in value.entries) {
      out[_freezeValue(entry.key)] = _freezeValue(entry.value);
    }
    return Map<Object?, Object?>.unmodifiable(out);
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeValue));
  }
  if (value is Set) {
    return Set<Object?>.unmodifiable(value.map(_freezeValue));
  }
  return value;
}
