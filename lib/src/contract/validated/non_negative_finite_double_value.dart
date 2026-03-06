import 'validated_value_support.dart';

class NonNegativeFiniteDoubleValue {
  const NonNegativeFiniteDoubleValue._(this.value);

  final double value;

  static NonNegativeFiniteDoubleValue parse(
    String raw, {
    String name = 'value',
  }) {
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      throw ArgumentError.value(raw, name, 'Must be a number.');
    }
    return of(parsed, name: name);
  }

  static NonNegativeFiniteDoubleValue of(
    double value, {
    String name = 'value',
  }) {
    return NonNegativeFiniteDoubleValue._(
      validatedRequireNonNegativeFiniteDouble(value, name: name),
    );
  }

  static NonNegativeFiniteDoubleValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'value',
  }) {
    return NonNegativeFiniteDoubleValue._(
      validatedRequireJsonNonNegativeFiniteDouble(
        raw,
        path: path,
        fieldName: fieldName,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NonNegativeFiniteDoubleValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'NonNegativeFiniteDoubleValue($value)';
}
