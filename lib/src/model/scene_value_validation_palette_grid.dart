import 'dart:ui';

import '../contract/snapshot.dart';
import '../core/scene.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

typedef _PaletteValidationFields = ({
  List<Color> penColors,
  List<Color> backgroundColors,
  List<double> gridSizes,
});

void sceneValidatePaletteSnapshot(
  ScenePaletteSnapshot palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePaletteFields(
    fields: (
      penColors: palette.penColors,
      backgroundColors: palette.backgroundColors,
      gridSizes: palette.gridSizes,
    ),
    field: field,
    onError: onError,
  );
}

void sceneValidatePalette(
  ScenePalette palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePaletteFields(
    fields: (
      penColors: palette.penColors,
      backgroundColors: palette.backgroundColors,
      gridSizes: palette.gridSizes,
    ),
    field: field,
    onError: onError,
  );
}

void sceneValidateGridSnapshot(
  GridSnapshot grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
}) {
  _sceneValidateGridCellSize(
    grid.cellSize,
    field: field,
    onError: onError,
    requirePositiveCellSize: requirePositiveCellSize,
  );
}

void sceneValidateGrid(
  GridSettings grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
}) {
  _sceneValidateGridCellSize(
    grid.cellSize,
    field: field,
    onError: onError,
    requirePositiveCellSize: requirePositiveCellSize,
  );
}

void _sceneValidatePaletteFields({
  required _PaletteValidationFields fields,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonEmptyList(
    fields.penColors,
    field: '$field.penColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    fields.backgroundColors,
    field: '$field.backgroundColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    fields.gridSizes,
    field: '$field.gridSizes',
    onError: onError,
  );
  sceneValidateFields<double>(
    List<SceneValidationField<double>>.generate(
      fields.gridSizes.length,
      (index) =>
          (value: fields.gridSizes[index], field: '$field.gridSizes[$index]'),
    ),
    onError: onError,
    validateValue: sceneValidatePositiveDouble,
  );
}

void _sceneValidateGridCellSize(
  double cellSize, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
}) {
  sceneValidateFiniteDouble(
    cellSize,
    field: '$field.cellSize',
    onError: onError,
  );
  if (requirePositiveCellSize) {
    sceneValidatePositiveDouble(
      cellSize,
      field: '$field.cellSize',
      onError: onError,
    );
  }
}
