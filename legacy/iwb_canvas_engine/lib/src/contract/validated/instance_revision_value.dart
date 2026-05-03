import 'validated_value_support.dart';

class InstanceRevisionValue {
  const InstanceRevisionValue._(this.value);

  final int value;

  static InstanceRevisionValue parse(
    String raw, {
    String name = 'instanceRevision',
    bool allowZero = true,
  }) {
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw ArgumentError.value(raw, name, 'Must be an int.');
    }
    return of(parsed, name: name, allowZero: allowZero);
  }

  static InstanceRevisionValue of(
    int value, {
    String name = 'instanceRevision',
    bool allowZero = true,
  }) {
    return InstanceRevisionValue._(
      validatedRequireInstanceRevision(value, name: name, allowZero: allowZero),
    );
  }

  static InstanceRevisionValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'instanceRevision',
    bool allowZero = true,
  }) {
    return InstanceRevisionValue._(
      validatedRequireJsonInt(
        raw,
        path: path,
        fieldName: fieldName,
        allowZero: allowZero,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstanceRevisionValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'InstanceRevisionValue($value)';
}
