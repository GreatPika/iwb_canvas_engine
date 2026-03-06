import '../scene_contract_limits.dart';
import 'validated_value_support.dart';

const String _layerIdGeneratedPrefix = 'layer-';

class LayerIdValue {
  const LayerIdValue._(this.value);

  final String value;

  static LayerIdValue parse(String raw, {String name = 'layerId'}) {
    return LayerIdValue._(
      validatedRequireString(
        raw,
        name: name,
        maxLength: kMaxLayerIdLength,
        allowEmpty: false,
      ),
    );
  }

  static LayerIdValue of(String value, {String name = 'layerId'}) {
    return parse(value, name: name);
  }

  static LayerIdValue fromJson(
    Object? raw, {
    required String path,
    String fieldName = 'id',
  }) {
    return LayerIdValue._(
      validatedRequireJsonString(
        raw,
        path: path,
        fieldName: fieldName,
        maxLength: kMaxLayerIdLength,
        allowEmpty: false,
      ),
    );
  }

  static LayerIdValue generate(int seed) {
    return LayerIdValue._(
      validatedParseGeneratedId(
        prefix: _layerIdGeneratedPrefix,
        seed: seed,
        maxLength: kMaxLayerIdLength,
        name: 'layerIdSeed',
      ),
    );
  }

  static bool isGeneratedLegacyFormat(String value) {
    return tryParseGeneratedSeed(value) != null;
  }

  static int? tryParseGeneratedSeed(String value) {
    return validatedTryParseGeneratedSeed(
      value,
      prefix: _layerIdGeneratedPrefix,
      maxLength: kMaxLayerIdLength,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LayerIdValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'LayerIdValue($value)';
}
