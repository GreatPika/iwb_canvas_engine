part of 'scene_builder.dart';

Map<String, Object?> _castMap(Map value) {
  final out = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidFieldType,
        message: 'JSON object keys must be strings.',
      );
    }
    out[key] = entry.value;
  }
  return out;
}

Map<String, Object?> _requireMap(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be an object.',
    );
  }
  final value = json[key];
  if (value is! Map) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an object.',
    );
  }
  return _castMap(value);
}

List<Object?> _requireList(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be a list.',
    );
  }
  final value = json[key];
  if (value is! List) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a list.',
    );
  }
  return List<Object?>.from(value);
}

String _requireString(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be a string.',
    );
  }
  final value = json[key];
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a string.',
    );
  }
  return value;
}

String _requireStringValue(Object? value, String key) {
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Items of $key must be strings.',
    );
  }
  return value;
}

bool _requireBool(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be a bool.',
    );
  }
  final value = json[key];
  if (value is! bool) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a bool.',
    );
  }
  return value;
}

int _requireInt(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  final asDouble = value.toDouble();
  if (!asDouble.isFinite || asDouble.truncateToDouble() != asDouble) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  if (asDouble.abs() > 9007199254740991) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Field $key must be an int.',
      source: value,
    );
  }
  return asDouble.toInt();
}

double _requireDouble(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw SceneDataException(
      code: SceneDataErrorCode.missingField,
      path: key,
      message: 'Field $key must be a number.',
    );
  }
  final value = json[key];
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a number.',
    );
  }
  final out = value.toDouble();
  if (!out.isFinite) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Field $key must be finite.',
      source: value,
    );
  }
  return out;
}

double _requireDoubleValue(Object? value, String key) {
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Items of $key must be numbers.',
    );
  }
  final out = value.toDouble();
  if (!out.isFinite) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Items of $key must be finite.',
      source: value,
    );
  }
  return out;
}

Transform2D _decodeTransform2D(Map<String, Object?> json) {
  return Transform2D(
    a: _requireDouble(json, 'a'),
    b: _requireDouble(json, 'b'),
    c: _requireDouble(json, 'c'),
    d: _requireDouble(json, 'd'),
    tx: _requireDouble(json, 'tx'),
    ty: _requireDouble(json, 'ty'),
  );
}

Size _requireSize(Map<String, Object?> json, String key) {
  final map = _requireMap(json, key);
  return Size(_requireDouble(map, 'w'), _requireDouble(map, 'h'));
}

Size? _optionalSizeMap(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an object.',
    );
  }
  final parsed = _castMap(value);
  final width = parsed['w'];
  final height = parsed['h'];
  if (width is! num || height is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Optional size must be numeric.',
    );
  }
  final w = width.toDouble();
  final h = height.toDouble();
  if (!w.isFinite || !h.isFinite) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Optional size must be finite.',
    );
  }
  return Size(w, h);
}

String? _optionalString(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a string.',
    );
  }
  return value;
}

double? _optionalDouble(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a number.',
    );
  }
  final out = value.toDouble();
  if (!out.isFinite) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Field $key must be finite.',
      source: value,
    );
  }
  return out;
}

int? _optionalInt(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is int) {
    return value;
  }
  if (value is! num) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  final asDouble = value.toDouble();
  if (!asDouble.isFinite || asDouble.truncateToDouble() != asDouble) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be an int.',
    );
  }
  if (asDouble.abs() > 9007199254740991) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: key,
      message: 'Field $key must be an int.',
      source: value,
    );
  }
  return asDouble.toInt();
}

Offset _parsePoint(Object? value, String field) {
  if (value is! Map) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: field,
      message: '$field must be an object with x/y.',
    );
  }
  final map = _castMap(value);
  return Offset(_requireDouble(map, 'x'), _requireDouble(map, 'y'));
}

Color _parseColor(String value) {
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (normalized.length == 6) {
    final parsed = int.tryParse('FF$normalized', radix: 16);
    if (parsed == null) {
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
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
        message: 'Invalid color: $value.',
        source: value,
      );
    }
    return Color(parsed);
  }
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    message: 'Invalid color: $value.',
    source: value,
  );
}

Color? _optionalColor(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidFieldType,
      path: key,
      message: 'Field $key must be a string.',
    );
  }
  return _parseColor(value);
}

NodeType _parseNodeType(String value) {
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
        path: 'type',
        message: 'Unknown node type: $value.',
        source: value,
      );
  }
}

V2PathFillRule _parsePathFillRule(String value) {
  switch (value) {
    case 'nonZero':
      return V2PathFillRule.nonZero;
    case 'evenOdd':
      return V2PathFillRule.evenOdd;
    default:
      throw SceneDataException(
        code: SceneDataErrorCode.invalidValue,
        path: 'fillRule',
        message: 'Unknown fillRule: $value.',
        source: value,
      );
  }
}

TextAlign _parseTextAlign(String value) {
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
        path: 'align',
        message: 'Unknown text align: $value.',
        source: value,
      );
  }
}
