import 'dart:ui';

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session_identity.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import '../../support/runtime_root_with_committed_document_seed.dart';

// Terminal composition consumes the raw read capture from the shared real-root
// harness; assertions stay with the sibling acceptance fixture.
TerminalEraserEntryRouteWork runTerminalEraserEntryRoute({
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

  return TerminalEraserEntryRouteWork(
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

EraserPreviewEntryRouteWork runEraserPreviewEntryRoute({
  required List<CanvasElementId> targetIds,
  int unrelatedElementCount = 0,
}) {
  final read = _runEraserReadRoute(
    targetIds: targetIds,
    unrelatedElementCount: unrelatedElementCount,
    terminal: false,
  );

  return EraserPreviewEntryRouteWork(
    root: read.root,
    facts: read.facts,
    storeWork: read.storeWork,
    routeEvents: read.routeEvents,
    frameHandleEnumerations: read.frameHandleEnumerations,
    projectionBuildDelta: read.projectionBuildDelta,
  );
}

// One nested boundary is needed to measure only read-to-entry work against the
// same root snapshot; splitting observers would weaken that route witness.
// ignore: halstead-volume, source-lines-of-code
_EraserReadRoute _runEraserReadRoute({
  required List<CanvasElementId> targetIds,
  required int unrelatedElementCount,
  required bool terminal,
}) {
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(targetIds, unrelatedElementCount),
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

List<CanvasElementId> terminalEraserTargetIds(int count) => [
  for (var index = 0; index < count; index += 1)
    CanvasElementId('target-$index'),
];

CanvasDocument _document(
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
              Offset(_targetIndex(id) * 20, 0),
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

int _targetIndex(CanvasElementId id) => switch (id.value) {
  'target-0' => 0,
  'target-1' => 1,
  'target-2' => 2,
  'target-3' => 3,
  _ => throw ArgumentError.value(id, 'id', 'Unsupported terminal target'),
};

final class TerminalEraserEntryRouteWork {
  const TerminalEraserEntryRouteWork({
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

final class EraserPreviewEntryRouteWork {
  const EraserPreviewEntryRouteWork({
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
