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

void sceneValidateSnapshotValues(
  SceneSnapshot snapshot, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
}) {
  sceneValidateFiniteOffset(
    snapshot.camera.offset,
    field: 'camera.offset',
    onError: onError,
  );
  sceneValidateGridSnapshot(
    snapshot.background.grid,
    field: 'background.grid',
    onError: onError,
    requirePositiveCellSize: requirePositiveGridCellSize,
  );
  sceneValidatePaletteSnapshot(
    snapshot.palette,
    field: 'palette',
    onError: onError,
  );
  _sceneValidateSnapshotLayerNodes(
    snapshot.backgroundLayer.nodes,
    field: 'backgroundLayer',
    onError: onError,
    validateNode: sceneValidateNodeSnapshot,
  );
  _sceneValidateContentLayers<ContentLayerSnapshot, NodeSnapshot>(
    snapshot.layers,
    onError: onError,
    accessors: (
      layerIdOf: (layer) => layer.id,
      layerNodesOf: (layer) => layer.nodes,
      validateSingleNode: sceneValidateNodeSnapshot,
      validateLayerNodes: _sceneValidateSnapshotLayerNodes,
    ),
  );
}

void sceneValidateSceneValues(
  Scene scene, {
  required SceneValidationErrorReporter onError,
  required bool requirePositiveGridCellSize,
}) {
  sceneValidateFiniteOffset(
    scene.camera.offset,
    field: 'camera.offset',
    onError: onError,
  );
  sceneValidateGrid(
    scene.background.grid,
    field: 'background.grid',
    onError: onError,
    requirePositiveCellSize: requirePositiveGridCellSize,
  );
  sceneValidatePalette(scene.palette, field: 'palette', onError: onError);

  final backgroundLayer = scene.backgroundLayer;
  if (backgroundLayer != null) {
    _sceneValidateRuntimeLayerNodes(
      backgroundLayer.nodes,
      field: 'backgroundLayer',
      onError: onError,
      validateNode: sceneValidateNode,
    );
  }

  _sceneValidateContentLayers<ContentLayer, SceneNode>(
    scene.layers,
    onError: onError,
    accessors: (
      layerIdOf: (layer) => layer.id,
      layerNodesOf: (layer) => layer.nodes,
      validateSingleNode: sceneValidateNode,
      validateLayerNodes: _sceneValidateRuntimeLayerNodes,
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
