import 'validated/layer_id_value.dart';
import 'validated/node_id_value.dart';

/// Stable node identifier used across public and internal scene contracts.
typedef NodeId = String;

/// Stable content-layer identifier used across scene contracts.
typedef LayerId = String;

NodeId parseNodeId(String raw, {String name = 'nodeId'}) {
  return NodeIdValue.parse(raw, name: name).value;
}

LayerId parseLayerId(String raw, {String name = 'layerId'}) {
  return LayerIdValue.parse(raw, name: name).value;
}
