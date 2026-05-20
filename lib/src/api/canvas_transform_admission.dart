import 'dart:math' as math;

import 'canvas_contract_limits.dart';
import 'canvas_errors.dart';
import 'canvas_geometry.dart';
import 'canvas_value_validators.dart';

void validateElementTransformAdmission(
  CanvasTransform value, {
  required String path,
}) {
  _validateCanvasTransform(value, path: path);
  _validateTransformSingularValues(value, path: path);
}

void _validateCanvasTransform(CanvasTransform value, {required String path}) {
  _validateTransformEntries(value, path: path);
  validateOffset(value.translation, path: '$path.translation');
}

void _validateTransformEntries(CanvasTransform value, {required String path}) {
  final entries = {
    'a': value.a,
    'b': value.b,
    'c': value.c,
    'd': value.d,
    'tx': value.tx,
    'ty': value.ty,
  };
  for (final entry in entries.entries) {
    validateFiniteDouble(entry.value, path: '$path.${entry.key}');
  }
}

void _validateTransformSingularValues(
  CanvasTransform value, {
  required String path,
}) {
  final determinant = value.a * value.d - value.b * value.c;
  if (determinant == 0) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustBeInvertible,
      message: '$path must be invertible.',
      path: path,
    );
  }

  final singularMax = _maxSingularValue(value);
  final singularMin = determinant.abs() / singularMax;
  if (singularMin < canvasTransformSingularValueMin ||
      singularMax > canvasTransformSingularValueMax) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustBeInRange,
      message: '$path scale must stay within transform singular-value limits.',
      path: path,
      details: {
        'min': canvasTransformSingularValueMin,
        'max': canvasTransformSingularValueMax,
        'actualMin': singularMin,
        'actualMax': singularMax,
      },
    );
  }
}

double _maxSingularValue(CanvasTransform value) {
  final aa = value.a * value.a + value.b * value.b;
  final bb = value.c * value.c + value.d * value.d;
  final ab = value.a * value.c + value.b * value.d;
  final trace = aa + bb;
  final determinant = aa * bb - ab * ab;
  final discriminant = math.max(0, trace * trace - 4 * determinant);
  final eigenvalue = (trace + math.sqrt(discriminant)) / 2;

  return math.sqrt(eigenvalue);
}
