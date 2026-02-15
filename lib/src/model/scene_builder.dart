import 'dart:math' as math;
import 'dart:ui';

import '../core/background_layer_invariants.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/scene_limits.dart';
import '../core/text_layout.dart';
import '../core/transform2d.dart';
import '../public/scene_data_exception.dart';
import '../public/snapshot.dart' hide NodeId;
import 'scene_value_validation.dart';

part 'scene_builder_json_require.part.dart';
part 'scene_builder_decode_json.part.dart';
part 'scene_builder_scene_from_snapshot.part.dart';
part 'scene_builder_snapshot_from_scene.part.dart';
part 'scene_builder_canonicalize_validate.part.dart';

Scene sceneBuildFromSnapshot(
  SceneSnapshot rawSnapshot, {
  int Function()? nextInstanceRevision,
}) {
  final canonicalSnapshot = sceneCanonicalizeAndValidateSnapshot(rawSnapshot);
  return _sceneFromSnapshot(
    canonicalSnapshot,
    nextInstanceRevision: nextInstanceRevision,
  );
}

Scene sceneBuildFromJsonMap(Map<String, Object?> rawJson) {
  try {
    final rawSnapshot = _decodeSnapshotFromJson(rawJson);
    return sceneBuildFromSnapshot(rawSnapshot);
  } on SceneDataException {
    rethrow;
  } catch (error) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidJson,
      message: 'Invalid scene JSON payload.',
      source: error,
    );
  }
}

SceneSnapshot sceneCanonicalizeAndValidateSnapshot(SceneSnapshot rawSnapshot) {
  final canonicalSnapshot = canonicalizeBackgroundLayerSnapshot(rawSnapshot);
  _validateStructuralInvariants(canonicalSnapshot);
  sceneValidateSnapshotValues(
    canonicalSnapshot,
    onError: _snapshotValidationError,
    requirePositiveGridCellSize: true,
  );
  _validateSnapshotRanges(canonicalSnapshot);
  return canonicalSnapshot;
}

Scene sceneCanonicalizeAndValidateScene(Scene rawScene) {
  sceneValidateSceneValues(
    rawScene,
    onError: _sceneValidationError,
    requirePositiveGridCellSize: true,
  );
  final rawSnapshot = _snapshotFromScene(rawScene);
  final canonicalSnapshot = sceneCanonicalizeAndValidateSnapshot(rawSnapshot);
  return _sceneFromSnapshot(canonicalSnapshot);
}

Scene sceneValidateCore(Scene scene) {
  return sceneCanonicalizeAndValidateScene(scene);
}
