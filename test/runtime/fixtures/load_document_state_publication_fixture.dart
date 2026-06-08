import 'dart:convert';
import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/load_interaction_boundary.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _registerSuccessfulLoadPublicationTests();
  _registerFailedLoadPublicationTests();
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
}

void _registerFailedLoadPublicationTests() {
  test('malformed JSON load leaves runtime facts unchanged', () {
    expect(
      () => _expectFailedLoadHasNoSideEffects(
        '{',
        CanvasDataErrorCode.invalidJson,
      ),
      returnsNormally,
    );
  });

  test('schema version failure leaves runtime facts unchanged', () {
    expect(
      () => _expectFailedLoadHasNoSideEffects(
        jsonEncode({'schemaVersion': 2}),
        CanvasDataErrorCode.unsupportedSchemaVersion,
      ),
      returnsNormally,
    );
  });

  test('import event failure leaves runtime facts unchanged', () {
    expect(
      () => _expectFailedLoadHasNoSideEffects(
        _jsonWithImportFieldFailure(),
        CanvasDataErrorCode.missingField,
      ),
      returnsNormally,
    );
  });

  test('store preparation failure leaves runtime facts unchanged', () {
    expect(
      () => _expectFailedLoadHasNoSideEffects(
        _jsonWithDuplicateElements(),
        CanvasDataErrorCode.duplicateElementId,
      ),
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
  _expectReplacementDocumentInstalled(root);
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
  expect(state.revisions.selection, 2);
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
  });

  factory _RuntimeFactsSnapshot.capture(RuntimeRoot root) {
    return _RuntimeFactsSnapshot(
      state: root.state.value,
      document: root.readDocument(),
      selection: root.selectedElementIds,
      cameraOffset: root.cameraPort().offset,
      preview: root.preview,
    );
  }

  final CanvasRuntimeState state;
  final CanvasDocument document;
  final Set<CanvasElementId> selection;
  final Offset cameraOffset;
  final CanvasPreviewState preview;

  void expectStillCurrent(RuntimeRoot root) {
    expect(root.state.value, state);
    expect(root.readDocument(), same(document));
    expect(root.selectedElementIds, selection);
    expect(root.cameraPort().offset, cameraOffset);
    expect(root.preview, same(preview));
  }
}

final class _PreviewChangedLoadBoundary implements LoadInteractionBoundary {
  const _PreviewChangedLoadBoundary();

  @override
  LoadInteractionCleanupOutcome prepareLoadCleanup() {
    return const LoadInteractionCleanupOutcome(previewChanged: true);
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
