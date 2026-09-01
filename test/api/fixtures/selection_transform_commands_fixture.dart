// Test bodies are named helpers so DCM metrics stay on each scenario; the
// assertions live in those helpers and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/runtime/selection_transform_facts_reader.dart';
import '../../support/runtime_with_document.dart';
import '../../support/accept_commit.dart';

final _moveTransform = CanvasTransform.translation(const Offset(3, 4));

void main() {
  test(
    'move validates delta and moves only eligible selected elements',
    _moveValidatesDeltaAndMovesOnlyEligibleSelectedElements,
  );

  test(
    'rotate and flip use selection center pivot and document order actions',
    _rotateAndFlipUseSelectionCenterPivotAndDocumentOrderActions,
  );
  test(
    'unified rotation and reflection requests retain qualified facts once',
    _unifiedTransformRequestsRetainFactsAndLeaseOrder,
  );
  test(
    'rotation and reflection rejection paths leave committed state unchanged',
    _transformRejectionsLeaveCommittedStateUnchanged,
  );
  test(
    'ineligible transform commands remain resolver silent',
    _ineligibleTransformCommandsStayResolverSilent,
  );
  test(
    'accepted move aborts its lease when preparation overflows',
    _acceptedMoveOverflowAbortsLease,
  );

  test(
    'delete selection prunes removed ids and stays silent for no-op',
    _deleteSelectionPrunesRemovedIdsAndStaysSilentForNoop,
  );
  test(
    'all-or-none selection deletion rejects a mixed selection',
    _allOrNoneSelectionDeletionRejectsMixedSelection,
  );
  test(
    'locked content remains deletable under all-or-none selection deletion',
    _lockedContentRemainsDeletableUnderAllOrNone,
  );
  test(
    'selection deletion re-reads current deletion facts',
    _selectionDeletionRereadsCurrentFacts,
  );
  test(
    'selection deletion presents the full Store entry set before cancellation',
    _selectionDeletionResolverCanCancelThePreparedSet,
  );
}

void _acceptedMoveOverflowAbortsLease() {
  final lease = _TransformLease();
  var calls = 0;
  final runtime = runtimeWithDocument(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('l'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('a'),
              size: const Size(1, 1),
              transform: CanvasTransform.translation(const Offset(10000000, 0)),
            ),
          ],
        ),
      ],
    ),
    config: CanvasRuntimeConfig(
      commitResolver: (_) {
        calls += 1;
        return CanvasMoveCommitAccept(delta: const Offset(1, 0), lease: lease);
      },
    ),
  );
  addTearDown(runtime.dispose);
  runtime.selection.setSelection([CanvasElementId('a')]);
  final before = runtime.state.value;
  expect(
    () => runtime.selection.moveSelection(const Offset(1, 0)),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        CanvasDataErrorCode.fieldMustBeInRange,
      ),
    ),
  );
  expect(calls, 1);
  expect(lease.abortedCalls, 1);
  expect(lease.committedCalls, 0);
  expect(runtime.state.value, before);
}

// The request and cancel snapshot are one public-route witness, so keeping
// their assertions together makes the Store-to-resolver contract readable.
// ignore: halstead-volume
void _selectionDeletionResolverCanCancelThePreparedSet() {
  final requests = <CanvasDeleteCommitRequest>[];
  final runtime = runtimeWithDocument(
    _document(),
    config: CanvasRuntimeConfig(
      commitResolver: (request) {
        requests.add(request as CanvasDeleteCommitRequest);
        return const CanvasCommitCancel();
      },
    ),
  );
  addTearDown(runtime.dispose);
  runtime.selection.setSelection([
    CanvasElementId('rect-b'),
    CanvasElementId('rect-a'),
  ]);
  final before = runtime.state.value;

  runtime.selection.deleteSelection();

  expect(requests, hasLength(1));
  final request = requests.single;
  expect(request.entries.map((entry) => entry.element.id), [
    CanvasElementId('rect-a'),
    CanvasElementId('rect-b'),
  ]);
  expect(request.entries[0].elementIndex, 0);
  expect(request.entries[1].elementIndex, 2);
  expect(runtime.state.value, before);
}

// The scenario keeps eligibility, transform math, validation, and action shape
// together because they are one public move command contract.
// ignore: halstead-volume, source-lines-of-code
Future<void> _moveValidatesDeltaAndMovesOnlyEligibleSelectedElements() async {
  final preparedWork = <PreparedInteractionApplyWorkEvent>[];
  final runtime = runtimeWithDocument(
    _document(),
    config: CanvasRuntimeConfig(
      commitResolver: (request) {
        expect(request, isA<CanvasMoveCommitRequest>());
        expect(
          preparedWork.where(
            (event) => event == PreparedInteractionApplyWorkEvent.prepared,
          ),
          isEmpty,
        );
        final move = request as CanvasMoveCommitRequest;
        return CanvasMoveCommitAccept(
          delta: move.proposedDelta,
          lease: testAcceptingCommitLease,
        );
      },
    ),
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });

  runtime.selection.selectAll(onlySelectable: false);
  final before = runtime.state.value;

  CommitApplier.observePreparedInteractionWork(
    preparedWork.add,
    () => runtime.selection.moveSelection(const Offset(3, 4), timestampMs: 11),
  );
  await Future<void>.delayed(Duration.zero);

  expect(
    preparedWork.where(
      (event) => event == PreparedInteractionApplyWorkEvent.prepared,
    ),
    hasLength(1),
  );
  expect(
    preparedWork.where(
      (event) => event == PreparedInteractionApplyWorkEvent.consumed,
    ),
    hasLength(1),
  );

  expect(runtime.state.value.revisions.document, before.revisions.document + 1);
  _expectTransformClose(_element(runtime, 'rect-a').transform, _moveTransform);
  _expectTransformClose(
    _element(runtime, 'rect-b').transform,
    CanvasTransform.translation(const Offset(13, 4)),
  );
  expect(_element(runtime, 'locked-a').transform, CanvasTransform.identity);
  _expectTransformClose(
    _element(runtime, 'hidden-a').transform,
    _moveTransform,
  );
  _expectTransformClose(
    _element(runtime, 'not-selectable-a').transform,
    CanvasTransform.translation(const Offset(-7, 4)),
  );
  _expectTransformClose(
    _element(runtime, 'not-deletable-a').transform,
    _moveTransform,
  );
  _expectTransformAction(
    actions.single,
    type: CanvasActionType.moveSelection,
    ids: [
      CanvasElementId('rect-a'),
      CanvasElementId('rect-b'),
      CanvasElementId('hidden-a'),
      CanvasElementId('not-selectable-a'),
      CanvasElementId('not-deletable-a'),
    ],
    operation: CanvasTransformOperation.move,
    transform: _moveTransform,
    timestampMs: 11,
  );

  runtime.selection.moveSelection(Offset.zero);
  await Future<void>.delayed(Duration.zero);
  expect(actions, hasLength(1));
  expect(
    () => runtime.selection.moveSelection(const Offset(double.nan, 0)),
    throwsA(isA<CanvasDataException>()),
  );
}

// Pivot math and follow-up flip are checked together so the test proves one
// center-derived transform command contract rather than disconnected facts.
// ignore: halstead-volume
Future<void>
_rotateAndFlipUseSelectionCenterPivotAndDocumentOrderActions() async {
  final runtime = runtimeWithDocument(_document());
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });
  runtime.selection.selectAll(onlySelectable: false);

  final rotation = _aroundPivot(
    CanvasTransform.rotationDegrees(90),
    const Offset(0, 0),
  );
  runtime.selection.rotateSelectionClockwise(timestampMs: 12);
  await Future<void>.delayed(Duration.zero);
  _expectTransformAction(
    actions.single,
    type: CanvasActionType.transformSelection,
    ids: [
      CanvasElementId('rect-a'),
      CanvasElementId('rect-b'),
      CanvasElementId('hidden-a'),
      CanvasElementId('not-selectable-a'),
      CanvasElementId('not-deletable-a'),
    ],
    operation: CanvasTransformOperation.rotateClockwise,
    transform: rotation,
    pivotWorld: const Offset(0, 0),
    timestampMs: 12,
  );
  _expectTransformClose(_element(runtime, 'rect-a').transform, rotation);

  runtime.selection.flipSelectionHorizontal(timestampMs: 13);
  await Future<void>.delayed(Duration.zero);
  _expectFlipAction(actions.last);
}

// One public command trace per operation keeps exact retained request facts,
// the Unit-8 read count, lease order, and resulting action mutually visible.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _unifiedTransformRequestsRetainFactsAndLeaseOrder() async {
  final cases = <_TransformRequestCase>[
    _TransformRequestCase.rotate(
      CanvasTransformOperation.rotateClockwise,
      (selection) => selection.rotateSelectionClockwise(timestampMs: 31),
      CanvasTransform.rotationDegrees(90),
      31,
    ),
    _TransformRequestCase.rotate(
      CanvasTransformOperation.rotateCounterClockwise,
      (selection) => selection.rotateSelectionCounterClockwise(timestampMs: 32),
      CanvasTransform.rotationDegrees(-90),
      32,
    ),
    _TransformRequestCase.reflect(
      CanvasTransformOperation.flipVertical,
      (selection) => selection.flipSelectionVertical(timestampMs: 33),
      CanvasTransform.scale(1, -1),
      33,
    ),
    _TransformRequestCase.reflect(
      CanvasTransformOperation.flipHorizontal,
      (selection) => selection.flipSelectionHorizontal(timestampMs: 34),
      CanvasTransform.scale(-1, 1),
      34,
    ),
  ];

  for (final testCase in cases) {
    CanvasCommitRequest? request;
    var resolverCalls = 0;
    final preparedWork = <PreparedInteractionApplyWorkEvent>[];
    final lease = _TransformLease();
    final runtime = runtimeWithDocument(
      _document(),
      config: CanvasRuntimeConfig(
        commitResolver: (candidate) {
          expect(
            preparedWork.where(
              (event) => event == PreparedInteractionApplyWorkEvent.prepared,
            ),
            hasLength(1),
          );
          resolverCalls += 1;
          request = candidate;
          return CanvasCommitAccept(lease: lease);
        },
      ),
    );
    final actions = <CanvasActionCommitted>[];
    final subscription = runtime.actions.listen(actions.add);
    try {
      runtime.selection.selectAll(onlySelectable: false);
      final before = runtime.state.value;
      lease.onCommitted = () => lease.snapshots.add((
        revision: runtime.state.value.revisions.document,
        actions: actions.length,
      ));
      final orderingWork = <SelectionTransformOrderingWorkEvent>[];
      CommitApplier.observePreparedInteractionWork(
        preparedWork.add,
        () => observeSelectionTransformOrderingWork(
          orderingWork.add,
          () => testCase.invoke(runtime.selection),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final received = request;
      if (received == null) fail('Expected a qualified transform request.');
      expect(resolverCalls, 1);
      expect(
        received.documentSummary,
        const CanvasDocumentSummary(
          elementCount: 6,
          layerCount: 1,
          resourceCount: 0,
        ),
      );
      expect(received.documentRevision, before.revisions.document);
      expect(received.selectedElementIdsBefore, _allSelectedIds);
      expect(
        () => received.selectedElementIdsBefore.clear(),
        throwsUnsupportedError,
      );
      _expectTransformRequest(testCase, received);
      final expectedTransform = _aroundPivot(
        testCase.localTransform,
        Offset.zero,
      );
      for (var index = 0; index < _movableSelectedIds.length; index += 1) {
        _expectTransformClose(
          _element(runtime, _movableSelectedIds[index].value).transform,
          expectedTransform.multiply(_movableInitialTransforms[index]),
        );
      }
      expect(orderingWork, hasLength(5));
      expect(
        orderingWork,
        everyElement(
          SelectionTransformOrderingWorkEvent.canonicalOrderComparison,
        ),
      );
      expect(actions, hasLength(1));
      _expectTransformAction(
        actions.single,
        type: CanvasActionType.transformSelection,
        ids: _movableSelectedIds,
        operation: testCase.operation,
        transform: expectedTransform,
        pivotWorld: Offset.zero,
        timestampMs: testCase.timestampMs,
      );
      expect(
        preparedWork.where(
          (event) => event == PreparedInteractionApplyWorkEvent.prepared,
        ),
        hasLength(1),
      );
      expect(
        preparedWork.where(
          (event) => event == PreparedInteractionApplyWorkEvent.consumed,
        ),
        hasLength(1),
      );
      expect(
        preparedWork.where(
          (event) => event == PreparedInteractionApplyWorkEvent.discarded,
        ),
        isEmpty,
      );
      expect(lease.snapshots, [
        (revision: before.revisions.document + 1, actions: 0),
      ]);
      expect(lease.committedCalls, 1);
      expect(lease.abortedCalls, 0);
    } finally {
      await subscription.cancel();
      runtime.dispose();
    }
  }
}

// Cancellation, callback failure, and a Move-only resolution are the three
// distinct rejection forms that must not reach Unit-8 installation.
// ignore: halstead-volume, source-lines-of-code
Future<void> _transformRejectionsLeaveCommittedStateUnchanged() async {
  final cancelledPreparedWork = <PreparedInteractionApplyWorkEvent>[];
  final cancelled = runtimeWithDocument(
    _document(),
    config: CanvasRuntimeConfig(
      commitResolver: (_) {
        expect(
          cancelledPreparedWork.where(
            (event) => event == PreparedInteractionApplyWorkEvent.prepared,
          ),
          hasLength(1),
        );
        return const CanvasCommitCancel();
      },
    ),
  );
  final cancelledActions = <CanvasActionCommitted>[];
  final cancelledSubscription = cancelled.actions.listen(cancelledActions.add);
  try {
    cancelled.selection.selectAll(onlySelectable: false);
    final before = cancelled.state.value;
    final beforeDocument = cancelled.readDocument();
    final beforeSelection = cancelled.selection.selectedElementIds;
    CommitApplier.observePreparedInteractionWork(
      cancelledPreparedWork.add,
      cancelled.selection.rotateSelectionClockwise,
    );
    await Future<void>.delayed(Duration.zero);
    expect(cancelled.state.value, before);
    expect(cancelled.readDocument(), same(beforeDocument));
    expect(cancelled.selection.selectedElementIds, beforeSelection);
    expect(cancelledActions, isEmpty);
    expect(
      cancelledPreparedWork.where(
        (event) => event == PreparedInteractionApplyWorkEvent.discarded,
      ),
      hasLength(1),
    );
    expect(
      cancelledPreparedWork.where(
        (event) => event == PreparedInteractionApplyWorkEvent.consumed,
      ),
      isEmpty,
    );
    expect(cancelled.generateElementId(), CanvasElementId('e0'));
  } finally {
    await cancelledSubscription.cancel();
    cancelled.dispose();
  }

  final failing = runtimeWithDocument(
    _document(),
    config: CanvasRuntimeConfig(
      commitResolver: (_) => throw StateError('transform resolver failure'),
    ),
  );
  final failingActions = <CanvasActionCommitted>[];
  final failingSubscription = failing.actions.listen(failingActions.add);
  try {
    failing.selection.selectAll(onlySelectable: false);
    final before = failing.state.value;
    final beforeDocument = failing.readDocument();
    final beforeSelection = failing.selection.selectedElementIds;
    failing.selection.rotateSelectionCounterClockwise();
    await Future<void>.delayed(Duration.zero);
    expect(failing.state.value, before);
    expect(failing.readDocument(), same(beforeDocument));
    expect(failing.selection.selectedElementIds, beforeSelection);
    expect(failingActions, isEmpty);
    expect(failing.generateElementId(), CanvasElementId('e0'));
  } finally {
    await failingSubscription.cancel();
    failing.dispose();
  }

  final lease = _TransformLease();
  final incompatible = runtimeWithDocument(
    _document(),
    config: CanvasRuntimeConfig(
      commitResolver: (_) =>
          CanvasMoveCommitAccept(delta: const Offset(1, 0), lease: lease),
    ),
  );
  final incompatibleActions = <CanvasActionCommitted>[];
  final incompatibleSubscription = incompatible.actions.listen(
    incompatibleActions.add,
  );
  try {
    incompatible.selection.selectAll(onlySelectable: false);
    final before = incompatible.state.value;
    final beforeDocument = incompatible.readDocument();
    final beforeSelection = incompatible.selection.selectedElementIds;
    incompatible.selection.flipSelectionVertical();
    await Future<void>.delayed(Duration.zero);
    expect(incompatible.state.value, before);
    expect(incompatible.readDocument(), same(beforeDocument));
    expect(incompatible.selection.selectedElementIds, beforeSelection);
    expect(incompatibleActions, isEmpty);
    expect(lease.abortedCalls, 1);
    expect(lease.committedCalls, 0);
    expect(incompatible.generateElementId(), CanvasElementId('e0'));
  } finally {
    await incompatibleSubscription.cancel();
    incompatible.dispose();
  }
}

Future<void> _ineligibleTransformCommandsStayResolverSilent() async {
  var resolverCalls = 0;
  final runtime = runtimeWithDocument(
    _document(),
    config: CanvasRuntimeConfig(
      commitResolver: (_) {
        resolverCalls += 1;
        return const CanvasCommitCancel();
      },
    ),
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  try {
    runtime.selection.setSelection([CanvasElementId('locked-a')]);
    final before = runtime.state.value;

    runtime.selection.rotateSelectionClockwise();
    runtime.selection.rotateSelectionCounterClockwise();
    runtime.selection.flipSelectionVertical();
    runtime.selection.flipSelectionHorizontal();
    await Future<void>.delayed(Duration.zero);

    expect(resolverCalls, 0);
    expect(runtime.state.value, before);
    expect(actions, isEmpty);
  } finally {
    await subscription.cancel();
    runtime.dispose();
  }
}

final _allSelectedIds = [
  CanvasElementId('rect-a'),
  CanvasElementId('locked-a'),
  CanvasElementId('rect-b'),
  CanvasElementId('hidden-a'),
  CanvasElementId('not-selectable-a'),
  CanvasElementId('not-deletable-a'),
];

final _movableSelectedIds = [
  CanvasElementId('rect-a'),
  CanvasElementId('rect-b'),
  CanvasElementId('hidden-a'),
  CanvasElementId('not-selectable-a'),
  CanvasElementId('not-deletable-a'),
];

final _movableInitialTransforms = [
  CanvasTransform.identity,
  CanvasTransform.translation(const Offset(10, 0)),
  CanvasTransform.identity,
  CanvasTransform.translation(const Offset(-10, 0)),
  CanvasTransform.identity,
];

// Keeping the complete immutable payload together makes a failed public
// confirmation easier to diagnose than duplicated partial assertions.
// ignore: halstead-volume, source-lines-of-code
void _expectTransformRequest(
  _TransformRequestCase testCase,
  CanvasCommitRequest request,
) {
  final expectedTransform = _aroundPivot(testCase.localTransform, Offset.zero);
  final affected = switch (request) {
    CanvasRotateCommitRequest(
      :final affectedElements,
      :final pivotWorld,
      :final worldTransform,
      :final operation,
    )
        when testCase.isRotation =>
      (
        affectedElements: affectedElements,
        pivotWorld: pivotWorld,
        worldTransform: worldTransform,
        operation: operation,
      ),
    CanvasReflectCommitRequest(
      :final affectedElements,
      :final pivotWorld,
      :final worldTransform,
      :final operation,
    )
        when !testCase.isRotation =>
      (
        affectedElements: affectedElements,
        pivotWorld: pivotWorld,
        worldTransform: worldTransform,
        operation: operation,
      ),
    _ => throw TestFailure('Wrong unified transform request subtype.'),
  };
  expect(affected.operation, testCase.operation);
  expect(affected.pivotWorld, Offset.zero);
  _expectTransformClose(affected.worldTransform, expectedTransform);
  expect(
    affected.affectedElements.map((element) => element.id),
    _movableSelectedIds,
  );
  for (var index = 0; index < _movableInitialTransforms.length; index += 1) {
    _expectTransformClose(
      affected.affectedElements[index].transform,
      _movableInitialTransforms[index],
    );
  }
  expect(() => affected.affectedElements.clear(), throwsUnsupportedError);
}

final class _TransformRequestCase {
  const _TransformRequestCase._({
    required this.operation,
    required this.invoke,
    required this.localTransform,
    required this.isRotation,
    required this.timestampMs,
  });

  factory _TransformRequestCase.rotate(
    CanvasTransformOperation operation,
    void Function(CanvasSelectionPort selection) invoke,
    CanvasTransform localTransform,
    int timestampMs,
  ) => _TransformRequestCase._(
    operation: operation,
    invoke: invoke,
    localTransform: localTransform,
    isRotation: true,
    timestampMs: timestampMs,
  );

  factory _TransformRequestCase.reflect(
    CanvasTransformOperation operation,
    void Function(CanvasSelectionPort selection) invoke,
    CanvasTransform localTransform,
    int timestampMs,
  ) => _TransformRequestCase._(
    operation: operation,
    invoke: invoke,
    localTransform: localTransform,
    isRotation: false,
    timestampMs: timestampMs,
  );

  final CanvasTransformOperation operation;
  final void Function(CanvasSelectionPort selection) invoke;
  final CanvasTransform localTransform;
  final bool isRotation;
  final int timestampMs;
}

final class _TransformLease implements CanvasCommitLease {
  void Function()? onCommitted;
  int committedCalls = 0;
  int abortedCalls = 0;
  final List<({int revision, int actions})> snapshots = [];

  @override
  void committed() {
    committedCalls += 1;
    onCommitted?.call();
  }

  @override
  void aborted() {
    abortedCalls += 1;
  }
}

// Deletion pruning and no-op silence are one observable command contract.
// ignore: halstead-volume
Future<void> _deleteSelectionPrunesRemovedIdsAndStaysSilentForNoop() async {
  final runtime = runtimeWithDocument(_document());
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });
  runtime.selection.setSelection([
    CanvasElementId('rect-a'),
    CanvasElementId('not-deletable-a'),
  ]);

  runtime.selection.deleteSelection(timestampMs: 14);
  await Future<void>.delayed(Duration.zero);

  expect(
    runtime.readDocument().layers.single.elements.map((element) => element.id),
    isNot(contains(CanvasElementId('rect-a'))),
  );
  expect(runtime.selection.selectedElementIds, {
    CanvasElementId('not-deletable-a'),
  });
  _expectDeleteAction(actions.single);

  runtime.selection.deleteSelection();
  await Future<void>.delayed(Duration.zero);
  expect(actions, hasLength(1));
}

Future<void> _allOrNoneSelectionDeletionRejectsMixedSelection() async {
  final allOrNoneRuntime = runtimeWithDocument(
    _document(),
    config: const CanvasRuntimeConfig(
      commitResolver: acceptCommit,
      selectionDeletePolicy: CanvasSelectionDeletePolicy.allOrNone,
    ),
  );
  final allOrNoneActions = <CanvasActionCommitted>[];
  final allOrNoneSubscription = allOrNoneRuntime.actions.listen(
    allOrNoneActions.add,
  );
  addTearDown(() async {
    await allOrNoneSubscription.cancel();
    allOrNoneRuntime.dispose();
  });

  allOrNoneRuntime.selection.setSelection([
    CanvasElementId('rect-a'),
    CanvasElementId('not-deletable-a'),
  ]);
  expect(
    allOrNoneRuntime.selection.deleteAvailability,
    const CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: false,
      hasAnySelectedElementDeletable: true,
    ),
  );
  allOrNoneRuntime.selection.deleteSelection();
  await Future<void>.delayed(Duration.zero);
  expect(allOrNoneActions, isEmpty);
  expect(_element(allOrNoneRuntime, 'rect-a'), isNotNull);
}

// Availability, command delivery, and committed document outcome form one
// public locked-element behavior, so keeping them together is clearer.
// ignore: halstead-volume
Future<void> _lockedContentRemainsDeletableUnderAllOrNone() async {
  final lockedRuntime = runtimeWithDocument(
    _document(),
    config: const CanvasRuntimeConfig(
      commitResolver: acceptCommit,
      selectionDeletePolicy: CanvasSelectionDeletePolicy.allOrNone,
    ),
  );
  final lockedActions = <CanvasActionCommitted>[];
  final lockedSubscription = lockedRuntime.actions.listen(lockedActions.add);
  addTearDown(() async {
    await lockedSubscription.cancel();
    lockedRuntime.dispose();
  });
  lockedRuntime.selection.setSelection([CanvasElementId('locked-a')]);
  expect(
    lockedRuntime.selection.deleteAvailability,
    const CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: true,
      hasAnySelectedElementDeletable: true,
    ),
  );
  lockedRuntime.selection.deleteSelection();
  await Future<void>.delayed(Duration.zero);
  expect(lockedActions.single.elementIds, [CanvasElementId('locked-a')]);
  expect(
    lockedRuntime.readDocument().layers.single.elements.map(
      (element) => element.id,
    ),
    isNot(contains(CanvasElementId('locked-a'))),
  );
}

Future<void> _selectionDeletionRereadsCurrentFacts() async {
  final freshFactsRuntime = runtimeWithDocument(_document());
  final freshFactsActions = <CanvasActionCommitted>[];
  final freshFactsSubscription = freshFactsRuntime.actions.listen(
    freshFactsActions.add,
  );
  addTearDown(() async {
    await freshFactsSubscription.cancel();
    freshFactsRuntime.dispose();
  });
  freshFactsRuntime.selection.setSelection([CanvasElementId('locked-a')]);
  expect(
    freshFactsRuntime.selection.deleteAvailability,
    const CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: true,
      hasAnySelectedElementDeletable: true,
    ),
  );
  freshFactsRuntime.edits.edit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('locked-a'),
        isDeletable: const CanvasFieldSet(false),
      ),
    );
  });
  freshFactsRuntime.selection.deleteSelection();
  await Future<void>.delayed(Duration.zero);
  expect(freshFactsActions, isEmpty);
  expect(_element(freshFactsRuntime, 'locked-a'), isNotNull);
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(2, 2),
          ),
          CanvasRectElement(
            id: CanvasElementId('locked-a'),
            size: const Size(2, 2),
            isLocked: true,
          ),
          CanvasRectElement(
            id: CanvasElementId('rect-b'),
            size: const Size(2, 2),
            transform: CanvasTransform.translation(const Offset(10, 0)),
          ),
          CanvasRectElement(
            id: CanvasElementId('hidden-a'),
            size: const Size(2, 2),
            isVisible: false,
          ),
          CanvasRectElement(
            id: CanvasElementId('not-selectable-a'),
            size: const Size(2, 2),
            isSelectable: false,
            transform: CanvasTransform.translation(const Offset(-10, 0)),
          ),
          CanvasRectElement(
            id: CanvasElementId('not-deletable-a'),
            size: const Size(2, 2),
            isDeletable: false,
          ),
        ],
      ),
    ],
  );
}

CanvasElement _element(CanvasRuntime runtime, String id) {
  return runtime.readDocument().layers.single.elements.singleWhere(
    (element) => element.id == CanvasElementId(id),
  );
}

void _expectFlipAction(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.transformSelection);
  expect(action.elementIds, [
    CanvasElementId('rect-a'),
    CanvasElementId('rect-b'),
    CanvasElementId('hidden-a'),
    CanvasElementId('not-selectable-a'),
    CanvasElementId('not-deletable-a'),
  ]);
  final payload = action.payload as CanvasTransformActionPayload;
  expect(payload.operation, CanvasTransformOperation.flipHorizontal);
  expect(payload.pivotWorld, isNotNull);
  expect(action.timestampMs, 13);
}

void _expectDeleteAction(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.deleteElements);
  expect(action.elementIds, [CanvasElementId('rect-a')]);
  expect((action.payload as CanvasDeleteActionPayload).removedElementIds, [
    CanvasElementId('rect-a'),
  ]);
  expect(action.timestampMs, 14);
}

// The helper names the full public transform-action payload shape; replacing
// the named fields with a wrapper would make these contract assertions harder
// to read without changing behavior.
// ignore: number-of-parameters
void _expectTransformAction(
  CanvasActionCommitted action, {
  required CanvasActionType type,
  required List<CanvasElementId> ids,
  required CanvasTransformOperation operation,
  required CanvasTransform transform,
  required int timestampMs,
  Offset? pivotWorld,
}) {
  expect(action.type, type);
  expect(action.elementIds, ids);
  expect(action.timestampMs, timestampMs);
  final payload = action.payload as CanvasTransformActionPayload;
  expect(payload.operation, operation);
  expect(payload.pivotWorld, pivotWorld);
  _expectTransformClose(payload.delta, transform);
}

CanvasTransform _aroundPivot(CanvasTransform transform, Offset pivot) {
  return CanvasTransform.translation(
    pivot,
  ).multiply(transform).multiply(CanvasTransform.translation(-pivot));
}

void _expectTransformClose(CanvasTransform actual, CanvasTransform expected) {
  expect(actual.a, closeTo(expected.a, 0.000000001));
  expect(actual.b, closeTo(expected.b, 0.000000001));
  expect(actual.c, closeTo(expected.c, 0.000000001));
  expect(actual.d, closeTo(expected.d, 0.000000001));
  expect(actual.tx, closeTo(expected.tx, 0.000000001));
  expect(actual.ty, closeTo(expected.ty, 0.000000001));
}
