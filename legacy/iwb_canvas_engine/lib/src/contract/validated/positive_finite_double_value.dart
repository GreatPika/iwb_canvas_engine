import 'validated_value_support.dart';

class PositiveFiniteDoubleValue {
  const PositiveFiniteDoubleValue._(this.value);

  final double value;

  static PositiveFiniteDoubleValue parse(String raw, {String name = 'value'}) {
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      throw ArgumentError.value(raw, name, 'Must be a number.');
    }
    return of(parsed, name: name);
  }

  static PositiveFiniteDoubleValue of(double value, {String name = 'value'}) {
    return PositiveFiniteDoubleValue._(
      validatedRequirePositiveFiniteDouble(value, name: name),
    );
  }

  static PositiveFiniteDoubleValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'value',
  }) {
    return PositiveFiniteDoubleValue._(
      validatedRequireJsonPositiveFiniteDouble(
        raw,
        path: path,
        fieldName: fieldName,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositiveFiniteDoubleValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PositiveFiniteDoubleValue($value)';
}
