import '../contract/scene_data_exception.dart';
import '../contract/validated/validated_value_support.dart';

typedef JsonValidatedFieldParser<T> =
    T Function(
      Object? value, {
      required String path,
      required String fieldName,
    });

typedef _SceneBuilderJsonFieldAccess = ({
  bool isPresent,
  String path,
  Object? value,
});
typedef _SceneBuilderTypedFieldSpec = ({bool isRequired, String typeLabel});

String sceneBuilderPathAt(String pathPrefix, String segment) {
  if (pathPrefix.isEmpty) return segment;
  if (segment.startsWith('[')) return '$pathPrefix$segment';
  return '$pathPrefix.$segment';
}

Map<String, Object?> sceneBuilderCastMap(
  Map<Object?, Object?> value, {
  String? path,
}) {
  final out = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidFieldType,
        path: path,
        message: 'JSON object keys must be strings.',
      );
    }
    out[key] = entry.value;
  }
  return out;
}

Map<String, Object?> sceneBuilderRequireObjectValue(
  Object? value, {
  required String path,
  required String objectName,
}) {
  if (value is! Map) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: '$objectName must be an object.',
    );
  }
  return sceneBuilderCastMap(value, path: path);
}

_SceneBuilderJsonFieldAccess _sceneBuilderFieldAccess(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final path = sceneBuilderPathAt(pathPrefix, key);
  final isPresent = json.containsKey(key);
  return (
    isPresent: isPresent,
    path: path,
    value: isPresent ? json[key] : null,
  );
}

Object? _sceneBuilderRequireAccessedValue(_SceneBuilderJsonFieldAccess access) {
  if (!access.isPresent) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: access.path,
      message: 'Missing required field ${access.path}.',
    );
  }
  return access.value;
}

T sceneBuilderRequireParsedField<T>(
  Map<String, Object?> json,
  String key, {
  required JsonValidatedFieldParser<T> parse,
  String pathPrefix = '',
}) {
  final access = _sceneBuilderFieldAccess(json, key, pathPrefix: pathPrefix);
  return parse(
    _sceneBuilderRequireAccessedValue(access),
    path: access.path,
    fieldName: key,
  );
}

T? sceneBuilderOptionalParsedField<T>(
  Map<String, Object?> json,
  String key, {
  required JsonValidatedFieldParser<T> parse,
  required String pathPrefix,
}) {
  final access = _sceneBuilderFieldAccess(json, key, pathPrefix: pathPrefix);
  final value = access.value;
  if (!access.isPresent || value == null) {
    return null;
  }
  return parse(value, path: access.path, fieldName: key);
}

T _sceneBuilderRequireTypedValue<T>(
  Object? value, {
  required String path,
  required String fieldName,
  required String typeLabel,
}) {
  if (value is! T) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $fieldName must be a $typeLabel.',
    );
  }
  return value;
}

Map<String, Object?> _sceneBuilderParseFieldObjectMap(
  Object? value, {
  required String path,
  required String fieldName,
}) {
  return sceneBuilderRequireObjectValue(
    value,
    path: path,
    objectName: 'Field $fieldName',
  );
}

T? _sceneBuilderTypedField<T>(
  Map<String, Object?> json,
  String key, {
  required _SceneBuilderTypedFieldSpec spec,
  String pathPrefix = '',
}) {
  T parse(Object? value, {required String path, required String fieldName}) {
    return _sceneBuilderRequireTypedValue<T>(
      value,
      path: path,
      fieldName: fieldName,
      typeLabel: spec.typeLabel,
    );
  }

  if (spec.isRequired) {
    return sceneBuilderRequireParsedField(
      json,
      key,
      pathPrefix: pathPrefix,
      parse: parse,
    );
  }
  return sceneBuilderOptionalParsedField(
    json,
    key,
    pathPrefix: pathPrefix,
    parse: parse,
  );
}

Map<String, Object?> sceneBuilderRequireMap(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  return sceneBuilderRequireParsedField(
    json,
    key,
    pathPrefix: pathPrefix,
    parse: _sceneBuilderParseFieldObjectMap,
  );
}

List<Object?> sceneBuilderRequireList(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
  int? maxLength,
}) {
  return sceneBuilderRequireParsedField(
    json,
    key,
    pathPrefix: pathPrefix,
    parse: (value, {required path, required fieldName}) {
      if (value is! List) {
        throw SceneDataException(
          code: SceneDataErrorCode.invalidFieldType,
          path: path,
          message: 'Field $fieldName must be a list.',
        );
      }
      final list = List<Object?>.from(value);
      if (maxLength != null && list.length > maxLength) {
        throw SceneDataException(
          code: SceneDataErrorCode.invalidValue,
          path: path,
          message: 'Field $path must contain at most $maxLength items.',
          source: list.length,
        );
      }
      return list;
    },
  );
}

Object? sceneBuilderRequireField(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  return _sceneBuilderRequireAccessedValue(
    _sceneBuilderFieldAccess(json, key, pathPrefix: pathPrefix),
  );
}

T sceneBuilderRequireValidatedField<T>(
  Map<String, Object?> json,
  String key, {
  required JsonValidatedFieldParser<T> parse,
  String pathPrefix = '',
}) {
  return sceneBuilderRequireParsedField(
    json,
    key,
    parse: parse,
    pathPrefix: pathPrefix,
  );
}

T? sceneBuilderOptionalValidatedField<T>(
  Map<String, Object?> json,
  String key, {
  required JsonValidatedFieldParser<T> parse,
  required String pathPrefix,
}) {
  return sceneBuilderOptionalParsedField(
    json,
    key,
    parse: parse,
    pathPrefix: pathPrefix,
  );
}

T? sceneBuilderOptionalTypedField<T>(
  Map<String, Object?> json,
  String key, {
  required String typeLabel,
  String pathPrefix = '',
}) {
  return _sceneBuilderTypedField<T>(
    json,
    key,
    pathPrefix: pathPrefix,
    spec: (isRequired: false, typeLabel: typeLabel),
  );
}

Map<String, Object?>? sceneBuilderOptionalObjectMap(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  return sceneBuilderOptionalParsedField(
    json,
    key,
    pathPrefix: pathPrefix,
    parse: _sceneBuilderParseFieldObjectMap,
  );
}

String sceneBuilderRequireStringValue(
  Object? value, {
  required String field,
  required String path,
}) {
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Items of $field must be strings.',
    );
  }
  return value;
}

T sceneBuilderRequireTypedField<T>(
  Map<String, Object?> json,
  String key, {
  required String typeLabel,
  String pathPrefix = '',
}) {
  return _sceneBuilderTypedField<T>(
        json,
        key,
        pathPrefix: pathPrefix,
        spec: (isRequired: true, typeLabel: typeLabel),
      )
      as T;
}

String sceneBuilderRequireStringField(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  return sceneBuilderRequireTypedField<String>(
    json,
    key,
    pathPrefix: pathPrefix,
    typeLabel: 'string',
  );
}

bool sceneBuilderRequireBoolField(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  return sceneBuilderRequireTypedField<bool>(
    json,
    key,
    pathPrefix: pathPrefix,
    typeLabel: 'bool',
  );
}

double sceneBuilderRequireDoubleValue(
  Object? value, {
  required String field,
  required String path,
}) {
  return validatedRequireJsonFiniteDoubleItem(
    value,
    path: path,
    fieldName: field,
  );
}
