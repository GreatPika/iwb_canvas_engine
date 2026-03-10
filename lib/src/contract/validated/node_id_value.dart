import '../scene_contract_limits.dart';
import 'validated_value_support.dart';

class NodeIdValue {
  const NodeIdValue._(this.value);

  final String value;

  static NodeIdValue parse(String raw, {String name = 'nodeId'}) {
    return NodeIdValue._(
      validatedRequireString(
        raw,
        name: name,
        maxLength: kMaxNodeIdLength,
        allowEmpty: false,
      ),
    );
  }

  static NodeIdValue of(String value, {String name = 'nodeId'}) {
    return parse(value, name: name);
  }

  static NodeIdValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'id',
  }) {
    return NodeIdValue._(
      validatedRequireJsonString(
        raw,
        path: path,
        fieldName: fieldName,
        maxLength: kMaxNodeIdLength,
        allowEmpty: false,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeIdValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'NodeIdValue($value)';
}
