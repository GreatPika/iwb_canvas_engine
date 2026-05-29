import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_port.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _testInitialSpatialRebuild();
  _testEditDeliveryOrder();
  _testSelectableDeliveryOrder();
  _testLoadDeliveryOrder();
  _testSpatialFailureContainment();
}

void _testInitialSpatialRebuild() {
  test('initial document has spatial state before use', () {
    final root = _runtimeRoot();

    expect(_spatialIds(root, _nearOrigin()), [CanvasElementId('initial')]);
  });
}

void _testEditDeliveryOrder() {
  test('edit spatial delivery runs before state and observer callbacks', () {
    final outcome = _runEditDeliveryScenario();

    expect(outcome.events, ['state', 'observer']);
    expect(outcome.stateSpatialIds, [
      [CanvasElementId('added')],
    ]);
    expect(outcome.observerSpatialIds, [
      [CanvasElementId('added')],
    ]);
    expect(outcome.guardedMutationAttempts, 2);
    expect(outcome.nestedMutationRan, isFalse);
  });
}

void _testSelectableDeliveryOrder() {
  test('selectable update spatial delivery runs before publication', () {
    final outcome = _runSelectableDeliveryScenario();

    expect(outcome.events, ['state', 'observer']);
    expect(outcome.stateSpatialIds, [<CanvasElementId>[]]);
    expect(outcome.observerSpatialIds, [<CanvasElementId>[]]);
    expect(outcome.guardedMutationAttempts, 2);
    expect(outcome.nestedMutationRan, isFalse);
  });
}

void _testLoadDeliveryOrder() {
  test('load spatial delivery runs before state and observer callbacks', () {
    final outcome = _runLoadDeliveryScenario();

    expect(outcome.events, ['state', 'observer']);
    expect(outcome.stateSpatialIds.single, [CanvasElementId('loaded')]);
    expect(outcome.observerSpatialIds.single, [CanvasElementId('loaded')]);
    expect(outcome.guardedMutationAttempts, 2);
    expect(outcome.nestedMutationRan, isFalse);
  });
}

void _testSpatialFailureContainment() {
  test(
    'post-commit spatial failure keeps document and exposes invalid query',
    () {
      final root = _runtimeRoot();
      root.edits.edit((edit) {
        edit.addElement(_rect('accepted'), layerId: CanvasLayerId('layer'));
      });

      root.spatialKernel.applyTouched(
        root.frameFactsPort,
        TouchedSet(updatedElementIds: [CanvasElementId('missing')]),
      );

      expect(root.readDocument().layers.single.elements, hasLength(2));
      final result = root.spatialKernel.queryHit(_nearOrigin());
      expect(result, isA<SpatialInvalidIndexResult>());
      expect(result.candidates, isEmpty);
    },
  );
}

_DeliveryOutcome _runEditDeliveryScenario() {
  final recorder = _DeliveryRecorder();
  final root = _runtimeRoot(recorder.observe);
  recorder.bind(root);
  root.edits.edit((edit) {
    edit.addElement(
      _rect('added', translation: const Offset(1000, 0)),
      layerId: CanvasLayerId('layer'),
    );
  });

  return recorder.outcome();
}

_DeliveryOutcome _runSelectableDeliveryScenario() {
  final recorder = _DeliveryRecorder(_nearOrigin());
  final root = _runtimeRoot(recorder.observe);
  recorder.bind(root);
  root.edits.edit((edit) {
    expect(
      edit.updateElement(
        CanvasRectElementUpdate(
          id: CanvasElementId('initial'),
          isSelectable: const CanvasFieldSet(false),
        ),
      ),
      isTrue,
    );
  });

  return recorder.outcome();
}

_DeliveryOutcome _runLoadDeliveryScenario() {
  final recorder = _DeliveryRecorder();
  final root = _runtimeRoot(recorder.observe);
  recorder.bind(root);
  root.edits.loadDocument(
    _document([_rect('loaded', translation: const Offset(1000, 0))]),
  );

  return recorder.outcome();
}

final class _DeliveryRecorder {
  _DeliveryRecorder([this.queryWindow]);

  final SpatialQueryWindow? queryWindow;
  RuntimeRoot? _root;
  final List<String> events = [];
  final List<List<CanvasElementId>> stateSpatialIds = [];
  final List<List<CanvasElementId>> observerSpatialIds = [];
  bool nestedMutationRan = false;
  int guardedMutationAttempts = 0;

  void bind(RuntimeRoot root) {
    _root = root;
    root.state.addListener(recordState);
  }

  void recordState() {
    final root = _boundRoot();
    events.add('state');
    stateSpatialIds.add(_spatialIds(root, queryWindow ?? _nearMoved()));
    _expectMutationGuard();
  }

  void observe(List<CommitDeliveryEffect> effects) {
    final root = _boundRoot();
    events.add('observer');
    observerSpatialIds.add(_spatialIds(root, queryWindow ?? _nearMoved()));
    expect(effects.whereType<SpatialDeliveryEffect>(), hasLength(1));
    _expectMutationGuard();
  }

  void _expectMutationGuard() {
    final root = _boundRoot();
    guardedMutationAttempts += 1;
    expect(() {
      root.edits.edit((_) {
        nestedMutationRan = true;
      });
    }, throwsStateError);
  }

  RuntimeRoot _boundRoot() {
    final root = _root;
    if (root == null) {
      fail('runtime root was not bound before delivery');
    }

    return root;
  }

  _DeliveryOutcome outcome() {
    return _DeliveryOutcome(
      events: events,
      stateSpatialIds: stateSpatialIds,
      observerSpatialIds: observerSpatialIds,
      nestedMutationRan: nestedMutationRan,
      guardedMutationAttempts: guardedMutationAttempts,
    );
  }
}

final class _DeliveryOutcome {
  const _DeliveryOutcome({
    required this.events,
    required this.stateSpatialIds,
    required this.observerSpatialIds,
    required this.nestedMutationRan,
    required this.guardedMutationAttempts,
  });

  final List<String> events;
  final List<List<CanvasElementId>> stateSpatialIds;
  final List<List<CanvasElementId>> observerSpatialIds;
  final bool nestedMutationRan;
  final int guardedMutationAttempts;
}

RuntimeRoot _runtimeRoot([
  void Function(List<CommitDeliveryEffect>)? observer,
]) {
  return RuntimeRoot(
    initialDocument: _document([_rect('initial')]),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: observer,
  );
}

CanvasDocument _document(List<CanvasElement> elements) {
  return CanvasDocument(
    layers: [CanvasLayer(id: CanvasLayerId('layer'), elements: elements)],
  );
}

CanvasRectElement _rect(String id, {Offset translation = Offset.zero}) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: const Size(10, 10),
    transform: CanvasTransform.translation(translation),
  );
}

List<CanvasElementId> _spatialIds(RuntimeRoot root, SpatialQueryWindow window) {
  return root.spatialKernel
      .queryHit(window)
      .candidates
      .map((handle) => handle.id)
      .toList();
}

SpatialQueryWindow _nearOrigin() {
  return const SpatialQueryWindow(
    boundsWorld: Rect.fromLTRB(-20, -20, 20, 20),
    structuralRevision: 0,
  );
}

SpatialQueryWindow _nearMoved() {
  return const SpatialQueryWindow(
    boundsWorld: Rect.fromLTRB(980, -20, 1020, 20),
    structuralRevision: 1,
  );
}
