// Test bodies are named helpers so DCM metrics stay on each scenario; the
// assertions live in those helpers and DCM does not follow tear-offs.
// ignore_for_file: missing-test-assertion

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../../support/runtime_with_document.dart';

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

// The request and cancel snapshot are one public-route witness, so keeping
// their assertions together makes the Store-to-resolver contract readable.
// ignore: halstead-volume
void _selectionDeletionResolverCanCancelThePreparedSet() {
  final requests = <CanvasDeletionCommitRequest>[];
  final runtime = runtimeWithDocument(
    _document(),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (request) {
        requests.add(request);
        return CanvasDeletionDecision.cancel;
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
  expect(request.operation, CanvasDeletionOperation.deleteSelection);
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
  final runtime = runtimeWithDocument(_document());
  final actions = <CanvasActionCommitted>[];
  final subscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    runtime.dispose();
  });

  runtime.selection.selectAll(onlySelectable: false);
  final before = runtime.state.value;

  runtime.selection.moveSelection(const Offset(3, 4), timestampMs: 11);
  await Future<void>.delayed(Duration.zero);

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
      deletionCommitResolver: _acceptDeletionCommit,
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
      deletionCommitResolver: _acceptDeletionCommit,
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

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;
