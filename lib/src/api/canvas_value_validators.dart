import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'canvas_contract_limits.dart';
import 'canvas_errors.dart';
import 'canvas_geometry.dart';

String validateCanvasIdValue(
  String value, {
  required String path,
  required int maxLength,
}) {
  if (value.isEmpty) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustNotBeEmpty,
      message: '$path must not be empty.',
      path: path,
    );
  }
  if (value != value.trim()) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: '$path must not contain leading or trailing whitespace.',
      path: path,
    );
  }
  if (value.length > maxLength) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMaxLength,
      message: '$path must be at most $maxLength characters.',
      path: path,
      details: {'maxLength': maxLength, 'actualLength': value.length},
    );
  }
  if (value.runes.any(_isControlCharacter)) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: '$path must not contain control characters.',
      path: path,
    );
  }

  return value;
}

String validateCanvasAppKeyValue(
  String value, {
  required String path,
  required int maxLength,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustNotBeEmpty,
      message: '$path must not be empty.',
      path: path,
    );
  }
  if (trimmed.length > maxLength) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMaxLength,
      message: '$path must be at most $maxLength characters.',
      path: path,
      details: {'maxLength': maxLength, 'actualLength': trimmed.length},
    );
  }
  if (trimmed.runes.any(_isControlCharacter)) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: '$path must not contain control characters.',
      path: path,
    );
  }

  return trimmed;
}

String validateCanvasMetadataKey(String value, {required String path}) {
  if (value.length > canvasMetadataMaxKeyLength) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidMetadata,
      message: '$path exceeds the maximum length.',
      path: path,
      details: {
        'maxLength': canvasMetadataMaxKeyLength,
        'actualLength': value.length,
      },
    );
  }

  return value;
}

void validateFiniteDouble(double value, {required String path}) {
  if (!value.isFinite) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustBeFinite,
      message: '$path must be finite.',
      path: path,
    );
  }
}

void validateIntegerRange(
  int value, {
  required String path,
  required int min,
  required int max,
}) {
  if (value < min || value > max) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustBeInRange,
      message: '$path must be between $min and $max.',
      path: path,
      details: {'min': min, 'max': max, 'actual': value},
    );
  }
}

void validateNonNegativeInt(int value, {required String path}) {
  if (value < 0) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustBeNonNegative,
      message: '$path must be non-negative.',
      path: path,
      details: {'actual': value},
    );
  }
}

void validateDoubleRange(
  double value, {
  required String path,
  required double min,
  required double max,
}) {
  validateFiniteDouble(value, path: path);
  if (value < min || value > max) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustBeInRange,
      message: '$path must be between $min and $max.',
      path: path,
      details: {'min': min, 'max': max, 'actual': value},
    );
  }
}

void validateNonNegativeDouble(
  double value, {
  required String path,
  double max = double.infinity,
}) {
  validateFiniteDouble(value, path: path);
  if (value < 0 || value > max) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustBeInRange,
      message: '$path must be non-negative and at most $max.',
      path: path,
      details: {'min': 0, 'max': max, 'actual': value},
    );
  }
}

void validatePositiveDouble(
  double value, {
  required String path,
  double max = double.infinity,
}) {
  validateFiniteDouble(value, path: path);
  if (value <= 0 || value > max) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustBePositive,
      message: '$path must be positive and at most $max.',
      path: path,
      details: {'max': max, 'actual': value},
    );
  }
}

void validateOffset(Offset value, {required String path}) {
  validateDoubleRange(
    value.dx,
    path: '$path.dx',
    min: canvasMinCoordinate,
    max: canvasMaxCoordinate,
  );
  validateDoubleRange(
    value.dy,
    path: '$path.dy',
    min: canvasMinCoordinate,
    max: canvasMaxCoordinate,
  );
}

void validateSize(Size value, {required String path}) {
  validatePositiveDouble(
    value.width,
    path: '$path.width',
    max: canvasMaxPositiveSize,
  );
  validatePositiveDouble(
    value.height,
    path: '$path.height',
    max: canvasMaxPositiveSize,
  );
}

void validateCanvasTransform(CanvasTransform value, {required String path}) {
  _validateTransformEntries(value, path: path);
  validateOffset(value.translation, path: '$path.translation');
}

void validateElementTransformAdmission(
  CanvasTransform value, {
  required String path,
}) {
  validateCanvasTransform(value, path: path);
  _validateTransformSingularValues(value, path: path);
}

Map<String, Object?> freezeCanvasMetadata(Map<String, Object?> values) {
  final frozen = <String, Object?>{};
  _validateMetadataObjectSize(values, path: 'metadata');
  for (final entry in values.entries) {
    final key = validateCanvasMetadataKey(
      entry.key,
      path: 'metadata.${entry.key}',
    );
    frozen[key] = _freezeMetadataValue(entry.value, path: key, depth: 1);
  }

  _validateMetadataEncodedLength(frozen);

  return Map.unmodifiable(frozen);
}

void validateRawJsonLength(String source) {
  if (source.length > canvasMaxRawJsonLength) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.maxRawJsonLength,
      message: 'raw JSON exceeds the maximum length.',
      path: r'$',
      details: {'maxLength': canvasMaxRawJsonLength},
    );
  }
}

void validateOptionalBoundedString(
  String? value, {
  required String path,
  required int maxLength,
}) {
  if (value == null) {
    return;
  }
  if (value.isEmpty) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMustNotBeEmpty,
      message: '$path must not be empty.',
      path: path,
    );
  }
  if (value.length > maxLength) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.fieldMaxLength,
      message: '$path exceeds the maximum length.',
      path: path,
      details: {'maxLength': maxLength, 'actualLength': value.length},
    );
  }
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

void _validateMetadataEncodedLength(Map<String, Object?> frozen) {
  final encodedLength = utf8.encode(jsonEncode(frozen)).length;
  if (encodedLength > canvasMetadataMaxEncodedBytes) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidMetadata,
      message: 'metadata exceeds the encoded byte limit.',
      path: 'metadata',
      details: {
        'maxEncodedBytes': canvasMetadataMaxEncodedBytes,
        'actualEncodedBytes': encodedLength,
      },
    );
  }
}

bool _isControlCharacter(int rune) => rune < 0x20 || rune == 0x7F;

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

Object? _freezeMetadataValue(
  Object? value, {
  required String path,
  required int depth,
}) {
  if (depth > canvasMetadataMaxDepth) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidMetadata,
      message: 'metadata exceeds the maximum depth.',
      path: 'metadata.$path',
      details: {'maxDepth': canvasMetadataMaxDepth},
    );
  }

  return switch (value) {
    null || bool() => value,
    String() => _freezeMetadataString(value, path: path),
    num() => _freezeMetadataNumber(value, path: path),
    List<Object?>() => _freezeMetadataList(value, path: path, depth: depth),
    Map<String, Object?>() => _freezeMetadataMap(
      value,
      path: path,
      depth: depth,
    ),
    _ => throw CanvasDataException(
      code: CanvasDataErrorCode.invalidMetadata,
      message: 'metadata contains an unsupported value.',
      path: 'metadata',
    ),
  };
}

String _freezeMetadataString(String value, {required String path}) {
  if (value.length > canvasMetadataMaxStringLength) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidMetadata,
      message: 'metadata string exceeds the maximum length.',
      path: 'metadata.$path',
      details: {
        'maxLength': canvasMetadataMaxStringLength,
        'actualLength': value.length,
      },
    );
  }

  return value;
}

num _freezeMetadataNumber(num value, {required String path}) {
  if (!value.isFinite) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidMetadata,
      message: 'metadata numbers must be finite.',
      path: 'metadata.$path',
    );
  }

  return value;
}

List<Object?> _freezeMetadataList(
  List<Object?> value, {
  required String path,
  required int depth,
}) {
  return List<Object?>.unmodifiable(
    value.indexed.map(
      (entry) => _freezeMetadataValue(
        entry.$2,
        path: '$path.${entry.$1}',
        depth: depth + 1,
      ),
    ),
  );
}

Map<String, Object?> _freezeMetadataMap(
  Map<String, Object?> value, {
  required String path,
  required int depth,
}) {
  _validateMetadataObjectSize(value, path: 'metadata.$path');

  return Map<String, Object?>.unmodifiable({
    for (final entry in value.entries)
      validateCanvasMetadataKey(
        entry.key,
        path: 'metadata.$path.${entry.key}',
      ): _freezeMetadataValue(
        entry.value,
        path: '$path.${entry.key}',
        depth: depth + 1,
      ),
  });
}

void _validateMetadataObjectSize(
  Map<String, Object?> value, {
  required String path,
}) {
  if (value.length > canvasMetadataMaxObjectKeys) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidMetadata,
      message: 'metadata object exceeds the maximum key count.',
      path: path,
      details: {
        'maxKeys': canvasMetadataMaxObjectKeys,
        'actualKeys': value.length,
      },
    );
  }
}
