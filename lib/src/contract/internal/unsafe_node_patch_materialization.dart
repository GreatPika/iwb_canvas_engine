import '../node_patch.dart';
import 'node_patch_backing.dart';
import 'node_patch_boundary_impl.dart';

CommonNodePatch unsafeMaterializeCommonNodePatch(
  CommonNodePatchBacking backing,
) {
  return materializeCommonNodePatchForInternalUse(backing);
}

NodePatch unsafeMaterializeNodePatch(NodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing);
}

ImageNodePatch unsafeMaterializeImageNodePatch(ImageNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as ImageNodePatch;
}

TextNodePatch unsafeMaterializeTextNodePatch(TextNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as TextNodePatch;
}

StrokeNodePatch unsafeMaterializeStrokeNodePatch(
  StrokeNodePatchBacking backing,
) {
  return materializeNodePatchForInternalUse(backing) as StrokeNodePatch;
}

LineNodePatch unsafeMaterializeLineNodePatch(LineNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as LineNodePatch;
}

RectNodePatch unsafeMaterializeRectNodePatch(RectNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as RectNodePatch;
}

PathNodePatch unsafeMaterializePathNodePatch(PathNodePatchBacking backing) {
  return materializeNodePatchForInternalUse(backing) as PathNodePatch;
}
