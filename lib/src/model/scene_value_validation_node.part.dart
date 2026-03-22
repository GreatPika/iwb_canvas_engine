part of 'scene_value_validation.dart';

typedef _ImageValidationFields = ({
  String imageId,
  Size size,
  Size? naturalSize,
});
typedef _NodeBaseValidationFields = ({
  String id,
  int instanceRevision,
  Transform2D transform,
  double hitPadding,
  double opacity,
});
typedef _TextValidationFields = ({
  String textValue,
  Size size,
  double fontSize,
  String? fontFamily,
  double? maxWidth,
  double? lineHeight,
});
typedef _LineValidationFields = ({
  Offset start,
  String startField,
  Offset end,
  String endField,
  double thickness,
});

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
  _sceneValidateNodeBaseFields(
    fields: _snapshotNodeBaseValidationFields(node),
    field: field,
    onError: onError,
    allowZeroInstanceRevision: true,
  );
}

_NodeBaseValidationFields _snapshotNodeBaseValidationFields(NodeSnapshot node) {
  return (
    id: node.id,
    instanceRevision: node.instanceRevision,
    transform: node.transform,
    hitPadding: node.hitPadding,
    opacity: node.opacity,
  );
}

void _sceneValidateNodeBaseFields({
  required _NodeBaseValidationFields fields,
  required String field,
  required SceneValidationErrorReporter onError,
  required bool allowZeroInstanceRevision,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.id',
    value: fields.id,
    onError: onError,
    validate: () => NodeIdValue.of(fields.id, name: '$field.id'),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.instanceRevision',
    value: fields.instanceRevision,
    onError: onError,
    validate: () => InstanceRevisionValue.of(
      fields.instanceRevision,
      name: '$field.instanceRevision',
      allowZero: allowZeroInstanceRevision,
    ),
  );
  sceneValidateFiniteTransform2D(
    fields.transform,
    field: '$field.transform',
    onError: onError,
  );
  _sceneValidateArgumentBoundary(
    field: '$field.hitPadding',
    value: fields.hitPadding,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(
      fields.hitPadding,
      name: '$field.hitPadding',
    ),
  );
  _sceneValidateArgumentBoundary(
    field: '$field.opacity',
    value: fields.opacity,
    onError: onError,
    validate: () => OpacityValue.of(fields.opacity, name: '$field.opacity'),
  );
}

void _sceneValidateSnapshotNodeTypeFields(
  NodeSnapshot node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  switch (node) {
    case ImageNodeSnapshot image:
      _sceneValidateImageFields(
        fields: _snapshotImageValidationFields(image),
        field: field,
        onError: onError,
      );
    case TextNodeSnapshot text:
      _sceneValidateTextFields(
        fields: _snapshotTextValidationFields(text),
        field: field,
        onError: onError,
      );
    case StrokeNodeSnapshot stroke:
      _sceneValidateSnapshotStrokeNode(stroke, field: field, onError: onError);
    case LineNodeSnapshot line:
      _sceneValidateLineFields(
        fields: _snapshotLineValidationFields(line, field: field),
        field: field,
        onError: onError,
      );
    case RectNodeSnapshot rect:
      _sceneValidateRectFields(
        size: rect.size,
        strokeWidth: rect.strokeWidth,
        field: field,
        onError: onError,
      );
    case PathNodeSnapshot path:
      _sceneValidatePathFields(
        svgPathData: path.svgPathData,
        strokeWidth: path.strokeWidth,
        field: field,
        onError: onError,
      );
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
  _sceneValidateNodeBaseFields(
    fields: _runtimeNodeBaseValidationFields(node),
    field: field,
    onError: onError,
    allowZeroInstanceRevision: false,
  );
}

_NodeBaseValidationFields _runtimeNodeBaseValidationFields(SceneNode node) {
  return (
    id: node.id,
    instanceRevision: node.instanceRevision,
    transform: node.transform,
    hitPadding: node.hitPadding,
    opacity: node.opacity,
  );
}

void _sceneValidateRuntimeNodeTypeFields(
  SceneNode node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  switch (node.type) {
    case NodeType.image:
      _sceneValidateImageFields(
        fields: _runtimeImageValidationFields(node as ImageNode),
        field: field,
        onError: onError,
      );
    case NodeType.text:
      _sceneValidateTextFields(
        fields: _runtimeTextValidationFields(node as TextNode),
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
      _sceneValidateLineFields(
        fields: _runtimeLineValidationFields(node as LineNode, field: field),
        field: field,
        onError: onError,
      );
    case NodeType.rect:
      _sceneValidateRuntimeRectFields(
        node as RectNode,
        field: field,
        onError: onError,
      );
    case NodeType.path:
      _sceneValidateRuntimePathFields(
        node as PathNode,
        field: field,
        onError: onError,
      );
  }
}

_ImageValidationFields _snapshotImageValidationFields(ImageNodeSnapshot image) {
  return (
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  );
}

_ImageValidationFields _runtimeImageValidationFields(ImageNode image) {
  return (
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  );
}

void _sceneValidateImageFields({
  required _ImageValidationFields fields,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.imageId',
    value: fields.imageId,
    onError: onError,
    validate: () => ImageIdValue.of(fields.imageId, name: '$field.imageId'),
  );
  sceneValidateNonNegativeSize(
    fields.size,
    field: '$field.size',
    onError: onError,
  );
  final naturalSize = fields.naturalSize;
  if (naturalSize != null) {
    sceneValidateNonNegativeSize(
      naturalSize,
      field: '$field.naturalSize',
      onError: onError,
    );
  }
}

_TextValidationFields _snapshotTextValidationFields(TextNodeSnapshot text) {
  return (
    textValue: text.text,
    size: text.size,
    fontSize: text.fontSize,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  );
}

_TextValidationFields _runtimeTextValidationFields(TextNode text) {
  return (
    textValue: text.text,
    size: text.size,
    fontSize: text.fontSize,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  );
}

void _sceneValidateTextFields({
  required _TextValidationFields fields,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.text',
    value: fields.textValue,
    onError: onError,
    validate: () => TextContentValue.of(fields.textValue, name: '$field.text'),
  );
  sceneValidateNonNegativeSize(
    fields.size,
    field: '$field.size',
    onError: onError,
  );
  _sceneValidateArgumentBoundary(
    field: '$field.fontSize',
    value: fields.fontSize,
    onError: onError,
    validate: () =>
        PositiveFiniteDoubleValue.of(fields.fontSize, name: '$field.fontSize'),
  );
  _sceneValidateOptionalFontFamily(
    fields.fontFamily,
    field: '$field.fontFamily',
    onError: onError,
  );
  _sceneValidateOptionalPositiveDouble(
    fields.maxWidth,
    field: '$field.maxWidth',
    onError: onError,
  );
  _sceneValidateOptionalPositiveDouble(
    fields.lineHeight,
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

void _sceneValidateLineFields({
  required _LineValidationFields fields,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateOffsetField(
    fields.start,
    field: fields.startField,
    onError: onError,
  );
  _sceneValidateOffsetField(
    fields.end,
    field: fields.endField,
    onError: onError,
  );
  _sceneValidateThicknessField(
    fields.thickness,
    field: '$field.thickness',
    onError: onError,
  );
}

_LineValidationFields _snapshotLineValidationFields(
  LineNodeSnapshot line, {
  required String field,
}) {
  return (
    start: line.start,
    startField: '$field.start',
    end: line.end,
    endField: '$field.end',
    thickness: line.thickness,
  );
}

_LineValidationFields _runtimeLineValidationFields(
  LineNode line, {
  required String field,
}) {
  return (
    start: line.start,
    startField: '$field.localA',
    end: line.end,
    endField: '$field.localB',
    thickness: line.thickness,
  );
}

void _sceneValidateRectFields({
  required Size size,
  required double strokeWidth,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateNonNegativeSize(size, field: '$field.size', onError: onError);
  _sceneValidateNonNegativeStrokeWidthField(
    strokeWidth,
    field: '$field.strokeWidth',
    onError: onError,
  );
}

void _sceneValidateRuntimeRectFields(
  RectNode rect, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateRectFields(
    size: rect.size,
    strokeWidth: rect.strokeWidth,
    field: field,
    onError: onError,
  );
}

void _sceneValidatePathFields({
  required String svgPathData,
  required double strokeWidth,
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: '$field.svgPathData',
    value: svgPathData,
    onError: onError,
    validate: () =>
        SvgPathDataValue.of(svgPathData, name: '$field.svgPathData'),
  );
  _sceneValidateNonNegativeStrokeWidthField(
    strokeWidth,
    field: '$field.strokeWidth',
    onError: onError,
  );
}

void _sceneValidateRuntimePathFields(
  PathNode path, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidatePathFields(
    svgPathData: path.svgPathData,
    strokeWidth: path.strokeWidth,
    field: field,
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
  _sceneValidateThicknessField(
    stroke.thickness,
    field: '$field.thickness',
    onError: onError,
  );
}

void _sceneValidateThicknessField(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => PositiveFiniteDoubleValue.of(value, name: field),
  );
}

void _sceneValidateNonNegativeStrokeWidthField(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(value, name: field),
  );
}

void _sceneValidateOptionalFontFamily(
  String? value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateOptionalValue<String>(
    value,
    field: field,
    onError: onError,
    validateValue: _sceneValidateFontFamilyField,
  );
}

void _sceneValidateOptionalPositiveDouble(
  double? value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateOptionalValue<double>(
    value,
    field: field,
    onError: onError,
    validateValue: _sceneValidatePositiveDoubleField,
  );
}

void _sceneValidatePoints(
  List<Offset> points, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateFields<Offset>(
    List<_SceneValidationField<Offset>>.generate(
      points.length,
      (index) => (value: points[index], field: '$field[$index]'),
    ),
    onError: onError,
    validateValue: _sceneValidateOffsetField,
  );
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

void _sceneValidateFontFamilyField(
  String value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => FontFamilyValue.of(value, name: field),
  );
}

void _sceneValidatePositiveDoubleField(
  double value, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateArgumentBoundary(
    field: field,
    value: value,
    onError: onError,
    validate: () => PositiveFiniteDoubleValue.of(value, name: field),
  );
}

void _sceneValidateOptionalValue<T>(
  T? value, {
  required String field,
  required SceneValidationErrorReporter onError,
  required _SceneValueValidator<T> validateValue,
}) {
  if (value == null) return;
  validateValue(value, field: field, onError: onError);
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
