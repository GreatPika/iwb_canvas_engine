import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

// This owner keeps every independently admitted edit outcome visibly
// registered at its public runtime boundary rather than hiding them behind a
// test-only inventory or dispatcher.
// ignore: halstead-volume, source-lines-of-code
void main() {
  test('field update admission and effects allow nullable clears', () {
    expect(_expectNullableClearUpdatesField, returnsNormally);
  });

  test('field update admission rejects dynamic non-nullable clears', () {
    expect(_expectDynamicNonNullableClearRejected, returnsNormally);
  });

  test('field update admission rejects non-invertible transforms', () {
    expect(_expectNonInvertibleTransformRejected, returnsNormally);
  });

  test('field update admission rejects mismatched update kinds', () {
    expect(_expectMismatchedUpdateKindRejected, returnsNormally);
  });

  test('field update effects advance geometry revisions', () {
    expect(_expectGeometryUpdateAdvancesBoundsRevision, returnsNormally);
  });

  test('field update effects request selection pruning', () {
    expect(_expectVisibilityUpdateTouchesSelection, returnsNormally);
  });

  test('vector sparse update preserves omitted fields', () {
    expect(_expectVectorSparseUpdatePreservesOmittedFields, returnsNormally);
  });

  test('resource edits reject an existing wrong vector resource kind', () {
    expect(_expectVectorResourceKindMismatchPreservesDocument, returnsNormally);
  });

  test(
    'resource and all references can change kind in either callback order',
    () {
      expect(_expectVectorKindTransitionInEitherCallbackOrder, returnsNormally);
    },
  );

  test('rejected vector resource edits preserve selected surface output', () {
    expect(
      _expectRejectedVectorResourceEditPreservesRuntimeFacts,
      returnsNormally,
    );
  });

  test('missing vector resource edits preserve selected surface output', () {
    expect(
      _expectMissingVectorResourceEditPreservesRuntimeFacts,
      returnsNormally,
    );
  });

  test('image elements reject vector resource edits without publication', () {
    expect(
      _expectImageToVectorResourceEditPreservesRuntimeFacts,
      returnsNormally,
    );
  });
}

void _expectNullableClearUpdatesField() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: const CanvasRuntimeConfig(),
  );

  final changed = root.edits.edit((edit) {
    return edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        fillColor: const CanvasFieldClear<Color>(),
      ),
    );
  });

  final rect = root.readDocument().layers.single.elements.single;
  expect(changed, isTrue);
  expect(rect, isA<CanvasRectElement>());
  expect((rect as CanvasRectElement).fillColor, isNull);
  expect(root.documentFacts.documentRevision, 1);
}

void _expectDynamicNonNullableClearRejected() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);
  final before = root.readDocument().layers.single.elements.single;

  expect(
    () => root.edits.edit((edit) {
      final Object clear = const CanvasFieldClear<double>();
      final update = CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        strokeWidth: clear as CanvasFieldUpdate<double>,
      );
      edit.updateElement(update);
    }),
    throwsA(anyOf(isA<TypeError>(), isA<CanvasDataException>())),
  );

  expect(root.readDocument().layers.single.elements.single, same(before));
  expect(root.documentFacts.documentRevision, 0);
  expect(effectBatches, isEmpty);
}

void _expectNonInvertibleTransformRejected() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);

  expect(
    () => root.edits.edit((edit) {
      edit.updateElement(
        CanvasRectElementUpdate(
          id: CanvasElementId('rect-1'),
          transform: CanvasFieldSet(
            CanvasTransform(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0),
          ),
        ),
      );
    }),
    throwsA(isA<CanvasDataException>()),
  );

  expect(root.documentFacts.documentRevision, 0);
  expect(effectBatches, isEmpty);
}

void _expectMismatchedUpdateKindRejected() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(effectBatches);

  expect(
    () => root.edits.edit((edit) {
      edit.updateElement(
        CanvasTextElementUpdate(
          id: CanvasElementId('rect-1'),
          text: const CanvasFieldSet('wrong kind'),
        ),
      );
    }),
    throwsArgumentError,
  );

  expect(root.documentFacts.documentRevision, 0);
  expect(effectBatches, isEmpty);
}

void _expectGeometryUpdateAdvancesBoundsRevision() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: const CanvasRuntimeConfig(),
  );

  final changed = root.edits.edit((edit) {
    return edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        size: const CanvasFieldSet(Size(2, 2)),
      ),
    );
  });

  expect(changed, isTrue);
  expect(root.documentFacts.documentRevision, 1);
  expect(root.frameRevisions.boundsRevision, 1);
  expect(root.frameRevisions.elementVisualRevision, 1);
}

void _expectVisibilityUpdateTouchesSelection() {
  final draft = DraftDocument(
    _document(),
    selectedElementIds: [CanvasElementId('rect-1')],
  );

  draft.updateElement(
    CanvasRectElementUpdate(
      id: CanvasElementId('rect-1'),
      isVisible: const CanvasFieldSet(false),
    ),
  );

  expect(draft.touchedSet.selection, isTrue);
  expect(draft.touchedSet.geometryElementIds, {CanvasElementId('rect-1')});
}

void _expectVectorSparseUpdatePreservesOmittedFields() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _vectorDocument(),
    config: const CanvasRuntimeConfig(),
  );

  final changed = root.edits.edit((edit) {
    return edit.updateElement(
      CanvasVectorElementUpdate(
        id: CanvasElementId('vector-1'),
        resourceId: CanvasFieldSet(CanvasResourceId('vector-resource-2')),
        size: const CanvasFieldSet(Size(30, 40)),
        naturalSize: const CanvasFieldClear<Size>(),
      ),
    );
  });

  final vector =
      root.readDocument().layers.single.elements.single as CanvasVectorElement;
  expect(changed, isTrue);
  expect(vector.resourceId, CanvasResourceId('vector-resource-2'));
  expect(vector.size, const Size(30, 40));
  expect(vector.naturalSize, isNull);
  expect(vector.opacity, 0.25);
  expect(vector.metadata, CanvasMetadata.fromMap({'kind': 'vector'}));
}

void _expectVectorResourceKindMismatchPreservesDocument() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _vectorDocument(),
    config: const CanvasRuntimeConfig(),
  );
  final before = root.readDocument();

  expect(
    () => root.edits.edit((edit) {
      edit.upsertResource(
        CanvasImageResource(
          id: CanvasResourceId('vector-resource-1'),
          source: CanvasResourceSource.appKey('vector-resource-1'),
        ),
      );
    }),
    throwsA(
      isA<CanvasDataException>()
          .having(
            (error) => error.code,
            'code',
            CanvasDataErrorCode.resourceKindMismatch,
          )
          .having((error) => error.path, 'path', 'vector.resourceId'),
    ),
  );
  expect(root.readDocument(), same(before));
  expect(root.documentFacts.documentRevision, 0);
}

// Both orders must exercise the same edit transaction; splitting its setup
// would hide whether a resource and all references become coherent together.
// ignore: halstead-volume
void _expectVectorKindTransitionInEitherCallbackOrder() {
  for (final resourceFirst in [true, false]) {
    final root = runtimeRootWithCommittedDocumentSeed(
      _imageDocument(),
      config: const CanvasRuntimeConfig(),
    );
    final vectorResource = CanvasVectorResource(
      id: CanvasResourceId('shared-resource'),
      source: CanvasResourceSource.appKey('shared-resource'),
    );
    final vectorElement = CanvasVectorElement(
      id: CanvasElementId('vector-1'),
      resourceId: vectorResource.id,
      size: const Size(20, 30),
    );

    final changed = root.edits.edit((edit) {
      if (resourceFirst) {
        edit.upsertResource(vectorResource);
      }
      edit.removeElement(CanvasElementId('image-1'));
      edit.addElement(vectorElement, layerId: CanvasLayerId('layer-1'));
      if (!resourceFirst) {
        edit.upsertResource(vectorResource);
      }

      return true;
    });

    expect(changed, isTrue);
    expect(root.documentFacts.documentRevision, 1);
    expect(root.readDocument().resources.single, isA<CanvasVectorResource>());
    expect(
      root.readDocument().layers.single.elements.single,
      isA<CanvasVectorElement>(),
    );
    root.dispose();
  }
}

// The no-partial-state proof needs one live root to observe document,
// selection, and retained output at the exact rejected transaction boundary.
// ignore: halstead-volume
void _expectRejectedVectorResourceEditPreservesRuntimeFacts() {
  _expectRejectedResourceEditPreservesRuntimeFacts(
    document: _vectorDocument(),
    apply: (edit) {
      edit.upsertResource(
        CanvasImageResource(
          id: CanvasResourceId('vector-resource-1'),
          source: CanvasResourceSource.appKey('vector-resource-1'),
        ),
      );
    },
    code: CanvasDataErrorCode.resourceKindMismatch,
    path: 'vector.resourceId',
  );
}

void _expectMissingVectorResourceEditPreservesRuntimeFacts() {
  _expectRejectedResourceEditPreservesRuntimeFacts(
    document: _vectorDocument(),
    apply: (edit) {
      edit.updateElement(
        CanvasVectorElementUpdate(
          id: CanvasElementId('vector-1'),
          resourceId: CanvasFieldSet(CanvasResourceId('missing-vector')),
        ),
      );
    },
    code: CanvasDataErrorCode.missingResourceReference,
    path: 'vector.resourceId',
  );
}

void _expectImageToVectorResourceEditPreservesRuntimeFacts() {
  _expectRejectedResourceEditPreservesRuntimeFacts(
    document: _imageDocument(),
    apply: (edit) {
      edit.upsertResource(
        CanvasVectorResource(
          id: CanvasResourceId('vector-resource-1'),
          source: CanvasResourceSource.appKey('vector-resource-1'),
        ),
      );
      edit.updateElement(
        CanvasImageElementUpdate(
          id: CanvasElementId('image-1'),
          resourceId: CanvasFieldSet(CanvasResourceId('vector-resource-1')),
        ),
      );
    },
    code: CanvasDataErrorCode.resourceKindMismatch,
    path: 'image.resourceId',
  );
}

// One live root must retain document, selection, and surface output through
// the rejected transaction, so these atomicity observables remain together.
// ignore: halstead-volume
void _expectRejectedResourceEditPreservesRuntimeFacts({
  required CanvasDocument document,
  required void Function(CanvasEdit edit) apply,
  required CanvasDataErrorCode code,
  required String path,
}) {
  final root = runtimeRootWithCommittedDocumentSeed(
    document,
    config: const CanvasRuntimeConfig(),
  );
  root.attachSurface(Object());
  root.selection.setSelection([document.layers.single.elements.single.id]);
  root.publishUnclassifiedRuntimeStateForTesting();
  final beforeDocument = root.readDocument();
  final beforeState = root.state.value;
  final beforeSelection = root.selectedElementIds;
  final beforeOutput = root.surfaceFrameSignal.value;

  expect(
    () => root.edits.edit((edit) {
      apply(edit);
    }),
    throwsA(
      isA<CanvasDataException>()
          .having((error) => error.code, 'code', code)
          .having((error) => error.path, 'path', path),
    ),
  );
  expect(root.readDocument(), same(beforeDocument));
  expect(root.state.value, beforeState);
  expect(root.selectedElementIds, beforeSelection);
  expect(root.surfaceFrameSignal.value, same(beforeOutput));
  root.dispose();
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-1'),
            size: const Size(1, 1),
            fillColor: const Color(0xFF00FF00),
            strokeWidth: 1,
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _vectorDocument() {
  return CanvasDocument(
    resources: [
      CanvasVectorResource(
        id: CanvasResourceId('vector-resource-1'),
        source: CanvasResourceSource.appKey('vector-resource-1'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('vector-resource-2'),
        source: CanvasResourceSource.appKey('vector-resource-2'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasVectorElement(
            id: CanvasElementId('vector-1'),
            resourceId: CanvasResourceId('vector-resource-1'),
            size: const Size(10, 20),
            naturalSize: const Size(20, 40),
            opacity: 0.25,
            metadata: CanvasMetadata.fromMap({'kind': 'vector'}),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _imageDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('shared-resource'),
        source: CanvasResourceSource.appKey('shared-resource'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-1'),
            resourceId: CanvasResourceId('shared-resource'),
            size: const Size(10, 10),
          ),
        ],
      ),
    ],
  );
}

RuntimeRoot _runtimeRoot(List<List<CommitDeliveryEffect>> effectBatches) {
  return runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
}
