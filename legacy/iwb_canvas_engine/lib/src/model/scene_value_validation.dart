import 'dart:ui';

import '../contract/scene_structure_validation.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../contract/scene_validation_diagnostics.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import 'scene_import_draft.dart';
import 'scene_validation_path_surface.dart';
import 'scene_value_validation_node.dart' as node_validation;
import 'scene_value_validation_palette_grid.dart' as palette_grid_validation;
import 'scene_value_validation_primitives.dart' as primitives_validation;
import 'scene_value_validation_support.dart' as validation_support;
import 'scene_value_validation_scene.dart' as scene_validation;

typedef SceneValidationErrorReporter =
    validation_support.SceneValidationErrorReporter;

Never sceneValidationThrowSceneDataException({
  required Object? value,
  required String field,
  String? message,
  SceneDataDiagnosticDescriptor? diagnostic,
}) => validation_support.sceneValidationThrowSceneDataException(
  value: value,
  field: field,
  message: message,
  diagnostic: diagnostic,
);

List<String> sceneCollectRuntimeSceneValidityViolations(Scene scene) {
  final violations = <String>[];

  violations.addAll(sceneCollectRuntimeStructuralSurfaceViolations(scene));
  violations.addAll(
    scene_validation.sceneCollectRuntimeSceneValueViolations(
      scene,
      requirePositiveGridCellSize: true,
      requireEnabledMinGridCellSize: true,
    ),
  );

  return violations;
}

List<String> sceneCollectRuntimeStructuralSurfaceViolations(Scene scene) {
  final violations = <String>[];

  violations.addAll(sceneCollectRuntimeSceneStructureViolations(scene));
  violations.addAll(
    scene_validation.sceneCollectRuntimeContentLayerIdViolations(scene),
  );

  return violations;
}

List<String> sceneCollectRuntimeSceneStructureViolations(Scene scene) {
  final structureErrors =
      sceneCollectSceneStructureErrors<ContentLayer, SceneNode>(
        layers: scene.layers,
        backgroundNodes: scene.backgroundLayer?.nodes ?? const <SceneNode>[],
        layerIdOf: (layer) => layer.id,
        nodesOf: (layer) => layer.nodes,
        nodeIdOf: (node) => node.id,
      );
  return structureErrors
      .map(validation_support.sceneFormatSceneDataViolation)
      .toList(growable: false);
}

List<String> sceneCollectRuntimeCameraOffsetViolations({
  required Offset value,
  String field = 'camera.offset',
}) {
  final violations = <String>[];
  validation_support.sceneCollectSceneDataViolation(
    violations: violations,
    validate: () => palette_grid_validation.sceneValidateCameraOffsetValue(
      value,
      field: field,
      onError: validation_support.sceneValidationThrowSceneDataException,
    ),
  );
  return violations;
}

List<String> sceneCollectRuntimeGridViolations(
  GridSettings grid, {
  String field = 'background.grid',
  required bool requirePositiveCellSize,
  required bool requireEnabledMinCellSize,
}) {
  final violations = <String>[];
  validation_support.sceneCollectSceneDataViolation(
    violations: violations,
    validate: () => palette_grid_validation.sceneValidateGrid(
      grid,
      field: field,
      onError: validation_support.sceneValidationThrowSceneDataException,
      requirePositiveCellSize: requirePositiveCellSize,
      requireEnabledMinCellSize: requireEnabledMinCellSize,
    ),
  );
  return violations;
}

List<String> sceneCollectRuntimePaletteViolations(
  ScenePalette palette, {
  String field = 'palette',
}) {
  final violations = <String>[];
  validation_support.sceneCollectSceneDataViolation(
    violations: violations,
    validate: () => palette_grid_validation.sceneValidatePalette(
      palette,
      field: field,
      onError: validation_support.sceneValidationThrowSceneDataException,
    ),
  );
  return violations;
}

List<String> sceneCollectRuntimeNodeViolations(
  SceneNode node, {
  required String field,
}) {
  final violations = <String>[];
  validation_support.sceneCollectSceneDataViolation(
    violations: violations,
    validate: () => node_validation.sceneValidateNode(
      node,
      field: field,
      onError: validation_support.sceneValidationThrowSceneDataException,
    ),
  );
  return violations;
}

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
  SceneValidationPathSurface pathSurface = SceneValidationPathSurface.snapshot,
}) => node_validation.sceneValidateNodeSnapshot(
  node,
  field: field,
  onError: onError,
  pathSurface: pathSurface,
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
  required ({bool requirePositiveCellSize, bool requireEnabledMinCellSize})
  gridPolicy,
  required SceneValidationPathSurface pathSurface,
}) => scene_validation.sceneValidateImportDraftValues(
  draft,
  onError: onError,
  gridPolicy: gridPolicy,
  pathSurface: pathSurface,
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
