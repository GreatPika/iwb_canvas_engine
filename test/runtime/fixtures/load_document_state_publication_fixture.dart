import 'dart:convert';
import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/load_interaction_boundary.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/surface_resource_session_lifecycle.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_contract_limits.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _registerSuccessfulLoadPublicationTests();
  _registerFailedLoadFactPreservationTests();
  _registerResourceRelationshipFactPreservationTests();
  _registerFailedLoadSessionTests();
}

void _registerSuccessfulLoadPublicationTests() {
  test('successful load publishes one post-install state and effects', () {
    expect(_expectSuccessfulLoadStatePublication, returnsNormally);
  });

  test('successful load records selection clear when already empty', () {
    expect(_expectSuccessfulLoadClearsEmptySelection, returnsNormally);
  });

  test('successful load publishes prepared cleanup preview outcome', () {
    expect(_expectSuccessfulLoadPublishesPreviewCleanup, returnsNormally);
  });

  test('successful load releases active resource session before publish', () {
    expect(_expectSuccessfulLoadReleasesActiveResourceSession, returnsNormally);
  });

  test('successful load drops failed resource session after publish', () {
    expect(_expectSuccessfulLoadDropsFailedResourceSession, returnsNormally);
  });

  test('successful load attributes reset failure to surface session', () {
    expect(
      _expectSuccessfulLoadDropsFailedSessionWithDifferentSink,
      returnsNormally,
    );
  });
}

void _registerFailedLoadFactPreservationTests() {
  _registerFailedLoadCase(
    'oversized raw JSON',
    () => ' ' * (canvasMaxRawJsonLength + 1),
    CanvasDataErrorCode.maxRawJsonLength,
  );
  _registerFailedLoadCase(
    'malformed JSON',
    () => '{',
    CanvasDataErrorCode.invalidJson,
  );
  _registerFailedLoadCase(
    'non-object JSON',
    () => jsonEncode(<Object?>[]),
    CanvasDataErrorCode.invalidJson,
  );
  _registerFailedLoadCase(
    'schema version',
    () => jsonEncode({'schemaVersion': 2}),
    CanvasDataErrorCode.unsupportedSchemaVersion,
  );
  _registerFailedLoadCase(
    'import event',
    _jsonWithImportFieldFailure,
    CanvasDataErrorCode.missingField,
  );
  _registerFailedLoadCase(
    'missing resource reference',
    _jsonWithMissingResourceReference,
    CanvasDataErrorCode.missingResourceReference,
  );
  _registerFailedLoadCase(
    'store preparation',
    _jsonWithDuplicateElements,
    CanvasDataErrorCode.duplicateElementId,
  );
}

void _registerResourceRelationshipFactPreservationTests() {
  test(
    'wrong vector resource kind leaves runtime output and facts unchanged',
    () {
      expect(_expectWrongVectorResourceKindHasNoSideEffects, returnsNormally);
    },
  );
  test('missing vector resource leaves runtime output and facts unchanged', () {
    expect(
      _expectMissingVectorResourceReferenceHasNoSideEffects,
      returnsNormally,
    );
  });
  test(
    'wrong image resource kind leaves runtime output and facts unchanged',
    () {
      expect(_expectWrongImageResourceKindHasNoSideEffects, returnsNormally);
    },
  );
}

void _registerFailedLoadCase(
  String boundary,
  String Function() json,
  CanvasDataErrorCode expectedCode,
) {
  test('$boundary failure leaves runtime facts unchanged', () {
    expect(
      () => _expectFailedLoadHasNoSideEffects(json(), expectedCode),
      returnsNormally,
    );
  });
}

void _registerFailedLoadSessionTests() {
  test('failed load does not release active resource session', () {
    expect(
      _expectFailedLoadDoesNotReleaseActiveResourceSession,
      returnsNormally,
    );
  });
}

void _expectSuccessfulLoadStatePublication() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.selection.setSelection([CanvasElementId('old-element')]);
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });

  root.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_replacementDocument()),
  );

  expect(snapshots, hasLength(1));
  expect(root.projectionBuildCount, 0);
  _expectReplacementDocumentInstalled(root);
  expect(root.projectionBuildCount, 1);
  _expectReplacementState(snapshots.single);
  _expectLoadEffects(effectBatches.single);
}

void _expectSuccessfulLoadClearsEmptySelection() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);

  root.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_replacementDocument()),
  );

  expect(root.state.value.revisions.selection, 1);
  _expectLoadEffects(effectBatches.single);
}

void _expectSuccessfulLoadPublishesPreviewCleanup() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(
    effectBatches,
    loadInteractionBoundary: const _PreviewChangedLoadBoundary(),
  );
  root.selection.setSelection([CanvasElementId('old-element')]);
  root.replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(2, 3)),
  );
  final beforePreviewRevision = root.state.value.revisions.preview;
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });

  root.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_replacementDocument()),
  );

  expect(snapshots, hasLength(1));
  final loadedState = snapshots.single;
  _expectReplacementDocumentInstalled(root);
  _expectReplacementState(
    loadedState,
    expectedPreviewRevision: beforePreviewRevision + 1,
  );
  expect(loadedState.revisions.preview, beforePreviewRevision + 1);
  expect(effectBatches, hasLength(1));
  _expectLoadEffects(effectBatches.single);
}

void _expectSuccessfulLoadReleasesActiveResourceSession() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  final token = Object();
  final session = _RecordingLifecycleSession();
  root.attachSurface(token);
  root.installSurfaceResourceSession(token, session);
  root.state.addListener(() {
    expect(session.replacementResetCount, 1);
  });

  root.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_replacementDocument()),
  );

  expect(session.replacementResetCount, 1);
  expect(session.releaseAllCount, 0);
  expect(session.releasedIds, isEmpty);
  expect(effectBatches, hasLength(1));
  root.dispose();
}

void _expectSuccessfulLoadDropsFailedResourceSession() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  final token = Object();
  final session = _ThrowingResetLifecycleSession();
  final snapshots = <CanvasRuntimeState>[];
  root.attachSurface(token);
  root.installSurfaceResourceSession(token, session);
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });

  root.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_replacementDocument()),
  );

  expect(snapshots, hasLength(1));
  _expectReplacementDocumentInstalled(root);
  _expectReplacementState(snapshots.single, expectedSelectionRevision: 1);
  expect(effectBatches, hasLength(1));
  expect(session.dropCount, 1);
  expect(root.activeSurfaceResourceSessionForTesting, isNull);
  root.dispose();
}

void _expectSuccessfulLoadDropsFailedSessionWithDifferentSink() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  final token = Object();
  final session = _ThrowingResetLifecycleSession();
  final sink = _RecordingLifecycleSession();
  root.attachSurface(token);
  root.installSurfaceResourceSession(token, session);
  root.attachResourceSessionReleaseSink(sink);

  root.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_replacementDocument()),
  );

  _expectReplacementDocumentInstalled(root);
  expect(effectBatches, hasLength(1));
  expect(session.dropCount, 1);
  expect(sink.dropCount, 0);
  expect(sink.releaseAllCount, 0);
  expect(root.activeSurfaceResourceSessionForTesting, isNull);
  root.dispose();
}

void _expectFailedLoadHasNoSideEffects(
  String json,
  CanvasDataErrorCode expectedCode,
) {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.selection.setSelection([CanvasElementId('old-element')]);
  root.cameraPort().setOffset(const Offset(3, 4));
  root.replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(1, 2)),
  );
  final before = _RuntimeFactsSnapshot.capture(root);
  final snapshots = <CanvasRuntimeState>[];
  final actionEvents = <CanvasActionCommitted>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });
  root.actions.listen(actionEvents.add);
  effectBatches.clear();

  _expectLoadRejected(root, json, expectedCode);

  expect(snapshots, isEmpty);
  expect(actionEvents, isEmpty);
  expect(effectBatches, isEmpty);
  before.expectStillCurrent(root);
  expect(root.generateElementId(), CanvasElementId('e0'));
}

void _expectWrongVectorResourceKindHasNoSideEffects() {
  _expectResourceRelationshipLoadHasNoSideEffects(
    _jsonWithWrongVectorResourceKind(),
    CanvasDataErrorCode.resourceKindMismatch,
    'vector.resourceId',
  );
}

void _expectMissingVectorResourceReferenceHasNoSideEffects() {
  _expectResourceRelationshipLoadHasNoSideEffects(
    _jsonWithMissingVectorResourceReference(),
    CanvasDataErrorCode.missingResourceReference,
    'vector.resourceId',
  );
}

void _expectWrongImageResourceKindHasNoSideEffects() {
  _expectResourceRelationshipLoadHasNoSideEffects(
    _jsonWithWrongImageResourceKind(),
    CanvasDataErrorCode.resourceKindMismatch,
    'image.resourceId',
  );
}

void _expectResourceRelationshipLoadHasNoSideEffects(
  String json,
  CanvasDataErrorCode expectedCode,
  String expectedPath,
) {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  root.attachSurface(Object());
  root.selection.setSelection([CanvasElementId('old-element')]);
  root.publishUnclassifiedRuntimeStateForTesting();
  final before = _RuntimeFactsSnapshot.capture(root);
  final beforeOutput = root.surfaceFrameSignal.value;
  effectBatches.clear();

  expect(
    () => root.edits.loadDocumentFromJson(json),
    throwsA(
      isA<CanvasDataException>()
          .having((error) => error.code, 'code', expectedCode)
          .having((error) => error.path, 'path', expectedPath),
    ),
  );
  before.expectStillCurrent(root);
  expect(root.surfaceFrameSignal.value, same(beforeOutput));
  expect(effectBatches, isEmpty);
  root.dispose();
}

void _expectFailedLoadDoesNotReleaseActiveResourceSession() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  final token = Object();
  final session = _RecordingLifecycleSession();
  root.attachSurface(token);
  root.installSurfaceResourceSession(token, session);

  _expectLoadRejected(root, '{', CanvasDataErrorCode.invalidJson);

  expect(session.releasedIds, isEmpty);
  expect(session.releaseAllCount, 0);
  expect(session.replacementResetCount, 0);
  expect(root.state.value.revisions.document, 0);
  expect(effectBatches, isEmpty);
  root.dispose();
}

void _expectLoadRejected(
  RuntimeRoot root,
  String json,
  CanvasDataErrorCode expectedCode,
) {
  expect(
    () => root.edits.loadDocumentFromJson(json),
    throwsA(
      isA<CanvasDataException>().having(
        (error) => error.code,
        'code',
        expectedCode,
      ),
    ),
  );
}

RuntimeRoot _runtimeRoot(
  List<List<CommitDeliveryEffect>> effectBatches, {
  LoadInteractionBoundary? loadInteractionBoundary,
}) {
  if (loadInteractionBoundary != null) {
    return runtimeRootWithCommittedDocumentSeed(
      _initialDocument(),
      config: const CanvasRuntimeConfig(),
      loadInteractionBoundary: loadInteractionBoundary,
      commitEffectObserver: effectBatches.add,
    );
  }

  return runtimeRootWithCommittedDocumentSeed(
    _initialDocument(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
}

void _expectReplacementDocumentInstalled(RuntimeRoot root) {
  expect(root.readDocument().backgroundElements.single.id.value, 'new-bg');
  expect(root.readDocument().layers.single.elements.single.id.value, 'new-el');
  expect(root.readDocument().resources.single.id.value, 'new-resource');
  expect(root.selectedElementIds, isEmpty);
  expect(root.cameraPort().offset, const Offset(7, 9));
  expect(root.generateElementId(), CanvasElementId('e0'));
}

void _expectReplacementState(
  CanvasRuntimeState state, {
  int expectedSelectionRevision = 2,
  int expectedPreviewRevision = 0,
}) {
  expect(
    state.summary,
    const CanvasRuntimeSummary(
      elementCount: 2,
      layerCount: 1,
      resourceCount: 1,
      selectedCount: 0,
    ),
  );
  expect(state.revisions.document, 1);
  expect(state.revisions.selection, expectedSelectionRevision);
  expect(state.revisions.viewCamera, 1);
  expect(state.revisions.epoch, 1);
  expect(state.revisions.preview, expectedPreviewRevision);
}

void _expectLoadEffects(List<CommitDeliveryEffect> effects) {
  expect(effects.whereType<ProjectionDeliveryEffect>(), hasLength(1));
  expect(effects.whereType<SpatialDeliveryEffect>(), hasLength(1));
  expect(effects.whereType<ResourceDeliveryEffect>(), hasLength(1));
  final repaintEffect = effects.whereType<RepaintDeliveryEffect>().single;
  expect(repaintEffect.mainCanvas, isTrue);
  expect(repaintEffect.overlayCanvas, isTrue);
  expect(effects.whereType<SelectionDeliveryEffect>(), hasLength(1));
  expect(effects.whereType<PublicStateDeliveryEffect>(), hasLength(1));
  expect(
    () => effects.add(const PublicStateDeliveryEffect()),
    throwsUnsupportedError,
  );
}

final class _RuntimeFactsSnapshot {
  const _RuntimeFactsSnapshot({
    required this.state,
    required this.document,
    required this.selection,
    required this.cameraOffset,
    required this.preview,
    required this.projectionBuildCount,
  });

  factory _RuntimeFactsSnapshot.capture(RuntimeRoot root) {
    return _RuntimeFactsSnapshot(
      state: root.state.value,
      document: root.readDocument(),
      selection: root.selectedElementIds,
      cameraOffset: root.cameraPort().offset,
      preview: root.preview,
      projectionBuildCount: root.projectionBuildCount,
    );
  }

  final CanvasRuntimeState state;
  final CanvasDocument document;
  final Set<CanvasElementId> selection;
  final Offset cameraOffset;
  final CanvasPreviewState preview;
  final int projectionBuildCount;

  void expectStillCurrent(RuntimeRoot root) {
    expect(root.state.value, state);
    expect(root.readDocument(), same(document));
    expect(root.selectedElementIds, selection);
    expect(root.cameraPort().offset, cameraOffset);
    expect(root.preview, same(preview));
    expect(root.projectionBuildCount, projectionBuildCount);
  }
}

final class _PreviewChangedLoadBoundary implements LoadInteractionBoundary {
  const _PreviewChangedLoadBoundary();

  @override
  LoadInteractionCleanupOutcome prepareLoadCleanup() {
    return const LoadInteractionCleanupOutcome(previewChanged: true);
  }
}

final class _RecordingLifecycleSession
    implements SurfaceResourceSessionLifecycle {
  final List<CanvasResourceId> releasedIds = [];
  int releaseAllCount = 0;
  int replacementResetCount = 0;
  int dropCount = 0;

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

  @override
  void resetForDocumentReplacement() {
    replacementResetCount += 1;
  }

  @override
  void drop() {
    dropCount += 1;
  }
}

final class _ThrowingResetLifecycleSession
    implements SurfaceResourceSessionLifecycle {
  int targetReleaseCount = 0;
  int releaseAllCount = 0;
  int dropCount = 0;

  @override
  void releaseResource(CanvasResourceId id) {
    targetReleaseCount += 1;
  }

  @override
  void releaseResources(Set<CanvasResourceId> ids) {
    targetReleaseCount += ids.length;
  }

  @override
  void releaseAllResources() {
    releaseAllCount += 1;
  }

  @override
  void resetForDocumentReplacement() {
    throw StateError('resource reset failed');
  }

  @override
  void drop() {
    dropCount += 1;
  }
}

CanvasDocument _initialDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('old-bg'), size: const Size(1, 1)),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('old-layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('old-element'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _replacementDocument() {
  return CanvasDocument(
    camera: CanvasCamera(offset: const Offset(7, 9)),
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('new-resource'),
        source: CanvasResourceSource.appKey('new-resource'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('new-bg'), size: const Size(1, 1)),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('new-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('new-el'),
            resourceId: CanvasResourceId('new-resource'),
            size: const Size(2, 2),
          ),
        ],
      ),
    ],
  );
}

String _jsonWithDuplicateElements() {
  return jsonEncode({
    'schemaVersion': 1,
    'backgroundLayer': {
      'elements': [
        {
          'id': 'duplicate',
          'kind': 'rect',
          'size': {'w': 1, 'h': 1},
          'strokeWidth': 0,
        },
      ],
    },
    'layers': [
      {
        'id': 'layer',
        'elements': [
          {
            'id': 'duplicate',
            'kind': 'rect',
            'size': {'w': 1, 'h': 1},
            'strokeWidth': 0,
          },
        ],
      },
    ],
  });
}

String _jsonWithMissingResourceReference() {
  return jsonEncode({
    'schemaVersion': 1,
    'resources': <Object?>[],
    'layers': [
      {
        'id': 'layer',
        'elements': [
          {
            'id': 'image',
            'kind': 'image',
            'resourceId': 'missing-resource',
            'size': {'w': 1, 'h': 1},
          },
        ],
      },
    ],
  });
}

String _jsonWithWrongVectorResourceKind() {
  return jsonEncode({
    'schemaVersion': 1,
    'resources': [
      {
        'id': 'image-resource',
        'kind': 'image',
        'source': {'kind': 'appKey', 'key': 'image-resource'},
      },
    ],
    'layers': [
      {
        'id': 'layer',
        'elements': [
          {
            'id': 'vector-element',
            'kind': 'vector',
            'resourceId': 'image-resource',
            'size': {'w': 1, 'h': 1},
          },
        ],
      },
    ],
  });
}

String _jsonWithMissingVectorResourceReference() {
  return jsonEncode({
    'schemaVersion': 1,
    'resources': <Object?>[],
    'layers': [
      {
        'id': 'layer',
        'elements': [
          {
            'id': 'vector-element',
            'kind': 'vector',
            'resourceId': 'missing-resource',
            'size': {'w': 1, 'h': 1},
          },
        ],
      },
    ],
  });
}

String _jsonWithWrongImageResourceKind() {
  return jsonEncode({
    'schemaVersion': 1,
    'resources': [
      {
        'id': 'vector-resource',
        'kind': 'vector',
        'source': {'kind': 'appKey', 'key': 'vector-resource'},
      },
    ],
    'layers': [
      {
        'id': 'layer',
        'elements': [
          {
            'id': 'image-element',
            'kind': 'image',
            'resourceId': 'vector-resource',
            'size': {'w': 1, 'h': 1},
          },
        ],
      },
    ],
  });
}

String _jsonWithImportFieldFailure() {
  return jsonEncode({
    'schemaVersion': 1,
    'backgroundLayer': {
      'elements': [
        {
          'id': 'invalid-rect',
          'kind': 'rect',
          'size': {'w': 1, 'h': 1},
        },
      ],
    },
  });
}
