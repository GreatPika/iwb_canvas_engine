import '../node_spec.dart';
import 'node_spec_backing.dart';
import 'node_spec_boundary_impl.dart';

NodeSpec unsafeMaterializeNodeSpec(NodeSpecBacking backing) {
  return materializeNodeSpecForInternalUse(backing);
}

ImageNodeSpec unsafeMaterializeImageNodeSpec(ImageNodeSpecBacking backing) {
  return materializeNodeSpecForInternalUse(backing) as ImageNodeSpec;
}

TextNodeSpec unsafeMaterializeTextNodeSpec(TextNodeSpecBacking backing) {
  return materializeNodeSpecForInternalUse(backing) as TextNodeSpec;
}

StrokeNodeSpec unsafeMaterializeStrokeNodeSpec(StrokeNodeSpecBacking backing) {
  return materializeNodeSpecForInternalUse(backing) as StrokeNodeSpec;
}

LineNodeSpec unsafeMaterializeLineNodeSpec(LineNodeSpecBacking backing) {
  return materializeNodeSpecForInternalUse(backing) as LineNodeSpec;
}

RectNodeSpec unsafeMaterializeRectNodeSpec(RectNodeSpecBacking backing) {
  return materializeNodeSpecForInternalUse(backing) as RectNodeSpec;
}

PathNodeSpec unsafeMaterializePathNodeSpec(PathNodeSpecBacking backing) {
  return materializeNodeSpecForInternalUse(backing) as PathNodeSpec;
}
