import 'dart:ui';

import 'validated_value_support.dart';

class FiniteOffsetValue {
  const FiniteOffsetValue._(this.value);

  final Offset value;

  static FiniteOffsetValue of(Offset value, {String name = 'offset'}) {
    return FiniteOffsetValue._(validatedRequireFiniteOffset(value, name: name));
  }

  static FiniteOffsetValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'offset',
  }) {
    return FiniteOffsetValue._(
      validatedRequireJsonFiniteOffset(raw, path: path, fieldName: fieldName),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiniteOffsetValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FiniteOffsetValue($value)';
}
