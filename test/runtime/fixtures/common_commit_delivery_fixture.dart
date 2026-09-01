// This fixture intentionally names runtime delivery boundaries in one proof
// surface so the shared recorder remains the source of setup truth.
// ignore_for_file: number-of-imports

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/api/canvas_runtime_surface_bridge.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resource_session_release_sink.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

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

  test(
    'common delivery keeps every synchronous owner in one guarded order',
    () {
      expect(_expectCompleteCommonDeliveryOrder, returnsNormally);
    },
  );

  test('throwing action listener keeps common delivery and guard release', () {
    expect(_expectActionListenerFailureIsContained, returnsNormally);
  });

  test('throwing frame bridge continues accepted delivery', () {
    expect(_expectFrameBridgeFailureIsContained, returnsNormally);
  });

  test('throwing state error reporter continues accepted delivery', () {
    expect(_expectStateErrorReporterFailureIsContained, returnsNormally);
  });

  test('real routes compose with common delivery owners', () {
    return expectLater(_expectRealRouteComposition(), completes);
  });
}

void _expectPostCommitObserverDelivery() {
  _ObserverDeliveryScenario().run();
}

void _expectObserverFailureIsContained() {
  _ObserverFailureScenario().run();
}

Future<void> _expectRealRouteComposition() async {
  await _expectMarqueeRealRoute();
  await _expectCommandRealRoute();
  await _expectChangedTextRealRoute();
}

// This one trace keeps route facts and delivery order together.
// Separating assertions would obscure the behavioral contract.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectMarqueeRealRoute() async {
  final scenario = _CommonDeliveryScenario(_document());
  try {
    scenario.root.handlePointer(
      CanvasPointerSample(
        pointerId: 1,
        position: const Offset(-20, -20),
        phase: CanvasPointerLifecyclePhase.down,
        kind: PointerDeviceKind.touch,
      ),
    );
    scenario.root.handlePointer(
      CanvasPointerSample(
        pointerId: 1,
        position: const Offset(55, 12),
        phase: CanvasPointerLifecyclePhase.move,
        kind: PointerDeviceKind.touch,
      ),
    );
    scenario.beforeCallback = () {
      expect(scenario.root.preview, isA<CanvasNoPreview>());
      expect(scenario.root.interactionEngine.activeSession, isNull);
      expect(scenario.root.selection.selectedElementIds, {
        CanvasElementId('element-1'),
      });
    };

    scenario.run(() {
      scenario.root.handlePointer(
        CanvasPointerSample(
          pointerId: 1,
          position: const Offset(55, 12),
          phase: CanvasPointerLifecyclePhase.up,
          kind: PointerDeviceKind.touch,
          timestampMs: 17,
        ),
      );
    });

    scenario.expectTrace([
      'guard-enter',
      'spatial',
      'frame',
      'bridge-frame',
      'state',
      'action',
      'observer',
      'guard-release',
    ]);
    expect(scenario.preparations, 1);
    expect(scenario.root.selection.selectedElementIds, {
      CanvasElementId('element-1'),
    });
    expect(scenario.actions, hasLength(1));
    final action = scenario.actions.single;
    expect(action.type, CanvasActionType.selectMarquee);
    expect(action.timestampMs, 17);
    final payload = action.payload as CanvasSelectionActionPayload;
    expect(payload.previousSelection, isEmpty);
    expect(payload.nextSelection, [CanvasElementId('element-1')]);
    scenario.expectCommonSemanticPhases();
    expect(scenario.root.generateElementId(), CanvasElementId('e0'));
  } finally {
    await scenario.dispose();
  }
}

// Keep the public result, resource release, and common callbacks in one trace
// because the required order is the behavior under test, not helper structure.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectCommandRealRoute() async {
  final scenario = _CommonDeliveryScenario(_documentWithResource());
  try {
    scenario.beforeCallback = () {
      expect(scenario.root.readDocument().layers.single.elements, isEmpty);
    };
    final result = scenario.run(
      () => scenario.root.commands.clearContent(
        removeUnusedResources: true,
        timestampMs: 87,
      ),
    );
    expect(result.didClearContent, isTrue);
    expect(result.removedElementIds, [CanvasElementId('element-1')]);
    expect(result.removedResourceIds, [CanvasResourceId('resource-1')]);
    scenario.expectTrace([
      'guard-enter',
      'spatial',
      'resource',
      'frame',
      'bridge-frame',
      'state',
      'action',
      'observer',
      'guard-release',
    ]);
    expect(scenario.preparations, 1);
    expect(scenario.releasedResourceIds, [
      {CanvasResourceId('resource-1')},
    ]);
    expect(scenario.root.readDocument().layers.single.elements, isEmpty);
    expect(scenario.actions, hasLength(1));
    final action = scenario.actions.single;
    expect(action.type, CanvasActionType.clearContent);
    expect(action.timestampMs, 87);
    final payload = action.payload as CanvasClearActionPayload;
    expect(payload.removedElementIds, [CanvasElementId('element-1')]);
    expect(payload.removedResourceIds, [CanvasResourceId('resource-1')]);
    scenario.expectCommonSemanticPhases();
    expect(scenario.root.generateElementId(), CanvasElementId('e0'));
  } finally {
    await scenario.dispose();
  }
}

// The public context/session setup and the final commit must remain adjacent to
// show that only the real changed-text route reaches common delivery.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectChangedTextRealRoute() async {
  final scenario = _CommonDeliveryScenario(_textDocument());
  final requests = <CanvasContextActionRequested>[];
  final requestSubscription = scenario.root.contextActionRequests.listen(
    requests.add,
  );
  try {
    scenario.root.handleDoubleTap(position: Offset.zero, timestampMs: 3);
    await Future<void>.delayed(Duration.zero);
    final request = requests.single;
    final session = scenario.root.textEditing.startFromContextAction(request);
    expect(session, isA<CanvasTextEditSession>());
    final textSession = session as CanvasTextEditSession;
    textSession.updateText('updated text');

    scenario.discardSetupNotifications();
    scenario.beforeCallback = () {
      expect(_textValue(scenario.root), 'updated text');
      expect(
        scenario.root.interactionEngine.requestFactsFor(request.requestId),
        isNull,
      );
      expect(scenario.root.textEditing.activeSession.value, isNull);
    };
    final didCommit = scenario.run(() => textSession.commit(timestampMs: 91));

    expect(didCommit, isTrue);
    scenario.expectTrace([
      'guard-enter',
      'spatial',
      'frame',
      'bridge-frame',
      'state',
      'action',
      'observer',
      'guard-release',
    ]);
    expect(scenario.preparations, 1);
    expect(_textValue(scenario.root), 'updated text');
    expect(
      scenario.root.interactionEngine.requestFactsFor(request.requestId),
      isNull,
    );
    expect(scenario.root.textEditing.activeSession.value, isNull);
    expect(textSession.isActive, isFalse);
    expect(scenario.actions, hasLength(1));
    final action = scenario.actions.single;
    expect(action.type, CanvasActionType.editText);
    expect(action.timestampMs, 91);
    final payload = action.payload as CanvasTextEditActionPayload;
    expect(payload.requestId, request.requestId);
    expect(payload.previousTextLength, 'hello'.length);
    expect(payload.nextTextLength, 'updated text'.length);
    scenario.expectCommonSemanticPhases();
    expect(scenario.root.generateElementId(), CanvasElementId('e0'));
  } finally {
    await requestSubscription.cancel();
    await scenario.dispose();
  }
}

// This recorder deliberately composes all delivery owners in one fixture-local
// scenario; splitting it would duplicate the delivery setup and its policy.
// ignore: coupling-between-object-classes
final class _CommonDeliveryScenario {
  // The constructor wires every synchronous callback once for all route traces.
  // ignore: halstead-volume
  _CommonDeliveryScenario(CanvasDocument document) {
    root = runtimeRootWithCommittedDocumentSeed(
      document,
      commitEffectObserver: (effects) {
        if (effects.isNotEmpty && _isDelivering) {
          _recordCallback('observer');
        }
      },
    );
    root.attachSurface(_surfaceToken);
    root.attachResourceSessionReleaseSink(_ScenarioReleaseSink(this));
    root.surfaceFrameSignal.addListener(() {
      if (_isDelivering && root.surfaceFrameSignal.value != null) {
        _recordCallback('frame');
      }
    });
    attachCanvasRuntimeSurfacePort(_surfaceRuntime, root);
    final bridge = canvasRuntimeSurfacePortFor(_surfaceRuntime);
    if (bridge == null) {
      fail('Runtime surface bridge was not attached.');
    }
    bridge.surfaceFrame.addListener(() {
      if (_isDelivering && bridge.surfaceFrame.value != null) {
        _recordCallback('bridge-frame');
      }
    });
    root.state.addListener(() {
      if (_isDelivering) {
        _recordCallback('state');
      }
    });
    subscription = root.actions.listen((action) {
      if (_isDelivering) {
        actions.add(action);
        _recordCallback('action');
      }
    });
  }

  late final RuntimeRoot root;
  late final StreamSubscription<CanvasActionCommitted> subscription;
  final Object _surfaceRuntime = Object();
  final Object _surfaceToken = Object();
  final List<String> events = <String>[];
  final List<RuntimeCommonDeliveryEvent> semanticEvents =
      <RuntimeCommonDeliveryEvent>[];
  final List<CanvasActionCommitted> actions = <CanvasActionCommitted>[];
  final List<Set<CanvasResourceId>> releasedResourceIds =
      <Set<CanvasResourceId>>[];
  int preparations = 0;
  bool _isDelivering = false;
  void Function()? beforeCallback;

  T run<T>(T Function() operation) {
    discardSetupNotifications();

    return CommitApplier.observeSealedDeliveryWork(
      (work) => preparations = work.preparations,
      () => RuntimeRoot.observeCommonDeliveryEvents(_record, operation),
    );
  }

  void discardSetupNotifications() {
    events.clear();
    semanticEvents.clear();
    actions.clear();
    releasedResourceIds.clear();
    preparations = 0;
    _isDelivering = false;
  }

  void _record(RuntimeCommonDeliveryEvent event) {
    semanticEvents.add(event);
    switch (event.kind) {
      case RuntimeCommonDeliveryEventKind.guardEntered:
        _isDelivering = true;
        events.add('guard-enter');
      case RuntimeCommonDeliveryEventKind.spatialEffectsCompleted:
        events.add('spatial');
      case RuntimeCommonDeliveryEventKind.guardReleased:
        events.add('guard-release');
        _isDelivering = false;
      default:
        break;
    }
  }

  void _recordCallback(String event) {
    events.add(event);
    beforeCallback?.call();
    _expectAllPublicMutationsGuarded(root);
  }

  void recordResourceRelease(Set<CanvasResourceId> ids) {
    if (_isDelivering) {
      releasedResourceIds.add(ids);
      _recordCallback('resource');
    }
  }

  void expectTrace(List<String> expected) {
    expect(events, expected);
  }

  void expectCommonSemanticPhases() {
    expect(semanticEvents.map((event) => event.kind), [
      RuntimeCommonDeliveryEventKind.guardEntered,
      RuntimeCommonDeliveryEventKind.spatialEffectsCompleted,
      RuntimeCommonDeliveryEventKind.resourceEffectsCompleted,
      RuntimeCommonDeliveryEventKind.repaintTargetEffectsCompleted,
      RuntimeCommonDeliveryEventKind.actionFinalizationCompleted,
      RuntimeCommonDeliveryEventKind.actionEmissionCompleted,
      RuntimeCommonDeliveryEventKind.guardReleased,
    ]);
  }

  Future<void> dispose() async {
    await subscription.cancel();
    root.dispose();
  }
}

final class _ScenarioReleaseSink implements ResourceSessionReleaseSink {
  _ScenarioReleaseSink(this.scenario);

  final _CommonDeliveryScenario scenario;

  @override
  void releaseResource(CanvasResourceId id) => releaseResources({id});

  @override
  void releaseResources(Set<CanvasResourceId> ids) {
    scenario.recordResourceRelease(ids);
  }

  @override
  void releaseAllResources() => scenario.recordResourceRelease(const {});
}

// The one integrated trace must keep cross-owner callback observations together
// so a reordered delivery surface cannot be hidden behind local logs.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectCompleteCommonDeliveryOrder() {
  final scenario = _CommonDeliveryScenario(_documentWithResource());
  try {
    scenario.run(() {
      scenario.root.deliverCommitPlanForTesting(
        CommitPlan(
          revisionDelta: const StoreRevisionDelta.resource(),
          touchedSet: TouchedSet(
            resourceDescriptorChangedIds: [CanvasResourceId('resource-1')],
          ),
          effects: [
            SpatialEffect(touchedSet: TouchedSet()),
            ResourceEffect(
              touchedSet: TouchedSet(
                resourceDescriptorChangedIds: [CanvasResourceId('resource-1')],
              ),
            ),
            const RepaintEffect(mainCanvas: true),
            const PublicStateEffect(),
          ],
          actionIntents: [
            DeleteSelectionActionIntent(
              removedElementIds: [CanvasElementId('element-1')],
            ),
          ],
        ),
        document: scenario.root.readDocument(),
      );
    });

    scenario.expectCommonSemanticPhases();
    scenario.expectTrace([
      'guard-enter',
      'spatial',
      'resource',
      'frame',
      'bridge-frame',
      'state',
      'action',
      'observer',
      'guard-release',
    ]);
    expect(scenario.releasedResourceIds, [
      {CanvasResourceId('resource-1')},
    ]);
    expect(scenario.root.generateElementId(), CanvasElementId('e0'));
  } finally {
    unawaited(scenario.dispose());
  }
}

// Error routing, peer delivery, observer continuation, and guard release form
// one synchronous stream outcome rather than independent implementation tests.
// ignore: halstead-volume, source-lines-of-code
void _expectActionListenerFailureIsContained() {
  final events = <String>[];
  final errors = <Object>[];
  final deliveryEvents = <RuntimeCommonDeliveryEvent>[];
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    _document(),
    commitEffectObserver: (_) => events.add('observer'),
  );
  root.state.addListener(() => events.add('state'));
  late StreamSubscription<CanvasActionCommitted> throwingSubscription;
  late StreamSubscription<CanvasActionCommitted> receivingSubscription;
  try {
    runZonedGuarded(() {
      throwingSubscription = root.actions.listen((_) {
        events.add('throwing-action');
        throw StateError('action listener failed');
      });
      receivingSubscription = root.actions.listen((_) {
        events.add('action');
        _expectAllPublicMutationsGuarded(root);
      });
      RuntimeRoot.observeCommonDeliveryEvents(deliveryEvents.add, () {
        final result = root.commands.clearContent(
          removeUnusedResources: true,
          timestampMs: 7,
        );
        expect(result.didClearContent, isTrue);
        expect(result.removedElementIds, [CanvasElementId('element-1')]);
        expect(result.removedResourceIds, isEmpty);
      });
    }, (error, _) => errors.add(error));

    expect(errors.single, isA<StateError>());
    expect(events, ['state', 'throwing-action', 'action', 'observer']);
    expect(
      deliveryEvents.map((event) => event.kind),
      containsAllInOrder([
        RuntimeCommonDeliveryEventKind.actionFinalizationCompleted,
        RuntimeCommonDeliveryEventKind.actionEmissionCompleted,
      ]),
    );
    expect(root.readDocument().layers.single.elements, isEmpty);
    expect(root.generateElementId(), CanvasElementId('e0'));
  } finally {
    unawaited(throwingSubscription.cancel());
    unawaited(receivingSubscription.cancel());
    root.dispose();
  }
}

// A real post-install delivery must not turn an already accepted operation into
// a failure when the frame bridge throws. The later state/action/observer
// attempts and a new mutation prove continuation and guard release through the
// public RuntimeRoot seam.
// ignore: halstead-volume, source-lines-of-code
void _expectFrameBridgeFailureIsContained() {
  final events = <String>[];
  late RuntimeRoot root;
  late StreamSubscription<CanvasActionCommitted> subscription;
  var failFrameBridge = false;
  root = runtimeRootWithCommittedDocumentSeed(
    _document(),
    commitEffectObserver: (_) => events.add('observer'),
  );
  root.attachSurface(Object());
  root.installSurfaceFrameMirror((_) {
    if (!failFrameBridge) {
      return;
    }
    events.add('frame-bridge');
    throw StateError('frame bridge failed');
  });
  root.state.addListener(() {
    events.add('state');
  });
  subscription = root.actions.listen((_) => events.add('action'));
  failFrameBridge = true;

  try {
    final result = root.commands.clearContent(
      removeUnusedResources: true,
      timestampMs: 9,
    );

    expect(result.didClearContent, isTrue);
    expect(root.readDocument().layers.single.elements, isEmpty);
    _expectClearedPublicState(root);
    expect(events, ['frame-bridge', 'state', 'action', 'observer']);
    expect(root.generateElementId(), CanvasElementId('e0'));
  } finally {
    failFrameBridge = false;
    unawaited(subscription.cancel());
    root.dispose();
  }
}

// ValueNotifier routes a listener failure through FlutterError. This witness
// makes the reporter fail too, proving RuntimeRoot still reaches action and
// observer delivery after the state notification has installed its value.
// ignore: halstead-volume, source-lines-of-code
void _expectStateErrorReporterFailureIsContained() {
  final events = <String>[];
  final previousOnError = FlutterError.onError;
  late RuntimeRoot root;
  late StreamSubscription<CanvasActionCommitted> subscription;
  void throwingStateListener() {
    events.add('state-listener');
    throw StateError('state listener failed');
  }

  root = runtimeRootWithCommittedDocumentSeed(
    _document(),
    commitEffectObserver: (_) => events.add('observer'),
  );
  root.state.addListener(throwingStateListener);
  FlutterError.onError = (_) {
    events.add('state-error-reporter');
    throw StateError('state error reporter failed');
  };
  subscription = root.actions.listen((_) => events.add('action'));

  try {
    final result = root.commands.clearContent(
      removeUnusedResources: true,
      timestampMs: 10,
    );

    expect(result.didClearContent, isTrue);
    expect(root.readDocument().layers.single.elements, isEmpty);
    _expectClearedPublicState(root);
    expect(events, [
      'state-listener',
      'state-error-reporter',
      'action',
      'observer',
    ]);
    expect(root.generateElementId(), CanvasElementId('e0'));
  } finally {
    FlutterError.onError = previousOnError;
    root.state.removeListener(throwingStateListener);
    unawaited(subscription.cancel());
    root.dispose();
  }
}

void _expectClearedPublicState(RuntimeRoot root) {
  expect(
    root.state.value.summary,
    const CanvasRuntimeSummary(
      elementCount: 0,
      layerCount: 1,
      resourceCount: 0,
      selectedCount: 0,
    ),
  );
  expect(root.state.value.revisions.document, 1);
}

// This scenario intentionally names every guarded public mutation entry point
// in one proof so missing guard coverage is visible in the test body.
// ignore: coupling-between-object-classes
final class _ObserverDeliveryScenario {
  _ObserverDeliveryScenario() {
    root = runtimeRootWithCommittedDocumentSeed(
      _document(),
      commitEffectObserver: _observeEffects,
    );
    baselineViewCameraRevision = root.state.value.revisions.viewCamera;
    root.state.addListener(_recordState);
  }

  late final RuntimeRoot root;
  CanvasEdit? editHandle;
  final List<String> events = <String>[];
  final List<CanvasRuntimeState> snapshots = <CanvasRuntimeState>[];
  final List<List<CommitDeliveryEffect>> effectBatches =
      <List<CommitDeliveryEffect>>[];
  late final int baselineViewCameraRevision;
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
    expect(root.state.value.revisions.viewCamera, baselineViewCameraRevision);
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
    root = runtimeRootWithCommittedDocumentSeed(
      _document(),
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

void _expectAllPublicMutationsGuarded(RuntimeRoot root) {
  _expectDeliveryGuard(() => root.edits.edit(_ignoreEdit));
  _expectDeliveryGuard(
    () => root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(CanvasDocument()),
    ),
  );
  _expectDeliveryGuard(() => root.selection.setSelection(const []));
  _expectDeliveryGuard(() => root.cameraPort().setOffset(const Offset(1, 1)));
  _expectDeliveryGuard(root.generateElementId);
  _expectDeliveryGuard(root.generateLayerId);
  _expectDeliveryGuard(root.generateResourceId);
  _expectDeliveryGuard(root.dispose);
}

void _ignoreEdit(CanvasEdit edit) {
  expect(edit, isA<CanvasEdit>());
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

CanvasDocument _documentWithResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
    ],
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

CanvasDocument _textDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasTextElement(
            id: CanvasElementId('text-1'),
            text: 'hello',
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    ],
  );
}

String _textValue(RuntimeRoot root) {
  return root
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasTextElement>()
      .single
      .text;
}
