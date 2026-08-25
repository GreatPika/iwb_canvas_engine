import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

// The three public-route witnesses share a single read-to-entry harness and
// exact Store oracle; keeping registration together avoids duplicate setup.
// ignore: halstead-volume, source-lines-of-code
void registerSelectionDeletionEntryRouteWorkTest() {
  test('selection delete retains canonical Store entries with linear work', () {
    final small = _runSelectionDelete(ids: _targetIds(2));
    final large = _runSelectionDelete(ids: _targetIds(4));

    _expectCompleteSelectionRoute(small, _targetIds(2));
    _expectCompleteSelectionRoute(large, _targetIds(4));
    expect(
      large.storeWork[DeletionProjectionWorkEvent.inputIdRead],
      2 * small.storeWork[DeletionProjectionWorkEvent.inputIdRead]!,
    );
    expect(
      large.storeWork[DeletionProjectionWorkEvent.canonicalOrderComparison],
      3,
    );
    expect(
      large.storeWork[DeletionProjectionWorkEvent.arbitraryOrderComparison],
      isNull,
    );
  });

  test('selection delete sorts only permuted Store input', () {
    final result = _runSelectionDelete(ids: _targetIds(4).reversed.toList());

    _expectCompleteSelectionRoute(result, _targetIds(4));
    expect(
      result.storeWork[DeletionProjectionWorkEvent.arbitraryOrderComparison],
      inInclusiveRange(1, 8),
    );
  });

  test('selection delete read-to-entry work ignores unrelated elements', () {
    final base = _runSelectionDelete(ids: _targetIds(2));
    final withUnrelated = _runSelectionDelete(
      ids: _targetIds(2),
      unrelatedElementCount: 100,
    );

    _expectCompleteSelectionRoute(base, _targetIds(2));
    _expectCompleteSelectionRoute(withUnrelated, _targetIds(2));
    expect(withUnrelated.storeWork, base.storeWork);
    expect(withUnrelated.routeKinds, base.routeKinds);
    expect(base.routeFrameHandleEnumerations, 0);
    expect(withUnrelated.routeFrameHandleEnumerations, 0);
    expect(base.projectionBuildDelta, 0);
    expect(withUnrelated.projectionBuildDelta, 0);
  });
}

void main() => registerSelectionDeletionEntryRouteWorkTest();

_SelectionDeleteRouteWork _runSelectionDelete({
  required List<CanvasElementId> ids,
  int unrelatedElementCount = 0,
}) {
  final document = _selectionDocument(unrelatedElementCount);
  final root = runtimeRootWithCommittedDocumentSeed(document);
  addTearDown(root.dispose);
  root.deliverCommitPlanForTesting(
    CommitPlan.replaceSelection(elementIds: ids),
    document: document,
  );

  final storeWork = <DeletionProjectionWorkEvent, int>{};
  final routeEvents = <RuntimeDeletionEntryRouteWorkEvent>[];
  List<DeletionEntryFacts>? storeEntries;
  final beforeProjectionBuilds = root.projectionBuildCount;
  DocumentStoreKernel.observeDeletionProjectionWork(
    (event) => storeWork.update(event, (count) => count + 1, ifAbsent: () => 1),
    () => DocumentStoreKernel.observeDeletionEntryProjection(
      (entries) => storeEntries = entries,
      () => RuntimeRoot.observeDeletionEntryRouteWork(
        routeEvents.add,
        () => root.deleteSelection(),
      ),
    ),
  );

  final routeEntries = routeEvents
      .singleWhere(
        (event) =>
            event.kind ==
            RuntimeDeletionEntryRouteWorkKind.selectionEntriesReady,
      )
      .entries;
  return _SelectionDeleteRouteWork(
    storeWork: storeWork,
    routeEvents: routeEvents,
    storeEntries: storeEntries,
    routeEntries: routeEntries,
    projectionBuildDelta: root.projectionBuildCount - beforeProjectionBuilds,
  );
}

// This one assertion keeps the route event, immutable container, and every
// Store entry identity together; splitting it would hide a partial handoff.
// ignore: halstead-volume
void _expectCompleteSelectionRoute(
  _SelectionDeleteRouteWork result,
  List<CanvasElementId> expectedIds,
) {
  expect(result.routeKinds, [
    RuntimeDeletionEntryRouteWorkKind.selectionReadStarted,
    RuntimeDeletionEntryRouteWorkKind.selectionEntriesReady,
  ]);
  expect(result.storeEntries, isNotNull);
  final storeEntries = result.storeEntries;
  if (storeEntries == null) {
    fail('Store did not publish the projected entries');
  }
  expect(result.routeEntries, hasLength(storeEntries.length));
  expect(result.routeEntries.map((entry) => entry.id), expectedIds);
  expect(
    result.routeEntries.map((entry) => entry.elementIndex),
    List<int>.generate(expectedIds.length, (index) => index),
  );
  for (var index = 0; index < expectedIds.length; index += 1) {
    expect(result.routeEntries[index], same(storeEntries[index]));
    expect(result.routeEntries[index].id, expectedIds[index]);
    expect(result.routeEntries[index].layerId, CanvasLayerId('targets'));
    expect(result.routeEntries[index].elementIndex, index);
    expect(
      result.routeEntries[index].orderToken,
      storeEntries[index].orderToken,
    );
    expect(
      result.routeEntries[index].element,
      same(storeEntries[index].element),
    );
  }
  expect(() => result.routeEntries.clear(), throwsUnsupportedError);
}

CanvasDocument _selectionDocument(int unrelatedElementCount) => CanvasDocument(
  layers: [
    CanvasLayer(
      id: CanvasLayerId('targets'),
      elements: [
        for (final id in _targetIds(4))
          CanvasRectElement(id: id, size: const Size(1, 1)),
      ],
    ),
    CanvasLayer(
      id: CanvasLayerId('unrelated'),
      elements: [
        for (var index = 0; index < unrelatedElementCount; index += 1)
          CanvasRectElement(
            id: CanvasElementId('unrelated-$index'),
            size: const Size(1, 1),
          ),
      ],
    ),
  ],
);

List<CanvasElementId> _targetIds(int count) => [
  for (var index = 0; index < count; index += 1)
    CanvasElementId('target-$index'),
];

final class _SelectionDeleteRouteWork {
  const _SelectionDeleteRouteWork({
    required this.storeWork,
    required this.routeEvents,
    required this.storeEntries,
    required this.routeEntries,
    required this.projectionBuildDelta,
  });

  final Map<DeletionProjectionWorkEvent, int> storeWork;
  final List<RuntimeDeletionEntryRouteWorkEvent> routeEvents;
  final List<DeletionEntryFacts>? storeEntries;
  final List<DeletionEntryFacts> routeEntries;
  final int projectionBuildDelta;

  List<RuntimeDeletionEntryRouteWorkKind> get routeKinds => [
    for (final event in routeEvents) event.kind,
  ];
  int get routeFrameHandleEnumerations => routeEvents
      .where(
        (event) =>
            event.kind ==
            RuntimeDeletionEntryRouteWorkKind.frameHandleEnumeration,
      )
      .length;
}
