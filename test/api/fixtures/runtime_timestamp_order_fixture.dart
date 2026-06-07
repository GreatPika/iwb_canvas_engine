import 'dart:async';
import 'dart:ui';
import "../../support/runtime_root_with_document.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('nullable and backwards action timestamp hints are monotonic', () async {
    final scenario = _TimestampScenario();
    addTearDown(scenario.dispose);

    await scenario.expectActionTimestampOrder();
    expect(scenario.actions, hasLength(3));
  });

  test('load and dispose do not create action timestamps', () async {
    final scenario = _TimestampScenario();
    addTearDown(scenario.dispose);

    await scenario.expectLoadAndDisposeSilence();
    expect(scenario.actions, isEmpty);
  });
}

final class _TimestampScenario {
  _TimestampScenario() {
    subscription = root.actions.listen(actions.add);
  }

  final RuntimeRoot root = runtimeRootWithDocument(
    _document(),
    config: const CanvasRuntimeConfig(),
  );
  final List<CanvasActionCommitted> actions = <CanvasActionCommitted>[];
  late final StreamSubscription<CanvasActionCommitted> subscription;
  bool didDispose = false;

  Future<void> expectActionTimestampOrder() async {
    _commitSelection(
      nextId: CanvasElementId('b'),
      intent: _marqueeIntent(nextId: CanvasElementId('b')),
    );
    _commitSelection(
      nextId: CanvasElementId('a'),
      intent: _marqueeIntent(nextId: CanvasElementId('a'), timestampHintMs: 7),
    );
    _commitSelection(
      nextId: CanvasElementId('b'),
      intent: _marqueeIntent(nextId: CanvasElementId('b'), timestampHintMs: 2),
    );
    await _flushActions();

    expect(actions.map((action) => action.timestampMs), [0, 7, 8]);
    expect(actions.map((action) => action.actionId.value), [
      'action-0',
      'action-1',
      'action-2',
    ]);
  }

  Future<void> expectLoadAndDisposeSilence() async {
    root.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(_document()));
    await _flushActions();
    expect(actions, isEmpty);

    await dispose();
    await _flushActions();
    expect(actions, isEmpty);
  }

  Future<void> dispose() async {
    if (didDispose) {
      return;
    }
    didDispose = true;
    await subscription.cancel();
    root.dispose();
  }

  void _commitSelection({
    required CanvasElementId nextId,
    required CommitActionIntent intent,
  }) {
    root.deliverCommitPlanForTesting(
      CommitPlan.replaceSelection(
        elementIds: [nextId],
        actionIntents: [intent],
      ),
      document: root.readDocument(),
    );
  }
}

SelectMarqueeActionIntent _marqueeIntent({
  required CanvasElementId nextId,
  int? timestampHintMs,
}) {
  return SelectMarqueeActionIntent(
    previousSelection: const [],
    nextSelection: [nextId],
    marqueeRectWorld: const Rect.fromLTRB(0, 0, 1, 1),
    timestampHintMs: timestampHintMs,
  );
}

Future<void> _flushActions() => Future<void>.delayed(Duration.zero);

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(1, 1)),
          CanvasRectElement(id: CanvasElementId('b'), size: const Size(1, 1)),
        ],
      ),
    ],
  );
}
