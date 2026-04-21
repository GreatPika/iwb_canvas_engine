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

typedef _IdFormatter<T extends String> =
    T Function({required String sessionToken, required int counter});

final _GeneratedIdAllocator<NodeId> _nodeIdAllocator =
    _GeneratedIdAllocator<NodeId>(
      counterOf: (state) => state.nextNodeCounter,
      setCounter: (state, value) => state.nextNodeCounter = value,
      formatId: _generateNodeId,
    );

final _GeneratedIdAllocator<LayerId> _layerIdAllocator =
    _GeneratedIdAllocator<LayerId>(
      counterOf: (state) => state.nextLayerCounter,
      setCounter: (state, value) => state.nextLayerCounter = value,
      formatId: _generateLayerId,
    );

NodeId generateNextNodeId(
  IdGeneratorState state, {
  required bool Function(NodeId id) containsNodeId,
}) {
  return _nodeIdAllocator.allocate(state, containsId: containsNodeId);
}

LayerId generateNextLayerId(
  IdGeneratorState state, {
  required bool Function(LayerId id) containsLayerId,
}) {
  return _layerIdAllocator.allocate(state, containsId: containsLayerId);
}

const String _nodeIdGeneratedPrefix = 'gen-n-';
const String _layerIdGeneratedPrefix = 'gen-l-';

int _sessionTokenCounter = 0;

class _GeneratedIdAllocator<T extends String> {
  const _GeneratedIdAllocator({
    required this.counterOf,
    required this.setCounter,
    required this.formatId,
  });

  final int Function(IdGeneratorState state) counterOf;
  final void Function(IdGeneratorState state, int value) setCounter;
  final _IdFormatter<T> formatId;

  T allocate(
    IdGeneratorState state, {
    required bool Function(T id) containsId,
  }) {
    while (true) {
      final candidate = formatId(
        sessionToken: state.sessionToken,
        counter: counterOf(state),
      );
      setCounter(state, counterOf(state) + 1);
      if (!containsId(candidate)) {
        return candidate;
      }
    }
  }
}

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
