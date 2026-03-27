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

export 'scene_node_boundary_mapping_common.dart'
    show TextNodeSnapshotSizePolicy;

SceneNode sceneNodeFromSnapshotViaBoundarySchema(
  NodeSnapshot node, {
  required int instanceRevision,
  TextNodeSnapshotSizePolicy textSizePolicy =
      TextNodeSnapshotSizePolicy.preserveBoundarySize,
}) {
  switch (node) {
    case ImageNodeSnapshot image:
      return imageNodeFromSnapshot(image, instanceRevision);
    case TextNodeSnapshot text:
      return textNodeFromSnapshot(text, instanceRevision, textSizePolicy);
    case StrokeNodeSnapshot stroke:
      return strokeNodeFromSnapshot(stroke, instanceRevision);
    case LineNodeSnapshot line:
      return lineNodeFromSnapshot(line, instanceRevision);
    case RectNodeSnapshot rect:
      return rectNodeFromSnapshot(rect, instanceRevision);
    case PathNodeSnapshot path:
      return pathNodeFromSnapshot(path, instanceRevision);
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
  }
}

NodeSnapshot sceneNodeSnapshotFromViaBoundarySchema(SceneNode node) {
  switch (node.type) {
    case NodeType.image:
      return sceneNodeSnapshotFromViaSchema(
        node: node as ImageNode,
        extractFields: imageNodeSchemaFieldsFromNode,
        buildSnapshot: imageSnapshotFromSchema,
      );
    case NodeType.text:
      return sceneNodeSnapshotFromViaSchema(
        node: node as TextNode,
        extractFields: textNodeSchemaFieldsFromNode,
        buildSnapshot: textSnapshotFromSchema,
      );
    case NodeType.stroke:
      return sceneNodeSnapshotFromViaSchema(
        node: node as StrokeNode,
        extractFields: strokeNodeSchemaFieldsFromNode,
        buildSnapshot: strokeSnapshotFromSchema,
      );
    case NodeType.line:
      return sceneNodeSnapshotFromViaSchema(
        node: node as LineNode,
        extractFields: lineNodeSchemaFieldsFromNode,
        buildSnapshot: lineSnapshotFromSchema,
      );
    case NodeType.rect:
      return sceneNodeSnapshotFromViaSchema(
        node: node as RectNode,
        extractFields: rectNodeSchemaFieldsFromNode,
        buildSnapshot: rectSnapshotFromSchema,
      );
    case NodeType.path:
      return sceneNodeSnapshotFromViaSchema(
        node: node as PathNode,
        extractFields: pathNodeSchemaFieldsFromNode,
        buildSnapshot: pathSnapshotFromSchema,
      );
  }
}

SceneNode cloneSceneNodeViaBoundarySchema(SceneNode node) {
  return sceneNodeFromSnapshotViaBoundarySchema(
    sceneNodeSnapshotFromViaBoundarySchema(node),
    instanceRevision: node.instanceRevision,
  );
}
