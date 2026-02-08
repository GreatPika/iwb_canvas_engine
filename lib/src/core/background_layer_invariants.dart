import 'scene.dart';

/// Ensures background-layer invariants for [layers]:
/// - exactly one background layer,
/// - background layer at index 0.
///
/// Recoverable cases are canonicalized in place:
/// - if no background exists, one is inserted at index 0;
/// - if a single background exists but is misordered, it is moved to index 0
///   while preserving the relative order of non-background layers.
///
/// Unrecoverable case:
/// - if multiple background layers exist, [onMultipleBackgroundError] is
///   called with the background layer count and must throw.
void canonicalizeBackgroundLayerInvariants(
  List<Layer> layers, {
  required void Function(int backgroundCount) onMultipleBackgroundError,
}) {
  var backgroundCount = 0;
  var backgroundIndex = -1;
  for (var i = 0; i < layers.length; i++) {
    if (!layers[i].isBackground) continue;
    backgroundCount += 1;
    if (backgroundIndex == -1) {
      backgroundIndex = i;
    }
  }

  if (backgroundCount == 0) {
    layers.insert(0, Layer(isBackground: true));
    return;
  }
  if (backgroundCount > 1) {
    onMultipleBackgroundError(backgroundCount);
    throw StateError(
      'onMultipleBackgroundError must throw for backgroundCount='
      '$backgroundCount.',
    );
  }
  if (backgroundIndex == 0) return;

  final backgroundLayer = layers.removeAt(backgroundIndex);
  layers.insert(0, backgroundLayer);
}
