part of 'scene_value_validation.dart';

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
  _sceneValidateSnapshotContentLayers(snapshot.layers, onError: onError);
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

  _sceneValidateRuntimeContentLayers(scene.layers, onError: onError);
}

void _sceneValidateSnapshotContentLayers(
  List<ContentLayerSnapshot> layers, {
  required SceneValidationErrorReporter onError,
}) {
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    final layer = layers[layerIndex];
    final field = 'layers[$layerIndex]';
    _sceneValidateLayerId(layer.id, field: '$field.id', onError: onError);
    _sceneValidateSnapshotLayerNodes(
      layer.nodes,
      field: field,
      onError: onError,
      validateNode: sceneValidateNodeSnapshot,
    );
  }
}

void _sceneValidateRuntimeContentLayers(
  List<ContentLayer> layers, {
  required SceneValidationErrorReporter onError,
}) {
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    final layer = layers[layerIndex];
    final field = 'layers[$layerIndex]';
    _sceneValidateLayerId(layer.id, field: '$field.id', onError: onError);
    _sceneValidateRuntimeLayerNodes(
      layer.nodes,
      field: field,
      onError: onError,
      validateNode: sceneValidateNode,
    );
  }
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
  for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
    final node = nodes[nodeIndex];
    final nodeField = '$field.nodes[$nodeIndex]';
    _sceneValidateNodeId(node.id, field: '$nodeField.id', onError: onError);
    validateNode(node, field: nodeField, onError: onError);
  }
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
  for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
    final node = nodes[nodeIndex];
    final nodeField = '$field.nodes[$nodeIndex]';
    _sceneValidateNodeId(node.id, field: '$nodeField.id', onError: onError);
    validateNode(node, field: nodeField, onError: onError);
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
