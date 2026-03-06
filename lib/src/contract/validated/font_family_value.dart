import '../scene_contract_limits.dart';
import 'validated_value_support.dart';

class FontFamilyValue {
  const FontFamilyValue._(this.value);

  final String value;

  static FontFamilyValue parse(String raw, {String name = 'fontFamily'}) {
    return FontFamilyValue._(
      validatedRequireString(
        raw,
        name: name,
        maxLength: kMaxFontFamilyLength,
        allowEmpty: false,
      ),
    );
  }

  static FontFamilyValue of(String value, {String name = 'fontFamily'}) {
    return parse(value, name: name);
  }

  static FontFamilyValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'fontFamily',
  }) {
    return FontFamilyValue._(
      validatedRequireJsonString(
        raw,
        path: path,
        fieldName: fieldName,
        maxLength: kMaxFontFamilyLength,
        allowEmpty: false,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFamilyValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FontFamilyValue($value)';
}
