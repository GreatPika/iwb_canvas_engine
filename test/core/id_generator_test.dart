import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/id_generator.dart';

void main() {
  test('createInitialIdGeneratorState starts a fresh allocator session', () {
    final state = createInitialIdGeneratorState();

    expect(state.sessionToken, isNotEmpty);
    expect(state.nextNodeCounter, 1);
    expect(state.nextLayerCounter, 1);
  });

  test('generateNextNodeId and generateNextLayerId use collision barrier', () {
    final state = createIdGeneratorStateForTesting(
      nextNodeCounter: 2,
      nextLayerCounter: 5,
    );

    final nodeId = generateNextNodeId(
      state,
      containsNodeId: (id) => id == 'gen-n-test-2',
    );
    final layerId = generateNextLayerId(
      state,
      containsLayerId: (id) => id == 'gen-l-test-5',
    );

    expect(nodeId, 'gen-n-test-3');
    expect(layerId, 'gen-l-test-6');
    expect(state.nextNodeCounter, 4);
    expect(state.nextLayerCounter, 7);
  });

  test('copy preserves allocator state snapshot', () {
    final state = createIdGeneratorStateForTesting(
      sessionToken: 'session-fixed',
      nextNodeCounter: 4,
      nextLayerCounter: 7,
    );

    final copy = state.copy();

    expect(copy, isNot(same(state)));
    expect(copy.sessionToken, 'session-fixed');
    expect(copy.nextNodeCounter, 4);
    expect(copy.nextLayerCounter, 7);
  });

  test('generator rejects non-positive counters', () {
    final negativeNodeState = createIdGeneratorStateForTesting(
      nextNodeCounter: 0,
      nextLayerCounter: 1,
    );

    expect(
      () => generateNextNodeId(negativeNodeState, containsNodeId: (_) => false),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('generator rejects empty session token', () {
    final state = createIdGeneratorStateForTesting(
      sessionToken: '',
      nextNodeCounter: 1,
      nextLayerCounter: 1,
    );

    expect(
      () => generateNextNodeId(state, containsNodeId: (_) => false),
      throwsA(isA<ArgumentError>()),
    );
  });
}
