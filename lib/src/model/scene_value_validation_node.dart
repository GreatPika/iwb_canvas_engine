import 'dart:math' as math;

import '../contract/internal/snapshot_fast_path.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../contract/validated/instance_revision_value.dart';
import '../contract/validated/node_id_value.dart';
import '../contract/validated/non_negative_finite_double_value.dart';
import '../contract/validated/opacity_value.dart';
import '../core/scene_limits.dart';
import '../core/nodes.dart';
import 'scene_validation_path_surface.dart';
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
  SceneValidationPathSurface pathSurface = SceneValidationPathSurface.snapshot,
}) {
  _sceneValidateSnapshotNodeBaseFields(node, field: field, onError: onError);
  _sceneValidateSnapshotNodeTypeFields(
    node,
    field: field,
    onError: onError,
    pathSurface: pathSurface,
  );
}

void sceneValidateNodeSnapshotBacking(
  NodeSnapshotBacking node, {
  required String field,
  required SceneValidationErrorReporter onError,
  SceneValidationPathSurface pathSurface = SceneValidationPathSurface.snapshot,
}) {
  _sceneValidateSnapshotNodeBackingBaseFields(
    node,
    field: field,
    onError: onError,
  );
  _sceneValidateSnapshotNodeBackingTypeFields(
    node,
    field: field,
    onError: onError,
    pathSurface: pathSurface,
  );
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

void _sceneValidateSnapshotNodeBackingBaseFields(
  NodeSnapshotBacking node, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  _sceneValidateNodeBaseFields(
    fields: _snapshotNodeBackingBaseValidationFields(node),
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
  sceneValidateDoubleInRange(
    fields.hitPadding,
    field: '$field.hitPadding',
    min: 0,
    max: sceneHitPaddingMax,
    onError: onError,
  );
  _sceneValidateTransformRanges(
    fields.transform,
    field: '$field.transform',
    onError: onError,
  );
}

void _sceneValidateSnapshotNodeTypeFields(
  NodeSnapshot node, {
  required String field,
  required SceneValidationErrorReporter onError,
  required SceneValidationPathSurface pathSurface,
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
        pathSurface: pathSurface,
      );
    case LineNodeSnapshot line:
      line_validation.sceneValidateLineNodeSnapshot(
        line,
        field: field,
        onError: onError,
        pathSurface: pathSurface,
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

void _sceneValidateSnapshotNodeBackingTypeFields(
  NodeSnapshotBacking node, {
  required String field,
  required SceneValidationErrorReporter onError,
  required SceneValidationPathSurface pathSurface,
}) {
  switch (node) {
    case ImageNodeSnapshotBacking image:
      image_validation.sceneValidateImageNodeSnapshotBacking(
        image,
        field: field,
        onError: onError,
      );
    case TextNodeSnapshotBacking text:
      text_validation.sceneValidateTextNodeSnapshotBacking(
        text,
        field: field,
        onError: onError,
      );
    case StrokeNodeSnapshotBacking stroke:
      stroke_validation.sceneValidateStrokeNodeSnapshotBacking(
        stroke,
        field: field,
        onError: onError,
        pathSurface: pathSurface,
      );
    case LineNodeSnapshotBacking line:
      line_validation.sceneValidateLineNodeSnapshotBacking(
        line,
        field: field,
        onError: onError,
        pathSurface: pathSurface,
      );
    case RectNodeSnapshotBacking rect:
      rect_validation.sceneValidateRectNodeSnapshotBacking(
        rect,
        field: field,
        onError: onError,
      );
    case PathNodeSnapshotBacking path:
      path_validation.sceneValidatePathNodeSnapshotBacking(
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
  switch ((node.type, node)) {
    case (NodeType.image, ImageNode image):
      image_validation.sceneValidateImageNode(
        image,
        field: field,
        onError: onError,
      );
    case (NodeType.text, TextNode text):
      text_validation.sceneValidateTextNode(
        text,
        field: field,
        onError: onError,
      );
    case (NodeType.stroke, StrokeNode stroke):
      stroke_validation.sceneValidateStrokeNode(
        stroke,
        field: field,
        onError: onError,
      );
    case (NodeType.line, LineNode line):
      line_validation.sceneValidateLineNode(
        line,
        field: field,
        onError: onError,
      );
    case (NodeType.rect, RectNode rect):
      rect_validation.sceneValidateRectNode(
        rect,
        field: field,
        onError: onError,
      );
    case (NodeType.path, PathNode path):
      path_validation.sceneValidatePathNode(
        path,
        field: field,
        onError: onError,
      );
    case _:
      sceneValidationFail(
        onError: onError,
        value: node.type,
        field: '$field.type',
        message:
            'must match the concrete runtime node subtype for '
            '${node.type.name}.',
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

_NodeBaseValidationFields _snapshotNodeBackingBaseValidationFields(
  NodeSnapshotBacking node,
) {
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

void _sceneValidateTransformRanges(
  Transform2D transform, {
  required String field,
  required SceneValidationErrorReporter onError,
}) {
  sceneValidateDoubleInRange(
    transform.tx,
    field: '$field.tx',
    min: sceneCoordMin,
    max: sceneCoordMax,
    onError: onError,
  );
  sceneValidateDoubleInRange(
    transform.ty,
    field: '$field.ty',
    min: sceneCoordMin,
    max: sceneCoordMax,
    onError: onError,
  );

  final scaleX = math.sqrt(
    transform.a * transform.a + transform.b * transform.b,
  );
  final scaleY = math.sqrt(
    transform.c * transform.c + transform.d * transform.d,
  );
  sceneValidateDoubleInRange(
    scaleX,
    field: '$field.scaleX',
    min: sceneScaleMin,
    max: sceneScaleMax,
    onError: onError,
  );
  sceneValidateDoubleInRange(
    scaleY,
    field: '$field.scaleY',
    min: sceneScaleMin,
    max: sceneScaleMax,
    onError: onError,
  );
}
