part of 'scene_node_boundary_mapping.dart';

typedef _SceneNodeFromSchema<FieldsT> =
    SceneNode Function({
      required _RuntimeNodeCommonFields common,
      required FieldsT fields,
    });

typedef _NodeSnapshotFromSchema<FieldsT, SnapshotT extends NodeSnapshot> =
    SnapshotT Function({
      required NodeSnapshotCommonSchemaFields common,
      required FieldsT fields,
    });

NodeSnapshotCommonSchemaFields _snapshotCommonFromNodeSnapshot(
  NodeSnapshot node,
) {
  return NodeBoundarySchema.snapshotCommonFromValidated((
    id: node.id,
    instanceRevision: node.instanceRevision,
    transform: node.transform,
    opacity: node.opacity,
    hitPadding: node.hitPadding,
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
    isLocked: node.isLocked,
    isDeletable: node.isDeletable,
    isTransformable: node.isTransformable,
  ));
}

NodeSpecCommonSchemaFields _specCommonFromNodeSpec(NodeSpec spec) {
  return NodeBoundarySchema.specCommonFromValidated((
    id: spec.id,
    transform: spec.transform,
    opacity: spec.opacity,
    hitPadding: spec.hitPadding,
    isVisible: spec.isVisible,
    isSelectable: spec.isSelectable,
    isLocked: spec.isLocked,
    isDeletable: spec.isDeletable,
    isTransformable: spec.isTransformable,
  ));
}

NodeSnapshotCommonSchemaFields _snapshotCommonFromSceneNode(SceneNode node) {
  return NodeBoundarySchema.snapshotCommonFromValidated((
    id: node.id,
    instanceRevision: node.instanceRevision,
    transform: node.transform,
    opacity: node.opacity,
    hitPadding: node.hitPadding,
    isVisible: node.isVisible,
    isSelectable: node.isSelectable,
    isLocked: node.isLocked,
    isDeletable: node.isDeletable,
    isTransformable: node.isTransformable,
  ));
}

_RuntimeNodeCommonFields _runtimeCommonFromSnapshot(
  NodeSnapshotCommonSchemaFields common, {
  required int instanceRevision,
}) {
  return (
    id: common.id,
    instanceRevision: instanceRevision,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

_RuntimeNodeCommonFields _runtimeCommonFromSpec(
  NodeSpecCommonSchemaFields common, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  return (
    id: common.id ?? fallbackId,
    instanceRevision: instanceRevision,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

ImageNode _imageNodeFromSchema({
  required _RuntimeNodeCommonFields common,
  required ImageNodeSchemaFields fields,
}) {
  return ImageNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    imageId: fields.imageId,
    size: fields.size,
    naturalSize: fields.naturalSize,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

TextNode _textNodeFromSnapshotSchema({
  required _RuntimeNodeCommonFields common,
  required TextNodeSnapshotSchemaFields fields,
  required TextNodeSnapshotSizePolicy textSizePolicy,
}) {
  final node = TextNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    size: textSizePolicy == TextNodeSnapshotSizePolicy.preserveBoundarySize
        ? fields.size
        : Size.zero,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: fields.fontFamily,
    maxWidth: fields.maxWidth,
    lineHeight: fields.lineHeight,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
  if (textSizePolicy == TextNodeSnapshotSizePolicy.recomputeFromLayout) {
    recomputeDerivedTextSize(node);
  }
  return node;
}

TextNode _textNodeFromSpecSchema({
  required _RuntimeNodeCommonFields common,
  required TextNodeSpecSchemaFields fields,
}) {
  final node = TextNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    size: Size.zero,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: fields.fontFamily,
    maxWidth: fields.maxWidth,
    lineHeight: fields.lineHeight,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
  recomputeDerivedTextSize(node);
  return node;
}

StrokeNode _strokeNodeFromSnapshotSchema({
  required _RuntimeNodeCommonFields common,
  required StrokeNodeSnapshotSchemaFields fields,
}) {
  return StrokeNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
    pointsRevision: fields.pointsRevision,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

StrokeNode _strokeNodeFromSpecSchema({
  required _RuntimeNodeCommonFields common,
  required StrokeNodeSpecSchemaFields fields,
}) {
  return StrokeNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

LineNode _lineNodeFromSchema({
  required _RuntimeNodeCommonFields common,
  required LineNodeSchemaFields fields,
}) {
  return LineNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    start: fields.start,
    end: fields.end,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

RectNode _rectNodeFromSchema({
  required _RuntimeNodeCommonFields common,
  required RectNodeSchemaFields fields,
}) {
  return RectNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

PathNode _pathNodeFromSchema({
  required _RuntimeNodeCommonFields common,
  required PathNodeSchemaFields fields,
}) {
  return PathNode(
    id: common.id,
    instanceRevision: common.instanceRevision,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

SceneNode _imageNodeFromSnapshotViaBoundarySchema(
  ImageNodeSnapshot image, {
  required int instanceRevision,
}) {
  return _nodeFromSnapshotViaBoundarySchema(
    snapshot: image,
    instanceRevision: instanceRevision,
    extractFields: _imageFieldsFromSnapshot,
    buildNode: _imageNodeFromSchema,
  );
}

SceneNode _imageNodeFromSpecViaBoundarySchema(
  ImageNodeSpec image, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  return _nodeFromSpecViaBoundarySchema(
    spec: image,
    buildCommon: (common) => _runtimeCommonFromSpec(
      common,
      fallbackId: fallbackId,
      instanceRevision: instanceRevision,
    ),
    extractFields: _imageFieldsFromSpec,
    buildNode: _imageNodeFromSchema,
  );
}

NodeSnapshot _imageSnapshotFromNodeViaBoundarySchema(ImageNode image) {
  return _nodeSnapshotFromNodeViaBoundarySchema(
    node: image,
    extractFields: _imageFieldsFromNode,
    buildSnapshot: _imageSnapshotFromSchema,
  );
}

ImageNodeSchemaFields _imageFieldsFromSnapshot(ImageNodeSnapshot image) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
}

ImageNodeSchemaFields _imageFieldsFromSpec(ImageNodeSpec image) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
}

ImageNodeSchemaFields _imageFieldsFromNode(ImageNode image) {
  return NodeBoundarySchema.imageFieldsFromValidated((
    imageId: image.imageId,
    size: image.size,
    naturalSize: image.naturalSize,
  ));
}

ImageNodeSnapshot _imageSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required ImageNodeSchemaFields fields,
}) {
  return imageNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    imageId: fields.imageId,
    size: fields.size,
    naturalSize: fields.naturalSize,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

SceneNode _textNodeFromSnapshotViaBoundarySchema(
  TextNodeSnapshot text, {
  required int instanceRevision,
  required TextNodeSnapshotSizePolicy textSizePolicy,
}) {
  return _nodeFromSnapshotViaBoundarySchema(
    snapshot: text,
    instanceRevision: instanceRevision,
    extractFields: _textFieldsFromSnapshot,
    buildNode: ({required common, required fields}) =>
        _textNodeFromSnapshotSchema(
          common: common,
          fields: fields,
          textSizePolicy: textSizePolicy,
        ),
  );
}

SceneNode _textNodeFromSpecViaBoundarySchema(
  TextNodeSpec text, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  return _nodeFromSpecViaBoundarySchema(
    spec: text,
    buildCommon: (common) => _runtimeCommonFromSpec(
      common,
      fallbackId: fallbackId,
      instanceRevision: instanceRevision,
    ),
    extractFields: _textFieldsFromSpec,
    buildNode: _textNodeFromSpecSchema,
  );
}

NodeSnapshot _textSnapshotFromNodeViaBoundarySchema(TextNode text) {
  return _nodeSnapshotFromNodeViaBoundarySchema(
    node: text,
    extractFields: _textFieldsFromNode,
    buildSnapshot: _textSnapshotFromSchema,
  );
}

TextNodeSnapshotSchemaFields _textFieldsFromSnapshot(TextNodeSnapshot text) {
  return NodeBoundarySchema.textSnapshotFieldsFromValidated((
    text: text.text,
    size: text.size,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
}

TextNodeSpecSchemaFields _textFieldsFromSpec(TextNodeSpec text) {
  return NodeBoundarySchema.textSpecFieldsFromValidated((
    text: text.text,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
}

TextNodeSnapshotSchemaFields _textFieldsFromNode(TextNode text) {
  return NodeBoundarySchema.textSnapshotFieldsFromValidated((
    text: text.text,
    size: text.size,
    fontSize: text.fontSize,
    color: text.color,
    align: text.align,
    isBold: text.isBold,
    isItalic: text.isItalic,
    isUnderline: text.isUnderline,
    fontFamily: text.fontFamily,
    maxWidth: text.maxWidth,
    lineHeight: text.lineHeight,
  ));
}

TextNodeSnapshot _textSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required TextNodeSnapshotSchemaFields fields,
}) {
  return textNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    text: fields.text,
    size: fields.size,
    fontSize: fields.fontSize,
    color: fields.color,
    align: fields.align,
    isBold: fields.isBold,
    isItalic: fields.isItalic,
    isUnderline: fields.isUnderline,
    fontFamily: fields.fontFamily,
    maxWidth: fields.maxWidth,
    lineHeight: fields.lineHeight,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

SceneNode _strokeNodeFromSnapshotViaBoundarySchema(
  StrokeNodeSnapshot stroke, {
  required int instanceRevision,
}) {
  return _nodeFromSnapshotViaBoundarySchema(
    snapshot: stroke,
    instanceRevision: instanceRevision,
    extractFields: _strokeFieldsFromSnapshot,
    buildNode: _strokeNodeFromSnapshotSchema,
  );
}

SceneNode _strokeNodeFromSpecViaBoundarySchema(
  StrokeNodeSpec stroke, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  return _nodeFromSpecViaBoundarySchema(
    spec: stroke,
    buildCommon: (common) => _runtimeCommonFromSpec(
      common,
      fallbackId: fallbackId,
      instanceRevision: instanceRevision,
    ),
    extractFields: _strokeFieldsFromSpec,
    buildNode: _strokeNodeFromSpecSchema,
  );
}

NodeSnapshot _strokeSnapshotFromNodeViaBoundarySchema(StrokeNode stroke) {
  return _nodeSnapshotFromNodeViaBoundarySchema(
    node: stroke,
    extractFields: _strokeFieldsFromNode,
    buildSnapshot: _strokeSnapshotFromSchema,
  );
}

StrokeNodeSnapshotSchemaFields _strokeFieldsFromSnapshot(
  StrokeNodeSnapshot stroke,
) {
  return NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: stroke.points,
    pointsRevision: stroke.pointsRevision,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
}

StrokeNodeSpecSchemaFields _strokeFieldsFromSpec(StrokeNodeSpec stroke) {
  return NodeBoundarySchema.strokeSpecFieldsFromValidated((
    points: stroke.points,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
}

StrokeNodeSnapshotSchemaFields _strokeFieldsFromNode(StrokeNode stroke) {
  return NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
    points: stroke.points,
    pointsRevision: stroke.pointsRevision,
    thickness: stroke.thickness,
    color: stroke.color,
  ));
}

StrokeNodeSnapshot _strokeSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required StrokeNodeSnapshotSchemaFields fields,
}) {
  return strokeNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    points: fields.points,
    pointsRevision: fields.pointsRevision,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

SceneNode _lineNodeFromSnapshotViaBoundarySchema(
  LineNodeSnapshot line, {
  required int instanceRevision,
}) {
  return _nodeFromSnapshotViaBoundarySchema(
    snapshot: line,
    instanceRevision: instanceRevision,
    extractFields: _lineFieldsFromSnapshot,
    buildNode: _lineNodeFromSchema,
  );
}

SceneNode _lineNodeFromSpecViaBoundarySchema(
  LineNodeSpec line, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  return _nodeFromSpecViaBoundarySchema(
    spec: line,
    buildCommon: (common) => _runtimeCommonFromSpec(
      common,
      fallbackId: fallbackId,
      instanceRevision: instanceRevision,
    ),
    extractFields: _lineFieldsFromSpec,
    buildNode: _lineNodeFromSchema,
  );
}

NodeSnapshot _lineSnapshotFromNodeViaBoundarySchema(LineNode line) {
  return _nodeSnapshotFromNodeViaBoundarySchema(
    node: line,
    extractFields: _lineFieldsFromNode,
    buildSnapshot: _lineSnapshotFromSchema,
  );
}

LineNodeSchemaFields _lineFieldsFromSnapshot(LineNodeSnapshot line) {
  return NodeBoundarySchema.lineFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
}

LineNodeSchemaFields _lineFieldsFromSpec(LineNodeSpec line) {
  return NodeBoundarySchema.lineFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
}

LineNodeSchemaFields _lineFieldsFromNode(LineNode line) {
  return NodeBoundarySchema.lineFieldsFromValidated((
    start: line.start,
    end: line.end,
    thickness: line.thickness,
    color: line.color,
  ));
}

LineNodeSnapshot _lineSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required LineNodeSchemaFields fields,
}) {
  return lineNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    start: fields.start,
    end: fields.end,
    thickness: fields.thickness,
    color: fields.color,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

SceneNode _rectNodeFromSnapshotViaBoundarySchema(
  RectNodeSnapshot rect, {
  required int instanceRevision,
}) {
  return _nodeFromSnapshotViaBoundarySchema(
    snapshot: rect,
    instanceRevision: instanceRevision,
    extractFields: _rectFieldsFromSnapshot,
    buildNode: _rectNodeFromSchema,
  );
}

SceneNode _rectNodeFromSpecViaBoundarySchema(
  RectNodeSpec rect, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  return _nodeFromSpecViaBoundarySchema(
    spec: rect,
    buildCommon: (common) => _runtimeCommonFromSpec(
      common,
      fallbackId: fallbackId,
      instanceRevision: instanceRevision,
    ),
    extractFields: _rectFieldsFromSpec,
    buildNode: _rectNodeFromSchema,
  );
}

NodeSnapshot _rectSnapshotFromNodeViaBoundarySchema(RectNode rect) {
  return _nodeSnapshotFromNodeViaBoundarySchema(
    node: rect,
    extractFields: _rectFieldsFromNode,
    buildSnapshot: _rectSnapshotFromSchema,
  );
}

RectNodeSchemaFields _rectFieldsFromSnapshot(RectNodeSnapshot rect) {
  return NodeBoundarySchema.rectFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
}

RectNodeSchemaFields _rectFieldsFromSpec(RectNodeSpec rect) {
  return NodeBoundarySchema.rectFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
}

RectNodeSchemaFields _rectFieldsFromNode(RectNode rect) {
  return NodeBoundarySchema.rectFieldsFromValidated((
    size: rect.size,
    fillColor: rect.fillColor,
    strokeColor: rect.strokeColor,
    strokeWidth: rect.strokeWidth,
  ));
}

RectNodeSnapshot _rectSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required RectNodeSchemaFields fields,
}) {
  return rectNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    size: fields.size,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}

SceneNode _pathNodeFromSnapshotViaBoundarySchema(
  PathNodeSnapshot path, {
  required int instanceRevision,
}) {
  return _nodeFromSnapshotViaBoundarySchema(
    snapshot: path,
    instanceRevision: instanceRevision,
    extractFields: _pathFieldsFromSnapshot,
    buildNode: _pathNodeFromSchema,
  );
}

SceneNode _pathNodeFromSpecViaBoundarySchema(
  PathNodeSpec path, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  return _nodeFromSpecViaBoundarySchema(
    spec: path,
    buildCommon: (common) => _runtimeCommonFromSpec(
      common,
      fallbackId: fallbackId,
      instanceRevision: instanceRevision,
    ),
    extractFields: _pathFieldsFromSpec,
    buildNode: _pathNodeFromSchema,
  );
}

NodeSnapshot _pathSnapshotFromNodeViaBoundarySchema(PathNode path) {
  return _nodeSnapshotFromNodeViaBoundarySchema(
    node: path,
    extractFields: _pathFieldsFromNode,
    buildSnapshot: _pathSnapshotFromSchema,
  );
}

PathNodeSchemaFields _pathFieldsFromSnapshot(PathNodeSnapshot path) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNodeSchemaFields _pathFieldsFromSpec(PathNodeSpec path) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNodeSchemaFields _pathFieldsFromNode(PathNode path) {
  return NodeBoundarySchema.pathFieldsFromValidated((
    svgPathData: path.svgPathData,
    fillColor: path.fillColor,
    strokeColor: path.strokeColor,
    strokeWidth: path.strokeWidth,
    fillRule: path.fillRule,
  ));
}

PathNodeSnapshot _pathSnapshotFromSchema({
  required NodeSnapshotCommonSchemaFields common,
  required PathNodeSchemaFields fields,
}) {
  return pathNodeSnapshotFromValidated(
    id: common.id,
    instanceRevision: common.instanceRevision,
    svgPathData: fields.svgPathData,
    fillColor: fields.fillColor,
    strokeColor: fields.strokeColor,
    strokeWidth: fields.strokeWidth,
    fillRule: fields.fillRule,
    transform: common.transform,
    opacity: common.opacity,
    hitPadding: common.hitPadding,
    isVisible: common.isVisible,
    isSelectable: common.isSelectable,
    isLocked: common.isLocked,
    isDeletable: common.isDeletable,
    isTransformable: common.isTransformable,
  );
}
