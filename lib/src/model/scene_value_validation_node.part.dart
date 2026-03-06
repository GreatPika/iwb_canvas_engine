part of 'scene_value_validation.dart';

void sceneValidateNodeSnapshot(
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

  switch (node) {
    case ImageNodeSnapshot image:
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
    case TextNodeSnapshot text:
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
        validate: () => PositiveFiniteDoubleValue.of(
          text.fontSize,
          name: '$field.fontSize',
        ),
      );
      final fontFamily = text.fontFamily;
      if (fontFamily != null) {
        _sceneValidateArgumentBoundary(
          field: '$field.fontFamily',
          value: fontFamily,
          onError: onError,
          validate: () =>
              FontFamilyValue.of(fontFamily, name: '$field.fontFamily'),
        );
      }
      final maxWidth = text.maxWidth;
      if (maxWidth != null) {
        _sceneValidateArgumentBoundary(
          field: '$field.maxWidth',
          value: maxWidth,
          onError: onError,
          validate: () =>
              PositiveFiniteDoubleValue.of(maxWidth, name: '$field.maxWidth'),
        );
      }
      final lineHeight = text.lineHeight;
      if (lineHeight != null) {
        _sceneValidateArgumentBoundary(
          field: '$field.lineHeight',
          value: lineHeight,
          onError: onError,
          validate: () => PositiveFiniteDoubleValue.of(
            lineHeight,
            name: '$field.lineHeight',
          ),
        );
      }
    case StrokeNodeSnapshot stroke:
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
      for (var i = 0; i < stroke.points.length; i++) {
        _sceneValidateArgumentBoundary(
          field: '$field.points[$i]',
          value: stroke.points[i],
          onError: onError,
          validate: () =>
              FiniteOffsetValue.of(stroke.points[i], name: '$field.points[$i]'),
        );
      }
      _sceneValidateArgumentBoundary(
        field: '$field.thickness',
        value: stroke.thickness,
        onError: onError,
        validate: () => PositiveFiniteDoubleValue.of(
          stroke.thickness,
          name: '$field.thickness',
        ),
      );
    case LineNodeSnapshot line:
      _sceneValidateArgumentBoundary(
        field: '$field.start',
        value: line.start,
        onError: onError,
        validate: () => FiniteOffsetValue.of(line.start, name: '$field.start'),
      );
      _sceneValidateArgumentBoundary(
        field: '$field.end',
        value: line.end,
        onError: onError,
        validate: () => FiniteOffsetValue.of(line.end, name: '$field.end'),
      );
      _sceneValidateArgumentBoundary(
        field: '$field.thickness',
        value: line.thickness,
        onError: onError,
        validate: () => PositiveFiniteDoubleValue.of(
          line.thickness,
          name: '$field.thickness',
        ),
      );
    case RectNodeSnapshot rect:
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
    case PathNodeSnapshot path:
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
}

void sceneValidateNode(
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

  switch (node.type) {
    case NodeType.image:
      final image = node as ImageNode;
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
    case NodeType.text:
      final text = node as TextNode;
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
        validate: () => PositiveFiniteDoubleValue.of(
          text.fontSize,
          name: '$field.fontSize',
        ),
      );
      final fontFamily = text.fontFamily;
      if (fontFamily != null) {
        _sceneValidateArgumentBoundary(
          field: '$field.fontFamily',
          value: fontFamily,
          onError: onError,
          validate: () =>
              FontFamilyValue.of(fontFamily, name: '$field.fontFamily'),
        );
      }
      final maxWidth = text.maxWidth;
      if (maxWidth != null) {
        _sceneValidateArgumentBoundary(
          field: '$field.maxWidth',
          value: maxWidth,
          onError: onError,
          validate: () =>
              PositiveFiniteDoubleValue.of(maxWidth, name: '$field.maxWidth'),
        );
      }
      final lineHeight = text.lineHeight;
      if (lineHeight != null) {
        _sceneValidateArgumentBoundary(
          field: '$field.lineHeight',
          value: lineHeight,
          onError: onError,
          validate: () => PositiveFiniteDoubleValue.of(
            lineHeight,
            name: '$field.lineHeight',
          ),
        );
      }
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      for (var i = 0; i < stroke.points.length; i++) {
        _sceneValidateArgumentBoundary(
          field: '$field.localPoints[$i]',
          value: stroke.points[i],
          onError: onError,
          validate: () => FiniteOffsetValue.of(
            stroke.points[i],
            name: '$field.localPoints[$i]',
          ),
        );
      }
      _sceneValidateArgumentBoundary(
        field: '$field.thickness',
        value: stroke.thickness,
        onError: onError,
        validate: () => PositiveFiniteDoubleValue.of(
          stroke.thickness,
          name: '$field.thickness',
        ),
      );
    case NodeType.line:
      final line = node as LineNode;
      _sceneValidateArgumentBoundary(
        field: '$field.localA',
        value: line.start,
        onError: onError,
        validate: () => FiniteOffsetValue.of(line.start, name: '$field.localA'),
      );
      _sceneValidateArgumentBoundary(
        field: '$field.localB',
        value: line.end,
        onError: onError,
        validate: () => FiniteOffsetValue.of(line.end, name: '$field.localB'),
      );
      _sceneValidateArgumentBoundary(
        field: '$field.thickness',
        value: line.thickness,
        onError: onError,
        validate: () => PositiveFiniteDoubleValue.of(
          line.thickness,
          name: '$field.thickness',
        ),
      );
    case NodeType.rect:
      final rect = node as RectNode;
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
    case NodeType.path:
      final path = node as PathNode;
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
