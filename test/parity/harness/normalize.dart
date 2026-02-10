import 'dart:collection';
import 'dart:convert';

const double parityEpsilon = 1e-6;

class NormalizedParityEvent {
  const NormalizedParityEvent({
    required this.type,
    required this.nodeIds,
    this.payloadSubset = const <String, Object?>{},
  });

  final String type;
  final List<String> nodeIds;
  final Map<String, Object?> payloadSubset;

  @override
  String toString() {
    return 'NormalizedParityEvent(type: $type, nodeIds: $nodeIds, payload: $payloadSubset)';
  }
}

class HarnessRunResult {
  const HarnessRunResult({
    required this.sceneJsonCanonical,
    required this.selectedNodeIds,
    required this.events,
  });

  final Object? sceneJsonCanonical;
  final List<String> selectedNodeIds;
  final List<NormalizedParityEvent> events;
}

Object? canonicalizeJsonLike(Object? value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      if (entry.key is! String) continue;
      sorted[entry.key as String] = canonicalizeJsonLike(entry.value);
    }
    return Map<String, Object?>.fromEntries(
      sorted.entries.map((entry) => MapEntry(entry.key, entry.value)),
    );
  }
  if (value is List) {
    return value.map(canonicalizeJsonLike).toList(growable: false);
  }
  if (value is num) {
    return _canonicalNumber(value);
  }
  return value;
}

String canonicalJsonString(Object? value) {
  return jsonEncode(canonicalizeJsonLike(value));
}

List<String> canonicalNodeIds(Iterable<String> ids) {
  final sorted = ids.toSet().toList(growable: false)..sort();
  return sorted;
}

Map<String, Object?> canonicalPayloadSubset(Map<String, Object?> payload) {
  final normalized = <String, Object?>{};
  for (final entry in payload.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value is num) {
      normalized[key] = _canonicalNumber(value);
      continue;
    }
    normalized[key] = value;
  }
  return normalized;
}

Object _canonicalNumber(num value) {
  if (value is int) return value;
  final rounded = (value / parityEpsilon).roundToDouble() * parityEpsilon;
  final asInt = rounded.toInt();
  if ((rounded - asInt).abs() <= parityEpsilon) {
    return asInt;
  }
  return rounded;
}
