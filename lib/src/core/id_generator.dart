import '../contract/ids.dart' show LayerId, NodeId;

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

IdGeneratorState createInitialIdGeneratorState() {
  return IdGeneratorState(
    sessionToken: _nextSessionToken(),
    nextNodeCounter: 1,
    nextLayerCounter: 1,
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

NodeId generateNextNodeId(
  IdGeneratorState state, {
  required bool Function(NodeId id) containsNodeId,
}) {
  while (true) {
    final candidate = _generateNodeId(
      sessionToken: state.sessionToken,
      counter: state.nextNodeCounter,
    );
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
    final candidate = _generateLayerId(
      sessionToken: state.sessionToken,
      counter: state.nextLayerCounter,
    );
    state.nextLayerCounter = state.nextLayerCounter + 1;
    if (!containsLayerId(candidate)) {
      return candidate;
    }
  }
}

const String _nodeIdGeneratedPrefix = 'gen-n-';
const String _layerIdGeneratedPrefix = 'gen-l-';

int _sessionTokenCounter = 0;

String _nextSessionToken() {
  final token = _sessionTokenCounter.toRadixString(36).padLeft(6, '0');
  _sessionTokenCounter = _sessionTokenCounter + 1;
  return token;
}

NodeId _generateNodeId({required String sessionToken, required int counter}) {
  return _formatLegacyGeneratedId(
    prefix: _nodeIdGeneratedPrefix,
    sessionToken: sessionToken,
    counter: counter,
    name: 'nodeIdCounter',
  );
}

LayerId _generateLayerId({required String sessionToken, required int counter}) {
  return _formatLegacyGeneratedId(
    prefix: _layerIdGeneratedPrefix,
    sessionToken: sessionToken,
    counter: counter,
    name: 'layerIdCounter',
  );
}

String _formatLegacyGeneratedId({
  required String prefix,
  required String sessionToken,
  required int counter,
  required String name,
}) {
  if (sessionToken.isEmpty) {
    throw ArgumentError.value(
      sessionToken,
      'sessionToken',
      'Must not be empty.',
    );
  }
  if (counter < 1) {
    throw ArgumentError.value(counter, name, 'Must be >= 1.');
  }
  return '$prefix$sessionToken-${counter.toRadixString(36)}';
}
