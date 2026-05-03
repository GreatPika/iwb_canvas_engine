import 'dart:ui';

import 'scene_contract_limits.dart';

String? sceneStrokePointCountViolationMessage(int pointCount) {
  if (pointCount <= kMaxStrokePointsPerNode) {
    return null;
  }
  return 'must contain at most $kMaxStrokePointsPerNode points.';
}

void validateStrokePointCount(
  int pointCount, {
  required String name,
  Object? source,
}) {
  final message = sceneStrokePointCountViolationMessage(pointCount);
  if (message == null) {
    return;
  }
  throw ArgumentError.value(source ?? pointCount, name, _capitalize(message));
}

String? scenePaletteItemCountViolationMessage(int itemCount) {
  if (itemCount <= kMaxPaletteItems) {
    return null;
  }
  return 'must contain at most $kMaxPaletteItems items.';
}

String? sceneNonEmptyListViolationMessage(List<Object?> values) {
  if (values.isNotEmpty) {
    return null;
  }
  return 'must not be empty.';
}

String? sceneCoordinateViolationMessage(double value) {
  if (!value.isFinite) {
    return 'must be finite.';
  }
  if (value < sceneCoordMin || value > sceneCoordMax) {
    return 'must be within [$sceneCoordMin, $sceneCoordMax].';
  }
  return null;
}

String? scenePositiveBoundedSizeViolationMessage(double value) {
  if (!value.isFinite) {
    return 'must be finite.';
  }
  if (value <= 0) {
    return 'must be > 0.';
  }
  if (value > sceneSizeMax) {
    return 'must be within [0, $sceneSizeMax].';
  }
  return null;
}

String? sceneEnabledGridCellSizeViolationMessage(double cellSize) {
  if (cellSize < kMinGridCellSize) {
    return 'must be >= $kMinGridCellSize when grid is enabled.';
  }
  return null;
}

void validatePaletteItemCount(
  int itemCount, {
  required String name,
  Object? source,
}) {
  final message = scenePaletteItemCountViolationMessage(itemCount);
  if (message == null) {
    return;
  }
  throw ArgumentError.value(source ?? itemCount, name, _capitalize(message));
}

void validateNonEmptyList(
  List<Object?> values, {
  required String name,
  Object? source,
}) {
  final message = sceneNonEmptyListViolationMessage(values);
  if (message == null) {
    return;
  }
  throw ArgumentError.value(source ?? values, name, _capitalize(message));
}

double validateSceneCoordinate(
  double value, {
  required String name,
  Object? source,
}) {
  final message = sceneCoordinateViolationMessage(value);
  if (message == null) {
    return value;
  }
  throw ArgumentError.value(source ?? value, name, _capitalize(message));
}

Offset validateSceneCameraOffset(Offset value, {required String name}) {
  validateSceneCoordinate(value.dx, name: '$name.dx', source: value);
  validateSceneCoordinate(value.dy, name: '$name.dy', source: value);
  return value;
}

double validateScenePositiveBoundedSize(
  double value, {
  required String name,
  Object? source,
}) {
  final message = scenePositiveBoundedSizeViolationMessage(value);
  if (message == null) {
    return value;
  }
  throw ArgumentError.value(source ?? value, name, _capitalize(message));
}

double validateSceneGridCellSize(
  double value, {
  required String name,
  required bool isEnabled,
  Object? source,
}) {
  final resolved = validateScenePositiveBoundedSize(
    value,
    name: name,
    source: source,
  );
  if (isEnabled) {
    final message = sceneEnabledGridCellSizeViolationMessage(resolved);
    if (message != null) {
      throw ArgumentError.value(source ?? value, name, _capitalize(message));
    }
  }
  return resolved;
}

List<Color> validateScenePaletteColorList(
  Iterable<Color> values, {
  required String name,
}) {
  final resolved = List<Color>.from(values);
  validatePaletteItemCount(resolved.length, name: name, source: resolved);
  validateNonEmptyList(resolved, name: name, source: resolved);
  return List<Color>.unmodifiable(resolved);
}

List<double> validateScenePaletteGridSizeList(
  Iterable<double> values, {
  required String name,
}) {
  final resolved = List<double>.from(values);
  validatePaletteItemCount(resolved.length, name: name, source: resolved);
  validateNonEmptyList(resolved, name: name, source: resolved);
  return List<double>.unmodifiable(
    List<double>.generate(
      resolved.length,
      (index) => validateScenePositiveBoundedSize(
        resolved[index],
        name: '$name[$index]',
        source: resolved[index],
      ),
      growable: false,
    ),
  );
}

String _capitalize(String message) {
  if (message.isEmpty) {
    return message;
  }
  return '${message[0].toUpperCase()}${message.substring(1)}';
}
