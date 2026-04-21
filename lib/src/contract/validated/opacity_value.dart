import 'validated_value_support.dart';

class OpacityValue {
  const OpacityValue._(this.value);

  final double value;

  static OpacityValue parse(String raw, {String name = 'opacity'}) {
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      throw ArgumentError.value(raw, name, 'Must be a number.');
    }
    return of(parsed, name: name);
  }

  static OpacityValue of(double value, {String name = 'opacity'}) {
    return OpacityValue._(validatedRequireOpacity(value, name: name));
  }

  static OpacityValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'opacity',
  }) {
    return OpacityValue._(
      validatedRequireJsonOpacity(raw, path: path, fieldName: fieldName),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OpacityValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'OpacityValue($value)';
}
