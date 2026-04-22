import '../contract/internal/snapshot_fast_path.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_node_boundary_mapping_common.dart';
import 'scene_node_boundary_mapping_image.dart';
import 'scene_node_boundary_mapping_line.dart';
import 'scene_node_boundary_mapping_path.dart';
import 'scene_node_boundary_mapping_rect.dart';
import 'scene_node_boundary_mapping_stroke.dart';
import 'scene_node_boundary_mapping_text.dart';

SceneNode sceneNodeFromSnapshotViaBoundarySchema(
  NodeSnapshot node, {
  required int instanceRevision,
}) {
  switch (node) {
    case ImageNodeSnapshot image:
      return imageNodeFromSnapshot(image, instanceRevision);
    case TextNodeSnapshot text:
      return textNodeFromSnapshot(text, instanceRevision);
    case StrokeNodeSnapshot stroke:
      return strokeNodeFromSnapshot(stroke, instanceRevision);
    case LineNodeSnapshot line:
      return lineNodeFromSnapshot(line, instanceRevision);
    case RectNodeSnapshot rect:
      return rectNodeFromSnapshot(rect, instanceRevision);
    case PathNodeSnapshot path:
      return pathNodeFromSnapshot(path, instanceRevision);
    default:
      throw StateError('Unsupported NodeSnapshot subtype: ${node.runtimeType}');
  }
}

SceneNode sceneNodeFromSnapshotBackingViaBoundarySchema(
  NodeSnapshotBacking node, {
  required int instanceRevision,
}) {
  switch (node) {
    case ImageNodeSnapshotBacking image:
      return imageNodeFromSnapshotBacking(image, instanceRevision);
    case TextNodeSnapshotBacking text:
      return textNodeFromSnapshotBacking(text, instanceRevision);
    case StrokeNodeSnapshotBacking stroke:
      return strokeNodeFromSnapshotBacking(stroke, instanceRevision);
    case LineNodeSnapshotBacking line:
      return lineNodeFromSnapshotBacking(line, instanceRevision);
    case RectNodeSnapshotBacking rect:
      return rectNodeFromSnapshotBacking(rect, instanceRevision);
    case PathNodeSnapshotBacking path:
      return pathNodeFromSnapshotBacking(path, instanceRevision);
  }
}

SceneNode sceneNodeFromSpecViaBoundarySchema(
  NodeSpec spec, {
  required NodeId fallbackId,
  required int instanceRevision,
}) {
  final runtimeContext = (
    fallbackId: fallbackId,
    instanceRevision: instanceRevision,
  );
  switch (spec) {
    case ImageNodeSpec image:
      return imageNodeFromSpec(image, runtimeContext);
    case TextNodeSpec text:
      return textNodeFromSpec(text, runtimeContext);
    case StrokeNodeSpec stroke:
      return strokeNodeFromSpec(stroke, runtimeContext);
    case LineNodeSpec line:
      return lineNodeFromSpec(line, runtimeContext);
    case RectNodeSpec rect:
      return rectNodeFromSpec(rect, runtimeContext);
    case PathNodeSpec path:
      return pathNodeFromSpec(path, runtimeContext);
    default:
      throw StateError('Unsupported NodeSpec subtype: ${spec.runtimeType}');
  }
}

NodeSnapshot sceneNodeSnapshotFromViaBoundarySchema(SceneNode node) {
  return nodeSnapshotFromValidatedBacking(
    sceneNodeSnapshotBackingFromViaBoundarySchema(node),
  );
}

NodeSnapshotBacking sceneNodeSnapshotBackingFromViaBoundarySchema(
  SceneNode node,
) {
  switch (node.type) {
    case NodeType.image:
      return sceneNodeSnapshotBackingFromViaSchema(
        node: node as ImageNode,
        extractFields: imageNodeSchemaFieldsFromNode,
        buildSnapshotBacking: imageSnapshotBackingFromSchema,
      );
    case NodeType.text:
      return sceneNodeSnapshotBackingFromViaSchema(
        node: node as TextNode,
        extractFields: textNodeSchemaFieldsFromNode,
        buildSnapshotBacking: textSnapshotBackingFromSchema,
      );
    case NodeType.stroke:
      return sceneNodeSnapshotBackingFromViaSchema(
        node: node as StrokeNode,
        extractFields: strokeNodeSchemaFieldsFromNode,
        buildSnapshotBacking: strokeSnapshotBackingFromSchema,
      );
    case NodeType.line:
      return sceneNodeSnapshotBackingFromViaSchema(
        node: node as LineNode,
        extractFields: lineNodeSchemaFieldsFromNode,
        buildSnapshotBacking: lineSnapshotBackingFromSchema,
      );
    case NodeType.rect:
      return sceneNodeSnapshotBackingFromViaSchema(
        node: node as RectNode,
        extractFields: rectNodeSchemaFieldsFromNode,
        buildSnapshotBacking: rectSnapshotBackingFromSchema,
      );
    case NodeType.path:
      return sceneNodeSnapshotBackingFromViaSchema(
        node: node as PathNode,
        extractFields: pathNodeSchemaFieldsFromNode,
        buildSnapshotBacking: pathSnapshotBackingFromSchema,
      );
  }
}

SceneNode cloneRuntimeSceneNode(SceneNode node) {
  switch (node.type) {
    case NodeType.image:
      return cloneRuntimeImageNode(node as ImageNode);
    case NodeType.text:
      return cloneRuntimeTextNode(node as TextNode);
    case NodeType.stroke:
      return cloneRuntimeStrokeNode(node as StrokeNode);
    case NodeType.line:
      return cloneRuntimeLineNode(node as LineNode);
    case NodeType.rect:
      return cloneRuntimeRectNode(node as RectNode);
    case NodeType.path:
      return cloneRuntimePathNode(node as PathNode);
  }
}
