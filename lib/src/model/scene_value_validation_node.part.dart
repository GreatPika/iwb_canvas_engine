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
  final explicitId = spec.id;
  if (explicitId != null) {
    _sceneValidateArgumentBoundary(
      field: '$field.id',
      value: explicitId,
      onError: onError,
      validate: () => NodeIdValue.of(explicitId, name: '$field.id'),
    );
  }
  _sceneValidateArgumentBoundary(
    field: '$field.hitPadding',
    value: spec.hitPadding,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(
      spec.hitPadding,
      name: '$field.hitPadding',
    ),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.opacity',
    value: spec.opacity,
    onError: onError,
    validate: () => OpacityValue.of(spec.opacity, name: '$field.opacity'),
  );

  switch (spec) {
    case ImageNodeSpec image:
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
    case TextNodeSpec text:
      _sceneValidateArgumentBoundary(
        field: '$field.text',
        value: text.text,
        onError: onError,
        validate: () => TextContentValue.of(text.text, name: '$field.text'),
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
    case StrokeNodeSpec stroke:
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
    case LineNodeSpec line:
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
    case RectNodeSpec rect:
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
    case PathNodeSpec path:
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
  _sceneValidateArgumentBoundary(
    field: '$field.id',
    value: patch.id,
    onError: onError,
    validate: () => NodeIdValue.of(patch.id, name: '$field.id'),
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
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.imageId',
          value: value,
          onError: onError,
          validate: () => ImageIdValue.of(value, name: '$field.imageId'),
        ),
      );
    case TextNodePatch text:
      _sceneValidateNonNullablePatchField(
        text.text,
        field: '$field.text',
        onError: onError,
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.text',
          value: value,
          onError: onError,
          validate: () => TextContentValue.of(value, name: '$field.text'),
        ),
      );
      _sceneValidateNonNullablePatchField(
        text.fontSize,
        field: '$field.fontSize',
        onError: onError,
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.fontSize',
          value: value,
          onError: onError,
          validate: () =>
              PositiveFiniteDoubleValue.of(value, name: '$field.fontSize'),
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
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.fontFamily',
          value: value,
          onError: onError,
          validate: () => FontFamilyValue.of(value, name: '$field.fontFamily'),
        ),
      );
      _sceneValidateNullablePatchField(
        text.maxWidth,
        field: '$field.maxWidth',
        onError: onError,
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.maxWidth',
          value: value,
          onError: onError,
          validate: () =>
              PositiveFiniteDoubleValue.of(value, name: '$field.maxWidth'),
        ),
      );
      _sceneValidateNullablePatchField(
        text.lineHeight,
        field: '$field.lineHeight',
        onError: onError,
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.lineHeight',
          value: value,
          onError: onError,
          validate: () =>
              PositiveFiniteDoubleValue.of(value, name: '$field.lineHeight'),
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
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.thickness',
          value: value,
          onError: onError,
          validate: () =>
              PositiveFiniteDoubleValue.of(value, name: '$field.thickness'),
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
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.thickness',
          value: value,
          onError: onError,
          validate: () =>
              PositiveFiniteDoubleValue.of(value, name: '$field.thickness'),
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
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.strokeWidth',
          value: value,
          onError: onError,
          validate: () => NonNegativeFiniteDoubleValue.of(
            value,
            name: '$field.strokeWidth',
          ),
        ),
      );
    case PathNodePatch path:
      _sceneValidateNonNullablePatchField(
        path.svgPathData,
        field: '$field.svgPathData',
        onError: onError,
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.svgPathData',
          value: value,
          onError: onError,
          validate: () =>
              SvgPathDataValue.of(value, name: '$field.svgPathData'),
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
        validate: (value) => _sceneValidateArgumentBoundary(
          field: '$field.strokeWidth',
          value: value,
          onError: onError,
          validate: () => NonNegativeFiniteDoubleValue.of(
            value,
            name: '$field.strokeWidth',
          ),
        ),
      );
      _sceneValidateNonNullablePatchField(
        path.fillRule,
        field: '$field.fillRule',
        onError: onError,
      );
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
    validate: (value) => _sceneValidateArgumentBoundary(
      field: '$field.opacity',
      value: value,
      onError: onError,
      validate: () => OpacityValue.of(value, name: '$field.opacity'),
    ),
  );
  _sceneValidateNonNullablePatchField(
    patch.hitPadding,
    field: '$field.hitPadding',
    onError: onError,
    validate: (value) => _sceneValidateArgumentBoundary(
      field: '$field.hitPadding',
      value: value,
      onError: onError,
      validate: () =>
          NonNegativeFiniteDoubleValue.of(value, name: '$field.hitPadding'),
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
