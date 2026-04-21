import 'scene.dart';

/// Ensures [scene] has a runtime background layer and returns it.
///
/// This helper is a local write-path utility. It materializes the dedicated
/// background layer on demand for mutable runtime code and does not synchronize
/// separate runtime/boundary policy models.
BackgroundLayer ensureBackgroundLayer(Scene scene) {
  final existing = scene.backgroundLayer;
  if (existing != null) {
    return existing;
  }
  final created = BackgroundLayer();
  scene.backgroundLayer = created;
  return created;
}
