import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import '../scene_data_exception.dart';
import '../scene_contract_limits.dart';

const int validatedSafeIntegerMax = 9007199254740991;

String validatedRequireString(
  String value, {
  required String name,
  int? maxLength,
  bool allowEmpty = true,
}) {
  if (!allowEmpty && value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
  if (maxLength != null && value.length > maxLength) {
    throw ArgumentError.value(
      value.length,
      name,
      'Length must be <= $maxLength characters.',
    );
  }
  return value;
}

String validatedRequireJsonString(
  Object? raw, {
  required String path,
  required String fieldName,
  int? maxLength,
  bool allowEmpty = true,
}) {
  if (raw is! String) {
    throw SceneDataException.invalidFieldType(
      path: path,
      fieldName: fieldName,
      expected: 'string',
      source: raw,
    );
  }
  if (!allowEmpty && raw.trim().isEmpty) {
    throw SceneDataException.fieldMustNotBeEmpty(path: path, source: raw);
  }
  if (maxLength != null && raw.length > maxLength) {
    throw SceneDataException.fieldMaxLength(
      path: path,
      maxLength: maxLength,
      source: raw.length,
    );
  }
  return raw;
}

double validatedRequireFiniteDouble(double value, {required String name}) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
  return value;
}

double validatedRequireNonNegativeFiniteDouble(
  double value, {
  required String name,
}) {
  validatedRequireFiniteDouble(value, name: name);
  if (value < 0) {
    throw ArgumentError.value(value, name, 'Must be >= 0.');
  }
  return value;
}

double validatedRequirePositiveFiniteDouble(
  double value, {
  required String name,
}) {
  validatedRequireFiniteDouble(value, name: name);
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'Must be > 0.');
  }
  return value;
}

double validatedRequireOpacity(double value, {required String name}) {
  validatedRequireFiniteDouble(value, name: name);
  if (value < 0 || value > 1) {
    throw ArgumentError.value(value, name, 'Must be within [0,1].');
  }
  return value;
}

Offset validatedRequireFiniteOffset(Offset value, {required String name}) {
  validatedRequireFiniteDouble(value.dx, name: '$name.dx');
  validatedRequireFiniteDouble(value.dy, name: '$name.dy');
  return value;
}

int validatedRequireInstanceRevision(
  int value, {
  required String name,
  required bool allowZero,
}) {
  final minimum = allowZero ? 0 : 1;
  if (value < minimum) {
    throw ArgumentError.value(
      value,
      name,
      allowZero ? 'Must be >= 0.' : 'Must be > 0.',
    );
  }
  if (value.abs() > validatedSafeIntegerMax) {
    throw ArgumentError.value(
      value,
      name,
      'Must be a safe integer within +/-$validatedSafeIntegerMax.',
    );
  }
  return value;
}

int validatedRequireJsonInt(
  Object? raw, {
  required String path,
  required String fieldName,
  required bool allowZero,
}) {
  if (raw is int) {
    if (raw.abs() > validatedSafeIntegerMax) {
      throw SceneDataException.fieldMustBeInt(
        code: SceneDataErrorCode.invalidValue,
        path: path,
        fieldName: fieldName,
        source: raw,
      );
    }
    return _validateJsonRevisionValue(raw, path: path, allowZero: allowZero);
  }
  if (raw is! num) {
    throw SceneDataException.fieldMustBeInt(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      fieldName: fieldName,
      source: raw,
    );
  }
  final asDouble = raw.toDouble();
  if (!asDouble.isFinite || asDouble.truncateToDouble() != asDouble) {
    throw SceneDataException.fieldMustBeInt(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      fieldName: fieldName,
      source: raw,
    );
  }
  if (asDouble.abs() > validatedSafeIntegerMax) {
    throw SceneDataException.fieldMustBeInt(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      fieldName: fieldName,
      source: raw,
    );
  }
  return _validateJsonRevisionValue(
    asDouble.toInt(),
    path: path,
    allowZero: allowZero,
  );
}

int _validateJsonRevisionValue(
  int value, {
  required String path,
  required bool allowZero,
}) {
  final minimum = allowZero ? 0 : 1;
  if (value < minimum) {
    throw allowZero
        ? SceneDataException.fieldMustBeAtLeast(
            path: path,
            limit: 0,
            source: value,
          )
        : SceneDataException.fieldMustBeGreaterThan(
            path: path,
            limit: 0,
            source: value,
          );
  }
  return value;
}

double validatedRequireJsonFiniteDouble(
  Object? raw, {
  required String path,
  required String fieldName,
}) {
  if (raw is! num) {
    throw SceneDataException.invalidFieldType(
      path: path,
      fieldName: fieldName,
      expected: 'number',
      source: raw,
    );
  }
  final value = raw.toDouble();
  if (!value.isFinite) {
    throw SceneDataException.fieldMustBeFinite(
      path: path,
      fieldName: fieldName,
      source: raw,
    );
  }
  return value;
}

double validatedRequireJsonNonNegativeFiniteDouble(
  Object? raw, {
  required String path,
  required String fieldName,
}) {
  final value = validatedRequireJsonFiniteDouble(
    raw,
    path: path,
    fieldName: fieldName,
  );
  if (value < 0) {
    throw SceneDataException.fieldMustBeAtLeast(
      path: path,
      limit: 0,
      source: value,
    );
  }
  return value;
}

double validatedRequireJsonPositiveFiniteDouble(
  Object? raw, {
  required String path,
  required String fieldName,
}) {
  final value = validatedRequireJsonFiniteDouble(
    raw,
    path: path,
    fieldName: fieldName,
  );
  if (value <= 0) {
    throw SceneDataException.fieldMustBeGreaterThan(
      path: path,
      limit: 0,
      source: value,
    );
  }
  return value;
}

double validatedRequireJsonOpacity(
  Object? raw, {
  required String path,
  required String fieldName,
}) {
  final value = validatedRequireJsonFiniteDouble(
    raw,
    path: path,
    fieldName: fieldName,
  );
  if (value < 0 || value > 1) {
    throw SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      message: 'Field $path must be within [0,1].',
      source: value,
    );
  }
  return value;
}

Offset validatedRequireJsonFiniteOffset(
  Object? raw, {
  required String path,
  required String fieldName,
}) {
  if (raw is! Map<Object?, Object?>) {
    throw SceneDataException.boundary(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $fieldName must be an object with x/y.',
      source: raw,
    );
  }
  final dx = raw['x'];
  final dy = raw['y'];
  if (dx is! num || dy is! num) {
    throw SceneDataException.boundary(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Field $fieldName must be an object with x/y.',
      source: raw,
    );
  }
  final offset = Offset(dx.toDouble(), dy.toDouble());
  if (!offset.dx.isFinite || !offset.dy.isFinite) {
    throw SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      message: 'Field $path coordinates must be finite.',
      source: raw,
    );
  }
  return offset;
}

String validatedParseGeneratedId({
  required String prefix,
  required int seed,
  required int maxLength,
  required String name,
}) {
  if (seed < 0) {
    throw ArgumentError.value(seed, name, 'Must be >= 0.');
  }
  final generated = '$prefix$seed';
  validatedRequireString(
    generated,
    name: name,
    maxLength: maxLength,
    allowEmpty: false,
  );
  return generated;
}

int? validatedTryParseGeneratedSeed(
  String value, {
  required String prefix,
  required int maxLength,
}) {
  if (value.length > maxLength) {
    return null;
  }
  if (!value.startsWith(prefix)) {
    return null;
  }
  final rawSeed = value.substring(prefix.length);
  if (rawSeed.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(rawSeed);
  if (parsed == null || parsed < 0) {
    return null;
  }
  if (rawSeed != parsed.toString()) {
    return null;
  }
  return parsed;
}

double validatedRequireJsonFiniteDoubleItem(
  Object? raw, {
  required String path,
  required String fieldName,
}) {
  if (raw is! num) {
    throw SceneDataException.boundary(
      code: SceneDataErrorCode.invalidFieldType,
      path: path,
      message: 'Items of $fieldName must be numbers.',
      source: raw,
    );
  }
  final value = raw.toDouble();
  if (!value.isFinite) {
    throw SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      message: 'Items of $fieldName must be finite.',
      source: raw,
    );
  }
  return value;
}

String validatedRequireSvgPathData(String value, {required String name}) {
  validatedRequireString(
    value,
    name: name,
    maxLength: kMaxSvgPathDataLength,
    allowEmpty: false,
  );
  try {
    parseSvgPathData(value);
  } catch (_) {
    throw ArgumentError.value(value, name, 'Must be valid SVG path data.');
  }
  return value;
}

String validatedRequireJsonSvgPathData(
  Object? raw, {
  required String path,
  required String fieldName,
}) {
  final value = validatedRequireJsonString(
    raw,
    path: path,
    fieldName: fieldName,
    maxLength: kMaxSvgPathDataLength,
    allowEmpty: false,
  );
  try {
    parseSvgPathData(value);
  } catch (_) {
    throw SceneDataException.boundary(
      code: SceneDataErrorCode.invalidValue,
      path: path,
      message: 'Field $path must be valid SVG path data.',
      source: value,
    );
  }
  return value;
}
