import '../scene_contract_limits.dart';
import 'validated_value_support.dart';

class ImageIdValue {
  const ImageIdValue._(this.value);

  final String value;

  static ImageIdValue parse(String raw, {String name = 'imageId'}) {
    return ImageIdValue._(
      validatedRequireString(raw, name: name, maxLength: kMaxImageIdLength),
    );
  }

  static ImageIdValue of(String value, {String name = 'imageId'}) {
    return parse(value, name: name);
  }

  static ImageIdValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'imageId',
  }) {
    return ImageIdValue._(
      validatedRequireJsonString(
        raw,
        path: path,
        fieldName: fieldName,
        maxLength: kMaxImageIdLength,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ImageIdValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ImageIdValue(length: ${value.length})';
}
