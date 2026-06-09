import 'dart:async';
import 'dart:io';
import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resource_session_invalidation_sink.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _registerDirtyAcceptanceTests();
  _registerDirtyGuardTests();
  _registerSessionInvalidationTests();
  _registerBoundaryTests();
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
}

void _registerSessionInvalidationTests() {
  test('active session invalidates before dirty publication', () {
    return expectLater(
      _expectActiveSessionInvalidatesBeforePublish(),
      completes,
    );
  });

  test('dirty invalidation failure drops sink after publication', () {
    return expectLater(_expectDirtyInvalidationFailureIsContained(), completes);
  });

  test(
    'edit resource effects invalidate active session before publication',
    () {
      return expectLater(
        _expectEditResourceEffectsInvalidateBeforePublish(),
        completes,
      );
    },
  );

  test('edit resource invalidation failure drops sink after publication', () {
    expect(_expectEditResourceInvalidationFailureIsContained, returnsNormally);
  });

  test('cleared active session is not mutated by later dirty calls', () {
    return expectLater(_expectClearedActiveSessionIsIgnored(), completes);
  });
}

void _registerBoundaryTests() {
  test('resource kernel does not import session invalidation sink', () {
    expect(
      _resourceKernelSource(),
      isNot(contains('ResourceSessionInvalidationSink')),
    );
    expect(
      _resourceKernelSource(),
      isNot(contains('resource_session_invalidation_sink')),
    );
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

Future<void> _expectActiveSessionInvalidatesBeforePublish() {
  final sink = _RecordingResourceSessionInvalidationSink();
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: (_) {
      sink.expectTargetInvalidated(CanvasResourceId('resource-a'));
    },
  );
  root.attachResourceSessionInvalidationSink(sink);
  root.state.addListener(() {
    sink.expectTargetInvalidated(CanvasResourceId('resource-a'));
  });

  root.resources.markResourceDirty(CanvasResourceId('resource-a'));

  expect(sink.targetInvalidations, [CanvasResourceId('resource-a')]);
  expect(sink.allInvalidationCount, 0);
  root.dispose();

  return Future<void>.value();
}

Future<void> _expectDirtyInvalidationFailureIsContained() {
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
  root.attachResourceSessionInvalidationSink(
    _ThrowingResourceSessionInvalidationSink(),
  );

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
  final sink = _RecordingResourceSessionInvalidationSink();
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: (_) {
      sink.expectTargetInvalidated(CanvasResourceId('resource-a'));
    },
  );
  root.attachResourceSessionInvalidationSink(sink);
  root.state.addListener(() {
    sink.expectTargetInvalidated(CanvasResourceId('resource-a'));
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
  expect(sink.targetInvalidations, [CanvasResourceId('resource-a')]);
  expect(sink.allInvalidationCount, 0);
  root.dispose();
}

void _expectEditRemoveResourceInvalidatesBeforePublish() {
  final sink = _RecordingResourceSessionInvalidationSink();
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: (_) {
      sink.expectTargetInvalidated(CanvasResourceId('resource-a'));
    },
  );
  root.attachResourceSessionInvalidationSink(sink);
  root.state.addListener(() {
    sink.expectTargetInvalidated(CanvasResourceId('resource-a'));
  });

  final changed = root.edits.edit((edit) {
    return edit.removeUnusedResource(CanvasResourceId('resource-a'));
  });

  expect(changed, isTrue);
  expect(sink.targetInvalidations, [CanvasResourceId('resource-a')]);
  expect(sink.allInvalidationCount, 0);
  root.dispose();
}

void _expectEditResourceInvalidationFailureIsContained() {
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
  root.attachResourceSessionInvalidationSink(
    _ThrowingResourceSessionInvalidationSink(),
  );

  final changed = _upsertResourceA(root);

  expect(changed, isTrue);
  expect(snapshots, hasLength(1));
  expect(effectBatches, hasLength(1));
  _expectUpdatedResourceASource(root);
  _expectDirtyAfterFailedSinkIsDropped(root);
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

Future<void> _expectClearedActiveSessionIsIgnored() {
  final sink = _RecordingResourceSessionInvalidationSink();
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithResource(),
    config: const CanvasRuntimeConfig(),
  );
  root.attachResourceSessionInvalidationSink(sink);
  root.clearResourceSessionInvalidationSink(sink);

  root.resources.markResourceDirty(CanvasResourceId('resource-a'));
  root.resources.markAllResourcesDirty();

  expect(root.state.value.revisions.resourceVisual, 2);
  expect(sink.targetInvalidations, isEmpty);
  expect(sink.allInvalidationCount, 0);
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
    subscription = root.actions.listen(actions.add);
    root.state.addListener(() {
      snapshots.add(root.state.value);
    });
  }

  late final RuntimeRoot root;
  late final _RuntimeFactsSnapshot before;
  late final StreamSubscription<CanvasActionCommitted> subscription;
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

  Future<void> dispose() async {
    await subscription.cancel();
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

String _resourceKernelSource() {
  return File('lib/src/resources/resource_kernel.dart').readAsStringSync();
}

final class _RecordingResourceSessionInvalidationSink
    implements ResourceSessionInvalidationSink {
  final List<CanvasResourceId> targetInvalidations = [];
  int allInvalidationCount = 0;

  @override
  void invalidateResourceImage(CanvasResourceId id) {
    targetInvalidations.add(id);
  }

  @override
  void invalidateAllResourceImages() {
    allInvalidationCount += 1;
  }

  void expectTargetInvalidated(CanvasResourceId id) {
    expect(targetInvalidations, contains(id));
  }
}

final class _ThrowingResourceSessionInvalidationSink
    implements ResourceSessionInvalidationSink {
  @override
  void invalidateResourceImage(CanvasResourceId id) {
    throw StateError('resource invalidation failed');
  }

  @override
  void invalidateAllResourceImages() {
    throw StateError('resource invalidation failed');
  }
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
  await scenario.subscription.cancel();
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
