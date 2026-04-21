import 'document.dart';
import 'scene_builder.dart' as model;
import '../contract/scene_data_exception.dart';
import '../contract/snapshot.dart';

/// Public scene import and canonicalization gateway.
///
/// `SceneBuilder` exposes the supported non-controller import boundary for
/// callers that already hold either a typed [SceneSnapshot] or a parsed
/// JSON-compatible map.
abstract final class SceneBuilder {
  /// Validates and canonicalizes [raw], then returns a canonical snapshot.
  ///
  /// Use this entrypoint when the caller already has a typed snapshot and wants
  /// the same boundary validation and canonicalization guarantees used by the
  /// JSON import path, without going through a controller.
  ///
  /// Throws [SceneDataException] when [raw] violates the public scene boundary
  /// contract. Structural and nested boundary failures include
  /// [SceneDataException.path] when the import boundary can attribute the exact
  /// field location.
  static SceneSnapshot buildFromSnapshot(SceneSnapshot raw) {
    final scene = model.sceneBuildFromSnapshot(raw);
    return txnSceneToSnapshot(scene);
  }

  /// Validates and canonicalizes [rawJson], then returns a canonical snapshot.
  ///
  /// Use this entrypoint when the caller already has a parsed map and wants the
  /// same import boundary used by [decodeScene], without the JSON string parse
  /// step performed by [decodeSceneFromJson].
  ///
  /// Throws [SceneDataException] when [rawJson] violates scene schema or import
  /// validation requirements. Compare failures by
  /// [SceneDataException.code], [SceneDataException.path], and immutable
  /// [SceneDataException.details]; [SceneDataException.message] is derived
  /// user-facing text. Nested failures include [SceneDataException.path] when
  /// the import boundary knows the exact field location.
  static SceneSnapshot buildFromJson(Map<String, dynamic> rawJson) {
    final scene = model.sceneBuildFromDynamicJsonMap(rawJson);
    return txnSceneToSnapshot(scene);
  }
}
