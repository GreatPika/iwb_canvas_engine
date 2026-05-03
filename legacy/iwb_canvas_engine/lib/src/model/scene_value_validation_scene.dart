import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import '../contract/validated/layer_id_value.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import 'scene_import_draft.dart';
import 'scene_validation_path_surface.dart';
import 'scene_value_validation_node.dart';
import 'scene_value_validation_palette_grid.dart';
import 'scene_value_validation_support.dart' as validation_support;

typedef _LayerNodeValidationAccessors<TLayer, TNode> = ({
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
typedef _GridValidationPolicy = ({
  bool requirePositiveCellSize,
  bool requireEnabledMinCellSize,
});

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
        required _GridValidationPolicy policy,
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

typedef _SceneValueValidationConfig<TScene, TGrid, TPalette, TLayer, TNode> = ({
  SceneValidationErrorReporter onError,
  _GridValidationPolicy gridPolicy,
  _SceneValidationStepRunner runStep,
  _SceneValueValidationAccessors<TScene, TGrid, TPalette, TLayer, TNode>
  accessors,
});

typedef _LayerNodeValidationConfig<TNode> = ({
  SceneValidationErrorReporter onError,
  _SceneValidationStepRunner runStep,
  _NodeValidationAccessors<TNode> accessors,
});

final _snapshotSceneValueValidationAccessors =
    _buildSnapshotSceneValueValidationAccessors();
final _runtimeSceneValueValidationAccessors =
    _buildRuntimeSceneValueValidationAccessors();

void sceneValidateSnapshotValues(
  SceneSnapshot snapshot, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
}) {
  _sceneValidateSceneValuesWithLayerIds<
    SceneSnapshot,
    GridSnapshot,
    ScenePaletteSnapshot,
    ContentLayerSnapshot,
    NodeSnapshot
  >(
    snapshot,
    config: (
      onError: onError,
      gridPolicy: (
        requirePositiveCellSize: requirePositiveGridCellSize,
        requireEnabledMinCellSize: requireEnabledMinGridCellSize,
      ),
      runStep: _sceneRunValidationStep,
      accessors: _snapshotSceneValueValidationAccessors,
    ),
  );
}

void sceneValidateSceneValues(
  Scene scene, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
}) {
  _sceneValidateSceneValuesWithLayerIds<
    Scene,
    GridSettings,
    ScenePalette,
    ContentLayer,
    SceneNode
  >(
    scene,
    config: (
      onError: onError,
      gridPolicy: (
        requirePositiveCellSize: requirePositiveGridCellSize,
        requireEnabledMinCellSize: requireEnabledMinGridCellSize,
      ),
      runStep: _sceneRunValidationStep,
      accessors: _runtimeSceneValueValidationAccessors,
    ),
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
    config: (
      onError: validation_support.sceneValidationThrowSceneDataException,
      gridPolicy: (
        requirePositiveCellSize: requirePositiveGridCellSize,
        requireEnabledMinCellSize: requireEnabledMinGridCellSize,
      ),
      runStep: _sceneCollectValidationStepRunner(violations),
      accessors: _runtimeSceneValueValidationAccessors,
    ),
  );

  return violations;
}

List<String> sceneCollectRuntimeContentLayerIdViolations(Scene scene) {
  final violations = <String>[];

  _sceneValidateContentLayerIds<ContentLayer>(
    scene.layers,
    onError: validation_support.sceneValidationThrowSceneDataException,
    runStep: _sceneCollectValidationStepRunner(violations),
    accessors: (layerIdOf: (layer) => layer.id),
  );

  return violations;
}

void sceneValidateImportDraftValues(
  SceneImportDraft draft, {
  required SceneValidationErrorReporter onError,
  required ({bool requirePositiveCellSize, bool requireEnabledMinCellSize})
  gridPolicy,
  required SceneValidationPathSurface pathSurface,
}) {
  _sceneValidateSceneValuesWithLayerIds<
    SceneImportDraft,
    GridSnapshotBacking,
    ScenePaletteSnapshotBacking,
    ContentLayerSnapshotBacking,
    NodeSnapshotBacking
  >(
    draft,
    config: (
      onError: onError,
      gridPolicy: gridPolicy,
      runStep: _sceneRunValidationStep,
      accessors: _buildDraftSceneValueValidationAccessors(
        pathSurface: pathSurface,
      ),
    ),
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
    validateGrid: _sceneValidateSnapshotGrid,
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
_buildDraftSceneValueValidationAccessors({
  required SceneValidationPathSurface pathSurface,
}) {
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
    validateGrid: _sceneValidateDraftGrid,
    validatePalette: _sceneValidateDraftPalette,
    validateSingleNode: _buildDraftNodeSnapshotValidator(pathSurface),
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
    validateGrid: _sceneValidateRuntimeGrid,
    validatePalette: sceneValidatePalette,
    validateSingleNode: sceneValidateNode,
  );
}

void _sceneValidateSceneValues<TScene, TGrid, TPalette, TLayer, TNode>(
  TScene scene, {
  required _SceneValueValidationConfig<TScene, TGrid, TPalette, TLayer, TNode>
  config,
}) {
  _sceneValidateSharedSceneFields(scene, config: config);

  _sceneValidateContentLayers<TLayer, TNode>(
    config.accessors.contentLayersOf(scene),
    onError: config.onError,
    runStep: config.runStep,
    accessors: (
      layerNodesOf: config.accessors.layerNodesOf,
      validateSingleNode: config.accessors.validateSingleNode,
    ),
  );
}

void
_sceneValidateSceneValuesWithLayerIds<TScene, TGrid, TPalette, TLayer, TNode>(
  TScene scene, {
  required _SceneValueValidationConfig<TScene, TGrid, TPalette, TLayer, TNode>
  config,
}) {
  _sceneValidateSharedSceneFields(scene, config: config);

  _sceneValidateContentLayersWithLayerIds<TLayer, TNode>(
    config.accessors.contentLayersOf(scene),
    onError: config.onError,
    runStep: config.runStep,
    accessors: (
      layerIdOf: config.accessors.layerIdOf,
      layerNodesOf: config.accessors.layerNodesOf,
      validateSingleNode: config.accessors.validateSingleNode,
    ),
  );
}

void _sceneValidateSharedSceneFields<TScene, TGrid, TPalette, TLayer, TNode>(
  TScene scene, {
  required _SceneValueValidationConfig<TScene, TGrid, TPalette, TLayer, TNode>
  config,
}) {
  config.runStep(
    () => config.accessors.validateCameraOffset(
      scene,
      field: 'camera.offset',
      onError: config.onError,
    ),
  );
  config.runStep(
    () => config.accessors.validateGrid(
      config.accessors.gridOf(scene),
      field: 'background.grid',
      onError: config.onError,
      policy: config.gridPolicy,
    ),
  );
  config.runStep(
    () => config.accessors.validatePalette(
      config.accessors.paletteOf(scene),
      field: 'palette',
      onError: config.onError,
    ),
  );

  final backgroundNodes = config.accessors.backgroundNodesOf(scene);
  if (backgroundNodes != null) {
    _sceneValidateLayerNodes<TNode>(
      backgroundNodes,
      field: 'backgroundLayer',
      config: (
        onError: config.onError,
        runStep: config.runStep,
        accessors: (validateNode: config.accessors.validateSingleNode),
      ),
    );
  }
}

void _sceneValidateContentLayerIds<TLayer>(
  List<TLayer> layers, {
  required SceneValidationErrorReporter onError,
  required _SceneValidationStepRunner runStep,
  required ({String Function(TLayer layer) layerIdOf}) accessors,
}) {
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    final layer = layers[layerIndex];
    runStep(
      () => _sceneValidateLayerId(
        accessors.layerIdOf(layer),
        field: 'layers[$layerIndex].id',
        onError: onError,
      ),
    );
  }
}

void _sceneValidateContentLayersWithLayerIds<TLayer, TNode>(
  List<TLayer> layers, {
  required SceneValidationErrorReporter onError,
  required _SceneValidationStepRunner runStep,
  required ({
    String Function(TLayer layer) layerIdOf,
    List<TNode> Function(TLayer layer) layerNodesOf,
    void Function(
      TNode node, {
      required String field,
      required SceneValidationErrorReporter onError,
    })
    validateSingleNode,
  })
  accessors,
}) {
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    final layer = layers[layerIndex];
    final field = 'layers[$layerIndex]';
    runStep(
      () => _sceneValidateLayerId(
        accessors.layerIdOf(layer),
        field: '$field.id',
        onError: onError,
      ),
    );
    _sceneValidateLayerNodes<TNode>(
      accessors.layerNodesOf(layer),
      field: field,
      config: (
        onError: onError,
        runStep: runStep,
        accessors: (validateNode: accessors.validateSingleNode),
      ),
    );
  }
}

void _sceneValidateContentLayers<TLayer, TNode>(
  List<TLayer> layers, {
  required SceneValidationErrorReporter onError,
  required _SceneValidationStepRunner runStep,
  required _LayerNodeValidationAccessors<TLayer, TNode> accessors,
}) {
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    final layer = layers[layerIndex];
    final field = 'layers[$layerIndex]';
    _sceneValidateLayerNodes<TNode>(
      accessors.layerNodesOf(layer),
      field: field,
      config: (
        onError: onError,
        runStep: runStep,
        accessors: (validateNode: accessors.validateSingleNode),
      ),
    );
  }
}

void _sceneValidateLayerNodes<TNode>(
  List<TNode> nodes, {
  required String field,
  required _LayerNodeValidationConfig<TNode> config,
}) {
  for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
    final node = nodes[nodeIndex];
    final nodeField = '$field.nodes[$nodeIndex]';
    config.runStep(
      () => config.accessors.validateNode(
        node,
        field: nodeField,
        onError: config.onError,
      ),
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

void _sceneValidateDraftGrid(
  GridSnapshotBacking grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required _GridValidationPolicy policy,
}) {
  sceneValidateGridCellSizeValue(
    cellSize: grid.cellSize,
    isEnabled: grid.isEnabled,
    field: field,
    onError: onError,
    requirePositiveCellSize: policy.requirePositiveCellSize,
    requireEnabledMinCellSize: policy.requireEnabledMinCellSize,
  );
}

void _sceneValidateDraftPalette(
  ScenePaletteSnapshotBacking palette, {
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

void _sceneValidateSnapshotGrid(
  GridSnapshot grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required _GridValidationPolicy policy,
}) {
  sceneValidateGridSnapshot(
    grid,
    field: field,
    onError: onError,
    requirePositiveCellSize: policy.requirePositiveCellSize,
    requireEnabledMinCellSize: policy.requireEnabledMinCellSize,
  );
}

void _sceneValidateRuntimeGrid(
  GridSettings grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required _GridValidationPolicy policy,
}) {
  sceneValidateGrid(
    grid,
    field: field,
    onError: onError,
    requirePositiveCellSize: policy.requirePositiveCellSize,
    requireEnabledMinCellSize: policy.requireEnabledMinCellSize,
  );
}

void Function(
  NodeSnapshotBacking node, {
  required String field,
  required SceneValidationErrorReporter onError,
})
_buildDraftNodeSnapshotValidator(SceneValidationPathSurface pathSurface) {
  return (node, {required field, required onError}) =>
      sceneValidateNodeSnapshotBacking(
        node,
        field: field,
        onError: onError,
        pathSurface: pathSurface,
      );
}

_SceneValidationStepRunner _sceneCollectValidationStepRunner(
  List<String> violations,
) =>
    (step) => validation_support.sceneCollectSceneDataViolation(
      violations: violations,
      validate: step,
    );
