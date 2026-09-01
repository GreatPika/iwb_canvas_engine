import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

// The package harness owns the outer test assertion; each fixture case returns
// its asynchronous public-route witness to that harness.
// ignore_for_file: missing-test-assertion

void main() {
  test(
    'selection delete publishes canonical exact entries and settles lease',
    () {
      return _verifySelectionDeleteAccept();
    },
  );
  test('direct background removal publishes nullable layer placement', () {
    return _verifyDirectBackgroundRemoval();
  });
  test('direct removal admits elements protected from selection deletion', () {
    return _verifyDirectNonDeletableRemoval();
  });
  test('delete rejected outcomes leave state and actions unchanged', () {
    return _verifyRejectedDeleteOutcomes();
  });
  test('selection policy and availability stay before resolver admission', () {
    return _verifyDeletePolicyAndAvailability();
  });
}

// This public request witness keeps its exact facts and terminal ordering in
// one assertion flow; splitting it would obscure the callback observation.
// ignore: halstead-volume, source-lines-of-code
Future<void> _verifySelectionDeleteAccept() async {
  CanvasDeleteCommitRequest? request;
  final lease = _DeleteLease();
  final root = _root((candidate) {
    request = candidate as CanvasDeleteCommitRequest;
    return CanvasCommitAccept(lease: lease);
  });
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });
  lease.onCommitted = () {
    lease.committedSnapshots.add((
      documentRevision: root.state.value.revisions.document,
      actionCount: actions.length,
    ));
  };
  root.selection.setSelection([CanvasElementId('b'), CanvasElementId('a')]);
  expect(
    root.selectionDeleteAvailability,
    const CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: true,
    ),
  );

  root.selection.deleteSelection(timestampMs: 17);
  await Future<void>.delayed(Duration.zero);

  final received = request;
  if (received == null) fail('Expected the unified resolver request.');
  expect(
    received.documentSummary,
    const CanvasDocumentSummary(
      elementCount: 4,
      layerCount: 2,
      resourceCount: 0,
    ),
  );
  expect(received.documentRevision, 0);
  expect(received.selectedElementIdsBefore, [
    CanvasElementId('b'),
    CanvasElementId('a'),
  ]);
  expect(received.entries.map((entry) => entry.element.id), [
    CanvasElementId('a'),
    CanvasElementId('b'),
  ]);
  expect(received.entries.map((entry) => entry.layerId), [
    CanvasLayerId('lower'),
    CanvasLayerId('upper'),
  ]);
  expect(received.entries.map((entry) => entry.elementIndex), [0, 0]);
  expect(actions.single.elementIds, [
    CanvasElementId('a'),
    CanvasElementId('b'),
  ]);
  expect(lease.committedSnapshots, [(documentRevision: 1, actionCount: 0)]);
  expect(lease.committedCalls, 1);
  expect(lease.abortedCalls, 0);
}

// Direct background placement and lease completion are one public witness.
// ignore: halstead-volume
Future<void> _verifyDirectBackgroundRemoval() async {
  CanvasDeleteCommitRequest? request;
  final lease = _DeleteLease();
  final root = _root((candidate) {
    request = candidate as CanvasDeleteCommitRequest;
    return CanvasCommitAccept(lease: lease);
  });
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  expect(root.commands.removeElement(CanvasElementId('background')), isTrue);
  await Future<void>.delayed(Duration.zero);

  final received = request;
  if (received == null) fail('Expected direct removal to resolve.');
  expect(received.entries, hasLength(1));
  expect(received.entries.single.element.id, CanvasElementId('background'));
  expect(received.entries.single.layerId, isNull);
  expect(received.entries.single.elementIndex, 0);
  expect(actions.single.type, CanvasActionType.deleteElements);
  expect(lease.committedCalls, 1);
  expect(lease.abortedCalls, 0);
}

Future<void> _verifyDirectNonDeletableRemoval() async {
  var calls = 0;
  final accepted = _root((_) {
    calls += 1;
    return CanvasCommitAccept(lease: _DeleteLease());
  });
  final actions = <CanvasActionCommitted>[];
  final subscription = accepted.actions.listen(actions.add);
  addTearDown(() async { await subscription.cancel(); accepted.dispose(); });
  expect(accepted.commands.removeElement(CanvasElementId('not-deletable')), isTrue);
  await Future<void>.delayed(Duration.zero);
  expect(calls, 1);
  expect(accepted.readDocument().layers.first.elements, hasLength(1));
  expect(actions, hasLength(1));

  var cancelledCalls = 0;
  final cancelled = _root((_) { cancelledCalls += 1; return const CanvasCommitCancel(); });
  addTearDown(cancelled.dispose);
  expect(cancelled.commands.removeElement(CanvasElementId('not-deletable')), isFalse);
  expect(cancelledCalls, 1);
  expect(cancelled.readDocument().layers.first.elements, hasLength(2));
}

// Rejected outcomes share the same immutable snapshot assertion surface.
// ignore: halstead-volume, source-lines-of-code
Future<void> _verifyRejectedDeleteOutcomes() async {
  final cancel = _root((_) => const CanvasCommitCancel());
  addTearDown(cancel.dispose);
  final cancelActions = <CanvasActionCommitted>[];
  final cancelSubscription = cancel.actions.listen(cancelActions.add);
  addTearDown(cancelSubscription.cancel);
  cancel.selection.setSelection([CanvasElementId('a')]);
  cancel.selection.deleteSelection();
  await Future<void>.delayed(Duration.zero);
  expect(cancel.readDocument().layers.first.elements, hasLength(2));
  expect(cancelActions, isEmpty);

  final incompatibleLease = _DeleteLease();
  final incompatible = _root(
    (_) => CanvasMoveCommitAccept(
      delta: const Offset(1, 0),
      lease: incompatibleLease,
    ),
  );
  addTearDown(incompatible.dispose);
  final incompatibleActions = <CanvasActionCommitted>[];
  final incompatibleSubscription = incompatible.actions.listen(
    incompatibleActions.add,
  );
  addTearDown(incompatibleSubscription.cancel);
  expect(incompatible.commands.removeElement(CanvasElementId('a')), isFalse);
  await Future<void>.delayed(Duration.zero);
  expect(incompatible.readDocument().layers.first.elements, hasLength(2));
  expect(incompatibleActions, isEmpty);
  expect(incompatibleLease.abortedCalls, 1);
  expect(incompatibleLease.committedCalls, 0);

  final error = _root((_) => throw StateError('delete resolver failure'));
  addTearDown(error.dispose);
  expect(error.commands.removeElement(CanvasElementId('a')), isFalse);
  expect(error.readDocument().layers.first.elements, hasLength(2));

  final failureLease = _DeleteLease();
  final failing = _root((_) => CanvasCommitAccept(lease: failureLease));
  addTearDown(failing.dispose);
  final failingActions = <CanvasActionCommitted>[];
  final failingSubscription = failing.actions.listen(failingActions.add);
  addTearDown(failingSubscription.cancel);
  failing.selection.setSelection([CanvasElementId('a')]);
  expect(
    () => DocumentStoreKernel.injectDeletionPreparedInstallFailure(
      StateError('pre-install failure'),
      failing.selection.deleteSelection,
    ),
    throwsStateError,
  );
  expect(failing.readDocument().layers.first.elements, hasLength(2));
  expect(failingActions, isEmpty);
  expect(failureLease.abortedCalls, 0);
  expect(failureLease.committedCalls, 0);
}

void _verifyDeletePolicyAndAvailability() {
  var calls = 0;
  final root = _root((_) {
    calls += 1;
    return CanvasCommitAccept(lease: _DeleteLease());
  }, policy: CanvasSelectionDeletePolicy.allOrNone);
  addTearDown(root.dispose);
  root.selection.setSelection([
    CanvasElementId('a'),
    CanvasElementId('not-deletable'),
  ]);

  expect(
    root.selectionDeleteAvailability,
    const CanvasSelectionDeleteAvailability(
      hasSelection: true,
      allSelectedElementsDeletable: false,
      hasAnySelectedElementDeletable: true,
    ),
  );
  root.selection.deleteSelection();
  expect(calls, 0);
  expect(root.readDocument().layers.first.elements, hasLength(2));
}

// The exact Store document is test data for every route outcome in this file.
// ignore: source-lines-of-code
RuntimeRoot _root(
  CanvasCommitResolver resolver, {
  CanvasSelectionDeletePolicy policy = CanvasSelectionDeletePolicy.partial,
}) {
  return RuntimeRoot.test(
    config: CanvasRuntimeConfig(
      commitResolver: resolver,
      selectionDeletePolicy: policy,
    ),
    store: DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(
        CanvasDocument(
          backgroundElements: [
            CanvasRectElement(
              id: CanvasElementId('background'),
              size: const Size(2, 2),
            ),
          ],
          layers: [
            CanvasLayer(
              id: CanvasLayerId('lower'),
              elements: [
                CanvasRectElement(
                  id: CanvasElementId('a'),
                  size: const Size(2, 2),
                ),
                CanvasRectElement(
                  id: CanvasElementId('not-deletable'),
                  size: const Size(2, 2),
                  isDeletable: false,
                ),
              ],
            ),
            CanvasLayer(
              id: CanvasLayerId('upper'),
              elements: [
                CanvasRectElement(
                  id: CanvasElementId('b'),
                  size: const Size(2, 2),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

final class _DeleteLease implements CanvasCommitLease {
  void Function()? onCommitted;
  int committedCalls = 0;
  int abortedCalls = 0;
  final List<({int documentRevision, int actionCount})> committedSnapshots = [];

  @override
  void aborted() {
    abortedCalls += 1;
  }

  @override
  void committed() {
    committedCalls += 1;
    onCommitted?.call();
  }
}
