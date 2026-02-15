part of 'scene_builder.dart';

void _validateStructuralInvariants(SceneSnapshot snapshot) {
  final seen = <String>{};

  final backgroundLayer = snapshot.backgroundLayer;
  if (backgroundLayer != null) {
    for (
      var nodeIndex = 0;
      nodeIndex < backgroundLayer.nodes.length;
      nodeIndex++
    ) {
      final node = backgroundLayer.nodes[nodeIndex];
      if (seen.add(node.id)) continue;
      throw SceneDataException(
        code: SceneDataErrorCode.duplicateNodeId,
        path: 'backgroundLayer.nodes[$nodeIndex].id',
        message: 'Must be unique across scene layers.',
        source: node.id,
      );
    }
  }

  for (var layerIndex = 0; layerIndex < snapshot.layers.length; layerIndex++) {
    final layer = snapshot.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final node = layer.nodes[nodeIndex];
      if (seen.add(node.id)) continue;
      throw SceneDataException(
        code: SceneDataErrorCode.duplicateNodeId,
        path: 'layers[$layerIndex].nodes[$nodeIndex].id',
        message: 'Must be unique across scene layers.',
        source: node.id,
      );
    }
  }
}

void _validateSnapshotRanges(SceneSnapshot snapshot) {
  _validateCoordinate(snapshot.camera.offset.dx, 'camera.offset.dx');
  _validateCoordinate(snapshot.camera.offset.dy, 'camera.offset.dy');

  _validateSizeUpper(
    snapshot.background.grid.cellSize,
    'background.grid.cellSize',
  );
  for (var i = 0; i < snapshot.palette.gridSizes.length; i++) {
    _validateSizeUpper(snapshot.palette.gridSizes[i], 'palette.gridSizes[$i]');
  }

  final backgroundLayer = snapshot.backgroundLayer;
  if (backgroundLayer != null) {
    for (
      var nodeIndex = 0;
      nodeIndex < backgroundLayer.nodes.length;
      nodeIndex++
    ) {
      final field = 'backgroundLayer.nodes[$nodeIndex]';
      _validateNodeRanges(backgroundLayer.nodes[nodeIndex], field);
    }
  }

  for (var layerIndex = 0; layerIndex < snapshot.layers.length; layerIndex++) {
    final layer = snapshot.layers[layerIndex];
    for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
      final field = 'layers[$layerIndex].nodes[$nodeIndex]';
      _validateNodeRanges(layer.nodes[nodeIndex], field);
    }
  }
}

void _validateNodeRanges(NodeSnapshot node, String field) {
  _validateTransformRanges(node.transform, '$field.transform');
  _validateInRange(
    node.hitPadding,
    min: 0,
    max: sceneHitPaddingMax,
    path: '$field.hitPadding',
  );

  switch (node) {
    case ImageNodeSnapshot image:
      _validateSize(image.size.width, '$field.size.w');
      _validateSize(image.size.height, '$field.size.h');
      final naturalSize = image.naturalSize;
      if (naturalSize != null) {
        _validateSize(naturalSize.width, '$field.naturalSize.w');
        _validateSize(naturalSize.height, '$field.naturalSize.h');
      }
    case TextNodeSnapshot text:
      _validateSize(text.size.width, '$field.size.w');
      _validateSize(text.size.height, '$field.size.h');
      _validateInRange(
        text.fontSize,
        min: 0,
        max: sceneSizeMax,
        path: '$field.fontSize',
      );
      final maxWidth = text.maxWidth;
      if (maxWidth != null) {
        _validateInRange(
          maxWidth,
          min: 0,
          max: sceneSizeMax,
          path: '$field.maxWidth',
        );
      }
      final lineHeight = text.lineHeight;
      if (lineHeight != null) {
        _validateInRange(
          lineHeight,
          min: 0,
          max: sceneSizeMax,
          path: '$field.lineHeight',
        );
      }
    case StrokeNodeSnapshot stroke:
      _validateInRange(
        stroke.thickness,
        min: 0,
        max: sceneThicknessMax,
        path: '$field.thickness',
      );
      for (var i = 0; i < stroke.points.length; i++) {
        _validateCoordinate(stroke.points[i].dx, '$field.points[$i].x');
        _validateCoordinate(stroke.points[i].dy, '$field.points[$i].y');
      }
    case LineNodeSnapshot line:
      _validateInRange(
        line.thickness,
        min: 0,
        max: sceneThicknessMax,
        path: '$field.thickness',
      );
      _validateCoordinate(line.start.dx, '$field.start.x');
      _validateCoordinate(line.start.dy, '$field.start.y');
      _validateCoordinate(line.end.dx, '$field.end.x');
      _validateCoordinate(line.end.dy, '$field.end.y');
    case RectNodeSnapshot rect:
      _validateSize(rect.size.width, '$field.size.w');
      _validateSize(rect.size.height, '$field.size.h');
      _validateInRange(
        rect.strokeWidth,
        min: 0,
        max: sceneThicknessMax,
        path: '$field.strokeWidth',
      );
    case PathNodeSnapshot path:
      _validateInRange(
        path.strokeWidth,
        min: 0,
        max: sceneThicknessMax,
        path: '$field.strokeWidth',
      );
  }
}

void _validateTransformRanges(Transform2D transform, String path) {
  _validateCoordinate(transform.tx, '$path.tx');
  _validateCoordinate(transform.ty, '$path.ty');

  final scaleX = math.sqrt(
    transform.a * transform.a + transform.b * transform.b,
  );
  final scaleY = math.sqrt(
    transform.c * transform.c + transform.d * transform.d,
  );
  _validateInRange(
    scaleX,
    min: sceneScaleMin,
    max: sceneScaleMax,
    path: '$path.scaleX',
  );
  _validateInRange(
    scaleY,
    min: sceneScaleMin,
    max: sceneScaleMax,
    path: '$path.scaleY',
  );
}

void _validateCoordinate(double value, String path) {
  _validateInRange(value, min: sceneCoordMin, max: sceneCoordMax, path: path);
}

void _validateSize(double value, String path) {
  _validateInRange(value, min: 0, max: sceneSizeMax, path: path);
}

void _validateSizeUpper(double value, String path) {
  _validateInRange(value, min: 0, max: sceneSizeMax, path: path);
}

void _validateInRange(
  double value, {
  required double min,
  required double max,
  required String path,
}) {
  if (value >= min && value <= max) return;
  throw SceneDataException(
    code: SceneDataErrorCode.outOfRange,
    path: path,
    message: 'Field $path must be within [$min, $max].',
    source: value,
  );
}

Never _snapshotValidationError({
  required Object? value,
  required String field,
  required String message,
}) {
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: field,
    message: 'Field $field $message',
    source: value,
  );
}

Never _sceneValidationError({
  required Object? value,
  required String field,
  required String message,
}) {
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: field,
    message: 'Field $field $message',
    source: value,
  );
}
