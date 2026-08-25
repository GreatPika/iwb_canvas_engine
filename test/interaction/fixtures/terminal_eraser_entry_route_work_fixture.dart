// This fixture keeps Store projection, adapter route, intent identity/order, and
// work observers on one captured trace; splitting for an import threshold would
// blur the owner evidence and make the route less readable.
// ignore_for_file: number-of-imports

import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session_identity.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import '../../support/runtime_root_with_committed_document_seed.dart';

// The assertions stay together as the terminal route's acceptance owner; each
// one reuses the same captured trace without duplicating its false-positive kills.
// ignore: halstead-volume, source-lines-of-code
void registerTerminalEraserEntryRouteWorkTest() {
  test('eraser preview keeps canonical ids without terminal Store work', () {
    final result = _runEraserPreviewEntryRoute(
      targetIds: _terminalEraserTargetIds(2),
    );
    addTearDown(result.dispose);

    expect(result.facts.erasedElementIds, _terminalEraserTargetIds(2));
    expect(result.facts.erasedEntries, isEmpty);
    expect(result.storeWork, isEmpty);
    expect(result.routeEvents, isEmpty);
    expect(result.frameHandleEnumerations, 0);
    expect(result.projectionBuildDelta, 0);
  });

  test(
    'terminal eraser carries a single exact hit without order comparisons',
    () {
      final result = _runTerminalEraserEntryRoute(
        targetIds: _terminalEraserTargetIds(1),
      );
      addTearDown(result.dispose);

      _expectCompleteTerminalRoute(result, _terminalEraserTargetIds(1));
      expect(result.exactHitIds, _terminalEraserTargetIds(1));
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
    final small = _runTerminalEraserEntryRoute(
      targetIds: _terminalEraserTargetIds(2),
    );
    final large = _runTerminalEraserEntryRoute(
      targetIds: _terminalEraserTargetIds(4),
    );
    addTearDown(small.dispose);
    addTearDown(large.dispose);

    _expectCompleteTerminalRoute(small, _terminalEraserTargetIds(2));
    _expectCompleteTerminalRoute(large, _terminalEraserTargetIds(4));
    expect(small.exactHitIds, _terminalEraserTargetIds(2).reversed.toList());
    expect(large.exactHitIds, _terminalEraserTargetIds(4).reversed.toList());
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
    final base = _runTerminalEraserEntryRoute(
      targetIds: _terminalEraserTargetIds(2),
    );
    final withUnrelated = _runTerminalEraserEntryRoute(
      targetIds: _terminalEraserTargetIds(2),
      unrelatedElementCount: 100,
    );
    addTearDown(base.dispose);
    addTearDown(withUnrelated.dispose);

    _expectCompleteTerminalRoute(base, _terminalEraserTargetIds(2));
    _expectCompleteTerminalRoute(withUnrelated, _terminalEraserTargetIds(2));
    expect(withUnrelated.storeWork, base.storeWork);
    expect(withUnrelated.routeKinds, base.routeKinds);
    expect(base.frameHandleEnumerations, 0);
    expect(withUnrelated.frameHandleEnumerations, 0);
    expect(base.projectionBuildDelta, 0);
    expect(withUnrelated.projectionBuildDelta, 0);
  });
}

void _expectCompleteTerminalRoute(
  _TerminalEraserEntryRouteWork result,
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

_TerminalEraserEntryRouteWork _runTerminalEraserEntryRoute({
  required List<CanvasElementId> targetIds,
  int unrelatedElementCount = 0,
}) {
  final read = _runEraserReadRoute(
    targetIds: targetIds,
    unrelatedElementCount: unrelatedElementCount,
    terminal: true,
  );
  final intent = const EraserMachine()
      .terminal(
        sessionId: const PointerSessionId(1),
        pointerToken: const PointerSessionToken(2),
        eraser: PointerEraserCapture(
          points: const [Offset.zero, Offset(60, 0)],
          thickness: 2,
        ),
        facts: read.facts,
      )
      .intent;

  return _TerminalEraserEntryRouteWork(
    root: read.root,
    storeWork: read.storeWork,
    routeEvents: read.routeEvents,
    storeEntries: read.storeEntries,
    factEntries: read.facts.erasedEntries,
    intentEntries: intent?.erasedEntries,
    intentIds: intent?.erasedElementIds,
    frameHandleEnumerations: read.frameHandleEnumerations,
    projectionBuildDelta: read.projectionBuildDelta,
  );
}

_EraserPreviewEntryRouteWork _runEraserPreviewEntryRoute({
  required List<CanvasElementId> targetIds,
  int unrelatedElementCount = 0,
}) {
  final read = _runEraserReadRoute(
    targetIds: targetIds,
    unrelatedElementCount: unrelatedElementCount,
    terminal: false,
  );

  return _EraserPreviewEntryRouteWork(
    root: read.root,
    facts: read.facts,
    storeWork: read.storeWork,
    routeEvents: read.routeEvents,
    frameHandleEnumerations: read.frameHandleEnumerations,
    projectionBuildDelta: read.projectionBuildDelta,
  );
}

// One nested boundary measures read-to-entry work against the same root
// snapshot; splitting its observers would weaken that route witness.
// ignore: halstead-volume, source-lines-of-code
_EraserReadRoute _runEraserReadRoute({
  required List<CanvasElementId> targetIds,
  required int unrelatedElementCount,
  required bool terminal,
}) {
  final root = runtimeRootWithCommittedDocumentSeed(
    _terminalEraserDocument(targetIds, unrelatedElementCount),
  );
  final storeWork = <DeletionProjectionWorkEvent, int>{};
  final routeEvents = <RuntimeEraserEntryRouteWorkEvent>[];
  List<DeletionEntryFacts>? storeEntries;
  var frameHandleEnumerations = 0;
  final beforeProjectionBuilds = root.projectionBuildCount;
  final facts = DocumentStoreKernel.observeDeletionProjectionWork(
    (event) => storeWork.update(event, (count) => count + 1, ifAbsent: () => 1),
    () => DocumentStoreKernel.observeDeletionEntryProjection(
      (entries) => storeEntries = entries,
      () => RuntimeRoot.observeFrameHandleEnumerations(
        () => frameHandleEnumerations += 1,
        () => RuntimeInteractionReadAdapter.observeEraserEntryRouteWork(
          routeEvents.add,
          () => terminal
              ? root.interactionReadPort.eraserTerminalFacts(
                  EraserReadRequest(
                    corridorPoints: const [Offset.zero, Offset(60, 0)],
                    eraserThickness: 2,
                  ),
                )
              : root.interactionReadPort.eraserPreviewFacts(
                  EraserReadRequest(
                    corridorPoints: const [Offset.zero, Offset(60, 0)],
                    eraserThickness: 2,
                  ),
                ),
        ),
      ),
    ),
  );

  return _EraserReadRoute(
    root: root,
    facts: facts,
    storeWork: storeWork,
    routeEvents: routeEvents,
    storeEntries: storeEntries,
    frameHandleEnumerations: frameHandleEnumerations,
    projectionBuildDelta: root.projectionBuildCount - beforeProjectionBuilds,
  );
}

final class _EraserReadRoute {
  const _EraserReadRoute({
    required this.root,
    required this.facts,
    required this.storeWork,
    required this.routeEvents,
    required this.storeEntries,
    required this.frameHandleEnumerations,
    required this.projectionBuildDelta,
  });

  final RuntimeRoot root;
  final EraserReadFacts facts;
  final Map<DeletionProjectionWorkEvent, int> storeWork;
  final List<RuntimeEraserEntryRouteWorkEvent> routeEvents;
  final List<DeletionEntryFacts>? storeEntries;
  final int frameHandleEnumerations;
  final int projectionBuildDelta;
}

List<CanvasElementId> _terminalEraserTargetIds(int count) => [
  for (var index = 0; index < count; index += 1)
    CanvasElementId('target-$index'),
];

CanvasDocument _terminalEraserDocument(
  List<CanvasElementId> targetIds,
  int unrelatedElementCount,
) => CanvasDocument(
  layers: [
    CanvasLayer(
      id: CanvasLayerId('layer-a'),
      elements: [
        for (final id in targetIds)
          CanvasRectElement(
            id: id,
            transform: CanvasTransform.translation(
              Offset(_terminalTargetIndex(id) * 20, 0),
            ),
            size: const Size(10, 10),
          ),
        for (var index = 0; index < unrelatedElementCount; index += 1)
          CanvasRectElement(
            id: CanvasElementId('unrelated-$index'),
            transform: CanvasTransform.translation(
              Offset(1000 + index * 20, 0),
            ),
            size: const Size(10, 10),
          ),
      ],
    ),
  ],
);

int _terminalTargetIndex(CanvasElementId id) => switch (id.value) {
  'target-0' => 0,
  'target-1' => 1,
  'target-2' => 2,
  'target-3' => 3,
  _ => throw ArgumentError.value(id, 'id', 'Unsupported terminal target'),
};

final class _TerminalEraserEntryRouteWork {
  const _TerminalEraserEntryRouteWork({
    required this.root,
    required this.storeWork,
    required this.routeEvents,
    required this.storeEntries,
    required this.factEntries,
    required this.intentEntries,
    required this.intentIds,
    required this.frameHandleEnumerations,
    required this.projectionBuildDelta,
  });

  final RuntimeRoot root;
  final Map<DeletionProjectionWorkEvent, int> storeWork;
  final List<RuntimeEraserEntryRouteWorkEvent> routeEvents;
  final List<DeletionEntryFacts>? storeEntries;
  final List<DeletionEntryFacts> factEntries;
  final List<DeletionEntryFacts>? intentEntries;
  final List<CanvasElementId>? intentIds;
  final int frameHandleEnumerations;
  final int projectionBuildDelta;

  void dispose() => root.dispose();

  List<RuntimeEraserEntryRouteWorkKind> get routeKinds => [
    for (final event in routeEvents) event.kind,
  ];
  List<CanvasElementId>? get exactHitIds => routeEvents
      .where(
        (event) =>
            event.kind == RuntimeEraserEntryRouteWorkKind.exactHitIdsReady,
      )
      .map((event) => event.exactHitIds)
      .firstOrNull;
}

final class _EraserPreviewEntryRouteWork {
  const _EraserPreviewEntryRouteWork({
    required this.root,
    required this.facts,
    required this.storeWork,
    required this.routeEvents,
    required this.frameHandleEnumerations,
    required this.projectionBuildDelta,
  });

  final RuntimeRoot root;
  final EraserReadFacts facts;
  final Map<DeletionProjectionWorkEvent, int> storeWork;
  final List<RuntimeEraserEntryRouteWorkEvent> routeEvents;
  final int frameHandleEnumerations;
  final int projectionBuildDelta;

  void dispose() => root.dispose();
}
