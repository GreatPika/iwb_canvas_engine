import 'dart:ui';
import "../../support/runtime_root_with_document.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test(
    'observer runs after install, handle closure, and state publication',
    () {
      expect(_expectPostCommitObserverDelivery, returnsNormally);
    },
  );

  test('observer failures do not roll back accepted commits', () {
    expect(_expectObserverFailureIsContained, returnsNormally);
  });
}

void _expectPostCommitObserverDelivery() {
  _ObserverDeliveryScenario().run();
}

void _expectObserverFailureIsContained() {
  _ObserverFailureScenario().run();
}

// This scenario intentionally names every guarded public mutation entry point
// in one proof so missing guard coverage is visible in the test body.
// ignore: coupling-between-object-classes
final class _ObserverDeliveryScenario {
  _ObserverDeliveryScenario() {
    root = runtimeRootWithDocument(
      _document(),
      config: const CanvasRuntimeConfig(),
      commitEffectObserver: _observeEffects,
    );
    root.state.addListener(_recordState);
  }

  late final RuntimeRoot root;
  CanvasEdit? editHandle;
  final List<String> events = <String>[];
  final List<CanvasRuntimeState> snapshots = <CanvasRuntimeState>[];
  final List<List<CommitDeliveryEffect>> effectBatches =
      <List<CommitDeliveryEffect>>[];
  bool nestedEditCallbackRan = false;
  int guardedPublicationWindows = 0;

  void run() {
    final callbackResult = root.edits.edit((edit) {
      editHandle = edit;
      edit.addElement(
        CanvasRectElement(
          id: CanvasElementId('element-2'),
          size: const Size(2, 2),
        ),
        layerId: CanvasLayerId('layer-1'),
      );

      return 'accepted';
    });

    _expectAcceptedResult(callbackResult);
    _expectDeliveredEffects();
    _expectPostObserverState();
  }

  void _observeEffects(List<CommitDeliveryEffect> effects) {
    events.add('observer');
    effectBatches.add(effects);

    _expectInstalledAndPublishedBeforeObserver();
    _expectDeliveryGuardedMutations();
  }

  void _recordState() {
    events.add('state');
    snapshots.add(root.state.value);
    guardedPublicationWindows += 1;
    _expectDeliveryGuardedMutations();
  }

  void _expectInstalledAndPublishedBeforeObserver() {
    final handle = editHandle;
    if (handle == null) {
      fail('edit handle was not captured before observer delivery');
    }

    expect(root.readDocument().layers.single.elements, hasLength(2));
    expect(handle.readDraftDocument, throwsStateError);
    expect(snapshots, hasLength(1));
    expect(snapshots.single.summary.elementCount, 2);
  }

  void _expectDeliveryGuardedMutations() {
    _expectDeliveryGuard(() {
      root.edits.edit((_) {
        nestedEditCallbackRan = true;
      });
    });
    _expectDeliveryGuard(
      () => root.edits.loadDocumentFromJson(
        encodeCanvasDocumentToJson(CanvasDocument()),
      ),
    );
    _expectDeliveryGuard(
      () => root.selection.setSelection([CanvasElementId('element-1')]),
    );
    _expectDeliveryGuard(() => root.cameraPort().setOffset(const Offset(1, 1)));
    _expectDeliveryGuard(root.generateElementId);
    _expectDeliveryGuard(root.generateLayerId);
    _expectDeliveryGuard(root.generateResourceId);
    _expectDeliveryGuard(root.dispose);
  }

  void _expectAcceptedResult(String callbackResult) {
    expect(callbackResult, 'accepted');
    expect(events, ['state', 'observer']);
    expect(nestedEditCallbackRan, isFalse);
    expect(guardedPublicationWindows, 1);
  }

  void _expectDeliveredEffects() {
    expect(effectBatches, hasLength(1));
    expect(
      effectBatches.single.whereType<ProjectionDeliveryEffect>(),
      hasLength(1),
    );
    expect(
      effectBatches.single.whereType<SpatialDeliveryEffect>(),
      hasLength(1),
    );
    expect(
      effectBatches.single.whereType<RepaintDeliveryEffect>(),
      hasLength(1),
    );
    expect(
      effectBatches.single.whereType<PublicStateDeliveryEffect>(),
      hasLength(1),
    );
    expect(
      () => effectBatches.single.add(const SelectionDeliveryEffect()),
      throwsUnsupportedError,
    );
  }

  void _expectPostObserverState() {
    expect(root.state.value.summary.elementCount, 2);
    expect(root.state.value.revisions.viewCamera, 0);
    expect(root.isDisposed, isFalse);
    expect(root.generateElementId(), CanvasElementId('e0'));
    expect(root.generateLayerId(), CanvasLayerId('l0'));
    expect(root.generateResourceId(), CanvasResourceId('r0'));
  }
}

// This scenario keeps the throwing observer, committed document, and published
// state assertions together because they define one failure-containment proof.
// ignore: coupling-between-object-classes
final class _ObserverFailureScenario {
  _ObserverFailureScenario() {
    root = runtimeRootWithDocument(
      _document(),
      config: const CanvasRuntimeConfig(),
      commitEffectObserver: _throwFromObserver,
    );
    root.state.addListener(() {
      snapshots.add(root.state.value);
    });
  }

  late final RuntimeRoot root;
  final List<CanvasRuntimeState> snapshots = <CanvasRuntimeState>[];
  int observerCalls = 0;

  void run() {
    final callbackResult = root.edits.edit((edit) {
      edit.addElement(
        CanvasRectElement(
          id: CanvasElementId('element-2'),
          size: const Size(2, 2),
        ),
        layerId: CanvasLayerId('layer-1'),
      );

      return 7;
    });

    expect(callbackResult, 7);
    expect(observerCalls, 1);
    expect(snapshots, hasLength(1));
    expect(root.readDocument().layers.single.elements, hasLength(2));
    expect(root.state.value.summary.elementCount, 2);
  }

  void _throwFromObserver(List<CommitDeliveryEffect> _) {
    observerCalls += 1;
    throw StateError('observer failed');
  }
}

void _expectDeliveryGuard(void Function() action) {
  expect(
    action,
    throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('post-commit effect delivery'),
      ),
    ),
  );
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('element-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}
