import 'dart:collection';

List<T> freezeList<T>(Iterable<T> values) {
  if (values is _FrozenList<T>) {
    return values;
  }
  return _FrozenList<T>(List<T>.from(values));
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

final class _FrozenList<T> extends ListBase<T> {
  _FrozenList(List<T> values) : _values = List<T>.unmodifiable(values);

  final List<T> _values;

  @override
  int get length => _values.length;

  @override
  set length(int newLength) {
    throw UnsupportedError('Cannot modify an immutable list.');
  }

  @override
  T operator [](int index) => _values[index];

  @override
  void operator []=(int index, T value) {
    throw UnsupportedError('Cannot modify an immutable list.');
  }
}
