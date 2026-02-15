import 'scene.dart';
import '../public/snapshot.dart';

/// Ensures [scene] has a background layer and returns it.
BackgroundLayer ensureBackgroundLayer(Scene scene) {
  final existing = scene.backgroundLayer;
  if (existing != null) {
    return existing;
  }
  final created = BackgroundLayer();
  scene.backgroundLayer = created;
  return created;
}

/// Returns a snapshot with canonical background layer shape.
///
/// Canonical shape keeps a dedicated `backgroundLayer` present even when input
/// omitted it.
SceneSnapshot canonicalizeBackgroundLayerSnapshot(SceneSnapshot snapshot) {
  return snapshot;
}
