import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../core/nodes.dart';
import 'scene_node_boundary_mapping_image.dart';
import 'scene_node_boundary_mapping_line.dart';
import 'scene_node_boundary_mapping_path.dart';
import 'scene_node_boundary_mapping_rect.dart';
import 'scene_node_boundary_mapping_stroke.dart';
import 'scene_node_boundary_mapping_support.dart';
import 'scene_node_boundary_mapping_text.dart';

export 'scene_node_boundary_mapping_support.dart'
    show TextNodeSnapshotSizePolicy;

SceneNode sceneNodeFromSnapshotViaBoundarySchema(
  NodeSnapshot node, {
  required int instanceRevision,
  TextNodeSnapshotSizePolicy textSizePolicy =
      TextNodeSnapshotSizePolicy.preserveBoundarySize,
}) {
  switch (node) {
    case ImageNodeSnapshot image:
      return _sceneNodeImageFromSnapshot(image, instanceRevision);
    case TextNodeSnapshot text:
      return _sceneNodeTextFromSnapshot(text, instanceRevision, textSizePolicy);
    case StrokeNodeSnapshot stroke:
      return _sceneNodeStrokeFromSnapshot(stroke, instanceRevision);
    case LineNodeSnapshot line:
      return _sceneNodeLineFromSnapshot(line, instanceRevision);
    case RectNodeSnapshot rect:
      return _sceneNodeRectFromSnapshot(rect, instanceRevision);
    case PathNodeSnapshot path:
      return _sceneNodePathFromSnapshot(path, instanceRevision);
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
      return _sceneNodeImageFromSpec(image, runtimeContext);
    case TextNodeSpec text:
      return _sceneNodeTextFromSpec(text, runtimeContext);
    case StrokeNodeSpec stroke:
      return _sceneNodeStrokeFromSpec(stroke, runtimeContext);
    case LineNodeSpec line:
      return _sceneNodeLineFromSpec(line, runtimeContext);
    case RectNodeSpec rect:
      return _sceneNodeRectFromSpec(rect, runtimeContext);
    case PathNodeSpec path:
      return _sceneNodePathFromSpec(path, runtimeContext);
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

ImageNode _sceneNodeImageFromSnapshot(
  ImageNodeSnapshot image,
  int instanceRevision,
) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: image,
        instanceRevision: instanceRevision,
        extractFields: imageNodeSchemaFieldsFromSnapshot,
        buildNode: imageNodeFromSchema,
      )
      as ImageNode;
}

TextNode _sceneNodeTextFromSnapshot(
  TextNodeSnapshot text,
  int instanceRevision,
  TextNodeSnapshotSizePolicy textSizePolicy,
) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: text,
        instanceRevision: instanceRevision,
        extractFields: textNodeSchemaFieldsFromSnapshot,
        buildNode: ({required common, required fields}) =>
            textNodeFromSnapshotSchema(
              common: common,
              fields: fields,
              textSizePolicy: textSizePolicy,
            ),
      )
      as TextNode;
}

StrokeNode _sceneNodeStrokeFromSnapshot(
  StrokeNodeSnapshot stroke,
  int instanceRevision,
) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: stroke,
        instanceRevision: instanceRevision,
        extractFields: strokeNodeSchemaFieldsFromSnapshot,
        buildNode: strokeNodeFromSnapshotSchema,
      )
      as StrokeNode;
}

LineNode _sceneNodeLineFromSnapshot(
  LineNodeSnapshot line,
  int instanceRevision,
) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: line,
        instanceRevision: instanceRevision,
        extractFields: lineNodeSchemaFieldsFromSnapshot,
        buildNode: lineNodeFromSchema,
      )
      as LineNode;
}

RectNode _sceneNodeRectFromSnapshot(
  RectNodeSnapshot rect,
  int instanceRevision,
) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: rect,
        instanceRevision: instanceRevision,
        extractFields: rectNodeSchemaFieldsFromSnapshot,
        buildNode: rectNodeFromSchema,
      )
      as RectNode;
}

PathNode _sceneNodePathFromSnapshot(
  PathNodeSnapshot path,
  int instanceRevision,
) {
  return sceneNodeFromSnapshotViaSchema(
        snapshot: path,
        instanceRevision: instanceRevision,
        extractFields: pathNodeSchemaFieldsFromSnapshot,
        buildNode: pathNodeFromSchema,
      )
      as PathNode;
}

ImageNode _sceneNodeImageFromSpec(
  ImageNodeSpec image,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: image,
        runtimeContext: runtimeContext,
        extractFields: imageNodeSchemaFieldsFromSpec,
        buildNode: imageNodeFromSchema,
      )
      as ImageNode;
}

TextNode _sceneNodeTextFromSpec(
  TextNodeSpec text,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: text,
        runtimeContext: runtimeContext,
        extractFields: textNodeSchemaFieldsFromSpec,
        buildNode: textNodeFromSpecSchema,
      )
      as TextNode;
}

StrokeNode _sceneNodeStrokeFromSpec(
  StrokeNodeSpec stroke,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: stroke,
        runtimeContext: runtimeContext,
        extractFields: strokeNodeSchemaFieldsFromSpec,
        buildNode: strokeNodeFromSpecSchema,
      )
      as StrokeNode;
}

LineNode _sceneNodeLineFromSpec(
  LineNodeSpec line,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: line,
        runtimeContext: runtimeContext,
        extractFields: lineNodeSchemaFieldsFromSpec,
        buildNode: lineNodeFromSchema,
      )
      as LineNode;
}

RectNode _sceneNodeRectFromSpec(
  RectNodeSpec rect,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: rect,
        runtimeContext: runtimeContext,
        extractFields: rectNodeSchemaFieldsFromSpec,
        buildNode: rectNodeFromSchema,
      )
      as RectNode;
}

PathNode _sceneNodePathFromSpec(
  PathNodeSpec path,
  SpecRuntimeNodeContext runtimeContext,
) {
  return sceneNodeFromSpecViaSchema(
        spec: path,
        runtimeContext: runtimeContext,
        extractFields: pathNodeSchemaFieldsFromSpec,
        buildNode: pathNodeFromSchema,
      )
      as PathNode;
}
