import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/transform2d.dart';
import '../public/node_patch.dart';
import '../public/node_spec.dart';
import '../public/patch_field.dart';
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

void sceneValidateNonNegativeInt(
  int value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (value >= 0) return;
  _sceneValidationFail(
    onError: onError,
    value: value,
    field: field,
    message: 'must be >= 0.',
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
      sceneValidateNonNegativeInt(
        stroke.pointsRevision,
        field: '$field.pointsRevision',
        onError: onError,
      );
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

void sceneValidateNodeSpecValues(
  NodeSpec spec, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateFiniteTransform2D(
    spec.transform,
    field: '$field.transform',
    onError: onError,
  );
  sceneValidateNonNegativeDouble(
    spec.hitPadding,
    field: '$field.hitPadding',
    onError: onError,
  );
  sceneValidateClamped01Double(
    spec.opacity,
    field: '$field.opacity',
    onError: onError,
  );

  switch (spec) {
    case ImageNodeSpec image:
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
    case TextNodeSpec text:
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
    case StrokeNodeSpec stroke:
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
    case LineNodeSpec line:
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
    case RectNodeSpec rect:
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
    case PathNodeSpec path:
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

void sceneValidateNodePatchValues(
  NodePatch patch, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateCommonNodePatch(
    patch.common,
    field: '$field.common',
    onError: onError,
  );

  switch (patch) {
    case ImageNodePatch image:
      _sceneValidateNonNullablePatchField(
        image.size,
        field: '$field.size',
        onError: onError,
        validate: (value) => sceneValidateNonNegativeSize(
          value,
          field: '$field.size',
          onError: onError,
        ),
      );
      _sceneValidateNullablePatchField(
        image.naturalSize,
        field: '$field.naturalSize',
        onError: onError,
        validate: (value) => sceneValidateNonNegativeSize(
          value,
          field: '$field.naturalSize',
          onError: onError,
        ),
      );
      _sceneValidateNonNullablePatchField(
        image.imageId,
        field: '$field.imageId',
        onError: onError,
      );
    case TextNodePatch text:
      _sceneValidateNonNullablePatchField(
        text.text,
        field: '$field.text',
        onError: onError,
      );
      _sceneValidateNonNullablePatchField(
        text.fontSize,
        field: '$field.fontSize',
        onError: onError,
        validate: (value) => sceneValidatePositiveDouble(
          value,
          field: '$field.fontSize',
          onError: onError,
        ),
      );
      _sceneValidateNonNullablePatchField(
        text.color,
        field: '$field.color',
        onError: onError,
      );
      _sceneValidateNonNullablePatchField(
        text.align,
        field: '$field.align',
        onError: onError,
      );
      _sceneValidateNonNullablePatchField(
        text.isBold,
        field: '$field.isBold',
        onError: onError,
      );
      _sceneValidateNonNullablePatchField(
        text.isItalic,
        field: '$field.isItalic',
        onError: onError,
      );
      _sceneValidateNonNullablePatchField(
        text.isUnderline,
        field: '$field.isUnderline',
        onError: onError,
      );
      _sceneValidateNullablePatchField(
        text.fontFamily,
        field: '$field.fontFamily',
        onError: onError,
      );
      _sceneValidateNullablePatchField(
        text.maxWidth,
        field: '$field.maxWidth',
        onError: onError,
        validate: (value) => sceneValidatePositiveDouble(
          value,
          field: '$field.maxWidth',
          onError: onError,
        ),
      );
      _sceneValidateNullablePatchField(
        text.lineHeight,
        field: '$field.lineHeight',
        onError: onError,
        validate: (value) => sceneValidatePositiveDouble(
          value,
          field: '$field.lineHeight',
          onError: onError,
        ),
      );
    case StrokeNodePatch stroke:
      _sceneValidateNonNullablePatchField(
        stroke.points,
        field: '$field.points',
        onError: onError,
        validate: (value) {
          for (var i = 0; i < value.length; i++) {
            sceneValidateFiniteOffset(
              value[i],
              field: '$field.points[$i]',
              onError: onError,
            );
          }
        },
      );
      _sceneValidateNonNullablePatchField(
        stroke.thickness,
        field: '$field.thickness',
        onError: onError,
        validate: (value) => sceneValidatePositiveDouble(
          value,
          field: '$field.thickness',
          onError: onError,
        ),
      );
      _sceneValidateNonNullablePatchField(
        stroke.color,
        field: '$field.color',
        onError: onError,
      );
    case LineNodePatch line:
      _sceneValidateNonNullablePatchField(
        line.start,
        field: '$field.start',
        onError: onError,
        validate: (value) => sceneValidateFiniteOffset(
          value,
          field: '$field.start',
          onError: onError,
        ),
      );
      _sceneValidateNonNullablePatchField(
        line.end,
        field: '$field.end',
        onError: onError,
        validate: (value) => sceneValidateFiniteOffset(
          value,
          field: '$field.end',
          onError: onError,
        ),
      );
      _sceneValidateNonNullablePatchField(
        line.thickness,
        field: '$field.thickness',
        onError: onError,
        validate: (value) => sceneValidatePositiveDouble(
          value,
          field: '$field.thickness',
          onError: onError,
        ),
      );
      _sceneValidateNonNullablePatchField(
        line.color,
        field: '$field.color',
        onError: onError,
      );
    case RectNodePatch rect:
      _sceneValidateNonNullablePatchField(
        rect.size,
        field: '$field.size',
        onError: onError,
        validate: (value) => sceneValidateNonNegativeSize(
          value,
          field: '$field.size',
          onError: onError,
        ),
      );
      _sceneValidateNullablePatchField(
        rect.fillColor,
        field: '$field.fillColor',
        onError: onError,
      );
      _sceneValidateNullablePatchField(
        rect.strokeColor,
        field: '$field.strokeColor',
        onError: onError,
      );
      _sceneValidateNonNullablePatchField(
        rect.strokeWidth,
        field: '$field.strokeWidth',
        onError: onError,
        validate: (value) => sceneValidateNonNegativeDouble(
          value,
          field: '$field.strokeWidth',
          onError: onError,
        ),
      );
    case PathNodePatch path:
      _sceneValidateNonNullablePatchField(
        path.svgPathData,
        field: '$field.svgPathData',
        onError: onError,
        validate: (value) => sceneValidateSvgPathData(
          value,
          field: '$field.svgPathData',
          onError: onError,
        ),
      );
      _sceneValidateNullablePatchField(
        path.fillColor,
        field: '$field.fillColor',
        onError: onError,
      );
      _sceneValidateNullablePatchField(
        path.strokeColor,
        field: '$field.strokeColor',
        onError: onError,
      );
      _sceneValidateNonNullablePatchField(
        path.strokeWidth,
        field: '$field.strokeWidth',
        onError: onError,
        validate: (value) => sceneValidateNonNegativeDouble(
          value,
          field: '$field.strokeWidth',
          onError: onError,
        ),
      );
      _sceneValidateNonNullablePatchField(
        path.fillRule,
        field: '$field.fillRule',
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

void _sceneValidateCommonNodePatch(
  CommonNodePatch patch, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateNonNullablePatchField(
    patch.transform,
    field: '$field.transform',
    onError: onError,
    validate: (value) => sceneValidateFiniteTransform2D(
      value,
      field: '$field.transform',
      onError: onError,
    ),
  );
  _sceneValidateNonNullablePatchField(
    patch.opacity,
    field: '$field.opacity',
    onError: onError,
    validate: (value) => sceneValidateClamped01Double(
      value,
      field: '$field.opacity',
      onError: onError,
    ),
  );
  _sceneValidateNonNullablePatchField(
    patch.hitPadding,
    field: '$field.hitPadding',
    onError: onError,
    validate: (value) => sceneValidateNonNegativeDouble(
      value,
      field: '$field.hitPadding',
      onError: onError,
    ),
  );
  _sceneValidateNonNullablePatchField(
    patch.isVisible,
    field: '$field.isVisible',
    onError: onError,
  );
  _sceneValidateNonNullablePatchField(
    patch.isSelectable,
    field: '$field.isSelectable',
    onError: onError,
  );
  _sceneValidateNonNullablePatchField(
    patch.isLocked,
    field: '$field.isLocked',
    onError: onError,
  );
  _sceneValidateNonNullablePatchField(
    patch.isDeletable,
    field: '$field.isDeletable',
    onError: onError,
  );
  _sceneValidateNonNullablePatchField(
    patch.isTransformable,
    field: '$field.isTransformable',
    onError: onError,
  );
}

void _sceneValidateNonNullablePatchField<T>(
  PatchField<T> patch, {
  required String field,
  required SceneValidationErrorReporter onError,
  void Function(T value)? validate,
}) {
  if (patch.isAbsent) return;
  if (patch.isNullValue) {
    _sceneValidationFail(
      onError: onError,
      value: null,
      field: field,
      message: 'PatchField.nullValue() is invalid for non-nullable field.',
    );
  }
  final value = patch.value;
  validate?.call(value);
}

void _sceneValidateNullablePatchField<T>(
  PatchField<T?> patch, {
  required String field,
  required SceneValidationErrorReporter onError,
  void Function(T value)? validate,
}) {
  if (patch.isAbsent || patch.isNullValue) return;
  final value = patch.value;
  if (value == null) return;
  validate?.call(value);
}

Never _sceneValidationFail({
  required SceneValidationErrorReporter onError,
  required Object? value,
  required String field,
  required String message,
}) {
  return onError(value: value, field: field, message: message);
}
