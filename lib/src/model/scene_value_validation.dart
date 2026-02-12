import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/transform2d.dart';
import '../public/snapshot.dart' hide NodeId;

typedef SceneValidationErrorReporter =
    Never Function({
      required Object? value,
      required String field,
      required String message,
    });

void sceneValidateFiniteDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (value.isFinite) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be finite.',
  );
}

void sceneValidateNonNegativeDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteDouble(value, field: field, onError: onError);
  if (value >= 0) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be >= 0.',
  );
}

void sceneValidatePositiveDouble(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteDouble(value, field: field, onError: onError);
  if (value > 0) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be > 0.',
  );
}

void sceneValidateClamped01Double(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteDouble(value, field: field, onError: onError);
  if (value >= 0 && value <= 1) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be within [0,1].',
  );
}

void sceneValidateFiniteOffset(
  Offset value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteDouble(value.dx, field: '$field.dx', onError: onError);
  sceneValidateFiniteDouble(value.dy, field: '$field.dy', onError: onError);
}

void sceneValidateNonNegativeSize(
  Size value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonNegativeDouble(
    value.width,
    field: '$field.w',
    onError: onError,
  );
  sceneValidateNonNegativeDouble(
    value.height,
    field: '$field.h',
    onError: onError,
  );
}

void sceneValidateFiniteTransform2D(
  Transform2D value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteDouble(value.a, field: '$field.a', onError: onError);
  sceneValidateFiniteDouble(value.b, field: '$field.b', onError: onError);
  sceneValidateFiniteDouble(value.c, field: '$field.c', onError: onError);
  sceneValidateFiniteDouble(value.d, field: '$field.d', onError: onError);
  sceneValidateFiniteDouble(value.tx, field: '$field.tx', onError: onError);
  sceneValidateFiniteDouble(value.ty, field: '$field.ty', onError: onError);
}

void sceneValidateNonEmptyList(
  List<Object?> values, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (values.isNotEmpty) return;
  _sceneValidationFail(
    onError: onError,
    value: values,
    field: field,
    message: 'must not be empty.',
  );
}

void sceneValidateSvgPathData(
  String value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (value.trim().isEmpty) {
    _sceneValidationFail(
      onError: onError,
      value: value,
      field: field,
      message: 'must not be empty.',
    );
  }
  try {
    parseSvgPathData(value);
  } catch (_) {
    _sceneValidationFail(
      onError: onError,
      value: value,
      field: field,
      message: 'must be valid SVG path data.',
    );
  }
}

void sceneValidatePaletteSnapshot(
  ScenePaletteSnapshot palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonEmptyList(
    palette.penColors,
    field: '$field.penColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    palette.backgroundColors,
    field: '$field.backgroundColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    palette.gridSizes,
    field: '$field.gridSizes',
    onError: onError,
  );

  for (var i = 0; i < palette.gridSizes.length; i++) {
    sceneValidatePositiveDouble(
      palette.gridSizes[i],
      field: '$field.gridSizes[$i]',
      onError: onError,
    );
  }
}

void sceneValidatePalette(
  ScenePalette palette, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonEmptyList(
    palette.penColors,
    field: '$field.penColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    palette.backgroundColors,
    field: '$field.backgroundColors',
    onError: onError,
  );
  sceneValidateNonEmptyList(
    palette.gridSizes,
    field: '$field.gridSizes',
    onError: onError,
  );

  for (var i = 0; i < palette.gridSizes.length; i++) {
    sceneValidatePositiveDouble(
      palette.gridSizes[i],
      field: '$field.gridSizes[$i]',
      onError: onError,
    );
  }
}

void sceneValidateGridSnapshot(
  GridSnapshot grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
}) {
  sceneValidateFiniteDouble(
    grid.cellSize,
    field: '$field.cellSize',
    onError: onError,
  );
  if (requirePositiveCellSize) {
    sceneValidatePositiveDouble(
      grid.cellSize,
      field: '$field.cellSize',
      onError: onError,
    );
  }
}

void sceneValidateGrid(
  GridSettings grid, {
  required String field,
  required SceneValidationErrorReporter onError,
  required bool requirePositiveCellSize,
}) {
  sceneValidateFiniteDouble(
    grid.cellSize,
    field: '$field.cellSize',
    onError: onError,
  );
  if (requirePositiveCellSize) {
    sceneValidatePositiveDouble(
      grid.cellSize,
      field: '$field.cellSize',
      onError: onError,
    );
  }
}

void sceneValidateNodeSnapshot(
  NodeSnapshot node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteTransform2D(
    node.transform,
    field: '$field.transform',
    onError: onError,
  );
  sceneValidateNonNegativeDouble(
    node.hitPadding,
    field: '$field.hitPadding',
    onError: onError,
  );
  sceneValidateClamped01Double(
    node.opacity,
    field: '$field.opacity',
    onError: onError,
  );

  switch (node) {
    case ImageNodeSnapshot image:
      sceneValidateNonNegativeSize(
        image.size,
        field: '$field.size',
        onError: onError,
      );
      final naturalSize = image.naturalSize;
      if (naturalSize != null) {
        sceneValidateNonNegativeSize(
          naturalSize,
          field: '$field.naturalSize',
          onError: onError,
        );
      }
    case TextNodeSnapshot text:
      sceneValidateNonNegativeSize(
        text.size,
        field: '$field.size',
        onError: onError,
      );
      sceneValidatePositiveDouble(
        text.fontSize,
        field: '$field.fontSize',
        onError: onError,
      );
      final maxWidth = text.maxWidth;
      if (maxWidth != null) {
        sceneValidatePositiveDouble(
          maxWidth,
          field: '$field.maxWidth',
          onError: onError,
        );
      }
      final lineHeight = text.lineHeight;
      if (lineHeight != null) {
        sceneValidatePositiveDouble(
          lineHeight,
          field: '$field.lineHeight',
          onError: onError,
        );
      }
    case StrokeNodeSnapshot stroke:
      for (var i = 0; i < stroke.points.length; i++) {
        sceneValidateFiniteOffset(
          stroke.points[i],
          field: '$field.points[$i]',
          onError: onError,
        );
      }
      sceneValidatePositiveDouble(
        stroke.thickness,
        field: '$field.thickness',
        onError: onError,
      );
    case LineNodeSnapshot line:
      sceneValidateFiniteOffset(
        line.start,
        field: '$field.start',
        onError: onError,
      );
      sceneValidateFiniteOffset(
        line.end,
        field: '$field.end',
        onError: onError,
      );
      sceneValidatePositiveDouble(
        line.thickness,
        field: '$field.thickness',
        onError: onError,
      );
    case RectNodeSnapshot rect:
      sceneValidateNonNegativeSize(
        rect.size,
        field: '$field.size',
        onError: onError,
      );
      sceneValidateNonNegativeDouble(
        rect.strokeWidth,
        field: '$field.strokeWidth',
        onError: onError,
      );
    case PathNodeSnapshot path:
      sceneValidateSvgPathData(
        path.svgPathData,
        field: '$field.svgPathData',
        onError: onError,
      );
      sceneValidateNonNegativeDouble(
        path.strokeWidth,
        field: '$field.strokeWidth',
        onError: onError,
      );
  }
}

void sceneValidateNode(
  SceneNode node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteTransform2D(
    node.transform,
    field: '$field.transform',
    onError: onError,
  );
  sceneValidateNonNegativeDouble(
    node.hitPadding,
    field: '$field.hitPadding',
    onError: onError,
  );
  sceneValidateClamped01Double(
    node.opacity,
    field: '$field.opacity',
    onError: onError,
  );

  switch (node.type) {
    case NodeType.image:
      final image = node as ImageNode;
      sceneValidateNonNegativeSize(
        image.size,
        field: '$field.size',
        onError: onError,
      );
      final naturalSize = image.naturalSize;
      if (naturalSize != null) {
        sceneValidateNonNegativeSize(
          naturalSize,
          field: '$field.naturalSize',
          onError: onError,
        );
      }
    case NodeType.text:
      final text = node as TextNode;
      sceneValidateNonNegativeSize(
        text.size,
        field: '$field.size',
        onError: onError,
      );
      sceneValidatePositiveDouble(
        text.fontSize,
        field: '$field.fontSize',
        onError: onError,
      );
      final maxWidth = text.maxWidth;
      if (maxWidth != null) {
        sceneValidatePositiveDouble(
          maxWidth,
          field: '$field.maxWidth',
          onError: onError,
        );
      }
      final lineHeight = text.lineHeight;
      if (lineHeight != null) {
        sceneValidatePositiveDouble(
          lineHeight,
          field: '$field.lineHeight',
          onError: onError,
        );
      }
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      for (var i = 0; i < stroke.points.length; i++) {
        sceneValidateFiniteOffset(
          stroke.points[i],
          field: '$field.localPoints[$i]',
          onError: onError,
        );
      }
      sceneValidatePositiveDouble(
        stroke.thickness,
        field: '$field.thickness',
        onError: onError,
      );
    case NodeType.line:
      final line = node as LineNode;
      sceneValidateFiniteOffset(
        line.start,
        field: '$field.localA',
        onError: onError,
      );
      sceneValidateFiniteOffset(
        line.end,
        field: '$field.localB',
        onError: onError,
      );
      sceneValidatePositiveDouble(
        line.thickness,
        field: '$field.thickness',
        onError: onError,
      );
    case NodeType.rect:
      final rect = node as RectNode;
      sceneValidateNonNegativeSize(
        rect.size,
        field: '$field.size',
        onError: onError,
      );
      sceneValidateNonNegativeDouble(
        rect.strokeWidth,
        field: '$field.strokeWidth',
        onError: onError,
      );
    case NodeType.path:
      final path = node as PathNode;
      sceneValidateSvgPathData(
        path.svgPathData,
        field: '$field.svgPathData',
        onError: onError,
      );
      sceneValidateNonNegativeDouble(
        path.strokeWidth,
        field: '$field.strokeWidth',
        onError: onError,
      );
  }
}

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
  var backgroundLayerCount = 0;
  for (var layerIndex = 0; layerIndex < snapshot.layers.length; layerIndex++) {
    final layer = snapshot.layers[layerIndex];
    if (layer.isBackground) {
      backgroundLayerCount = backgroundLayerCount + 1;
    }
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

  if (backgroundLayerCount > 1) {
    _sceneValidationFail(
      onError: onError,
      value: backgroundLayerCount,
      field: 'layers',
      message: 'must contain at most one background layer.',
    );
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
  var backgroundLayerCount = 0;
  for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
    final layer = scene.layers[layerIndex];
    if (layer.isBackground) {
      backgroundLayerCount = backgroundLayerCount + 1;
    }
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

  if (backgroundLayerCount > 1) {
    _sceneValidationFail(
      onError: onError,
      value: backgroundLayerCount,
      field: 'layers',
      message: 'must contain at most one background layer.',
    );
  }
}

Never _sceneValidationFail({
  required SceneValidationErrorReporter onError,
  required Object? value,
  required String field,
  required String message,
}) {
  return onError(value: value, field: field, message: message);
}
