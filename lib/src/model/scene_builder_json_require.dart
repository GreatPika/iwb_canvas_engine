import '../contract/scene_data_exception.dart';
import '../contract/validated/validated_value_support.dart';

typedef JsonValidatedFieldParser<T> =
    T Function(
      Object? value, {
      required String path,
      required String fieldName,
    });

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

Map<String, Object?> sceneBuilderRequireMap(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final path = sceneBuilderPathAt(pathPrefix, key);
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: path,
      message: 'Missing required field $path.',
    );
  }
  final value = json[key];
  if (value is! Map<Object?, Object?>) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $key must be an object.',
    );
  }
  return sceneBuilderCastMap(value, path: path);
}

List<Object?> sceneBuilderRequireList(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
  int? maxLength,
}) {
  final path = sceneBuilderPathAt(pathPrefix, key);
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: path,
      message: 'Missing required field $path.',
    );
  }
  final value = json[key];
  if (value is! List) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $key must be a list.',
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
}

Object? sceneBuilderRequireField(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final path = sceneBuilderPathAt(pathPrefix, key);
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: path,
      message: 'Missing required field $path.',
    );
  }
  return json[key];
}

T sceneBuilderRequireValidatedField<T>(
  Map<String, Object?> json,
  String key, {
  required JsonValidatedFieldParser<T> parse,
  String pathPrefix = '',
}) {
  final path = sceneBuilderPathAt(pathPrefix, key);
  return parse(
    sceneBuilderRequireField(json, key, pathPrefix: pathPrefix),
    path: path,
    fieldName: key,
  );
}

T? sceneBuilderOptionalValidatedField<T>(
  Map<String, Object?> json,
  String key, {
  required JsonValidatedFieldParser<T> parse,
  required String pathPrefix,
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final value = json[key];
  if (value == null) {
    return null;
  }
  final path = sceneBuilderPathAt(pathPrefix, key);
  return parse(value, path: path, fieldName: key);
}

T? sceneBuilderOptionalTypedField<T>(
  Map<String, Object?> json,
  String key, {
  required String typeLabel,
  String pathPrefix = '',
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final value = json[key];
  if (value == null) {
    return null;
  }
  final path = sceneBuilderPathAt(pathPrefix, key);
  if (value is! T) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $key must be a $typeLabel.',
    );
  }
  return value as T;
}

Map<String, Object?>? sceneBuilderOptionalObjectMap(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final value = json[key];
  if (value == null) {
    return null;
  }
  final path = sceneBuilderPathAt(pathPrefix, key);
  if (value is! Map<Object?, Object?>) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $key must be an object.',
    );
  }
  return sceneBuilderCastMap(value, path: path);
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
  final path = sceneBuilderPathAt(pathPrefix, key);
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: path,
      message: 'Missing required field $path.',
    );
  }
  final value = json[key];
  if (value is! T) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $key must be a $typeLabel.',
    );
  }
  return value;
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
