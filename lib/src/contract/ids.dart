import 'validated/layer_id_value.dart';
import 'validated/node_id_value.dart';

/// Stable node identifier used across public and internal scene contracts.
typedef NodeId = String;

/// Stable content-layer identifier used across scene contracts.
typedef LayerId = String;

NodeId parseNodeId(String raw, {String name = 'nodeId'}) {
  return NodeIdValue.parse(raw, name: name).value;
}

NodeId generateNodeId(int seed) {
  return NodeIdValue.generate(seed).value;
}

bool isGeneratedNodeId(NodeId value) {
  return NodeIdValue.isGeneratedLegacyFormat(value);
}

int? tryParseGeneratedNodeIdSeed(NodeId value) {
  return NodeIdValue.tryParseGeneratedSeed(value);
}

LayerId parseLayerId(String raw, {String name = 'layerId'}) {
  return LayerIdValue.parse(raw, name: name).value;
}

LayerId generateLayerId(int seed) {
  return LayerIdValue.generate(seed).value;
}

bool isGeneratedLayerId(LayerId value) {
  return LayerIdValue.isGeneratedLegacyFormat(value);
}

int? tryParseGeneratedLayerIdSeed(LayerId value) {
  return LayerIdValue.tryParseGeneratedSeed(value);
}
