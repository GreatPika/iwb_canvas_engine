import 'package:characters/characters.dart';

import 'canvas_diagnostic_policy_limits.dart';

const int _maxDiagnosticDetailDepth = 8;
const String _truncatedMarker = '<truncated>';

Map<String, Object?> sanitizeCanvasErrorDetails(Map<String, Object?> details) {
  return sanitizeCanvasErrorDetailsWithLimits(
    details,
    maxPreviewLength: canvasDiagnosticVerbosePreviewLengthDefault,
    maxListEntries: canvasDiagnosticVerboseListEntriesDefault,
  );
}

Map<String, Object?> sanitizeCanvasErrorDetailsWithLimits(
  Map<String, Object?> details, {
  required int maxPreviewLength,
  required int maxListEntries,
}) {
  if (details.isEmpty) {
    return const {};
  }

  final sanitized = <String, Object?>{};
  for (final entry in _limitedEntries(details.entries, maxListEntries)) {
    sanitized[_sanitizeKey(entry.key, maxPreviewLength)] = _sanitizeDetailValue(
      entry.value,
      depth: 1,
      maxPreviewLength: maxPreviewLength,
      maxListEntries: maxListEntries,
    );
  }

  return Map<String, Object?>.unmodifiable(sanitized);
}

Object? _sanitizeDetailValue(
  Object? value, {
  required int depth,
  required int maxPreviewLength,
  required int maxListEntries,
}) {
  if (depth > _maxDiagnosticDetailDepth) {
    return _truncatedMarker;
  }

  return switch (value) {
    null || bool() || int() => value,
    double() =>
      value.isFinite
          ? value
          : _sanitizeNonFiniteNumber(value, maxPreviewLength: maxPreviewLength),
    String() => _sanitizeString(value, maxPreviewLength: maxPreviewLength),
    Map() => _sanitizeMap(
      value,
      depth: depth,
      maxPreviewLength: maxPreviewLength,
      maxListEntries: maxListEntries,
    ),
    Iterable<Object?>() => _sanitizeIterable(
      value,
      depth: depth,
      maxPreviewLength: maxPreviewLength,
      maxListEntries: maxListEntries,
    ),
    _ => _sanitizeUnsupportedObject(value, maxPreviewLength: maxPreviewLength),
  };
}

Map<String, Object?> _sanitizeMap(
  Map<Object?, Object?> value, {
  required int depth,
  required int maxPreviewLength,
  required int maxListEntries,
}) {
  final sanitized = <String, Object?>{};
  for (final entry in _limitedEntries(value.entries, maxListEntries)) {
    sanitized[_sanitizeKey(entry.key, maxPreviewLength)] = _sanitizeDetailValue(
      entry.value,
      depth: depth + 1,
      maxPreviewLength: maxPreviewLength,
      maxListEntries: maxListEntries,
    );
  }

  return Map<String, Object?>.unmodifiable(sanitized);
}

List<Object?> _sanitizeIterable(
  Iterable<Object?> value, {
  required int depth,
  required int maxPreviewLength,
  required int maxListEntries,
}) {
  return List<Object?>.unmodifiable(
    _limitedEntries(value, maxListEntries).map(
      (entry) => _sanitizeDetailValue(
        entry,
        depth: depth + 1,
        maxPreviewLength: maxPreviewLength,
        maxListEntries: maxListEntries,
      ),
    ),
  );
}

Iterable<T> _limitedEntries<T>(Iterable<T> values, int maxListEntries) {
  return values.take(maxListEntries);
}

String _sanitizeKey(Object? key, int maxPreviewLength) {
  return _sanitizeString(
    key is String ? key : key.runtimeType.toString(),
    maxPreviewLength: maxPreviewLength,
  );
}

String _sanitizeString(String value, {required int maxPreviewLength}) {
  if (value.length <= maxPreviewLength) {
    return value;
  }

  return '${value.characters.take(maxPreviewLength)}'
      '$_truncatedMarker';
}

Map<String, Object?> _sanitizeNonFiniteNumber(
  double value, {
  required int maxPreviewLength,
}) {
  return Map<String, Object?>.unmodifiable({
    'unsupportedType': 'nonFiniteNumber',
    'preview': _sanitizeString(
      value.toString(),
      maxPreviewLength: maxPreviewLength,
    ),
  });
}

Map<String, Object?> _sanitizeUnsupportedObject(
  Object value, {
  required int maxPreviewLength,
}) {
  return Map<String, Object?>.unmodifiable({
    'unsupportedType': _sanitizeString(
      value.runtimeType.toString(),
      maxPreviewLength: maxPreviewLength,
    ),
  });
}
