import 'scene.dart';

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
