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
      return _imageNodeFromSnapshotViaBoundarySchema(
        image,
        instanceRevision: instanceRevision,
      );
    case TextNodeSnapshot text:
      return _textNodeFromSnapshotViaBoundarySchema(
        text,
        instanceRevision: instanceRevision,
        textSizePolicy: textSizePolicy,
      );
    case StrokeNodeSnapshot stroke:
      return _strokeNodeFromSnapshotViaBoundarySchema(
        stroke,
        instanceRevision: instanceRevision,
      );
    case LineNodeSnapshot line:
      return _lineNodeFromSnapshotViaBoundarySchema(
        line,
        instanceRevision: instanceRevision,
      );
    case RectNodeSnapshot rect:
      return _rectNodeFromSnapshotViaBoundarySchema(
        rect,
        instanceRevision: instanceRevision,
      );
    case PathNodeSnapshot path:
      return _pathNodeFromSnapshotViaBoundarySchema(
        path,
        instanceRevision: instanceRevision,
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
      return _imageNodeFromSpecViaBoundarySchema(
        image,
        fallbackId: fallbackId,
        instanceRevision: instanceRevision,
      );
    case TextNodeSpec text:
      return _textNodeFromSpecViaBoundarySchema(
        text,
        fallbackId: fallbackId,
        instanceRevision: instanceRevision,
      );
    case StrokeNodeSpec stroke:
      return _strokeNodeFromSpecViaBoundarySchema(
        stroke,
        fallbackId: fallbackId,
        instanceRevision: instanceRevision,
      );
    case LineNodeSpec line:
      return _lineNodeFromSpecViaBoundarySchema(
        line,
        fallbackId: fallbackId,
        instanceRevision: instanceRevision,
      );
    case RectNodeSpec rect:
      return _rectNodeFromSpecViaBoundarySchema(
        rect,
        fallbackId: fallbackId,
        instanceRevision: instanceRevision,
      );
    case PathNodeSpec path:
      return _pathNodeFromSpecViaBoundarySchema(
        path,
        fallbackId: fallbackId,
        instanceRevision: instanceRevision,
      );
  }
}

NodeSnapshot sceneNodeSnapshotFromViaBoundarySchema(SceneNode node) {
  switch (node.type) {
    case NodeType.image:
      return _imageSnapshotFromNodeViaBoundarySchema(node as ImageNode);
    case NodeType.text:
      return _textSnapshotFromNodeViaBoundarySchema(node as TextNode);
    case NodeType.stroke:
      return _strokeSnapshotFromNodeViaBoundarySchema(node as StrokeNode);
    case NodeType.line:
      return _lineSnapshotFromNodeViaBoundarySchema(node as LineNode);
    case NodeType.rect:
      return _rectSnapshotFromNodeViaBoundarySchema(node as RectNode);
    case NodeType.path:
      return _pathSnapshotFromNodeViaBoundarySchema(node as PathNode);
  }
}

SceneNode cloneSceneNodeViaBoundarySchema(SceneNode node) {
  return sceneNodeFromSnapshotViaBoundarySchema(
    sceneNodeSnapshotFromViaBoundarySchema(node),
    instanceRevision: node.instanceRevision,
  );
}
