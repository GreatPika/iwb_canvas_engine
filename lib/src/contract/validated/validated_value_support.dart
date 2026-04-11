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
    throw SceneValidationArgumentError.value(
      value,
      name,
      'Must not be empty.',
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustNotBeEmpty(),
    );
  }
  if (maxLength != null && value.length > maxLength) {
    throw SceneValidationArgumentError.value(
      value.length,
      name,
      'Length must be <= $maxLength characters.',
      diagnostic: SceneDataDiagnosticDescriptor.fieldMaxLength(
        maxLength: maxLength,
      ),
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
    throw SceneValidationArgumentError.value(
      value,
      name,
      'Must be finite.',
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeFinite(
        fieldName: name,
      ),
    );
  }
  return value;
}

double validatedRequireNonNegativeFiniteDouble(
  double value, {
  required String name,
}) {
  validatedRequireFiniteDouble(value, name: name);
  if (value < 0) {
    throw SceneValidationArgumentError.value(
      value,
      name,
      'Must be >= 0.',
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeAtLeast(limit: 0),
    );
  }
  return value;
}

double validatedRequirePositiveFiniteDouble(
  double value, {
  required String name,
}) {
  validatedRequireFiniteDouble(value, name: name);
  if (value <= 0) {
    throw SceneValidationArgumentError.value(
      value,
      name,
      'Must be > 0.',
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeGreaterThan(
        limit: 0,
      ),
    );
  }
  return value;
}

double validatedRequireOpacity(double value, {required String name}) {
  validatedRequireFiniteDouble(value, name: name);
  if (value < 0 || value > 1) {
    throw SceneValidationArgumentError.value(
      value,
      name,
      'Must be within [0,1].',
      diagnostic: SceneDataDiagnosticDescriptor.outOfRange(min: 0, max: 1),
    );
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
    throw SceneValidationArgumentError.value(
      value,
      name,
      allowZero ? 'Must be >= 0.' : 'Must be > 0.',
      diagnostic: allowZero
          ? SceneDataDiagnosticDescriptor.fieldMustBeAtLeast(limit: 0)
          : SceneDataDiagnosticDescriptor.fieldMustBeGreaterThan(limit: 0),
    );
  }
  if (value.abs() > validatedSafeIntegerMax) {
    throw SceneValidationArgumentError.value(
      value,
      name,
      'Must be a safe integer within +/-$validatedSafeIntegerMax.',
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeSafeInteger(
        limit: validatedSafeIntegerMax,
      ),
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
      throw SceneDataException.fieldMustBeSafeInteger(
        path: path,
        limit: validatedSafeIntegerMax,
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
    throw SceneDataException.fieldMustBeSafeInteger(
      path: path,
      limit: validatedSafeIntegerMax,
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
    throw SceneDataException.outOfRange(
      path: path,
      min: 0,
      max: 1,
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
    throw SceneDataException.fieldMustBeOffsetObject(
      path: path,
      fieldName: fieldName,
      source: raw,
    );
  }
  final dx = raw['x'];
  final dy = raw['y'];
  if (dx is! num || dy is! num) {
    throw SceneDataException.fieldMustBeOffsetObject(
      path: path,
      fieldName: fieldName,
      source: raw,
    );
  }
  final offset = Offset(dx.toDouble(), dy.toDouble());
  if (!offset.dx.isFinite || !offset.dy.isFinite) {
    throw SceneDataException.fieldCoordinatesMustBeFinite(
      path: path,
      fieldName: fieldName,
      source: raw,
    );
  }
  return offset;
}

double validatedRequireJsonFiniteDoubleItem(
  Object? raw, {
  required String path,
  required String fieldName,
}) {
  if (raw is! num) {
    throw SceneDataException.itemsMustBeType(
      path: path,
      fieldName: fieldName,
      expected: 'numbers',
      source: raw,
    );
  }
  final value = raw.toDouble();
  if (!value.isFinite) {
    throw SceneDataException.itemsMustBeFinite(
      path: path,
      fieldName: fieldName,
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
    throw SceneValidationArgumentError.value(
      value,
      name,
      'Must be valid SVG path data.',
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeValidSvgPathData(),
    );
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
    throw SceneDataException.fieldMustBeValidSvgPathData(
      path: path,
      source: value,
    );
  }
  return value;
}
