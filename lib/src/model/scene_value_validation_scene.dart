import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import '../contract/validated/layer_id_value.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import 'scene_import_draft.dart';
import 'scene_value_validation_node.dart';
import 'scene_value_validation_palette_grid.dart';
import 'scene_value_validation_support.dart' as validation_support;

typedef _LayerValidationAccessors<TLayer, TNode> = ({
  String Function(TLayer layer) layerIdOf,
  List<TNode> Function(TLayer layer) layerNodesOf,
  void Function(
    TNode node, {
    required String field,
    required SceneValidationErrorReporter onError,
  })
  validateSingleNode,
});

typedef _NodeValidationAccessors<TNode> = ({
  void Function(
    TNode node, {
    required String field,
    required SceneValidationErrorReporter onError,
  })
  validateNode,
});

typedef SceneValidationErrorReporter =
    validation_support.SceneValidationErrorReporter;

typedef _SceneValidationStepRunner = void Function(void Function() step);

typedef _SceneValueValidationAccessors<TScene, TGrid, TPalette, TLayer, TNode> =
    ({
      void Function(
        TScene scene, {
        required String field,
        required SceneValidationErrorReporter onError,
      })
      validateCameraOffset,
      TGrid Function(TScene scene) gridOf,
      TPalette Function(TScene scene) paletteOf,
      List<TNode>? Function(TScene scene) backgroundNodesOf,
      List<TLayer> Function(TScene scene) contentLayersOf,
      String Function(TLayer layer) layerIdOf,
      List<TNode> Function(TLayer layer) layerNodesOf,
      void Function(
        TGrid grid, {
        required String field,
        required SceneValidationErrorReporter onError,
        required bool requirePositiveCellSize,
        required bool requireEnabledMinCellSize,
      })
      validateGrid,
      void Function(
        TPalette palette, {
        required String field,
        required SceneValidationErrorReporter onError,
      })
      validatePalette,
      void Function(
        TNode node, {
        required String field,
        required SceneValidationErrorReporter onError,
      })
      validateSingleNode,
    });

final _snapshotSceneValueValidationAccessors =
    _buildSnapshotSceneValueValidationAccessors();
final _draftSceneValueValidationAccessors =
    _buildDraftSceneValueValidationAccessors();
final _runtimeSceneValueValidationAccessors =
    _buildRuntimeSceneValueValidationAccessors();

void sceneValidateSnapshotValues(
  SceneSnapshot snapshot, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
}) {
  _sceneValidateSceneValues<
    SceneSnapshot,
    GridSnapshot,
    ScenePaletteSnapshot,
    ContentLayerSnapshot,
    NodeSnapshot
  >(
    snapshot,
    onError: onError,
    requirePositiveGridCellSize: requirePositiveGridCellSize,
    requireEnabledMinGridCellSize: requireEnabledMinGridCellSize,
    validateLayerIds: true,
    runStep: _sceneRunValidationStep,
    accessors: _snapshotSceneValueValidationAccessors,
  );
}

void sceneValidateSceneValues(
  Scene scene, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
}) {
  _sceneValidateSceneValues<
    Scene,
    GridSettings,
    ScenePalette,
    ContentLayer,
    SceneNode
  >(
    scene,
    onError: onError,
    requirePositiveGridCellSize: requirePositiveGridCellSize,
    requireEnabledMinGridCellSize: requireEnabledMinGridCellSize,
    validateLayerIds: true,
    runStep: _sceneRunValidationStep,
    accessors: _runtimeSceneValueValidationAccessors,
  );
}

List<String> sceneCollectRuntimeSceneValueViolations(
  Scene scene, {
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
}) {
  final violations = <String>[];

  _sceneValidateSceneValues<
    Scene,
    GridSettings,
    ScenePalette,
    ContentLayer,
    SceneNode
  >(
    scene,
    onError: validation_support.sceneValidationThrowSceneDataException,
    requirePositiveGridCellSize: requirePositiveGridCellSize,
    requireEnabledMinGridCellSize: requireEnabledMinGridCellSize,
    validateLayerIds: false,
    runStep: _sceneCollectValidationStepRunner(violations),
    accessors: _runtimeSceneValueValidationAccessors,
  );

  return violations;
}

List<String> sceneCollectRuntimeContentLayerIdViolations(Scene scene) {
  final violations = <String>[];

  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final layer = scene.layers[layerIndex];
    validation_support.sceneCollectSceneDataViolation(
      violations: violations,
      validate: () => _sceneValidateLayerId(
        layer.id,
        field: 'layers[$layerIndex].id',
        onError: validation_support.sceneValidationThrowSceneDataException,
      ),
    );
  }

  return violations;
}

void sceneValidateImportDraftValues(
  SceneImportDraft draft, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
}) {
  _sceneValidateSceneValues<
    SceneImportDraft,
    GridSnapshotBacking,
    ScenePaletteSnapshotBacking,
    ContentLayerSnapshotBacking,
    NodeSnapshotBacking
  >(
    draft,
    onError: onError,
    requirePositiveGridCellSize: requirePositiveGridCellSize,
    requireEnabledMinGridCellSize: requireEnabledMinGridCellSize,
    validateLayerIds: true,
    runStep: _sceneRunValidationStep,
    accessors: _draftSceneValueValidationAccessors,
  );
}

_SceneValueValidationAccessors<
  SceneSnapshot,
  GridSnapshot,
  ScenePaletteSnapshot,
  ContentLayerSnapshot,
  NodeSnapshot
>
_buildSnapshotSceneValueValidationAccessors() {
  return (
    validateCameraOffset: (scene, {required field, required onError}) =>
        sceneValidateCameraOffsetValue(
          scene.camera.offset,
          field: field,
          onError: onError,
        ),
    gridOf: (scene) => scene.background.grid,
    paletteOf: (scene) => scene.palette,
    backgroundNodesOf: (scene) => scene.backgroundLayer.nodes,
    contentLayersOf: (scene) => scene.layers,
    layerIdOf: (layer) => layer.id,
    layerNodesOf: (layer) => layer.nodes,
    validateGrid: sceneValidateGridSnapshot,
    validatePalette: sceneValidatePaletteSnapshot,
    validateSingleNode: sceneValidateNodeSnapshot,
  );
}

_SceneValueValidationAccessors<
  SceneImportDraft,
  GridSnapshotBacking,
  ScenePaletteSnapshotBacking,
  ContentLayerSnapshotBacking,
  NodeSnapshotBacking
>
_buildDraftSceneValueValidationAccessors() {
  return (
    validateCameraOffset: (scene, {required field, required onError}) =>
        sceneValidateCameraOffsetValue(
          scene.camera.offset,
          field: field,
          onError: onError,
        ),
    gridOf: (scene) => scene.background.grid,
    paletteOf: (scene) => scene.palette,
    backgroundNodesOf: (scene) => scene.backgroundLayer.nodes,
    contentLayersOf: (scene) => scene.layers,
    layerIdOf: (layer) => layer.id,
    layerNodesOf: (layer) => layer.nodes,
    validateGrid:
        (
          grid, {
          required field,
          required onError,
          required requirePositiveCellSize,
          required requireEnabledMinCellSize,
        }) => sceneValidateGridCellSizeValue(
          cellSize: grid.cellSize,
          isEnabled: grid.isEnabled,
          field: field,
          onError: onError,
          requirePositiveCellSize: requirePositiveCellSize,
          requireEnabledMinCellSize: requireEnabledMinCellSize,
        ),
    validatePalette: (palette, {required field, required onError}) =>
        sceneValidatePaletteFields(
          penColors: palette.penColors,
          backgroundColors: palette.backgroundColors,
          gridSizes: palette.gridSizes,
          field: field,
          onError: onError,
        ),
    validateSingleNode: (node, {required field, required onError}) =>
        sceneValidateNodeSnapshot(
          materializeNodeSnapshot(node),
          field: field,
          onError: onError,
        ),
  );
}

_SceneValueValidationAccessors<
  Scene,
  GridSettings,
  ScenePalette,
  ContentLayer,
  SceneNode
>
_buildRuntimeSceneValueValidationAccessors() {
  return (
    validateCameraOffset: (scene, {required field, required onError}) =>
        sceneValidateCameraOffsetValue(
          scene.camera.offset,
          field: field,
          onError: onError,
        ),
    gridOf: (scene) => scene.background.grid,
    paletteOf: (scene) => scene.palette,
    backgroundNodesOf: (scene) => scene.backgroundLayer?.nodes,
    contentLayersOf: (scene) => scene.layers,
    layerIdOf: (layer) => layer.id,
    layerNodesOf: (layer) => layer.nodes,
    validateGrid: sceneValidateGrid,
    validatePalette: sceneValidatePalette,
    validateSingleNode: sceneValidateNode,
  );
}

void _sceneValidateSceneValues<TScene, TGrid, TPalette, TLayer, TNode>(
  TScene scene, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
  required bool validateLayerIds,
  required _SceneValidationStepRunner runStep,
  required _SceneValueValidationAccessors<
    TScene,
    TGrid,
    TPalette,
    TLayer,
    TNode
  >
  accessors,
}) {
  runStep(
    () => accessors.validateCameraOffset(
      scene,
      field: 'camera.offset',
      onError: onError,
    ),
  );
  runStep(
    () => accessors.validateGrid(
      accessors.gridOf(scene),
      field: 'background.grid',
      onError: onError,
      requirePositiveCellSize: requirePositiveGridCellSize,
      requireEnabledMinCellSize: requireEnabledMinGridCellSize,
    ),
  );
  runStep(
    () => accessors.validatePalette(
      accessors.paletteOf(scene),
      field: 'palette',
      onError: onError,
    ),
  );

  final backgroundNodes = accessors.backgroundNodesOf(scene);
  if (backgroundNodes != null) {
    _sceneValidateLayerNodes<TNode>(
      backgroundNodes,
      field: 'backgroundLayer',
      onError: onError,
      runStep: runStep,
      accessors: (validateNode: accessors.validateSingleNode),
    );
  }

  _sceneValidateContentLayers<TLayer, TNode>(
    accessors.contentLayersOf(scene),
    onError: onError,
    validateLayerIds: validateLayerIds,
    runStep: runStep,
    accessors: (
      layerIdOf: accessors.layerIdOf,
      layerNodesOf: accessors.layerNodesOf,
      validateSingleNode: accessors.validateSingleNode,
    ),
  );
}

void _sceneValidateContentLayers<TLayer, TNode>(
  List<TLayer> layers, {
  required SceneValidationErrorReporter onError,
  required bool validateLayerIds,
  required _SceneValidationStepRunner runStep,
  required _LayerValidationAccessors<TLayer, TNode> accessors,
}) {
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    final layer = layers[layerIndex];
    final field = 'layers[$layerIndex]';
    if (validateLayerIds) {
      runStep(
        () => _sceneValidateLayerId(
          accessors.layerIdOf(layer),
          field: '$field.id',
          onError: onError,
        ),
      );
    }
    _sceneValidateLayerNodes<TNode>(
      accessors.layerNodesOf(layer),
      field: field,
      onError: onError,
      runStep: runStep,
      accessors: (validateNode: accessors.validateSingleNode),
    );
  }
}

void _sceneValidateLayerNodes<TNode>(
  List<TNode> nodes, {
  required String field,
  required SceneValidationErrorReporter onError,
  required _SceneValidationStepRunner runStep,
  required _NodeValidationAccessors<TNode> accessors,
}) {
  for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
    final node = nodes[nodeIndex];
    final nodeField = '$field.nodes[$nodeIndex]';
    runStep(
      () => accessors.validateNode(node, field: nodeField, onError: onError),
    );
  }
}

void _sceneValidateLayerId(
  String value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  validation_support.sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => LayerIdValue.of(value, name: field),
  );
}

void _sceneRunValidationStep(void Function() step) => step();

_SceneValidationStepRunner _sceneCollectValidationStepRunner(
  List<String> violations,
) =>
    (step) => validation_support.sceneCollectSceneDataViolation(
      violations: violations,
      validate: step,
    );
