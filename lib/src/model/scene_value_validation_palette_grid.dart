import 'dart:ui';

import '../contract/scene_contract_limits.dart';
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';
import '../core/scene_limits.dart';
import '../core/scene.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

void sceneValidatePaletteSnapshot(
  ScenePaletteSnapshot palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidatePaletteFields(
    penColors: palette.penColors,
    backgroundColors: palette.backgroundColors,
    gridSizes: palette.gridSizes,
    field: field,
    onError: onError,
  );
}

void sceneValidatePalette(
  ScenePalette palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidatePaletteFields(
    penColors: palette.penColors,
    backgroundColors: palette.backgroundColors,
    gridSizes: palette.gridSizes,
    field: field,
    onError: onError,
  );
}

void sceneValidateGridSnapshot(
  GridSnapshot grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
  required bool requireEnabledMinCellSize,
}) {
  sceneValidateGridCellSizeValue(
    cellSize: grid.cellSize,
    isEnabled: grid.isEnabled,
    field: field,
    onError: onError,
    requirePositiveCellSize: requirePositiveCellSize,
    requireEnabledMinCellSize: requireEnabledMinCellSize,
  );
}

void sceneValidateGrid(
  GridSettings grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
  required bool requireEnabledMinCellSize,
}) {
  sceneValidateGridCellSizeValue(
    cellSize: grid.cellSize,
    isEnabled: grid.isEnabled,
    field: field,
    onError: onError,
    requirePositiveCellSize: requirePositiveCellSize,
    requireEnabledMinCellSize: requireEnabledMinCellSize,
  );
}

void sceneValidateCameraOffsetValue(
  Offset value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateCoordinateComponent(
    value.dx,
    field: '$field.dx',
    onError: onError,
  );
  _sceneValidateCoordinateComponent(
    value.dy,
    field: '$field.dy',
    onError: onError,
  );
}

void sceneValidatePaletteFields({
  required List<Color> penColors,
  required List<Color> backgroundColors,
  required List<double> gridSizes,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePaletteItemCount(
    penColors,
    field: '$field.penColors',
    onError: onError,
  );
  _sceneValidatePaletteItemCount(
    backgroundColors,
    field: '$field.backgroundColors',
    onError: onError,
  );
  _sceneValidatePaletteItemCount(
    gridSizes,
    field: '$field.gridSizes',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    penColors,
    field: '$field.penColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    backgroundColors,
    field: '$field.backgroundColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    gridSizes,
    field: '$field.gridSizes',
    onError: onError,
  );
  for (var index = 0; index < gridSizes.length; index++) {
    _sceneValidatePositiveBoundedSize(
      gridSizes[index],
      field: '$field.gridSizes[$index]',
      onError: onError,
    );
  }
}

void _sceneValidatePaletteItemCount<T>(
  List<T> values, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (values.length <= kMaxPaletteItems) {
    return;
  }
  onError(
    field: field,
    value: values,
    diagnostic: SceneDataDiagnosticDescriptor.maxItems(
      maxItems: kMaxPaletteItems,
    ),
  );
}

void sceneValidateGridCellSizeValue({
  required double cellSize,
  required bool isEnabled,
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
  required bool requireEnabledMinCellSize,
}) {
  final cellSizeField = '$field.cellSize';
  if (requirePositiveCellSize) {
    _sceneValidatePositiveBoundedSize(
      cellSize,
      field: cellSizeField,
      onError: onError,
    );
  } else {
    _sceneValidateFiniteBoundedUpperSize(
      cellSize,
      field: cellSizeField,
      onError: onError,
    );
  }
  if (requireEnabledMinCellSize && isEnabled) {
    if (cellSize < kMinGridCellSize) {
      onError(
        field: cellSizeField,
        value: cellSize,
        diagnostic:
            SceneDataDiagnosticDescriptor.fieldMustBeAtLeastWhenFlagEnabled(
              limit: kMinGridCellSize,
              enabledField: '$field.enabled',
            ),
      );
    }
  }
}

void _sceneValidateCoordinateComponent(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (!value.isFinite) {
    onError(
      field: field,
      value: value,
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeFinite(
        fieldName: field,
      ),
    );
  }
  if (value >= sceneCoordMin && value <= sceneCoordMax) {
    return;
  }
  throw SceneDataException.outOfRange(
    path: field,
    min: sceneCoordMin,
    max: sceneCoordMax,
    source: value,
  );
}

void _sceneValidatePositiveBoundedSize(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (!value.isFinite) {
    onError(
      field: field,
      value: value,
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeFinite(
        fieldName: field,
      ),
    );
  }
  if (value <= 0) {
    onError(
      field: field,
      value: value,
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeGreaterThan(
        limit: 0,
      ),
    );
  }
  if (value > 0 && value <= sceneSizeMax) {
    return;
  }
  throw SceneDataException.outOfRange(
    path: field,
    min: 0,
    max: sceneSizeMax,
    source: value,
  );
}

void _sceneValidateFiniteBoundedUpperSize(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (!value.isFinite) {
    onError(
      field: field,
      value: value,
      diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeFinite(
        fieldName: field,
      ),
    );
  }
  if (value > sceneSizeMax) {
    throw SceneDataException.outOfRange(
      path: field,
      min: 0,
      max: sceneSizeMax,
      source: value,
    );
  }
}
