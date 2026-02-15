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

  final seenNodeIds = <String>{};
  final backgroundLayer = snapshot.backgroundLayer;
  if (backgroundLayer != null) {
    for (
      var nodeIndex = 0;
      nodeIndex < backgroundLayer.nodes.length;
      nodeIndex++
    ) {
      final field = 'backgroundLayer.nodes[$nodeIndex]';
      final node = backgroundLayer.nodes[nodeIndex];
      if (!seenNodeIds.add(node.id)) {
        _sceneValidationFail(
          onError: onError,
          value: node.id,
          field: '$field.id',
          message: 'must be unique across scene layers.',
        );
      }
      sceneValidateNodeSnapshot(node, field: field, onError: onError);
    }
  }

  for (var layerIndex = 0; layerIndex < snapshot.layers.length; layerIndex++) {
    final layer = snapshot.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final field = 'layers[$layerIndex].nodes[$nodeIndex]';
      final node = layer.nodes[nodeIndex];
      if (!seenNodeIds.add(node.id)) {
        _sceneValidationFail(
          onError: onError,
          value: node.id,
          field: '$field.id',
          message: 'must be unique across scene layers.',
        );
      }
      sceneValidateNodeSnapshot(node, field: field, onError: onError);
    }
  }
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

  final seenNodeIds = <String>{};
  final backgroundLayer = scene.backgroundLayer;
  if (backgroundLayer != null) {
    for (
      var nodeIndex = 0;
      nodeIndex < backgroundLayer.nodes.length;
      nodeIndex++
    ) {
      final field = 'backgroundLayer.nodes[$nodeIndex]';
      final node = backgroundLayer.nodes[nodeIndex];
      if (!seenNodeIds.add(node.id)) {
        _sceneValidationFail(
          onError: onError,
          value: node.id,
          field: '$field.id',
          message: 'must be unique across scene layers.',
        );
      }
      sceneValidateNode(node, field: field, onError: onError);
    }
  }

  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final layer = scene.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final field = 'layers[$layerIndex].nodes[$nodeIndex]';
      final node = layer.nodes[nodeIndex];
      if (!seenNodeIds.add(node.id)) {
        _sceneValidationFail(
          onError: onError,
          value: node.id,
          field: '$field.id',
          message: 'must be unique across scene layers.',
        );
      }
      sceneValidateNode(node, field: field, onError: onError);
    }
  }
}
