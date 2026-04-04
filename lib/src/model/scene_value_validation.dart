import 'dart:ui';

import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import 'scene_import_draft.dart';
import 'scene_value_validation_node.dart' as node_validation;
import 'scene_value_validation_palette_grid.dart' as palette_grid_validation;
import 'scene_value_validation_primitives.dart' as primitives_validation;
import 'scene_value_validation_support.dart' as validation_support;
import 'scene_value_validation_scene.dart' as scene_validation;

typedef SceneValidationErrorReporter =
    validation_support.SceneValidationErrorReporter;

void sceneValidateFiniteDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidateFiniteDouble(
  value,
  field: field,
  onError: onError,
);

void sceneValidateNonNegativeDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidateNonNegativeDouble(
  value,
  field: field,
  onError: onError,
);

void sceneValidatePositiveDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidatePositiveDouble(
  value,
  field: field,
  onError: onError,
);

void sceneValidateClamped01Double(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidateClamped01Double(
  value,
  field: field,
  onError: onError,
);

void sceneValidateNonNegativeInt(
  int value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidateNonNegativeInt(
  value,
  field: field,
  onError: onError,
);

void sceneValidatePositiveInt(
  int value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidatePositiveInt(
  value,
  field: field,
  onError: onError,
);

void sceneValidateFiniteOffset(
  Offset value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidateFiniteOffset(
  value,
  field: field,
  onError: onError,
);

void sceneValidateNonNegativeSize(
  Size value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidateNonNegativeSize(
  value,
  field: field,
  onError: onError,
);

void sceneValidateFiniteTransform2D(
  Transform2D value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidateFiniteTransform2D(
  value,
  field: field,
  onError: onError,
);

void sceneValidateNonEmptyList(
  List<Object?> values, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidateNonEmptyList(
  values,
  field: field,
  onError: onError,
);

void sceneValidateSvgPathData(
  String value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => primitives_validation.sceneValidateSvgPathData(
  value,
  field: field,
  onError: onError,
);

void sceneValidatePaletteSnapshot(
  ScenePaletteSnapshot palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => palette_grid_validation.sceneValidatePaletteSnapshot(
  palette,
  field: field,
  onError: onError,
);

void sceneValidatePalette(
  ScenePalette palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => palette_grid_validation.sceneValidatePalette(
  palette,
  field: field,
  onError: onError,
);

void sceneValidateGridSnapshot(
  GridSnapshot grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
  required bool requireEnabledMinCellSize,
}) => palette_grid_validation.sceneValidateGridSnapshot(
  grid,
  field: field,
  onError: onError,
  requirePositiveCellSize: requirePositiveCellSize,
  requireEnabledMinCellSize: requireEnabledMinCellSize,
);

void sceneValidateGrid(
  GridSettings grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
  required bool requireEnabledMinCellSize,
}) => palette_grid_validation.sceneValidateGrid(
  grid,
  field: field,
  onError: onError,
  requirePositiveCellSize: requirePositiveCellSize,
  requireEnabledMinCellSize: requireEnabledMinCellSize,
);

void sceneValidateNodeSnapshot(
  NodeSnapshot node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => node_validation.sceneValidateNodeSnapshot(
  node,
  field: field,
  onError: onError,
);

void sceneValidateNode(
  SceneNode node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) => node_validation.sceneValidateNode(node, field: field, onError: onError);

void sceneValidateSnapshotValues(
  SceneSnapshot snapshot, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
}) => scene_validation.sceneValidateSnapshotValues(
  snapshot,
  onError: onError,
  requirePositiveGridCellSize: requirePositiveGridCellSize,
  requireEnabledMinGridCellSize: requireEnabledMinGridCellSize,
);

void sceneValidateImportDraftValues(
  SceneImportDraft draft, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
}) => scene_validation.sceneValidateImportDraftValues(
  draft,
  onError: onError,
  requirePositiveGridCellSize: requirePositiveGridCellSize,
  requireEnabledMinGridCellSize: requireEnabledMinGridCellSize,
);

void sceneValidateSceneValues(
  Scene scene, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
}) => scene_validation.sceneValidateSceneValues(
  scene,
  onError: onError,
  requirePositiveGridCellSize: requirePositiveGridCellSize,
  requireEnabledMinGridCellSize: requireEnabledMinGridCellSize,
);
