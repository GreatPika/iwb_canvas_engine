part of 'scene_value_validation.dart';

void sceneValidateNodeSnapshot(
  NodeSnapshot node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateSnapshotNodeBaseFields(node, field: field, onError: onError);
  _sceneValidateSnapshotNodeTypeFields(node, field: field, onError: onError);
}

void _sceneValidateSnapshotNodeBaseFields(
  NodeSnapshot node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.id',
    value: node.id,
    onError: onError,
    validate: () => NodeIdValue.of(node.id, name: '$field.id'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.instanceRevision',
    value: node.instanceRevision,
    onError: onError,
    validate: () => InstanceRevisionValue.of(
      node.instanceRevision,
      name: '$field.instanceRevision',
      allowZero: true,
    ),
  );
  sceneValidateFiniteTransform2D(
    node.transform,
    field: '$field.transform',
    onError: onError,
  );
  _sceneValidateArgumentBoundary(
    field: '$field.hitPadding',
    value: node.hitPadding,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(
      node.hitPadding,
      name: '$field.hitPadding',
    ),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.opacity',
    value: node.opacity,
    onError: onError,
    validate: () => OpacityValue.of(node.opacity, name: '$field.opacity'),
  );
}

void _sceneValidateSnapshotNodeTypeFields(
  NodeSnapshot node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  switch (node) {
    case ImageNodeSnapshot image:
      _sceneValidateSnapshotImageNode(image, field: field, onError: onError);
    case TextNodeSnapshot text:
      _sceneValidateSnapshotTextNode(text, field: field, onError: onError);
    case StrokeNodeSnapshot stroke:
      _sceneValidateSnapshotStrokeNode(stroke, field: field, onError: onError);
    case LineNodeSnapshot line:
      _sceneValidateSnapshotLineNode(line, field: field, onError: onError);
    case RectNodeSnapshot rect:
      _sceneValidateSnapshotRectNode(rect, field: field, onError: onError);
    case PathNodeSnapshot path:
      _sceneValidateSnapshotPathNode(path, field: field, onError: onError);
  }
}

void sceneValidateNode(
  SceneNode node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateRuntimeNodeBaseFields(node, field: field, onError: onError);
  _sceneValidateRuntimeNodeTypeFields(node, field: field, onError: onError);
}

void _sceneValidateRuntimeNodeBaseFields(
  SceneNode node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.id',
    value: node.id,
    onError: onError,
    validate: () => NodeIdValue.of(node.id, name: '$field.id'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.instanceRevision',
    value: node.instanceRevision,
    onError: onError,
    validate: () => InstanceRevisionValue.of(
      node.instanceRevision,
      name: '$field.instanceRevision',
      allowZero: false,
    ),
  );
  sceneValidateFiniteTransform2D(
    node.transform,
    field: '$field.transform',
    onError: onError,
  );
  _sceneValidateArgumentBoundary(
    field: '$field.hitPadding',
    value: node.hitPadding,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(
      node.hitPadding,
      name: '$field.hitPadding',
    ),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.opacity',
    value: node.opacity,
    onError: onError,
    validate: () => OpacityValue.of(node.opacity, name: '$field.opacity'),
  );
}

void _sceneValidateRuntimeNodeTypeFields(
  SceneNode node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  switch (node.type) {
    case NodeType.image:
      _sceneValidateRuntimeImageNode(
        node as ImageNode,
        field: field,
        onError: onError,
      );
    case NodeType.text:
      _sceneValidateRuntimeTextNode(
        node as TextNode,
        field: field,
        onError: onError,
      );
    case NodeType.stroke:
      _sceneValidateRuntimeStrokeNode(
        node as StrokeNode,
        field: field,
        onError: onError,
      );
    case NodeType.line:
      _sceneValidateRuntimeLineNode(
        node as LineNode,
        field: field,
        onError: onError,
      );
    case NodeType.rect:
      _sceneValidateRuntimeRectNode(
        node as RectNode,
        field: field,
        onError: onError,
      );
    case NodeType.path:
      _sceneValidateRuntimePathNode(
        node as PathNode,
        field: field,
        onError: onError,
      );
  }
}

void _sceneValidateSnapshotImageNode(
  ImageNodeSnapshot image, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.imageId',
    value: image.imageId,
    onError: onError,
    validate: () => ImageIdValue.of(image.imageId, name: '$field.imageId'),
  );
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
}

void _sceneValidateSnapshotTextNode(
  TextNodeSnapshot text, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.text',
    value: text.text,
    onError: onError,
    validate: () => TextContentValue.of(text.text, name: '$field.text'),
  );
  sceneValidateNonNegativeSize(
    text.size,
    field: '$field.size',
    onError: onError,
  );
  _sceneValidateArgumentBoundary(
    field: '$field.fontSize',
    value: text.fontSize,
    onError: onError,
    validate: () =>
        PositiveFiniteDoubleValue.of(text.fontSize, name: '$field.fontSize'),
  );
  _sceneValidateOptionalFontFamily(
    text.fontFamily,
    field: '$field.fontFamily',
    onError: onError,
  );
  _sceneValidateOptionalPositiveDouble(
    text.maxWidth,
    field: '$field.maxWidth',
    onError: onError,
  );
  _sceneValidateOptionalPositiveDouble(
    text.lineHeight,
    field: '$field.lineHeight',
    onError: onError,
  );
}

void _sceneValidateSnapshotStrokeNode(
  StrokeNodeSnapshot stroke, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.pointsRevision',
    value: stroke.pointsRevision,
    onError: onError,
    validate: () => InstanceRevisionValue.of(
      stroke.pointsRevision,
      name: '$field.pointsRevision',
      allowZero: true,
    ),
  );
  _sceneValidatePoints(stroke.points, field: '$field.points', onError: onError);
  _sceneValidateArgumentBoundary(
    field: '$field.thickness',
    value: stroke.thickness,
    onError: onError,
    validate: () => PositiveFiniteDoubleValue.of(
      stroke.thickness,
      name: '$field.thickness',
    ),
  );
}

void _sceneValidateSnapshotLineNode(
  LineNodeSnapshot line, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateOffsetField(
    line.start,
    field: '$field.start',
    onError: onError,
  );
  _sceneValidateOffsetField(line.end, field: '$field.end', onError: onError);
  _sceneValidateArgumentBoundary(
    field: '$field.thickness',
    value: line.thickness,
    onError: onError,
    validate: () =>
        PositiveFiniteDoubleValue.of(line.thickness, name: '$field.thickness'),
  );
}

void _sceneValidateSnapshotRectNode(
  RectNodeSnapshot rect, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonNegativeSize(
    rect.size,
    field: '$field.size',
    onError: onError,
  );
  _sceneValidateArgumentBoundary(
    field: '$field.strokeWidth',
    value: rect.strokeWidth,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(
      rect.strokeWidth,
      name: '$field.strokeWidth',
    ),
  );
}

void _sceneValidateSnapshotPathNode(
  PathNodeSnapshot path, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.svgPathData',
    value: path.svgPathData,
    onError: onError,
    validate: () =>
        SvgPathDataValue.of(path.svgPathData, name: '$field.svgPathData'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.strokeWidth',
    value: path.strokeWidth,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(
      path.strokeWidth,
      name: '$field.strokeWidth',
    ),
  );
}

void _sceneValidateRuntimeImageNode(
  ImageNode image, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.imageId',
    value: image.imageId,
    onError: onError,
    validate: () => ImageIdValue.of(image.imageId, name: '$field.imageId'),
  );
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
}

void _sceneValidateRuntimeTextNode(
  TextNode text, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.text',
    value: text.text,
    onError: onError,
    validate: () => TextContentValue.of(text.text, name: '$field.text'),
  );
  sceneValidateNonNegativeSize(
    text.size,
    field: '$field.size',
    onError: onError,
  );
  _sceneValidateArgumentBoundary(
    field: '$field.fontSize',
    value: text.fontSize,
    onError: onError,
    validate: () =>
        PositiveFiniteDoubleValue.of(text.fontSize, name: '$field.fontSize'),
  );
  _sceneValidateOptionalFontFamily(
    text.fontFamily,
    field: '$field.fontFamily',
    onError: onError,
  );
  _sceneValidateOptionalPositiveDouble(
    text.maxWidth,
    field: '$field.maxWidth',
    onError: onError,
  );
  _sceneValidateOptionalPositiveDouble(
    text.lineHeight,
    field: '$field.lineHeight',
    onError: onError,
  );
}

void _sceneValidateRuntimeStrokeNode(
  StrokeNode stroke, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePoints(
    stroke.points,
    field: '$field.localPoints',
    onError: onError,
  );
  _sceneValidateArgumentBoundary(
    field: '$field.thickness',
    value: stroke.thickness,
    onError: onError,
    validate: () => PositiveFiniteDoubleValue.of(
      stroke.thickness,
      name: '$field.thickness',
    ),
  );
}

void _sceneValidateRuntimeLineNode(
  LineNode line, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateOffsetField(
    line.start,
    field: '$field.localA',
    onError: onError,
  );
  _sceneValidateOffsetField(line.end, field: '$field.localB', onError: onError);
  _sceneValidateArgumentBoundary(
    field: '$field.thickness',
    value: line.thickness,
    onError: onError,
    validate: () =>
        PositiveFiniteDoubleValue.of(line.thickness, name: '$field.thickness'),
  );
}

void _sceneValidateRuntimeRectNode(
  RectNode rect, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonNegativeSize(
    rect.size,
    field: '$field.size',
    onError: onError,
  );
  _sceneValidateArgumentBoundary(
    field: '$field.strokeWidth',
    value: rect.strokeWidth,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(
      rect.strokeWidth,
      name: '$field.strokeWidth',
    ),
  );
}

void _sceneValidateRuntimePathNode(
  PathNode path, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.svgPathData',
    value: path.svgPathData,
    onError: onError,
    validate: () =>
        SvgPathDataValue.of(path.svgPathData, name: '$field.svgPathData'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.strokeWidth',
    value: path.strokeWidth,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(
      path.strokeWidth,
      name: '$field.strokeWidth',
    ),
  );
}

void _sceneValidateOptionalFontFamily(
  String? value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (value == null) return;
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => FontFamilyValue.of(value, name: field),
  );
}

void _sceneValidateOptionalPositiveDouble(
  double? value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  if (value == null) return;
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => PositiveFiniteDoubleValue.of(value, name: field),
  );
}

void _sceneValidatePoints(
  List<Offset> points, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  for (var i = 0; i < points.length; i++) {
    _sceneValidateOffsetField(points[i], field: '$field[$i]', onError: onError);
  }
}

void _sceneValidateOffsetField(
  Offset value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => FiniteOffsetValue.of(value, name: field),
  );
}

void _sceneValidateArgumentBoundary({
  required String field,
  required Object? value,
  required SceneValidationErrorReporter onError,
  required void Function() validate,
}) {
  try {
    validate();
  } on ArgumentError catch (error) {
    final argumentName = error.name;
    final reportedField = argumentName is String ? argumentName : field;
    _sceneValidationFail(
      onError: onError,
      value: value,
      field: reportedField,
      message: _sceneMessageFromArgumentError(error),
    );
  }
}

String _sceneMessageFromArgumentError(ArgumentError error) {
  final message = error.message;
  if (message is String && message.isNotEmpty) {
    final first = message[0];
    final lowerFirst = first.toLowerCase();
    if (first == lowerFirst) {
      return message;
    }
    return '$lowerFirst${message.substring(1)}';
  }
  return 'is invalid.';
}
