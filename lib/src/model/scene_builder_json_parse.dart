import 'dart:ui';

import '../contract/path_fill_rule.dart';
import '../contract/scene_data_exception.dart';
import '../contract/transform2d.dart';
import '../contract/validated/validated_value_support.dart';
import '../core/nodes.dart';
import 'scene_builder_json_require.dart';

Transform2D sceneBuilderDecodeTransform2D(
  Map<String, Object?> json, {
  String pathPrefix = '',
}) {
  return Transform2D(
    a: validatedRequireJsonFiniteDouble(
      sceneBuilderRequireField(json, 'a', pathPrefix: pathPrefix),
      path: sceneBuilderPathAt(pathPrefix, 'a'),
      fieldName: 'a',
    ),
    b: validatedRequireJsonFiniteDouble(
      sceneBuilderRequireField(json, 'b', pathPrefix: pathPrefix),
      path: sceneBuilderPathAt(pathPrefix, 'b'),
      fieldName: 'b',
    ),
    c: validatedRequireJsonFiniteDouble(
      sceneBuilderRequireField(json, 'c', pathPrefix: pathPrefix),
      path: sceneBuilderPathAt(pathPrefix, 'c'),
      fieldName: 'c',
    ),
    d: validatedRequireJsonFiniteDouble(
      sceneBuilderRequireField(json, 'd', pathPrefix: pathPrefix),
      path: sceneBuilderPathAt(pathPrefix, 'd'),
      fieldName: 'd',
    ),
    tx: validatedRequireJsonFiniteDouble(
      sceneBuilderRequireField(json, 'tx', pathPrefix: pathPrefix),
      path: sceneBuilderPathAt(pathPrefix, 'tx'),
      fieldName: 'tx',
    ),
    ty: validatedRequireJsonFiniteDouble(
      sceneBuilderRequireField(json, 'ty', pathPrefix: pathPrefix),
      path: sceneBuilderPathAt(pathPrefix, 'ty'),
      fieldName: 'ty',
    ),
  );
}

Size sceneBuilderRequireSize(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final map = sceneBuilderRequireMap(json, key, pathPrefix: pathPrefix);
  final sizePath = sceneBuilderPathAt(pathPrefix, key);
  return Size(
    validatedRequireJsonFiniteDouble(
      sceneBuilderRequireField(map, 'w', pathPrefix: sizePath),
      path: sceneBuilderPathAt(sizePath, 'w'),
      fieldName: 'w',
    ),
    validatedRequireJsonFiniteDouble(
      sceneBuilderRequireField(map, 'h', pathPrefix: sizePath),
      path: sceneBuilderPathAt(sizePath, 'h'),
      fieldName: 'h',
    ),
  );
}

Size? sceneBuilderOptionalSizeMap(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final parsed = sceneBuilderOptionalObjectMap(
    json,
    key,
    pathPrefix: pathPrefix,
  );
  if (parsed == null) {
    return null;
  }
  final sizePath = sceneBuilderPathAt(pathPrefix, key);
  final w = validatedRequireJsonFiniteDouble(
    sceneBuilderRequireField(parsed, 'w', pathPrefix: sizePath),
    path: sceneBuilderPathAt(sizePath, 'w'),
    fieldName: 'w',
  );
  final h = validatedRequireJsonFiniteDouble(
    sceneBuilderRequireField(parsed, 'h', pathPrefix: sizePath),
    path: sceneBuilderPathAt(sizePath, 'h'),
    fieldName: 'h',
  );
  return Size(w, h);
}

Color sceneBuilderParseColor(String value, {required String path}) {
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (normalized.length == 6) {
    final parsed = int.tryParse('FF$normalized', radix: 16);
    if (parsed == null) {
      throw SceneDataException.invalidColorLiteral(path: path, value: value);
    }
    return Color(parsed);
  }
  if (normalized.length == 8) {
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      throw SceneDataException.invalidColorLiteral(path: path, value: value);
    }
    return Color(parsed);
  }
  throw SceneDataException.invalidColorLiteral(path: path, value: value);
}

Color? sceneBuilderOptionalColor(
  Map<String, Object?> json,
  String key, {
  String pathPrefix = '',
}) {
  final value = sceneBuilderOptionalTypedField<String>(
    json,
    key,
    pathPrefix: pathPrefix,
    typeLabel: 'string',
  );
  if (value == null) {
    return null;
  }
  return sceneBuilderParseColor(
    value,
    path: sceneBuilderPathAt(pathPrefix, key),
  );
}

Color sceneBuilderDecodeRequiredColor(
  Map<String, Object?> json,
  String key, {
  required String pathPrefix,
}) {
  return sceneBuilderParseColor(
    sceneBuilderRequireTypedField<String>(
      json,
      key,
      pathPrefix: pathPrefix,
      typeLabel: 'string',
    ),
    path: sceneBuilderPathAt(pathPrefix, key),
  );
}

NodeType sceneBuilderParseNodeType(String value, {required String pathPrefix}) {
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
      throw SceneDataException.unknownEnumValue(
        path: sceneBuilderPathAt(pathPrefix, 'type'),
        value: value,
      );
  }
}

PathFillRule sceneBuilderParsePathFillRule(
  String value, {
  required String pathPrefix,
}) {
  switch (value) {
    case 'nonZero':
      return PathFillRule.nonZero;
    case 'evenOdd':
      return PathFillRule.evenOdd;
    default:
      throw SceneDataException.unknownEnumValue(
        path: sceneBuilderPathAt(pathPrefix, 'fillRule'),
        value: value,
      );
  }
}

TextAlign sceneBuilderParseTextAlign(
  String value, {
  required String pathPrefix,
}) {
  switch (value) {
    case 'left':
      return TextAlign.left;
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    case 'justify':
      return TextAlign.justify;
    case 'start':
      return TextAlign.start;
    case 'end':
      return TextAlign.end;
    default:
      throw SceneDataException.unknownEnumValue(
        path: sceneBuilderPathAt(pathPrefix, 'align'),
        value: value,
      );
  }
}

TextDirection sceneBuilderParseTextDirection(
  String value, {
  required String pathPrefix,
  required String fieldName,
}) {
  switch (value) {
    case 'ltr':
      return TextDirection.ltr;
    case 'rtl':
      return TextDirection.rtl;
    default:
      throw SceneDataException.unknownEnumValue(
        path: sceneBuilderPathAt(pathPrefix, fieldName),
        value: value,
      );
  }
}
