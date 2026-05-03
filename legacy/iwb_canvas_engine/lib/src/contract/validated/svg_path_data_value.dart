import 'validated_value_support.dart';

class SvgPathDataValue {
  const SvgPathDataValue._(this.value);

  final String value;

  static SvgPathDataValue parse(String raw, {String name = 'svgPathData'}) {
    return SvgPathDataValue._(validatedRequireSvgPathData(raw, name: name));
  }

  static SvgPathDataValue of(String value, {String name = 'svgPathData'}) {
    return parse(value, name: name);
  }

  static SvgPathDataValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'svgPathData',
  }) {
    return SvgPathDataValue._(
      validatedRequireJsonSvgPathData(raw, path: path, fieldName: fieldName),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SvgPathDataValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SvgPathDataValue(length: ${value.length})';
}
