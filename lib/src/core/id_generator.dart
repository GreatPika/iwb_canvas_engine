import '../contract/ids.dart' show LayerId, NodeId;
import '../contract/scene_contract_limits.dart'
    show kMaxLayerIdLength, kMaxNodeIdLength;
import '../core/nodes.dart';
import '../core/scene.dart';

/// Internal mutable owner of runtime generated-id allocation state.
class IdGeneratorState {
  IdGeneratorState({
    required this.sessionToken,
    required this.nextNodeCounter,
    required this.nextLayerCounter,
  });

  final String sessionToken;
  int nextNodeCounter;
  int nextLayerCounter;

  IdGeneratorState copy() {
    return IdGeneratorState(
      sessionToken: sessionToken,
      nextNodeCounter: nextNodeCounter,
      nextLayerCounter: nextLayerCounter,
    );
  }
}

IdGeneratorState createInitialIdGeneratorState(Scene scene) {
  return IdGeneratorState(
    sessionToken: _nextSessionToken(),
    nextNodeCounter: initialGeneratedNodeCounter(scene),
    nextLayerCounter: initialGeneratedLayerCounter(scene),
  );
}

IdGeneratorState createIdGeneratorStateForTesting({
  required int nextNodeCounter,
  required int nextLayerCounter,
  String sessionToken = 'test',
}) {
  return IdGeneratorState(
    sessionToken: sessionToken,
    nextNodeCounter: nextNodeCounter,
    nextLayerCounter: nextLayerCounter,
  );
}

void syncIdGeneratorStateWithSceneLowerBounds(
  IdGeneratorState state,
  Scene scene,
) {
  final minimumNodeCounter = initialGeneratedNodeCounter(scene);
  if (state.nextNodeCounter < minimumNodeCounter) {
    state.nextNodeCounter = minimumNodeCounter;
  }

  final minimumLayerCounter = initialGeneratedLayerCounter(scene);
  if (state.nextLayerCounter < minimumLayerCounter) {
    state.nextLayerCounter = minimumLayerCounter;
  }
}

NodeId generateNextNodeId(
  IdGeneratorState state, {
  required bool Function(NodeId id) containsNodeId,
}) {
  while (true) {
    final candidate = _generateNodeId(state.nextNodeCounter);
    state.nextNodeCounter = state.nextNodeCounter + 1;
    if (!containsNodeId(candidate)) {
      return candidate;
    }
  }
}

LayerId generateNextLayerId(
  IdGeneratorState state, {
  required bool Function(LayerId id) containsLayerId,
}) {
  while (true) {
    final candidate = _generateLayerId(state.nextLayerCounter);
    state.nextLayerCounter = state.nextLayerCounter + 1;
    if (!containsLayerId(candidate)) {
      return candidate;
    }
  }
}

int initialGeneratedNodeCounter(Scene scene) {
  var maxCounter = -1;
  final backgroundLayer = scene.backgroundLayer;
  final nodes = <SceneNode>[
    if (backgroundLayer != null) ...backgroundLayer.nodes,
    for (final layer in scene.layers) ...layer.nodes,
  ];
  for (final node in nodes) {
    final parsed = _tryParseLegacyGeneratedCounter(
      node.id,
      prefix: _nodeIdGeneratedPrefix,
      maxLength: kMaxNodeIdLength,
    );
    if (parsed == null || parsed < 0) {
      continue;
    }
    if (parsed > maxCounter) {
      maxCounter = parsed;
    }
  }
  return maxCounter + 1;
}

int initialGeneratedLayerCounter(Scene scene) {
  var maxCounter = -1;
  for (final layer in scene.layers) {
    final parsed = _tryParseLegacyGeneratedCounter(
      layer.id,
      prefix: _layerIdGeneratedPrefix,
      maxLength: kMaxLayerIdLength,
    );
    if (parsed == null || parsed < 0) {
      continue;
    }
    if (parsed > maxCounter) {
      maxCounter = parsed;
    }
  }
  return maxCounter + 1;
}

const String _nodeIdGeneratedPrefix = 'node-';
const String _layerIdGeneratedPrefix = 'layer-';

int _sessionTokenCounter = 0;

String _nextSessionToken() {
  final token = _sessionTokenCounter.toRadixString(36).padLeft(6, '0');
  _sessionTokenCounter = _sessionTokenCounter + 1;
  return token;
}

NodeId _generateNodeId(int counter) {
  return _formatLegacyGeneratedId(
    prefix: _nodeIdGeneratedPrefix,
    counter: counter,
    name: 'nodeIdCounter',
  );
}

LayerId _generateLayerId(int counter) {
  return _formatLegacyGeneratedId(
    prefix: _layerIdGeneratedPrefix,
    counter: counter,
    name: 'layerIdCounter',
  );
}

String _formatLegacyGeneratedId({
  required String prefix,
  required int counter,
  required String name,
}) {
  if (counter < 0) {
    throw ArgumentError.value(counter, name, 'Must be >= 0.');
  }
  return '$prefix$counter';
}

int? _tryParseLegacyGeneratedCounter(
  String value, {
  required String prefix,
  required int maxLength,
}) {
  if (value.length > maxLength || !value.startsWith(prefix)) {
    return null;
  }
  final rawCounter = value.substring(prefix.length);
  if (rawCounter.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(rawCounter);
  if (parsed == null || parsed < 0) {
    return null;
  }
  if (rawCounter != parsed.toString()) {
    return null;
  }
  return parsed;
}
