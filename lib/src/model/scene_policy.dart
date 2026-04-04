import 'dart:math' as math;
import '../contract/internal/snapshot_fast_path.dart';
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';
import '../contract/scene_structure_validation.dart';
import '../contract/transform2d.dart';
import '../core/scene.dart';
import '../core/scene_limits.dart';
import '../core/text_layout.dart';
import 'scene_import_draft.dart';
import 'scene_import_draft_from_snapshot.dart';
import 'scene_value_validation.dart';

typedef ScenePolicySnapshotFromScene = SceneSnapshot Function(Scene scene);
typedef ScenePolicySceneFromImportDraft =
    Scene Function(SceneImportDraft draft);

abstract final class ScenePolicy {
  static SceneImportDraft validateImportDraft(SceneImportDraft rawDraft) {
    sceneValidateSceneSnapshotBackingStructure(rawDraft.backing);
    return _validateStructurallyValidImportDraft(rawDraft);
  }

  static SceneSnapshot validateImportSnapshot(SceneSnapshot rawSnapshot) {
    final rawDraft = sceneImportDraftFromSnapshot(rawSnapshot);
    return sceneSnapshotFromValidatedImportDraft(validateImportDraft(rawDraft));
  }

  static Scene validateRuntimeScene(
    Scene rawScene, {
    required ScenePolicySnapshotFromScene snapshotFromScene,
    required ScenePolicySceneFromImportDraft sceneFromImportDraft,
  }) {
    return _validateSceneBoundary(
      rawScene,
      snapshotFromScene: snapshotFromScene,
      sceneFromImportDraft: sceneFromImportDraft,
    );
  }

  static Scene validateEncodeScene(
    Scene scene, {
    required ScenePolicySnapshotFromScene snapshotFromScene,
    required ScenePolicySceneFromImportDraft sceneFromImportDraft,
  }) {
    return _validateSceneBoundary(
      scene,
      snapshotFromScene: snapshotFromScene,
      sceneFromImportDraft: sceneFromImportDraft,
    );
  }

  static Scene _validateSceneBoundary(
    Scene rawScene, {
    required ScenePolicySnapshotFromScene snapshotFromScene,
    required ScenePolicySceneFromImportDraft sceneFromImportDraft,
  }) {
    sceneValidateSceneValues(
      rawScene,
      onError: _sceneValidationError,
      requirePositiveGridCellSize: true,
      requireEnabledMinGridCellSize: true,
    );
    final rawSnapshot = snapshotFromScene(rawScene);
    final rawDraft = sceneImportDraftFromSnapshot(rawSnapshot);
    final canonicalDraft = _validateStructurallyValidImportDraft(rawDraft);
    return sceneFromImportDraft(canonicalDraft);
  }
}

SceneImportDraft _validateStructurallyValidImportDraft(SceneImportDraft draft) {
  sceneValidateImportDraftValues(
    draft,
    onError: _snapshotValidationError,
    requirePositiveGridCellSize: true,
    requireEnabledMinGridCellSize: true,
  );
  _validateDraftRanges(draft);
  return draft;
}

void _validateDraftRanges(SceneImportDraft draft) {
  _validateSceneRanges(draft);
  _validateBackgroundLayerRanges(draft.backgroundLayer);
  _validateContentLayerRanges(draft.layers);
}

void _validateNodeRanges(NodeSnapshot node, String field) {
  _validateCommonNodeRanges(node, field);

  switch (node) {
    case ImageNodeSnapshot image:
      _validateImageNodeRanges(image, field);
    case TextNodeSnapshot text:
      _validateTextNodeRanges(text, field);
    case StrokeNodeSnapshot stroke:
      _validateStrokeNodeRanges(stroke, field);
    case LineNodeSnapshot line:
      _validateLineNodeRanges(line, field);
    case RectNodeSnapshot rect:
      _validateRectNodeRanges(rect, field);
    case PathNodeSnapshot path:
      _validatePathNodeRanges(path, field);
  }
}

void _validateSceneRanges(SceneImportDraft draft) {
  _validateCoordinate(draft.camera.offset.dx, 'camera.offset.dx');
  _validateCoordinate(draft.camera.offset.dy, 'camera.offset.dy');
  _validateSizeUpper(
    draft.background.grid.cellSize,
    'background.grid.cellSize',
  );
  for (var i = 0; i < draft.palette.gridSizes.length; i++) {
    _validateSizeUpper(draft.palette.gridSizes[i], 'palette.gridSizes[$i]');
  }
}

void _validateBackgroundLayerRanges(
  BackgroundLayerSnapshotBacking backgroundLayer,
) {
  _validateLayerNodeRanges(
    backgroundLayer.nodes,
    layerField: 'backgroundLayer',
  );
}

void _validateContentLayerRanges(List<ContentLayerSnapshotBacking> layers) {
  for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
    _validateLayerNodeRanges(
      layers[layerIndex].nodes,
      layerField: 'layers[$layerIndex]',
    );
  }
}

void _validateLayerNodeRanges(
  List<NodeSnapshotBacking> nodes, {
  required String layerField,
}) {
  for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
    _validateNodeRanges(
      materializeNodeSnapshot(nodes[nodeIndex]),
      '$layerField.nodes[$nodeIndex]',
    );
  }
}

void _validateCommonNodeRanges(NodeSnapshot node, String field) {
  _validateTransformRanges(node.transform, '$field.transform');
  _validateInRange(
    node.hitPadding,
    min: 0,
    max: sceneHitPaddingMax,
    path: '$field.hitPadding',
  );
}

void _validateImageNodeRanges(ImageNodeSnapshot image, String field) {
  _validateSize(image.size.width, '$field.size.w');
  _validateSize(image.size.height, '$field.size.h');
  final naturalSize = image.naturalSize;
  if (naturalSize == null) return;
  _validateSize(naturalSize.width, '$field.naturalSize.w');
  _validateSize(naturalSize.height, '$field.naturalSize.h');
}

void _validateTextNodeRanges(TextNodeSnapshot text, String field) {
  _validateInRange(
    text.fontSize,
    min: 0,
    max: sceneSizeMax,
    path: '$field.fontSize',
  );
  _validateOptionalNodeSize(text.maxWidth, '$field.maxWidth');
  _validateOptionalNodeSize(text.lineHeight, '$field.lineHeight');
  final derivedBounds = TextLayoutRequest.forSnapshot(text).measure();
  _validateSize(derivedBounds.width, '$field.derivedBounds.w');
  _validateSize(derivedBounds.height, '$field.derivedBounds.h');
}

void _validateStrokeNodeRanges(StrokeNodeSnapshot stroke, String field) {
  _validateInRange(
    stroke.thickness,
    min: 0,
    max: sceneThicknessMax,
    path: '$field.thickness',
  );
  for (var i = 0; i < stroke.points.length; i++) {
    _validateCoordinate(stroke.points[i].dx, '$field.points[$i].x');
    _validateCoordinate(stroke.points[i].dy, '$field.points[$i].y');
  }
}

void _validateLineNodeRanges(LineNodeSnapshot line, String field) {
  _validateInRange(
    line.thickness,
    min: 0,
    max: sceneThicknessMax,
    path: '$field.thickness',
  );
  _validateCoordinate(line.start.dx, '$field.start.x');
  _validateCoordinate(line.start.dy, '$field.start.y');
  _validateCoordinate(line.end.dx, '$field.end.x');
  _validateCoordinate(line.end.dy, '$field.end.y');
}

void _validateRectNodeRanges(RectNodeSnapshot rect, String field) {
  _validateSize(rect.size.width, '$field.size.w');
  _validateSize(rect.size.height, '$field.size.h');
  _validateInRange(
    rect.strokeWidth,
    min: 0,
    max: sceneThicknessMax,
    path: '$field.strokeWidth',
  );
}

void _validatePathNodeRanges(PathNodeSnapshot path, String field) {
  _validateInRange(
    path.strokeWidth,
    min: 0,
    max: sceneThicknessMax,
    path: '$field.strokeWidth',
  );
}

void _validateOptionalNodeSize(double? value, String path) {
  if (value == null) return;
  _validateInRange(value, min: 0, max: sceneSizeMax, path: path);
}

void _validateTransformRanges(Transform2D transform, String path) {
  _validateCoordinate(transform.tx, '$path.tx');
  _validateCoordinate(transform.ty, '$path.ty');

  final scaleX = math.sqrt(
    transform.a * transform.a + transform.b * transform.b,
  );
  final scaleY = math.sqrt(
    transform.c * transform.c + transform.d * transform.d,
  );
  _validateInRange(
    scaleX,
    min: sceneScaleMin,
    max: sceneScaleMax,
    path: '$path.scaleX',
  );
  _validateInRange(
    scaleY,
    min: sceneScaleMin,
    max: sceneScaleMax,
    path: '$path.scaleY',
  );
}

void _validateCoordinate(double value, String path) {
  _validateInRange(value, min: sceneCoordMin, max: sceneCoordMax, path: path);
}

void _validateSize(double value, String path) {
  _validateInRange(value, min: 0, max: sceneSizeMax, path: path);
}

void _validateSizeUpper(double value, String path) {
  _validateInRange(value, min: 0, max: sceneSizeMax, path: path);
}

void _validateInRange(
  double value, {
  required double min,
  required double max,
  required String path,
}) {
  if (value >= min && value <= max) return;
  throw SceneDataException.outOfRange(
    path: path,
    min: min,
    max: max,
    source: value,
  );
}

Never _snapshotValidationError({
  required Object? value,
  required String field,
  required String message,
}) {
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: field,
    message: 'Field $field $message',
    source: value,
  );
}

Never _sceneValidationError({
  required Object? value,
  required String field,
  required String message,
}) {
  throw SceneDataException(
    code: SceneDataErrorCode.invalidValue,
    path: field,
    message: 'Field $field $message',
    source: value,
  );
}
