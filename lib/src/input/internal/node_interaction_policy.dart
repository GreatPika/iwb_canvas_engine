import '../../core/nodes.dart';
import '../../core/scene.dart';

/// Returns whether [node] is interactive for selection in [layer].
bool isNodeInteractiveForSelection(
  SceneNode node,
  Layer layer, {
  required bool onlySelectable,
}) {
  if (layer.isBackground) return false;
  if (!node.isVisible) return false;
  if (onlySelectable && !node.isSelectable) return false;
  return true;
}

/// Returns whether [node] can be deleted from [layer].
bool isNodeDeletableInLayer(SceneNode node, Layer layer) {
  if (layer.isBackground) return false;
  return node.isDeletable;
}
