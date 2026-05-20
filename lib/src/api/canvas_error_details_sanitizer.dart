import 'canvas_diagnostic_policy_limits.dart';

const int _maxDiagnosticDetailDepth = 8;
const String _truncatedMarker = '<truncated>';

Map<String, Object?> sanitizeCanvasErrorDetails(Map<String, Object?> details) {
  if (details.isEmpty) {
    return const {};
  }

  final sanitized = <String, Object?>{};
  for (final entry in _limitedEntries(details.entries)) {
    sanitized[_sanitizeKey(entry.key)] = _sanitizeDetailValue(
      entry.value,
      depth: 1,
    );
  }

  return Map<String, Object?>.unmodifiable(sanitized);
}

Object? _sanitizeDetailValue(Object? value, {required int depth}) {
  if (depth > _maxDiagnosticDetailDepth) {
    return _truncatedMarker;
  }

  return switch (value) {
    null || bool() || int() => value,
    double() => value.isFinite ? value : _sanitizeNonFiniteNumber(value),
    String() => _sanitizeString(value),
    Map() => _sanitizeMap(value, depth: depth),
    Iterable<Object?>() => _sanitizeIterable(value, depth: depth),
    _ => _sanitizeUnsupportedObject(value),
  };
}

Map<String, Object?> _sanitizeMap(
  Map<Object?, Object?> value, {
  required int depth,
}) {
  final sanitized = <String, Object?>{};
  for (final entry in _limitedEntries(value.entries)) {
    sanitized[_sanitizeKey(entry.key)] = _sanitizeDetailValue(
      entry.value,
      depth: depth + 1,
    );
  }

  return Map<String, Object?>.unmodifiable(sanitized);
}

List<Object?> _sanitizeIterable(Iterable<Object?> value, {required int depth}) {
  return List<Object?>.unmodifiable(
    _limitedEntries(
      value,
    ).map((entry) => _sanitizeDetailValue(entry, depth: depth + 1)),
  );
}

Iterable<T> _limitedEntries<T>(Iterable<T> values) {
  return values.take(canvasDiagnosticVerboseListEntriesDefault);
}

String _sanitizeKey(Object? key) {
  return _sanitizeString(key is String ? key : key.runtimeType.toString());
}

String _sanitizeString(String value) {
  if (value.length <= canvasDiagnosticVerbosePreviewLengthDefault) {
    return value;
  }

  return '${value.substring(0, canvasDiagnosticVerbosePreviewLengthDefault)}'
      '$_truncatedMarker';
}

Map<String, Object?> _sanitizeNonFiniteNumber(double value) {
  return Map<String, Object?>.unmodifiable({
    'unsupportedType': 'nonFiniteNumber',
    'preview': value.toString(),
  });
}

Map<String, Object?> _sanitizeUnsupportedObject(Object value) {
  return Map<String, Object?>.unmodifiable({
    'unsupportedType': _sanitizeString(value.runtimeType.toString()),
  });
}
