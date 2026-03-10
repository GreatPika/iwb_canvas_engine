import 'dart:ui';

import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../core/scene_limits.dart';
import '../contract/validated/finite_offset_value.dart';
import '../contract/validated/font_family_value.dart';
import '../contract/validated/image_id_value.dart';
import '../contract/validated/instance_revision_value.dart';
import '../contract/validated/layer_id_value.dart';
import '../contract/validated/node_id_value.dart';
import '../contract/validated/non_negative_finite_double_value.dart';
import '../contract/validated/opacity_value.dart';
import '../contract/validated/positive_finite_double_value.dart';
import '../contract/validated/svg_path_data_value.dart';
import '../contract/validated/text_content_value.dart';
import '../contract/validated/validated_value_support.dart';
import '../core/text_layout.dart';
import '../contract/transform2d.dart';
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';
import 'scene_structural_limits.dart';
import 'scene_policy.dart';

part 'scene_builder_json_require.part.dart';
part 'scene_builder_decode_json.part.dart';
part 'scene_builder_scene_from_snapshot.part.dart';
part 'scene_builder_snapshot_from_scene.part.dart';

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
    throw SceneDataException.invalidJsonPayload(source: error);
  }
}

Scene sceneBuildFromDynamicJsonMap(Map<String, dynamic> rawJson) {
  return _guardBuild(rawJson, sceneBuildFromJsonMap);
}

SceneSnapshot sceneCanonicalizeAndValidateSnapshot(SceneSnapshot rawSnapshot) {
  return ScenePolicy.validateImportSnapshot(rawSnapshot);
}

Scene sceneCanonicalizeAndValidateScene(Scene rawScene) {
  return ScenePolicy.validateRuntimeScene(
    rawScene,
    snapshotFromScene: _snapshotFromScene,
    sceneFromSnapshot: (snapshot) => _sceneFromSnapshot(snapshot),
  );
}

Scene sceneValidateCore(Scene scene) {
  return ScenePolicy.validateEncodeScene(
    scene,
    snapshotFromScene: _snapshotFromScene,
    sceneFromSnapshot: (snapshot) => _sceneFromSnapshot(snapshot),
  );
}

T _guardBuild<T>(
  Map<String, dynamic> rawJson,
  T Function(Map<String, Object?> raw) build,
) {
  try {
    return build(Map<String, Object?>.from(rawJson));
  } on SceneDataException {
    rethrow;
  } on FormatException catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  } catch (error) {
    throw SceneDataException.invalidJsonPayload(source: error);
  }
}
