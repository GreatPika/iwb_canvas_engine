import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import 'terminal_eraser_entry_route_work_support.dart';

// The assertions stay together as the terminal route's acceptance owner; each
// one reuses the same captured trace without duplicating its false-positive kills.
// ignore: halstead-volume, source-lines-of-code
void registerTerminalEraserEntryRouteWorkTest() {
  test('eraser preview keeps canonical ids without terminal Store work', () {
    final result = runEraserPreviewEntryRoute(
      targetIds: terminalEraserTargetIds(2),
    );
    addTearDown(result.dispose);

    expect(result.facts.erasedElementIds, terminalEraserTargetIds(2));
    expect(result.facts.erasedEntries, isEmpty);
    expect(result.storeWork, isEmpty);
    expect(result.routeEvents, isEmpty);
    expect(result.frameHandleEnumerations, 0);
    expect(result.projectionBuildDelta, 0);
  });

  test(
    'terminal eraser carries a single exact hit without order comparisons',
    () {
      final result = runTerminalEraserEntryRoute(
        targetIds: terminalEraserTargetIds(1),
      );
      addTearDown(result.dispose);

      _expectCompleteTerminalRoute(result, terminalEraserTargetIds(1));
      expect(result.exactHitIds, terminalEraserTargetIds(1));
      expect(
        result.storeWork[DeletionProjectionWorkEvent.canonicalOrderComparison],
        isNull,
      );
      expect(
        result.storeWork[DeletionProjectionWorkEvent.arbitraryOrderComparison],
        isNull,
      );
    },
  );

  test('terminal eraser sorts real topmost-first multi-hit input at Store', () {
    final small = runTerminalEraserEntryRoute(
      targetIds: terminalEraserTargetIds(2),
    );
    final large = runTerminalEraserEntryRoute(
      targetIds: terminalEraserTargetIds(4),
    );
    addTearDown(small.dispose);
    addTearDown(large.dispose);

    _expectCompleteTerminalRoute(small, terminalEraserTargetIds(2));
    _expectCompleteTerminalRoute(large, terminalEraserTargetIds(4));
    expect(small.exactHitIds, terminalEraserTargetIds(2).reversed.toList());
    expect(large.exactHitIds, terminalEraserTargetIds(4).reversed.toList());
    expect(
      large.storeWork[DeletionProjectionWorkEvent.inputIdRead],
      2 * small.storeWork[DeletionProjectionWorkEvent.inputIdRead]!,
    );
    expect(
      large.storeWork[DeletionProjectionWorkEvent.arbitraryOrderComparison],
      inInclusiveRange(1, 8),
    );
  });

  test('terminal eraser read-to-intent work ignores unrelated elements', () {
    final base = runTerminalEraserEntryRoute(
      targetIds: terminalEraserTargetIds(2),
    );
    final withUnrelated = runTerminalEraserEntryRoute(
      targetIds: terminalEraserTargetIds(2),
      unrelatedElementCount: 100,
    );
    addTearDown(base.dispose);
    addTearDown(withUnrelated.dispose);

    _expectCompleteTerminalRoute(base, terminalEraserTargetIds(2));
    _expectCompleteTerminalRoute(withUnrelated, terminalEraserTargetIds(2));
    expect(withUnrelated.storeWork, base.storeWork);
    expect(withUnrelated.routeKinds, base.routeKinds);
    expect(base.frameHandleEnumerations, 0);
    expect(withUnrelated.frameHandleEnumerations, 0);
    expect(base.projectionBuildDelta, 0);
    expect(withUnrelated.projectionBuildDelta, 0);
  });
}

void main() => registerTerminalEraserEntryRouteWorkTest();

void _expectCompleteTerminalRoute(
  TerminalEraserEntryRouteWork result,
  List<CanvasElementId> expectedIds,
) {
  final storeEntries = result.storeEntries;
  final intentEntries = result.intentEntries;
  final intentIds = result.intentIds;
  if (storeEntries == null || intentEntries == null || intentIds == null) {
    fail('terminal route did not carry Store entries into its intent');
  }
  expect(result.routeKinds, [
    RuntimeEraserEntryRouteWorkKind.terminalReadStarted,
    RuntimeEraserEntryRouteWorkKind.exactHitIdsReady,
    RuntimeEraserEntryRouteWorkKind.entriesReady,
  ]);
  expect(identical(storeEntries, result.factEntries), isTrue);
  expect(identical(result.factEntries, intentEntries), isTrue);
  expect(intentIds, expectedIds);
  expect(result.factEntries.map((entry) => entry.id), expectedIds);
  for (var index = 0; index < expectedIds.length; index += 1) {
    expect(intentEntries[index].element, same(storeEntries[index].element));
  }
}
