part of 'scene_value_validation.dart';

void sceneValidatePaletteSnapshot(
  ScenePaletteSnapshot palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonEmptyList(
    palette.penColors,
    field: '$field.penColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    palette.backgroundColors,
    field: '$field.backgroundColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    palette.gridSizes,
    field: '$field.gridSizes',
    onError: onError,
  );

  for (var i = 0; i < palette.gridSizes.length; i++) {
    sceneValidatePositiveDouble(
      palette.gridSizes[i],
      field: '$field.gridSizes[$i]',
      onError: onError,
    );
  }
}

void sceneValidatePalette(
  ScenePalette palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonEmptyList(
    palette.penColors,
    field: '$field.penColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    palette.backgroundColors,
    field: '$field.backgroundColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    palette.gridSizes,
    field: '$field.gridSizes',
    onError: onError,
  );

  for (var i = 0; i < palette.gridSizes.length; i++) {
    sceneValidatePositiveDouble(
      palette.gridSizes[i],
      field: '$field.gridSizes[$i]',
      onError: onError,
    );
  }
}

void sceneValidateGridSnapshot(
  GridSnapshot grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
}) {
  sceneValidateFiniteDouble(
    grid.cellSize,
    field: '$field.cellSize',
    onError: onError,
  );
  if (requirePositiveCellSize) {
    sceneValidatePositiveDouble(
      grid.cellSize,
      field: '$field.cellSize',
      onError: onError,
    );
  }
}

void sceneValidateGrid(
  GridSettings grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
}) {
  sceneValidateFiniteDouble(
    grid.cellSize,
    field: '$field.cellSize',
    onError: onError,
  );
  if (requirePositiveCellSize) {
    sceneValidatePositiveDouble(
      grid.cellSize,
      field: '$field.cellSize',
      onError: onError,
    );
  }
}
