import 'dart:ui';

import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import '../contract/validated/layer_id_value.dart';
import '../contract/validated/node_id_value.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import 'scene_import_draft.dart';
import 'scene_value_validation_node.dart';
import 'scene_value_validation_palette_grid.dart';
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

typedef _LayerValidationAccessors<TLayer, TNode> = ({
  String Function(TLayer layer) layerIdOf,
  List<TNode> Function(TLayer layer) layerNodesOf,
  void Function(
    TNode node, {
    required String field,
    required SceneValidationErrorReporter onError,
  })
  validateSingleNode,
  void Function(
    List<TNode> nodes, {
    required String field,
    required SceneValidationErrorReporter onError,
    required void Function(
      TNode node, {
      required String field,
      required SceneValidationErrorReporter onError,
    })
    validateNode,
  })
  validateLayerNodes,
});

typedef _NodeValidationAccessors<TNode> = ({
  String Function(TNode node) nodeIdOf,
  void Function(
    TNode node, {
    required String field,
    required SceneValidationErrorReporter onError,
  })
  validateNode,
});

typedef _SceneValueValidationAccessors<TScene, TGrid, TPalette, TLayer, TNode> =
    ({
      Offset Function(TScene scene) cameraOffsetOf,
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
      void Function(
        List<TNode> nodes, {
        required String field,
        required SceneValidationErrorReporter onError,
        required void Function(
          TNode node, {
          required String field,
          required SceneValidationErrorReporter onError,
        })
        validateNode,
      })
      validateLayerNodes,
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
    accessors: _runtimeSceneValueValidationAccessors,
  );
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
    cameraOffsetOf: (scene) => scene.camera.offset,
    gridOf: (scene) => scene.background.grid,
    paletteOf: (scene) => scene.palette,
    backgroundNodesOf: (scene) => scene.backgroundLayer.nodes,
    contentLayersOf: (scene) => scene.layers,
    layerIdOf: (layer) => layer.id,
    layerNodesOf: (layer) => layer.nodes,
    validateGrid: sceneValidateGridSnapshot,
    validatePalette: sceneValidatePaletteSnapshot,
    validateSingleNode: sceneValidateNodeSnapshot,
    validateLayerNodes: _sceneValidateSnapshotLayerNodes,
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
    cameraOffsetOf: (scene) => scene.camera.offset,
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
        }) => sceneValidateGridSnapshot(
          GridSnapshot(
            isEnabled: grid.isEnabled,
            cellSize: grid.cellSize,
            color: grid.color,
          ),
          field: field,
          onError: onError,
          requirePositiveCellSize: requirePositiveCellSize,
          requireEnabledMinCellSize: requireEnabledMinCellSize,
        ),
    validatePalette: (palette, {required field, required onError}) =>
        sceneValidatePaletteSnapshot(
          materializeScenePaletteSnapshot(palette),
          field: field,
          onError: onError,
        ),
    validateSingleNode: (node, {required field, required onError}) =>
        sceneValidateNodeSnapshot(
          materializeNodeSnapshot(node),
          field: field,
          onError: onError,
        ),
    validateLayerNodes: _sceneValidateDraftLayerNodes,
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
    cameraOffsetOf: (scene) => scene.camera.offset,
    gridOf: (scene) => scene.background.grid,
    paletteOf: (scene) => scene.palette,
    backgroundNodesOf: (scene) => scene.backgroundLayer?.nodes,
    contentLayersOf: (scene) => scene.layers,
    layerIdOf: (layer) => layer.id,
    layerNodesOf: (layer) => layer.nodes,
    validateGrid: sceneValidateGrid,
    validatePalette: sceneValidatePalette,
    validateSingleNode: sceneValidateNode,
    validateLayerNodes: _sceneValidateRuntimeLayerNodes,
  );
}

void _sceneValidateSceneValues<TScene, TGrid, TPalette, TLayer, TNode>(
  TScene scene, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
  required bool requireEnabledMinGridCellSize,
  required _SceneValueValidationAccessors<
    TScene,
    TGrid,
    TPalette,
    TLayer,
    TNode
  >
  accessors,
}) {
  sceneValidateFiniteOffset(
    accessors.cameraOffsetOf(scene),
    field: 'camera.offset',
    onError: onError,
  );
  accessors.validateGrid(
    accessors.gridOf(scene),
    field: 'background.grid',
    onError: onError,
    requirePositiveCellSize: requirePositiveGridCellSize,
    requireEnabledMinCellSize: requireEnabledMinGridCellSize,
  );
  accessors.validatePalette(
    accessors.paletteOf(scene),
    field: 'palette',
    onError: onError,
  );

  final backgroundNodes = accessors.backgroundNodesOf(scene);
  if (backgroundNodes != null) {
    accessors.validateLayerNodes(
      backgroundNodes,
      field: 'backgroundLayer',
      onError: onError,
      validateNode: (node, {required field, required onError}) =>
          accessors.validateSingleNode(node, field: field, onError: onError),
    );
  }

  _sceneValidateContentLayers<TLayer, TNode>(
    accessors.contentLayersOf(scene),
    onError: onError,
    accessors: (
      layerIdOf: accessors.layerIdOf,
      layerNodesOf: accessors.layerNodesOf,
      validateSingleNode: accessors.validateSingleNode,
      validateLayerNodes: accessors.validateLayerNodes,
    ),
  );
}

void _sceneValidateSnapshotLayerNodes(
  List<NodeSnapshot> nodes, {
  required String field,
  required SceneValidationErrorReporter onError,
  required void Function(
    NodeSnapshot node, {
    required String field,
    required SceneValidationErrorReporter onError,
  })
  validateNode,
}) {
  _sceneValidateLayerNodes<NodeSnapshot>(
    nodes,
    field: field,
    onError: onError,
    accessors: (nodeIdOf: (node) => node.id, validateNode: validateNode),
  );
}

void _sceneValidateRuntimeLayerNodes(
  List<SceneNode> nodes, {
  required String field,
  required SceneValidationErrorReporter onError,
  required void Function(
    SceneNode node, {
    required String field,
    required SceneValidationErrorReporter onError,
  })
  validateNode,
}) {
  _sceneValidateLayerNodes<SceneNode>(
    nodes,
    field: field,
    onError: onError,
    accessors: (nodeIdOf: (node) => node.id, validateNode: validateNode),
  );
}

void _sceneValidateDraftLayerNodes(
  List<NodeSnapshotBacking> nodes, {
  required String field,
  required SceneValidationErrorReporter onError,
  required void Function(
    NodeSnapshotBacking node, {
    required String field,
    required SceneValidationErrorReporter onError,
  })
  validateNode,
}) {
  _sceneValidateLayerNodes<NodeSnapshotBacking>(
    nodes,
    field: field,
    onError: onError,
    accessors: (nodeIdOf: (node) => node.id, validateNode: validateNode),
  );
}

void _sceneValidateContentLayers<TLayer, TNode>(
  List<TLayer> layers, {
  required SceneValidationErrorReporter onError,
  required _LayerValidationAccessors<TLayer, TNode> accessors,
}) {
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    final layer = layers[layerIndex];
    final field = 'layers[$layerIndex]';
    _sceneValidateLayerId(
      accessors.layerIdOf(layer),
      field: '$field.id',
      onError: onError,
    );
    accessors.validateLayerNodes(
      accessors.layerNodesOf(layer),
      field: field,
      onError: onError,
      validateNode: (node, {required field, required onError}) =>
          accessors.validateSingleNode(node, field: field, onError: onError),
    );
  }
}

void _sceneValidateLayerNodes<TNode>(
  List<TNode> nodes, {
  required String field,
  required SceneValidationErrorReporter onError,
  required _NodeValidationAccessors<TNode> accessors,
}) {
  for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
    final node = nodes[nodeIndex];
    final nodeField = '$field.nodes[$nodeIndex]';
    _sceneValidateNodeId(
      accessors.nodeIdOf(node),
      field: '$nodeField.id',
      onError: onError,
    );
    accessors.validateNode(node, field: nodeField, onError: onError);
  }
}

void _sceneValidateLayerId(
  String value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => LayerIdValue.of(value, name: field),
  );
}

void _sceneValidateNodeId(
  String value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => NodeIdValue.of(value, name: field),
  );
}
