import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';

// INV:INV-ENG-SIGNALS-AFTER-COMMIT

void main() {
  SceneSnapshot twoRectSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            const RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
          ],
        ),
      ],
    );
  }

  test('signals are emitted only after successful commit', () async {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final emitted = <String>[];
    final sub = controller.signals.listen((signal) {
      emitted.add(signal.type);
    });
    addTearDown(sub.cancel);

    expect(
      () => controller.write<void>((writer) {
        writer.writeSignalEnqueue(type: 'will.rollback');
        throw StateError('fail');
      }),
      throwsStateError,
    );

    expect(emitted, isEmpty);

    controller.write<void>((writer) {
      writer.writeSignalEnqueue(type: 'committed');
    });
    await pumpEventQueue();

    expect(emitted, <String>['committed']);
  });

  test(
    'signals are delivered before repaint listeners for same commit',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final observed = <String>[];
      final sub = controller.signals.listen((_) {
        observed.add('signal');
      });
      addTearDown(sub.cancel);
      controller.addListener(() {
        observed.add('notify');
      });

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
        writer.writeSignalEnqueue(type: 'ordered');
      });
      await pumpEventQueue(times: 2);

      expect(observed, const <String>['signal', 'notify']);
    },
  );

  test(
    'signal listener observes committed state and can trigger follow-up write',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final observed =
          <({String type, int signalRevision, int storeRevision})>[];
      Object? nestedWriteError;
      final sub = controller.signals.listen((signal) {
        observed.add((
          type: signal.type,
          signalRevision: signal.commitRevision,
          storeRevision: controller.debugCommitRevision,
        ));
        if (signal.type == 'first') {
          try {
            controller.write<void>((writer) {
              writer.writeSignalEnqueue(type: 'second');
            });
          } catch (error) {
            nestedWriteError = error;
          }
        }
      });
      addTearDown(sub.cancel);

      controller.write<void>((writer) {
        writer.writeSignalEnqueue(type: 'first');
      });
      await pumpEventQueue(times: 2);

      expect(nestedWriteError, isNull);
      expect(
        observed.map((entry) => entry.type).toList(growable: false),
        const <String>['first', 'second'],
      );
      expect(
        observed
            .map((entry) => entry.signalRevision == entry.storeRevision)
            .toList(growable: false),
        everyElement(isTrue),
      );
      expect(controller.debugCommitRevision, 2);
    },
  );

  test(
    'change listener can trigger follow-up write without nested write error',
    () async {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      Object? nestedWriteError;
      var listenerCalls = 0;
      controller.addListener(() {
        listenerCalls = listenerCalls + 1;
        if (listenerCalls != 1) return;
        try {
          controller.write<void>((writer) {
            writer.writeSelectionReplace(const <NodeId>{'r2'});
          });
        } catch (error) {
          nestedWriteError = error;
        }
      });

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });
      await pumpEventQueue(times: 2);

      expect(nestedWriteError, isNull);
      expect(listenerCalls, 2);
      expect(controller.selectedNodeIds, const <NodeId>{'r2'});
    },
  );

  test('committed signals expose immutable payload and nodeIds', () async {
    // INV:INV-ENG-EVENTS-IMMUTABLE
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final emitted = <CommittedSignal>[];
    final sub = controller.signals.listen(emitted.add);
    addTearDown(sub.cancel);

    final nodeIds = <NodeId>['r1'];
    final payload = <String, Object?>{
      'nested': <String, Object?>{'value': 1},
      'items': <Object?>[1, 2],
    };
    controller.write<void>((writer) {
      writer.writeSignalEnqueue(
        type: 'immutable',
        nodeIds: nodeIds,
        payload: payload,
      );
    });

    nodeIds.add('r2');
    (payload['nested'] as Map<String, Object?>)['value'] = 99;
    (payload['items'] as List<Object?>).add(3);
    await pumpEventQueue();

    final signal = emitted.single;
    expect(signal.nodeIds, const <NodeId>['r1']);
    expect((signal.payload!['nested']! as Map<String, Object?>)['value'], 1);
    expect(signal.payload!['items'], const <Object?>[1, 2]);
    expect(() => signal.nodeIds.add('x'), throwsUnsupportedError);
    expect(
      () => (signal.payload!['nested'] as Map<Object?, Object?>)['value'] = 7,
      throwsUnsupportedError,
    );
  });
}
