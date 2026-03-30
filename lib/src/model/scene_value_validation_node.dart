import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../contract/validated/instance_revision_value.dart';
import '../contract/validated/node_id_value.dart';
import '../contract/validated/non_negative_finite_double_value.dart';
import '../contract/validated/opacity_value.dart';
import '../core/nodes.dart';
import 'scene_value_validation_node_image.dart' as image_validation;
import 'scene_value_validation_node_line.dart' as line_validation;
import 'scene_value_validation_node_path.dart' as path_validation;
import 'scene_value_validation_node_rect.dart' as rect_validation;
import 'scene_value_validation_node_stroke.dart' as stroke_validation;
import 'scene_value_validation_node_text.dart' as text_validation;
import 'scene_value_validation_primitives.dart';
import 'scene_value_validation_support.dart';

typedef _NodeBaseValidationFields = ({
  String id,
  int instanceRevision,
  Transform2D transform,
  double hitPadding,
  double opacity,
});

void sceneValidateNodeSnapshot(
  NodeSnapshot node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateSnapshotNodeBaseFields(node, field: field, onError: onError);
  _sceneValidateSnapshotNodeTypeFields(node, field: field, onError: onError);
}

void sceneValidateNode(
  SceneNode node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateRuntimeNodeBaseFields(node, field: field, onError: onError);
  _sceneValidateRuntimeNodeTypeFields(node, field: field, onError: onError);
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

void _sceneValidateNodeBaseFields({
  required _NodeBaseValidationFields fields,
  required String field,
  required SceneValidationErrorReporter onError,
  required bool allowZeroInstanceRevision,
}) {
  sceneValidateArgumentBoundary(
    field: '$field.id',
    value: fields.id,
    onError: onError,
    validate: () => NodeIdValue.of(fields.id, name: '$field.id'),
  );
  sceneValidateArgumentBoundary(
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
  sceneValidateArgumentBoundary(
    field: '$field.hitPadding',
    value: fields.hitPadding,
    onError: onError,
    validate: () => NonNegativeFiniteDoubleValue.of(
      fields.hitPadding,
      name: '$field.hitPadding',
    ),
  );
  sceneValidateArgumentBoundary(
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
      image_validation.sceneValidateImageNodeSnapshot(
        image,
        field: field,
        onError: onError,
      );
    case TextNodeSnapshot text:
      text_validation.sceneValidateTextNodeSnapshot(
        text,
        field: field,
        onError: onError,
      );
    case StrokeNodeSnapshot stroke:
      stroke_validation.sceneValidateStrokeNodeSnapshot(
        stroke,
        field: field,
        onError: onError,
      );
    case LineNodeSnapshot line:
      line_validation.sceneValidateLineNodeSnapshot(
        line,
        field: field,
        onError: onError,
      );
    case RectNodeSnapshot rect:
      rect_validation.sceneValidateRectNodeSnapshot(
        rect,
        field: field,
        onError: onError,
      );
    case PathNodeSnapshot path:
      path_validation.sceneValidatePathNodeSnapshot(
        path,
        field: field,
        onError: onError,
      );
  }
}

void _sceneValidateRuntimeNodeTypeFields(
  SceneNode node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  switch (node.type) {
    case NodeType.image:
      image_validation.sceneValidateImageNode(
        node as ImageNode,
        field: field,
        onError: onError,
      );
    case NodeType.text:
      text_validation.sceneValidateTextNode(
        node as TextNode,
        field: field,
        onError: onError,
      );
    case NodeType.stroke:
      stroke_validation.sceneValidateStrokeNode(
        node as StrokeNode,
        field: field,
        onError: onError,
      );
    case NodeType.line:
      line_validation.sceneValidateLineNode(
        node as LineNode,
        field: field,
        onError: onError,
      );
    case NodeType.rect:
      rect_validation.sceneValidateRectNode(
        node as RectNode,
        field: field,
        onError: onError,
      );
    case NodeType.path:
      path_validation.sceneValidatePathNode(
        node as PathNode,
        field: field,
        onError: onError,
      );
  }
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

_NodeBaseValidationFields _runtimeNodeBaseValidationFields(SceneNode node) {
  return (
    id: node.id,
    instanceRevision: node.instanceRevision,
    transform: node.transform,
    hitPadding: node.hitPadding,
    opacity: node.opacity,
  );
}
