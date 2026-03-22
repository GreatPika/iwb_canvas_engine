import 'dart:ui';

import '../contract/internal/node_boundary_schema.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../core/nodes.dart';
import '../core/text_layout.dart';

part 'scene_node_boundary_mapping_common.part.dart';
part 'scene_node_boundary_mapping_from_snapshot.part.dart';
part 'scene_node_boundary_mapping_from_spec.part.dart';
part 'scene_node_boundary_mapping_to_snapshot.part.dart';

enum TextNodeSnapshotSizePolicy { preserveBoundarySize, recomputeFromLayout }

typedef _RuntimeNodeCommonFields = ({
  NodeId id,
  int instanceRevision,
  Transform2D transform,
  double opacity,
  double hitPadding,
  bool isVisible,
  bool isSelectable,
  bool isLocked,
  bool isDeletable,
  bool isTransformable,
});

SceneNode sceneNodeFromSnapshotViaBoundarySchema(
  NodeSnapshot node, {
  required int instanceRevision,
  TextNodeSnapshotSizePolicy textSizePolicy =
      TextNodeSnapshotSizePolicy.preserveBoundarySize,
}) {
  switch (node) {
    case ImageNodeSnapshot image:
      return _nodeFromSnapshotViaBoundarySchema(
        snapshot: image,
        instanceRevision: instanceRevision,
        extractFields: (image) => NodeBoundarySchema.imageFieldsFromValidated((
          imageId: image.imageId,
          size: image.size,
          naturalSize: image.naturalSize,
        )),
        buildNode: _imageNodeFromSchema,
      );
    case TextNodeSnapshot text:
      return _nodeFromSnapshotViaBoundarySchema(
        snapshot: text,
        instanceRevision: instanceRevision,
        extractFields: (text) =>
            NodeBoundarySchema.textSnapshotFieldsFromValidated((
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
            )),
        buildNode: ({required common, required fields}) =>
            _textNodeFromSnapshotSchema(
              common: common,
              fields: fields,
              textSizePolicy: textSizePolicy,
            ),
      );
    case StrokeNodeSnapshot stroke:
      return _nodeFromSnapshotViaBoundarySchema(
        snapshot: stroke,
        instanceRevision: instanceRevision,
        extractFields: (stroke) =>
            NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
              points: stroke.points,
              pointsRevision: stroke.pointsRevision,
              thickness: stroke.thickness,
              color: stroke.color,
            )),
        buildNode: _strokeNodeFromSnapshotSchema,
      );
    case LineNodeSnapshot line:
      return _nodeFromSnapshotViaBoundarySchema(
        snapshot: line,
        instanceRevision: instanceRevision,
        extractFields: (line) => NodeBoundarySchema.lineFieldsFromValidated((
          start: line.start,
          end: line.end,
          thickness: line.thickness,
          color: line.color,
        )),
        buildNode: _lineNodeFromSchema,
      );
    case RectNodeSnapshot rect:
      return _nodeFromSnapshotViaBoundarySchema(
        snapshot: rect,
        instanceRevision: instanceRevision,
        extractFields: (rect) => NodeBoundarySchema.rectFieldsFromValidated((
          size: rect.size,
          fillColor: rect.fillColor,
          strokeColor: rect.strokeColor,
          strokeWidth: rect.strokeWidth,
        )),
        buildNode: _rectNodeFromSchema,
      );
    case PathNodeSnapshot path:
      return _nodeFromSnapshotViaBoundarySchema(
        snapshot: path,
        instanceRevision: instanceRevision,
        extractFields: (path) => NodeBoundarySchema.pathFieldsFromValidated((
          svgPathData: path.svgPathData,
          fillColor: path.fillColor,
          strokeColor: path.strokeColor,
          strokeWidth: path.strokeWidth,
          fillRule: path.fillRule,
        )),
        buildNode: _pathNodeFromSchema,
      );
  }
}

SceneNode sceneNodeFromSpecViaBoundarySchema(
  NodeSpec spec, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  switch (spec) {
    case ImageNodeSpec image:
      return _nodeFromSpecViaBoundarySchema(
        spec: image,
        buildCommon: (common) => _runtimeCommonFromSpec(
          common,
          fallbackId: fallbackId,
          instanceRevision: instanceRevision,
        ),
        extractFields: (image) => NodeBoundarySchema.imageFieldsFromValidated((
          imageId: image.imageId,
          size: image.size,
          naturalSize: image.naturalSize,
        )),
        buildNode: _imageNodeFromSchema,
      );
    case TextNodeSpec text:
      return _nodeFromSpecViaBoundarySchema(
        spec: text,
        buildCommon: (common) => _runtimeCommonFromSpec(
          common,
          fallbackId: fallbackId,
          instanceRevision: instanceRevision,
        ),
        extractFields: (text) =>
            NodeBoundarySchema.textSpecFieldsFromValidated((
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
            )),
        buildNode: _textNodeFromSpecSchema,
      );
    case StrokeNodeSpec stroke:
      return _nodeFromSpecViaBoundarySchema(
        spec: stroke,
        buildCommon: (common) => _runtimeCommonFromSpec(
          common,
          fallbackId: fallbackId,
          instanceRevision: instanceRevision,
        ),
        extractFields: (stroke) =>
            NodeBoundarySchema.strokeSpecFieldsFromValidated((
              points: stroke.points,
              thickness: stroke.thickness,
              color: stroke.color,
            )),
        buildNode: _strokeNodeFromSpecSchema,
      );
    case LineNodeSpec line:
      return _nodeFromSpecViaBoundarySchema(
        spec: line,
        buildCommon: (common) => _runtimeCommonFromSpec(
          common,
          fallbackId: fallbackId,
          instanceRevision: instanceRevision,
        ),
        extractFields: (line) => NodeBoundarySchema.lineFieldsFromValidated((
          start: line.start,
          end: line.end,
          thickness: line.thickness,
          color: line.color,
        )),
        buildNode: _lineNodeFromSchema,
      );
    case RectNodeSpec rect:
      return _nodeFromSpecViaBoundarySchema(
        spec: rect,
        buildCommon: (common) => _runtimeCommonFromSpec(
          common,
          fallbackId: fallbackId,
          instanceRevision: instanceRevision,
        ),
        extractFields: (rect) => NodeBoundarySchema.rectFieldsFromValidated((
          size: rect.size,
          fillColor: rect.fillColor,
          strokeColor: rect.strokeColor,
          strokeWidth: rect.strokeWidth,
        )),
        buildNode: _rectNodeFromSchema,
      );
    case PathNodeSpec path:
      return _nodeFromSpecViaBoundarySchema(
        spec: path,
        buildCommon: (common) => _runtimeCommonFromSpec(
          common,
          fallbackId: fallbackId,
          instanceRevision: instanceRevision,
        ),
        extractFields: (path) => NodeBoundarySchema.pathFieldsFromValidated((
          svgPathData: path.svgPathData,
          fillColor: path.fillColor,
          strokeColor: path.strokeColor,
          strokeWidth: path.strokeWidth,
          fillRule: path.fillRule,
        )),
        buildNode: _pathNodeFromSchema,
      );
  }
}

NodeSnapshot sceneNodeSnapshotFromViaBoundarySchema(SceneNode node) {
  switch (node.type) {
    case NodeType.image:
      final image = node as ImageNode;
      return _nodeSnapshotFromNodeViaBoundarySchema(
        node: image,
        extractFields: (image) => NodeBoundarySchema.imageFieldsFromValidated((
          imageId: image.imageId,
          size: image.size,
          naturalSize: image.naturalSize,
        )),
        buildSnapshot: _imageSnapshotFromSchema,
      );
    case NodeType.text:
      final text = node as TextNode;
      return _nodeSnapshotFromNodeViaBoundarySchema(
        node: text,
        extractFields: (text) =>
            NodeBoundarySchema.textSnapshotFieldsFromValidated((
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
            )),
        buildSnapshot: _textSnapshotFromSchema,
      );
    case NodeType.stroke:
      final stroke = node as StrokeNode;
      return _nodeSnapshotFromNodeViaBoundarySchema(
        node: stroke,
        extractFields: (stroke) =>
            NodeBoundarySchema.strokeSnapshotFieldsFromValidated((
              points: stroke.points,
              pointsRevision: stroke.pointsRevision,
              thickness: stroke.thickness,
              color: stroke.color,
            )),
        buildSnapshot: _strokeSnapshotFromSchema,
      );
    case NodeType.line:
      final line = node as LineNode;
      return _nodeSnapshotFromNodeViaBoundarySchema(
        node: line,
        extractFields: (line) => NodeBoundarySchema.lineFieldsFromValidated((
          start: line.start,
          end: line.end,
          thickness: line.thickness,
          color: line.color,
        )),
        buildSnapshot: _lineSnapshotFromSchema,
      );
    case NodeType.rect:
      final rect = node as RectNode;
      return _nodeSnapshotFromNodeViaBoundarySchema(
        node: rect,
        extractFields: (rect) => NodeBoundarySchema.rectFieldsFromValidated((
          size: rect.size,
          fillColor: rect.fillColor,
          strokeColor: rect.strokeColor,
          strokeWidth: rect.strokeWidth,
        )),
        buildSnapshot: _rectSnapshotFromSchema,
      );
    case NodeType.path:
      final path = node as PathNode;
      return _nodeSnapshotFromNodeViaBoundarySchema(
        node: path,
        extractFields: (path) => NodeBoundarySchema.pathFieldsFromValidated((
          svgPathData: path.svgPathData,
          fillColor: path.fillColor,
          strokeColor: path.strokeColor,
          strokeWidth: path.strokeWidth,
          fillRule: path.fillRule,
        )),
        buildSnapshot: _pathSnapshotFromSchema,
      );
  }
}

SceneNode cloneSceneNodeViaBoundarySchema(SceneNode node) {
  return sceneNodeFromSnapshotViaBoundarySchema(
    sceneNodeSnapshotFromViaBoundarySchema(node),
    instanceRevision: node.instanceRevision,
  );
}
