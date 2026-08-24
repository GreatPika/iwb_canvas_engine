import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_action_intent.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resource_session_release_sink.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/resources/resource_cache.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../resources/fixtures/surface_resource_session_test_support.dart';

void main() {
  _registerDirtyAcceptanceTests();
  _registerDirtyGuardTests();
  _registerSessionReleaseTests();
}

void _registerDirtyAcceptanceTests() {
  test('accepted dirty publishes one resource visual snapshot and effects', () {
    return expectLater(_expectAcceptedSingleTargetDirty(), completes);
  });

  test('missing target and empty mark-all are complete no-ops', () {
    return expectLater(_expectDirtyNoOps(), completes);
  });

  test('mark-all publishes one all-resource visual outcome', () {
    return expectLater(_expectAcceptedMarkAllDirty(), completes);
  });
}

void _registerDirtyGuardTests() {
  test('runtime mutation guards reject dirty before side effects', () {
    return expectLater(_expectDirtyMutationGuards(), completes);
  });

  test('observer failure does not roll back accepted dirty revision', () {
    return expectLater(_expectDirtyObserverFailureContainment(), completes);
  });

  test(
    'post-removal observer failure preserves accepted dirty publication',
    () {
      return expectLater(
        _expectPostRemovalObserverFailureIsContained(),
        completes,
      );
    },
  );
}

void _registerSessionReleaseTests() {
  test('active session releases before dirty publication', () {
    return expectLater(
      _expectActiveSessionInvalidatesBeforePublish(),
      completes,
    );
  });

  test('dirty release failure drops sink after publication', () {
    return expectLater(_expectDirtyReleaseFailureIsContained(), completes);
  });

  test('edit resource effects release active session before publication', () {
    return expectLater(
      _expectEditResourceEffectsInvalidateBeforePublish(),
      completes,
    );
  });

  test('edit resource release failure drops sink after publication', () {
    expect(_expectEditResourceReleaseFailureIsContained, returnsNormally);
  });

  test('real session target failure drops after common command delivery', () {
    return expectLater(_expectRealTargetFailure(), completes);
  });
  test('real session all-release failure drops after common delivery', () {
    return expectLater(_expectRealAllFailure(), completes);
  });
  test('real session reset failure drops after replacement delivery', () {
    return expectLater(_expectRealResetFailure(), completes);
  });

  test('cleared active session is not mutated by later dirty calls', () {
    return expectLater(_expectClearedActiveSessionIsIgnored(), completes);
  });
}

Future<void> _expectAcceptedSingleTargetDirty() async {
  final scenario = _DirtyRuntimeScenario.withDocument(_documentWithResource());
  scenario.root.resources.markResourceDirty(CanvasResourceId('resource-a'));

  scenario.expectOneSnapshotWithResourceVisual(1);
  scenario.expectOnlyResourceVisualChanged();
  scenario.expectTargetEffects(CanvasResourceId('resource-a'));
  await scenario.expectNoActions();
  await scenario.dispose();
}

Future<void> _expectDirtyNoOps() async {
  final missing = _DirtyRuntimeScenario.withDocument(_documentWithResource());
  missing.root.resources.markResourceDirty(CanvasResourceId('missing'));
  await missing.expectNoSideEffects();
  await missing.dispose();

  final empty = _DirtyRuntimeScenario.withDocument(CanvasDocument());
  empty.root.resources.markAllResourcesDirty();
  await empty.expectNoSideEffects();
  await empty.dispose();
}

Future<void> _expectAcceptedMarkAllDirty() async {
  final scenario = _DirtyRuntimeScenario.withDocument(_documentWithResource());
  scenario.root.resources.markAllResourcesDirty();

  scenario.expectOneSnapshotWithResourceVisual(1);
  scenario.expectOnlyResourceVisualChanged();
  scenario.expectAllResourceEffects();
  await scenario.expectNoActions();
  await scenario.dispose();
}

Future<void> _expectDirtyMutationGuards() async {
  await _expectDisposedGuard();
  await _expectActiveEditGuard();
  _expectPostCommitDeliveryGuard();
  await _expectResolverCallbackGuard();
}

Future<void> _expectDirtyObserverFailureContainment() async {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final actions = <CanvasActionCommitted>[];
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: (effects) {
      effectBatches.add(effects);
      throw StateError('observer failed');
    },
  );
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });
  final subscription = root.actions.listen(actions.add);

  root.resources.markResourceDirty(CanvasResourceId('resource-a'));
  await Future<void>.delayed(Duration.zero);

  expect(snapshots, hasLength(1));
  expect(root.state.value.revisions.resourceVisual, 1);
  expect(effectBatches, hasLength(1));
  expect(actions, isEmpty);
  await subscription.cancel();
  root.dispose();
}

// Removing retained-output release from SurfaceResourceSession must fail this
// scenario: the accepted dirty publication would still expose a matching borrow.
// Cache/output removal, accepted state, and post-acceptance failure are one
// ordered transaction here; splitting the assertions would hide that contract.
// ignore: halstead-volume, source-lines-of-code
Future<void> _expectPostRemovalObserverFailureIsContained() async {
  final image = await createResourceTestImage();
  final cache = ResourceAssetCache();
  final retainedOutput = _RetainedOutputProbe()..retain('resource-a');
  final snapshots = <CanvasRuntimeState>[];
  final deliveredEffects = <List<CommitDeliveryEffect>>[];
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: (effects) {
      _expectNoBorrow(cache, retainedOutput);
      deliveredEffects.add(effects);
      throw StateError('observer failed after release');
    },
  );
  final session = SurfaceResourceSession(
    resolver: RecordingResourceResolver((_) => image),
    mutationGuard: root,
    cache: cache,
    releaseRetainedResources: (ids) {
      for (final id in ids) {
        retainedOutput.release(id.value);
      }
    },
    releaseAllRetainedResources: retainedOutput.releaseAll,
  );
  final token = Object();
  root.attachSurface(token);
  root.installSurfaceResourceSession(token, session);
  session.resolveResource(descriptorRequest(id: 'resource-a'));
  root.state.addListener(() {
    _expectNoBorrow(cache, retainedOutput);
    snapshots.add(root.state.value);
  });

  expect(
    () => root.resources.markResourceDirty(CanvasResourceId('resource-a')),
    returnsNormally,
  );

  _expectNoBorrow(cache, retainedOutput);
  expect(snapshots, hasLength(1));
  expect(root.state.value.revisions.resourceVisual, 1);
  expect(deliveredEffects, hasLength(1));
  expect(
    deliveredEffects.single
        .whereType<RepaintDeliveryEffect>()
        .single
        .mainCanvas,
    isTrue,
  );
  expect(root.activeSurfaceResourceSessionForTesting, same(session));
  image.dispose();
  root.dispose();
}

void _expectNoBorrow(ResourceAssetCache cache, _RetainedOutputProbe output) {
  expect(
    cache.read(
      resolverGeneration: 0,
      resourceId: CanvasResourceId('resource-a'),
      resourceRevision: 0,
    ),
    isNull,
  );
  expect(output.hasBorrow('resource-a'), isFalse);
}

Future<void> _expectActiveSessionInvalidatesBeforePublish() {
  final sink = _RecordingResourceSessionReleaseSink();
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: (_) {
      sink.expectTargetReleased(CanvasResourceId('resource-a'));
    },
  );
  root.attachResourceSessionReleaseSink(sink);
  root.state.addListener(() {
    sink.expectTargetReleased(CanvasResourceId('resource-a'));
  });

  root.resources.markResourceDirty(CanvasResourceId('resource-a'));

  expect(sink.releasedIds, [CanvasResourceId('resource-a')]);
  expect(sink.releaseAllCount, 0);
  root.dispose();

  return Future<void>.value();
}

Future<void> _expectDirtyReleaseFailureIsContained() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final snapshots = <CanvasRuntimeState>[];
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });
  root.attachResourceSessionReleaseSink(_ThrowingResourceSessionReleaseSink());

  root.resources.markResourceDirty(CanvasResourceId('resource-a'));

  expect(snapshots, hasLength(1));
  expect(root.state.value.revisions.resourceVisual, 1);
  expect(effectBatches, hasLength(1));
  expect(
    () => root.resources.markResourceDirty(CanvasResourceId('resource-a')),
    returnsNormally,
  );
  root.dispose();

  return Future<void>.value();
}

Future<void> _expectEditResourceEffectsInvalidateBeforePublish() {
  _expectEditUpsertResourceInvalidatesBeforePublish();
  _expectEditRemoveResourceInvalidatesBeforePublish();

  return Future<void>.value();
}

void _expectEditUpsertResourceInvalidatesBeforePublish() {
  final sink = _RecordingResourceSessionReleaseSink();
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: (_) {
      sink.expectTargetReleased(CanvasResourceId('resource-a'));
    },
  );
  root.attachResourceSessionReleaseSink(sink);
  root.state.addListener(() {
    sink.expectTargetReleased(CanvasResourceId('resource-a'));
  });

  final changed = root.edits.edit((edit) {
    return edit.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('resource-a-updated'),
      ),
    );
  });

  expect(changed, isTrue);
  expect(sink.releasedIds, [CanvasResourceId('resource-a')]);
  expect(sink.releaseAllCount, 0);
  root.dispose();
}

void _expectEditRemoveResourceInvalidatesBeforePublish() {
  final sink = _RecordingResourceSessionReleaseSink();
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: (_) {
      sink.expectTargetReleased(CanvasResourceId('resource-a'));
    },
  );
  root.attachResourceSessionReleaseSink(sink);
  root.state.addListener(() {
    sink.expectTargetReleased(CanvasResourceId('resource-a'));
  });

  final changed = root.edits.edit((edit) {
    return edit.removeUnusedResource(CanvasResourceId('resource-a'));
  });

  expect(changed, isTrue);
  expect(sink.releasedIds, [CanvasResourceId('resource-a')]);
  expect(sink.releaseAllCount, 0);
  root.dispose();
}

// Release failure, ownership drop, frame/state continuation, and no retry are
// one accepted-edit resource contract, so splitting would hide the ordering.
// ignore: halstead-volume
void _expectEditResourceReleaseFailureIsContained() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final snapshots = <CanvasRuntimeState>[];
  final frames = <Object>[];
  final sink = _ThrowingResourceSessionReleaseSink();
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });
  root.attachSurface(Object());
  root.surfaceFrameSignal.addListener(() {
    final frame = root.surfaceFrameSignal.value;
    if (frame == null) return;
    expect(sink.releaseCalls, 1);
    frames.add(frame);
  });
  root.attachResourceSessionReleaseSink(sink);

  final changed = _upsertResourceA(root);

  expect(changed, isTrue);
  expect(sink.releaseCalls, 1);
  expect(frames, hasLength(1));
  expect(snapshots, hasLength(1));
  expect(effectBatches, hasLength(1));
  _expectUpdatedResourceASource(root);
  _expectDirtyAfterFailedSinkIsDropped(root);
  expect(sink.releaseCalls, 1);
  root.dispose();
}

bool _upsertResourceA(RuntimeRoot root) {
  return root.edits.edit((edit) {
    return edit.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('resource-a-updated'),
      ),
    );
  });
}

void _expectUpdatedResourceASource(RuntimeRoot root) {
  final updatedSource = root.resources.resources.single.source;
  expect(updatedSource, isA<CanvasAppKeyResourceSource>());
  expect(
    (updatedSource as CanvasAppKeyResourceSource).key,
    'resource-a-updated',
  );
}

void _expectDirtyAfterFailedSinkIsDropped(RuntimeRoot root) {
  expect(
    () => root.resources.markResourceDirty(CanvasResourceId('resource-a')),
    returnsNormally,
  );
}

// Each case is one ordered common-delivery failure witness.
// ignore: halstead-volume
Future<void> _expectRealTargetFailure() async {
  final probe = await _RealSessionFailureProbe.create(throwTarget: true);
  final actions = <CanvasActionCommitted>[];
  final subscription = probe.root.actions.listen((action) {
    probe.events.add('action');
    actions.add(action);
  });
  try {
    final result = probe.root.commands.clearContent(
      removeUnusedResources: true,
      timestampMs: 41,
    );
    expect(result.didClearContent, isTrue);
    expect(result.removedElementIds, [CanvasElementId('image-a')]);
    expect(result.removedResourceIds, [CanvasResourceId('resource-a')]);
    _expectRealFailureDelivery(probe, actions, ['target', 'all']);
    expect(probe.targetCalls, 1);
    expect(probe.allCalls, 1);
    probe.root.edits.edit((edit) {
      edit.addElement(
        CanvasRectElement(
          id: CanvasElementId('later-a'),
          size: const Size(1, 1),
        ),
        layerId: CanvasLayerId('layer-a'),
      );
    });
    expect((probe.targetCalls, probe.allCalls), (1, 1));
  } finally {
    await subscription.cancel();
    probe.dispose();
  }
}

// The all-release and drop callbacks must stay in one lifecycle witness.
// ignore: halstead-volume
Future<void> _expectRealAllFailure() async {
  final probe = await _RealSessionFailureProbe.create();
  final actions = <CanvasActionCommitted>[];
  final subscription = probe.root.actions.listen((action) {
    probe.events.add('action');
    actions.add(action);
  });
  try {
    probe.root.deliverCommitPlanForTesting(
      CommitPlan(
        revisionDelta: const StoreRevisionDelta.resource(),
        touchedSet: TouchedSet(allResourceVisualsChanged: true),
        effects: [
          ResourceEffect(
            touchedSet: TouchedSet(allResourceVisualsChanged: true),
          ),
          const RepaintEffect(mainCanvas: true),
          const PublicStateEffect(),
        ],
        actionIntents: [
          DeleteSelectionActionIntent(
            removedElementIds: [CanvasElementId('image-a')],
          ),
        ],
      ),
      document: probe.root.readDocument(),
    );
    _expectRealFailureDelivery(probe, actions, ['all', 'all']);
    expect(probe.allCalls, 2);
    expect(probe.root.state.value.revisions.document, 1);
    expect(_upsertResourceA(probe.root), isTrue);
    expect(probe.allCalls, 2);
    probe.root.generateElementId();
    expect(probe.allCalls, 2);
  } finally {
    await subscription.cancel();
    probe.dispose();
  }
}

// Replacement reset and its failing drop are one accepted-delivery outcome.
// ignore: halstead-volume
Future<void> _expectRealResetFailure() async {
  final probe = await _RealSessionFailureProbe.create();
  final actions = <CanvasActionCommitted>[];
  final subscription = probe.root.actions.listen((action) {
    probe.events.add('action');
    actions.add(action);
  });
  final replacement = _documentWithUnusedResource();
  try {
    probe.root.deliverCommitPlanForTesting(
      CommitPlan(
        revisionDelta: const StoreRevisionDelta.documentReplacement(),
        touchedSet: TouchedSet(documentReplaced: true),
        effects: [
          ResourceEffect(touchedSet: TouchedSet(documentReplaced: true)),
          const RepaintEffect(mainCanvas: true, overlayCanvas: true),
          const PublicStateEffect(),
        ],
        actionIntents: [
          DeleteSelectionActionIntent(
            removedElementIds: [CanvasElementId('image-a')],
          ),
        ],
      ),
      document: replacement,
    );
    _expectRealFailureDelivery(probe, actions, ['all', 'all']);
    expect(probe.allCalls, 2);
    expect(
      probe.root.readDocument().resources.map((resource) => resource.id),
      replacement.resources.map((resource) => resource.id),
    );
    expect(_upsertResourceA(probe.root), isTrue);
    expect(probe.allCalls, 2);
    probe.root.generateElementId();
    expect(probe.allCalls, 2);
  } finally {
    await subscription.cancel();
    probe.dispose();
  }
}

void _expectRealFailureDelivery(
  _RealSessionFailureProbe probe,
  List<CanvasActionCommitted> actions,
  List<String> releases,
) {
  expect(probe.events, [
    ...releases.map((value) => 'resource-$value'),
    'frame',
    'state',
    'action',
    'observer',
  ]);
  expect(actions, hasLength(1));
  _expectNoBorrow(probe.cache, probe.output);
  expect(probe.root.activeSurfaceResourceSessionForTesting, isNull);
  expect(probe.root.generateElementId(), CanvasElementId('e0'));
}

final class _RealSessionFailureProbe {
  _RealSessionFailureProbe._(this.root, this.cache, this.output, this.image);

  final RuntimeRoot root;
  final ResourceAssetCache cache;
  final _RetainedOutputProbe output;
  final Image image;
  final List<String> events = [];
  int targetCalls = 0;
  int allCalls = 0;

  // This setup keeps the real cache/output and failed lifecycle drop together.
  // ignore: halstead-volume
  static Future<_RealSessionFailureProbe> create({
    bool throwTarget = false,
  }) async {
    final image = await createResourceTestImage();
    final cache = ResourceAssetCache();
    final output = _RetainedOutputProbe()..retain('resource-a');
    late _RealSessionFailureProbe probe;
    final root = runtimeRootWithCommittedDocumentSeed(
      _documentWithResource(),
      config: const CanvasRuntimeConfig(),
      commitEffectObserver: (_) => probe.events.add('observer'),
    );
    probe = _RealSessionFailureProbe._(root, cache, output, image);
    final token = Object();
    root.attachSurface(token);
    root.surfaceFrameSignal.addListener(() => probe.events.add('frame'));
    root.state.addListener(() => probe.events.add('state'));
    final session = SurfaceResourceSession(
      resolver: RecordingResourceResolver((_) => image),
      mutationGuard: root,
      cache: cache,
      releaseRetainedResources: (_) {
        probe.targetCalls += 1;
        probe.events.add('resource-target');
        output.release('resource-a');
        if (throwTarget) throw StateError('target release failed');
      },
      releaseAllRetainedResources: () {
        probe.allCalls += 1;
        probe.events.add('resource-all');
        output.releaseAll();
        throw StateError('all release failed');
      },
    );
    root.installSurfaceResourceSession(token, session);
    session.resolveResource(descriptorRequest(id: 'resource-a'));
    return probe;
  }

  void dispose() {
    image.dispose();
    root.dispose();
  }
}

Future<void> _expectClearedActiveSessionIsIgnored() {
  final sink = _RecordingResourceSessionReleaseSink();
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
  );
  root.attachResourceSessionReleaseSink(sink);
  root.clearResourceSessionReleaseSink(sink);

  root.resources.markResourceDirty(CanvasResourceId('resource-a'));
  root.resources.markAllResourcesDirty();

  expect(root.state.value.revisions.resourceVisual, 2);
  expect(sink.releasedIds, isEmpty);
  expect(sink.releaseAllCount, 0);
  root.dispose();

  return Future<void>.value();
}

// This proof keeps the runtime, state snapshots, effects, and action stream in
// one scenario so dirty acceptance can be checked as one all-or-nothing event.
// Splitting it would hide the ordering guarantee behind fixture plumbing.
// ignore: coupling-between-object-classes
final class _DirtyRuntimeScenario {
  _DirtyRuntimeScenario.withDocument(CanvasDocument document) {
    root = runtimeRootWithCommittedDocumentSeed(
      document,
      config: const CanvasRuntimeConfig(),
      commitEffectObserver: effectBatches.add,
    );
    before = _RuntimeFactsSnapshot.capture(root);
    _cancelActions = root.actions.listen(actions.add).cancel;
    root.state.addListener(() {
      snapshots.add(root.state.value);
    });
  }

  late final RuntimeRoot root;
  late final _RuntimeFactsSnapshot before;
  late final Future<void> Function() _cancelActions;
  final List<CanvasRuntimeState> snapshots = [];
  final List<List<CommitDeliveryEffect>> effectBatches = [];
  final List<CanvasActionCommitted> actions = [];

  void expectOneSnapshotWithResourceVisual(int revision) {
    expect(snapshots, hasLength(1));
    expect(snapshots.single.revisions.resourceVisual, revision);
    expect(root.state.value.revisions.resourceVisual, revision);
  }

  void expectOnlyResourceVisualChanged() {
    final current = root.state.value;
    expect(current.revisions.document, before.state.revisions.document);
    expect(current.revisions.selection, before.state.revisions.selection);
    expect(current.revisions.preview, before.state.revisions.preview);
    expect(current.revisions.viewCamera, before.state.revisions.viewCamera);
    expect(current.revisions.interaction, before.state.revisions.interaction);
    expect(current.revisions.epoch, before.state.revisions.epoch);
    expect(root.frameRevisions.resourceRevision, before.resourceRevision);
    expect(root.readDocument(), same(before.document));
  }

  void expectTargetEffects(CanvasResourceId id) {
    final effects = _singleEffectBatch();
    final resourceEffect = effects.whereType<ResourceDeliveryEffect>().single;
    expect(resourceEffect.touchedSet.resourceVisualChangedIds, {id});
    expect(resourceEffect.touchedSet.allResourceVisualsChanged, isFalse);
    _expectMainRepaintOnly(effects);
  }

  void expectAllResourceEffects() {
    final effects = _singleEffectBatch();
    final resourceEffect = effects.whereType<ResourceDeliveryEffect>().single;
    expect(resourceEffect.touchedSet.resourceVisualChangedIds, isEmpty);
    expect(resourceEffect.touchedSet.allResourceVisualsChanged, isTrue);
    _expectMainRepaintOnly(effects);
  }

  Future<void> expectNoSideEffects() async {
    expect(snapshots, isEmpty);
    expect(effectBatches, isEmpty);
    await expectNoActions();
    before.expectStillCurrent(root);
  }

  Future<void> expectNoActions() async {
    await Future<void>.delayed(Duration.zero);
    expect(actions, isEmpty);
  }

  Future<void> cancelActionSubscription() => _cancelActions();

  Future<void> dispose() async {
    await cancelActionSubscription();
    root.dispose();
  }

  List<CommitDeliveryEffect> _singleEffectBatch() {
    expect(effectBatches, hasLength(1));

    return effectBatches.single;
  }
}

final class _RuntimeFactsSnapshot {
  const _RuntimeFactsSnapshot({
    required this.state,
    required this.document,
    required this.resourceRevision,
  });

  factory _RuntimeFactsSnapshot.capture(RuntimeRoot root) {
    return _RuntimeFactsSnapshot(
      state: root.state.value,
      document: root.readDocument(),
      resourceRevision: root.frameRevisions.resourceRevision,
    );
  }

  final CanvasRuntimeState state;
  final CanvasDocument document;
  final int resourceRevision;

  void expectStillCurrent(RuntimeRoot root) {
    expect(root.state.value, state);
    expect(root.readDocument(), same(document));
    expect(root.frameRevisions.resourceRevision, resourceRevision);
  }
}

void _expectMainRepaintOnly(List<CommitDeliveryEffect> effects) {
  expect(effects.whereType<ResourceDeliveryEffect>(), hasLength(1));
  final repaint = effects.whereType<RepaintDeliveryEffect>().single;
  expect(repaint.mainCanvas, isTrue);
  expect(repaint.overlayCanvas, isFalse);
  expect(effects.whereType<PublicStateDeliveryEffect>(), hasLength(1));
}

final class _RecordingResourceSessionReleaseSink
    implements ResourceSessionReleaseSink {
  final List<CanvasResourceId> releasedIds = [];
  int releaseAllCount = 0;

  @override
  void releaseResource(CanvasResourceId id) {
    releasedIds.add(id);
  }

  @override
  void releaseResources(Set<CanvasResourceId> ids) {
    releasedIds.addAll(ids);
  }

  @override
  void releaseAllResources() {
    releaseAllCount += 1;
  }

  void expectTargetReleased(CanvasResourceId id) {
    expect(releasedIds, contains(id));
  }
}

final class _ThrowingResourceSessionReleaseSink
    implements ResourceSessionReleaseSink {
  int releaseCalls = 0;

  @override
  void releaseResource(CanvasResourceId id) {
    releaseCalls += 1;
    throw StateError('resource release failed');
  }

  @override
  void releaseResources(Set<CanvasResourceId> ids) {
    releaseCalls += 1;
    throw StateError('resource release failed');
  }

  @override
  void releaseAllResources() {
    releaseCalls += 1;
    throw StateError('resource release failed');
  }
}

final class _RetainedOutputProbe {
  final Set<String> _borrowedIds = {};

  void retain(String id) {
    _borrowedIds.add(id);
  }

  void release(String id) {
    _borrowedIds.remove(id);
  }

  void releaseAll() {
    _borrowedIds.clear();
  }

  bool hasBorrow(String id) => _borrowedIds.contains(id);
}

Future<void> _expectDisposedGuard() async {
  final scenario = _DirtyRuntimeScenario.withDocument(_documentWithResource());
  scenario.root.dispose();

  expect(
    () => scenario.root.resources.markResourceDirty(
      CanvasResourceId('resource-a'),
    ),
    throwsStateError,
  );
  expect(scenario.root.resources.markAllResourcesDirty, throwsStateError);
  expect(scenario.snapshots, isEmpty);
  expect(scenario.effectBatches, isEmpty);
  await scenario.expectNoActions();
  await scenario.cancelActionSubscription();
}

Future<void> _expectActiveEditGuard() async {
  final scenario = _DirtyRuntimeScenario.withDocument(_documentWithResource());

  scenario.root.edits.edit((_) {
    expect(
      () => scenario.root.resources.markResourceDirty(
        CanvasResourceId('resource-a'),
      ),
      throwsStateError,
    );
    expect(scenario.root.resources.markAllResourcesDirty, throwsStateError);
  });

  await scenario.expectNoSideEffects();
  await scenario.dispose();
}

void _expectPostCommitDeliveryGuard() {
  final effects = <List<CommitDeliveryEffect>>[];
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: (batch) {
      effects.add(batch);
      expect(
        () => root.resources.markResourceDirty(CanvasResourceId('resource-a')),
        throwsStateError,
      );
      expect(root.resources.markAllResourcesDirty, throwsStateError);
    },
  );

  root.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(
        id: CanvasElementId('element-a'),
        size: const Size(1, 1),
      ),
      layerId: CanvasLayerId('layer-a'),
    );
  });

  expect(effects, hasLength(1));
  expect(root.state.value.revisions.resourceVisual, 0);
}

Future<void> _expectResolverCallbackGuard() async {
  final scenario = _DirtyRuntimeScenario.withDocument(_documentWithResource());

  scenario.root.runResolverCallback(() {
    expect(
      () => scenario.root.resources.markResourceDirty(
        CanvasResourceId('resource-a'),
      ),
      throwsStateError,
    );
    expect(scenario.root.resources.markAllResourcesDirty, throwsStateError);
  });

  await scenario.expectNoSideEffects();
  await scenario.dispose();
}

CanvasDocument _documentWithResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('resource-a'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithUnusedResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('resource-a'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}
