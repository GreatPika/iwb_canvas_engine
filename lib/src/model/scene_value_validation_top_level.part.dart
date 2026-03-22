part of 'scene_value_validation.dart';

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
final _runtimeSceneValueValidationAccessors =
    _buildRuntimeSceneValueValidationAccessors();

void sceneValidateSnapshotValues(
  SceneSnapshot snapshot, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
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
    accessors: _snapshotSceneValueValidationAccessors,
  );
}

void sceneValidateSceneValues(
  Scene scene, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
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
    accessors: _runtimeSceneValueValidationAccessors,
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
  _sceneValidateArgumentBoundary(
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
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => NodeIdValue.of(value, name: field),
  );
}
