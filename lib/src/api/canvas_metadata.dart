import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'canvas_value_equality.dart';
import 'canvas_value_validators.dart';

@immutable
/// Public API v1 declaration for [CanvasMetadata].
final class CanvasMetadata {
  const CanvasMetadata.empty() : _values = const {}, _encodedByteLength = 0;
  factory CanvasMetadata.fromMap(Map<String, Object?> values) {
    final frozen = freezeCanvasMetadata(values);

    return CanvasMetadata._(frozen, utf8.encode(jsonEncode(frozen)).length);
  }

  const CanvasMetadata._(this._values, this._encodedByteLength);

  final Map<String, Object?> _values;
  final int _encodedByteLength;

  bool get isEmpty => _values.isEmpty;
  Iterable<String> get keys => _values.keys;
  bool containsKey(String key) => _values.containsKey(key);
  Object? operator [](String key) => _values[key];

  @override
  bool operator ==(Object other) {
    return other is CanvasMetadata &&
        canvasJsonMapEquals(other._values, _values);
  }

  @override
  int get hashCode => canvasJsonMapHash(_values);
}

@internal
int canvasMetadataEncodedByteLength(CanvasMetadata metadata) {
  return metadata._encodedByteLength;
}
