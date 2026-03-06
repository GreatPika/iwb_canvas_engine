import '../scene_contract_limits.dart';
import 'validated_value_support.dart';

class TextContentValue {
  const TextContentValue._(this.value);

  final String value;

  static TextContentValue parse(String raw, {String name = 'text'}) {
    return TextContentValue._(
      validatedRequireString(raw, name: name, maxLength: kMaxTextLength),
    );
  }

  static TextContentValue of(String value, {String name = 'text'}) {
    return parse(value, name: name);
  }

  static TextContentValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'text',
  }) {
    return TextContentValue._(
      validatedRequireJsonString(
        raw,
        path: path,
        fieldName: fieldName,
        maxLength: kMaxTextLength,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextContentValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TextContentValue(length: ${value.length})';
}
