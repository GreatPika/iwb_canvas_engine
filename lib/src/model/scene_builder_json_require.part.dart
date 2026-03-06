part of 'scene_builder.dart';

String _pathAt(String pathPrefix, String segment) {
  if (pathPrefix.isEmpty) return segment;
  if (segment.startsWith('[')) return '$pathPrefix$segment';
  return '$pathPrefix.$segment';
}

Map<String, Object?> _castMap(Map<Object?, Object?> value, {String? path}) {
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

Map<String, Object?> _requireMap(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final path = _pathAt(pathPrefix, key);
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
  return _castMap(value, path: path);
}

List<Object?> _requireList(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
  int? maxLength,
}) {
  final path = _pathAt(pathPrefix, key);
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

Object? _requireField(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final path = _pathAt(pathPrefix, key);
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: path,
      message: 'Missing required field $path.',
    );
  }
  return json[key];
}

String _requireString(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final path = _pathAt(pathPrefix, key);
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: path,
      message: 'Missing required field $path.',
    );
  }
  final value = json[key];
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $key must be a string.',
    );
  }
  return value;
}

String _requireStringValue(
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

bool _requireBool(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final path = _pathAt(pathPrefix, key);
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: path,
      message: 'Missing required field $path.',
    );
  }
  final value = json[key];
  if (value is! bool) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $key must be a bool.',
    );
  }
  return value;
}

int _requireInt(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final path = _pathAt(pathPrefix, key);
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: path,
      message: 'Missing required field $path.',
    );
  }
  return validatedRequireJsonInt(
    json[key],
    path: path,
    fieldName: key,
    allowZero: false,
  );
}

double _requireDouble(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final path = _pathAt(pathPrefix, key);
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: path,
      message: 'Missing required field $path.',
    );
  }
  return validatedRequireJsonFiniteDouble(
    json[key],
    path: path,
    fieldName: key,
  );
}

double _requireDoubleValue(
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

Transform2D _decodeTransform2D(
  Map<String, Object?> json, {
  String pathPrefix = '',
}) {
  return Transform2D(
    a: _requireDouble(json, 'a', pathPrefix: pathPrefix),
    b: _requireDouble(json, 'b', pathPrefix: pathPrefix),
    c: _requireDouble(json, 'c', pathPrefix: pathPrefix),
    d: _requireDouble(json, 'd', pathPrefix: pathPrefix),
    tx: _requireDouble(json, 'tx', pathPrefix: pathPrefix),
    ty: _requireDouble(json, 'ty', pathPrefix: pathPrefix),
  );
}

Size _requireSize(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final map = _requireMap(json, key, pathPrefix: pathPrefix);
  final sizePath = _pathAt(pathPrefix, key);
  return Size(
    _requireDouble(map, 'w', pathPrefix: sizePath),
    _requireDouble(map, 'h', pathPrefix: sizePath),
  );
}

Size? _optionalSizeMap(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  final path = _pathAt(pathPrefix, key);
  if (value is! Map) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $key must be an object.',
    );
  }
  final parsed = _castMap(value, path: path);
  final width = parsed['w'];
  final height = parsed['h'];
  if (width is! num || height is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Optional size must be numeric.',
    );
  }
  final w = width.toDouble();
  final h = height.toDouble();
  if (!w.isFinite || !h.isFinite) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      message: 'Optional size must be finite.',
    );
  }
  return Size(w, h);
}

Color _parseColor(String value, {String? path}) {
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (normalized.length == 6) {
    final parsed = int.tryParse('FF$normalized', radix: 16);
    if (parsed == null) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: path,
        message: 'Invalid color: $value.',
        source: value,
      );
    }
    return Color(parsed);
  }
  if (normalized.length == 8) {
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: path,
        message: 'Invalid color: $value.',
        source: value,
      );
    }
    return Color(parsed);
  }
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: path,
    message: 'Invalid color: $value.',
    source: value,
  );
}

Color? _optionalColor(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  final path = _pathAt(pathPrefix, key);
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $key must be a string.',
    );
  }
  return _parseColor(value, path: path);
}

NodeType _parseNodeType(String value, {required String pathPrefix}) {
  switch (value) {
    case 'image':
      return NodeType.image;
    case 'text':
      return NodeType.text;
    case 'stroke':
      return NodeType.stroke;
    case 'line':
      return NodeType.line;
    case 'rect':
      return NodeType.rect;
    case 'path':
      return NodeType.path;
    default:
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: _pathAt(pathPrefix, 'type'),
        message: 'Unknown node type: $value.',
        source: value,
      );
  }
}

PathFillRule _parsePathFillRule(String value, {required String pathPrefix}) {
  switch (value) {
    case 'nonZero':
      return PathFillRule.nonZero;
    case 'evenOdd':
      return PathFillRule.evenOdd;
    default:
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: _pathAt(pathPrefix, 'fillRule'),
        message: 'Unknown fillRule: $value.',
        source: value,
      );
  }
}

TextAlign _parseTextAlign(String value, {required String pathPrefix}) {
  switch (value) {
    case 'left':
      return TextAlign.left;
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    default:
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: _pathAt(pathPrefix, 'align'),
        message: 'Unknown text align: $value.',
        source: value,
      );
  }
}
