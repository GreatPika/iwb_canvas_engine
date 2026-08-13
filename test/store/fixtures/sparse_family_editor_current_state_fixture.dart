import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../support/document_store_with_document.dart';
import 'family_tables_telemetry.dart';

// This fixture retains the decision matrix in one readable sequence; splitting
// the calls only to lower a metric would hide the shared stale-read oracle.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  test('ordered current-family decisions use only the editor view', () {
    final store = documentStoreWithDocument(_baseDocument());
    final work = FamilyTablesTelemetry();

    final prepared = FamilyTables.observeTelemetry(
      work.record,
      () => store.prepareSparseCommit(_orderedTrace()),
    );

    // This is a hand-written sequential oracle for the live editor state: the
    // first resource removal sees its image row, the later one sees its
    // removal; the newly added image is then validated against the final
    // descriptor before accepted delta and touched computation.
    expect(work.editorDecisionTrace, [
      FamilyTablesDecision.removeUnusedReference,
      FamilyTablesDecision.removeMembership,
      FamilyTablesDecision.removeUnusedReference,
      FamilyTablesDecision.duplicateAdd,
      FamilyTablesDecision.removeMembership,
      FamilyTablesDecision.relationship,
      FamilyTablesDecision.acceptedDelta,
      FamilyTablesDecision.acceptedDelta,
      FamilyTablesDecision.acceptedTouched,
      FamilyTablesDecision.acceptedTouched,
      FamilyTablesDecision.acceptedTouched,
    ]);
    expect(work.editorDecisionReads, [
      _read(
        FamilyTablesDecision.removeUnusedReference,
        FamilyTablesDecisionSubjectKind.resource,
        'resource',
        FamilyTablesDecisionResult.referenced,
      ),
      _read(
        FamilyTablesDecision.removeMembership,
        FamilyTablesDecisionSubjectKind.element,
        'old',
        FamilyTablesDecisionResult.present,
      ),
      _read(
        FamilyTablesDecision.removeUnusedReference,
        FamilyTablesDecisionSubjectKind.resource,
        'resource',
        FamilyTablesDecisionResult.unreferenced,
      ),
      _read(
        FamilyTablesDecision.duplicateAdd,
        FamilyTablesDecisionSubjectKind.element,
        'new',
        FamilyTablesDecisionResult.missing,
      ),
      _read(
        FamilyTablesDecision.removeMembership,
        FamilyTablesDecisionSubjectKind.element,
        'new',
        FamilyTablesDecisionResult.present,
      ),
      _read(
        FamilyTablesDecision.relationship,
        FamilyTablesDecisionSubjectKind.element,
        'new',
        FamilyTablesDecisionResult.valid,
      ),
      _read(
        FamilyTablesDecision.acceptedDelta,
        FamilyTablesDecisionSubjectKind.element,
        'old',
        FamilyTablesDecisionResult.removed,
      ),
      _read(
        FamilyTablesDecision.acceptedDelta,
        FamilyTablesDecisionSubjectKind.element,
        'new',
        FamilyTablesDecisionResult.added,
      ),
      _read(
        FamilyTablesDecision.acceptedTouched,
        FamilyTablesDecisionSubjectKind.resource,
        'resource',
        FamilyTablesDecisionResult.referenced,
      ),
      _read(
        FamilyTablesDecision.acceptedTouched,
        FamilyTablesDecisionSubjectKind.element,
        'old',
        FamilyTablesDecisionResult.removed,
      ),
      _read(
        FamilyTablesDecision.acceptedTouched,
        FamilyTablesDecisionSubjectKind.element,
        'new',
        FamilyTablesDecisionResult.added,
      ),
    ]);
    expect(work.staleDecisionReadCount, 0);
    for (final decision in FamilyTablesDecision.values) {
      expect(work.staleDecisionReadCountFor(decision), 0);
    }
    expect(prepared.touchedFacts.removedElementIds, {CanvasElementId('old')});
    expect(prepared.touchedFacts.addedElementIds, {CanvasElementId('new')});
  });

  test(
    'same batch image and vector transitions read every current editor row',
    () {
      final base = _repeatedResourceTransitionDocument();
      final store = documentStoreWithDocument(base);
      final work = FamilyTablesTelemetry();

      final prepared = FamilyTables.observeTelemetry(
        work.record,
        () => store.prepareSparseCommit(_repeatedResourceTransitionCommit()),
      );

      final tables = prepared.document.elements.familyTables;
      expect(
        tables.imageRows['image']!.resourceId,
        CanvasResourceId('image-c'),
      );
      expect(
        tables.vectorRows['vector']!.resourceId,
        CanvasResourceId('vector-c'),
      );
      expect(
        [
          tables.imageResourceReferenceCount(CanvasResourceId('image-a')),
          tables.imageResourceReferenceCount(CanvasResourceId('image-b')),
          tables.imageResourceReferenceCount(CanvasResourceId('image-c')),
          tables.vectorResourceReferenceCount(CanvasResourceId('vector-a')),
          tables.vectorResourceReferenceCount(CanvasResourceId('vector-b')),
          tables.vectorResourceReferenceCount(CanvasResourceId('vector-c')),
        ],
        [0, 0, 1, 0, 0, 1],
      );
      expect(
        [
          work.editorDecisionCount(FamilyTablesDecision.updateCurrentRow),
          work.editorCurrentRowReadCount,
          work.imageReferenceAffectedIdUpdateCount,
          work.vectorReferenceAffectedIdUpdateCount,
        ],
        [4, 4, 4, 4],
      );
      expect(work.staleDecisionReadCount, 0);
    },
  );

  // Each helper asserts one independent first-failure trace. Keeping them in
  // one diagnostic matrix makes their ordered editor ownership easy to audit.
  // ignore: missing-test-assertion
  test('diagnostic decisions and clear barrier use current editor rows', () {
    _expectDuplicateAddDecision();
    _expectAddUpdateDecision();
    _expectMissingUpdateDecision();
    _expectRemoveUpdateReaddDecision();
    _expectSourceKindAndNoOpDecisions();
    _expectRelationshipFailureDiscards();
    _expectClearBarrierDecision();
  });
}

// Exact diagnostics and the literal semantic event are one first-failure
// oracle; extracting either would decouple the result from its decision read.
// ignore: halstead-volume, source-lines-of-code
void _expectDuplicateAddDecision() {
  final store = documentStoreWithDocument(_baseDocument());
  final work = FamilyTablesTelemetry();

  expect(
    () => FamilyTables.observeTelemetry(
      work.record,
      () => store.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta.structural(),
          mutations: [
            StoreSparseAddElement(
              element: CanvasImageElement(
                id: CanvasElementId('old'),
                resourceId: CanvasResourceId('resource'),
                size: const Size(1, 1),
              ),
            ),
          ],
        ),
      ),
    ),
    throwsA(
      isA<CanvasDataException>()
          .having(
            (error) => error.code,
            'code',
            CanvasDataErrorCode.duplicateElementId,
          )
          .having((error) => error.message, 'message', 'duplicate element id.')
          .having((error) => error.path, 'path', 'elements.id'),
    ),
  );
  expect(work.editorDecisionTrace, [FamilyTablesDecision.duplicateAdd]);
  expect(work.editorDecisionReads, [
    _read(
      FamilyTablesDecision.duplicateAdd,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.present,
    ),
  ]);
  expect(work.transactionImmutablePublicationCount, 0);
  expect(work.staleDecisionReadCount, 0);
}

// This full journal is one ordered oracle; extracting values merely for metrics
// would make the required add-to-update decision order harder to inspect.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectAddUpdateDecision() {
  final store = documentStoreWithDocument(_baseDocument());
  final work = FamilyTablesTelemetry();
  final added = CanvasImageElement(
    id: CanvasElementId('added'),
    resourceId: CanvasResourceId('resource'),
    size: const Size(1, 1),
  );

  FamilyTables.observeTelemetry(
    work.record,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.structural().merge(
          const StoreRevisionDelta.elementBounds(),
        ),
        mutations: [
          StoreSparseAddElement(element: added),
          StoreSparseUpdateElement(
            before: added,
            element: CanvasImageElement(
              id: added.id,
              resourceId: added.resourceId,
              size: const Size(2, 2),
              revision: 1,
            ),
            elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
        ],
      ),
    ),
  );
  expect(work.editorDecisionTrace, [
    FamilyTablesDecision.duplicateAdd,
    FamilyTablesDecision.updateCurrentRow,
    FamilyTablesDecision.updateSource,
    FamilyTablesDecision.updateNoOp,
    FamilyTablesDecision.updateKind,
    FamilyTablesDecision.removeMembership,
    FamilyTablesDecision.relationship,
    FamilyTablesDecision.acceptedDelta,
    FamilyTablesDecision.acceptedTouched,
  ]);
  expect(work.editorDecisionReads, [
    _read(
      FamilyTablesDecision.duplicateAdd,
      FamilyTablesDecisionSubjectKind.element,
      'added',
      FamilyTablesDecisionResult.missing,
    ),
    _read(
      FamilyTablesDecision.updateCurrentRow,
      FamilyTablesDecisionSubjectKind.element,
      'added',
      FamilyTablesDecisionResult.present,
    ),
    _read(
      FamilyTablesDecision.updateSource,
      FamilyTablesDecisionSubjectKind.element,
      'added',
      FamilyTablesDecisionResult.matches,
    ),
    _read(
      FamilyTablesDecision.updateNoOp,
      FamilyTablesDecisionSubjectKind.element,
      'added',
      FamilyTablesDecisionResult.changed,
    ),
    _read(
      FamilyTablesDecision.updateKind,
      FamilyTablesDecisionSubjectKind.element,
      'added',
      FamilyTablesDecisionResult.matches,
    ),
    _read(
      FamilyTablesDecision.removeMembership,
      FamilyTablesDecisionSubjectKind.element,
      'added',
      FamilyTablesDecisionResult.present,
    ),
    _read(
      FamilyTablesDecision.relationship,
      FamilyTablesDecisionSubjectKind.element,
      'added',
      FamilyTablesDecisionResult.valid,
    ),
    _read(
      FamilyTablesDecision.acceptedDelta,
      FamilyTablesDecisionSubjectKind.element,
      'added',
      FamilyTablesDecisionResult.added,
    ),
    _read(
      FamilyTablesDecision.acceptedTouched,
      FamilyTablesDecisionSubjectKind.element,
      'added',
      FamilyTablesDecisionResult.added,
    ),
  ]);
  expect(work.staleDecisionReadCount, 0);
}

// The missing update outcome and both literal decision reads are one semantic
// transition, kept together so no derived helper can mask the missing branch.
// ignore: halstead-volume, source-lines-of-code
void _expectMissingUpdateDecision() {
  final store = documentStoreWithDocument(_baseDocument());
  final work = FamilyTablesTelemetry();

  final prepared = FamilyTables.observeTelemetry(
    work.record,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          StoreSparseUpdateElement(
            before: CanvasImageElement(
              id: CanvasElementId('missing'),
              resourceId: CanvasResourceId('resource'),
              size: const Size(1, 1),
            ),
            element: CanvasImageElement(
              id: CanvasElementId('missing'),
              resourceId: CanvasResourceId('resource'),
              size: const Size(2, 2),
              revision: 1,
            ),
            elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
          ),
        ],
      ),
    ),
  );

  expect(prepared.hasChanges, isFalse);
  expect(work.editorDecisionTrace, [
    FamilyTablesDecision.updateCurrentRow,
    FamilyTablesDecision.updateMissingId,
  ]);
  expect(work.editorDecisionReads, [
    _read(
      FamilyTablesDecision.updateCurrentRow,
      FamilyTablesDecisionSubjectKind.element,
      'missing',
      FamilyTablesDecisionResult.missing,
    ),
    _read(
      FamilyTablesDecision.updateMissingId,
      FamilyTablesDecisionSubjectKind.element,
      'missing',
      FamilyTablesDecisionResult.missing,
    ),
  ]);
  expect(work.transactionImmutablePublicationCount, 0);
  expect(work.staleDecisionReadCount, 0);
}

// The complete event sequence must stay together for its ordering assertion.
// ignore: halstead-volume, source-lines-of-code
void _expectRemoveUpdateReaddDecision() {
  final store = documentStoreWithDocument(_baseDocument());
  final work = FamilyTablesTelemetry();
  final old = _oldImage();

  FamilyTables.observeTelemetry(
    work.record,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.structural(),
        mutations: [
          StoreSparseRemoveElement(old.id),
          StoreSparseUpdateElement(
            before: old,
            element: CanvasImageElement(
              id: old.id,
              resourceId: old.resourceId,
              size: const Size(2, 2),
              revision: 1,
            ),
            elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
          StoreSparseAddElement(element: old),
        ],
      ),
    ),
  );
  expect(work.editorDecisionTrace, [
    FamilyTablesDecision.removeMembership,
    FamilyTablesDecision.updateCurrentRow,
    FamilyTablesDecision.updateMissingId,
    FamilyTablesDecision.duplicateAdd,
    FamilyTablesDecision.removeMembership,
    FamilyTablesDecision.relationship,
    FamilyTablesDecision.acceptedDelta,
  ]);
  expect(work.editorDecisionReads, [
    _read(
      FamilyTablesDecision.removeMembership,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.present,
    ),
    _read(
      FamilyTablesDecision.updateCurrentRow,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.missing,
    ),
    _read(
      FamilyTablesDecision.updateMissingId,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.missing,
    ),
    _read(
      FamilyTablesDecision.duplicateAdd,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.missing,
    ),
    _read(
      FamilyTablesDecision.removeMembership,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.present,
    ),
    _read(
      FamilyTablesDecision.relationship,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.valid,
    ),
    _read(
      FamilyTablesDecision.acceptedDelta,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.unchanged,
    ),
  ]);
  _expectNoFreezeOrPublication(work);
  expect(work.staleDecisionReadCount, 0);
}

// These related update outcomes share one ordered literal expectation list.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectSourceKindAndNoOpDecisions() {
  _expectUpdateFailure(
    _sourceMismatch(),
    FamilyTablesDecision.updateSource,
    'before',
    'sparse element update delta must be derived from the committed row.',
    [
      _read(
        FamilyTablesDecision.updateCurrentRow,
        FamilyTablesDecisionSubjectKind.element,
        'old',
        FamilyTablesDecisionResult.present,
      ),
      _read(
        FamilyTablesDecision.updateSource,
        FamilyTablesDecisionSubjectKind.element,
        'old',
        FamilyTablesDecisionResult.differs,
      ),
    ],
  );
  _expectUpdateFailure(
    _kindMismatch(),
    FamilyTablesDecision.updateKind,
    'element',
    'element update kind does not match the target element.',
    [
      _read(
        FamilyTablesDecision.updateCurrentRow,
        FamilyTablesDecisionSubjectKind.element,
        'old',
        FamilyTablesDecisionResult.present,
      ),
      _read(
        FamilyTablesDecision.updateSource,
        FamilyTablesDecisionSubjectKind.element,
        'old',
        FamilyTablesDecisionResult.matches,
      ),
      _read(
        FamilyTablesDecision.updateNoOp,
        FamilyTablesDecisionSubjectKind.element,
        'old',
        FamilyTablesDecisionResult.changed,
      ),
      _read(
        FamilyTablesDecision.updateKind,
        FamilyTablesDecisionSubjectKind.element,
        'old',
        FamilyTablesDecisionResult.differs,
      ),
    ],
  );

  final store = documentStoreWithDocument(_baseDocument());
  final work = FamilyTablesTelemetry();
  final old = _oldImage();
  final prepared = FamilyTables.observeTelemetry(
    work.record,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          StoreSparseUpdateElement(
            before: old,
            element: old,
            elementRevisionDelta: const StoreRevisionDelta(),
          ),
        ],
      ),
    ),
  );
  expect(prepared.hasChanges, isFalse);
  expect(work.editorDecisionTrace, [
    FamilyTablesDecision.updateCurrentRow,
    FamilyTablesDecision.updateSource,
    FamilyTablesDecision.updateNoOp,
  ]);
  expect(work.editorDecisionReads, [
    _read(
      FamilyTablesDecision.updateCurrentRow,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.present,
    ),
    _read(
      FamilyTablesDecision.updateSource,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.matches,
    ),
    _read(
      FamilyTablesDecision.updateNoOp,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.unchanged,
    ),
  ]);
  expect(work.transactionImmutablePublicationCount, 0);
  expect(work.staleDecisionReadCount, 0);
}

// The exact final relationship diagnostic and its recorded failed decision are
// one oracle, so retaining the complete witness is safer than reshaping it.
// ignore: halstead-volume, source-lines-of-code
void _expectRelationshipFailureDiscards() {
  final store = documentStoreWithDocument(_baseDocument());
  final work = FamilyTablesTelemetry();

  expect(
    () => FamilyTables.observeTelemetry(
      work.record,
      () => store.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta.structural(),
          mutations: [
            StoreSparseAddElement(
              element: CanvasImageElement(
                id: CanvasElementId('missing-resource'),
                resourceId: CanvasResourceId('missing-resource'),
                size: const Size(1, 1),
              ),
            ),
          ],
        ),
      ),
    ),
    throwsA(
      isA<CanvasDataException>()
          .having(
            (error) => error.code,
            'code',
            CanvasDataErrorCode.missingResourceReference,
          )
          .having(
            (error) => error.message,
            'message',
            'resource element references a missing resource.',
          )
          .having((error) => error.path, 'path', 'image.resourceId'),
    ),
  );
  expect(work.editorDecisionTrace, contains(FamilyTablesDecision.relationship));
  expect(work.editorDecisionReads, [
    _read(
      FamilyTablesDecision.duplicateAdd,
      FamilyTablesDecisionSubjectKind.element,
      'missing-resource',
      FamilyTablesDecisionResult.missing,
    ),
    _read(
      FamilyTablesDecision.removeMembership,
      FamilyTablesDecisionSubjectKind.element,
      'missing-resource',
      FamilyTablesDecisionResult.present,
    ),
    _read(
      FamilyTablesDecision.relationship,
      FamilyTablesDecisionSubjectKind.element,
      'missing-resource',
      FamilyTablesDecisionResult.invalid,
    ),
  ]);
  _expectNoFreezeOrPublication(work);
  expect(work.staleDecisionReadCount, 0);
}

// A sparse update failure has one diagnostic plus its event list; the cohesive
// assertion avoids a test-only transport object merely to lower parameters.
// ignore: number-of-parameters
void _expectUpdateFailure(
  StoreSparseUpdateElement update,
  FamilyTablesDecision terminalDecision,
  String errorName,
  String errorMessage,
  List<FamilyTablesDecisionRead> expectedReads,
) {
  final store = documentStoreWithDocument(_baseDocument());
  final work = FamilyTablesTelemetry();

  expect(
    () => FamilyTables.observeTelemetry(
      work.record,
      () => store.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta.elementVisual(),
          mutations: [update],
        ),
      ),
    ),
    throwsA(
      isA<ArgumentError>()
          .having((error) => error.name, 'name', errorName)
          .having((error) => error.message, 'message', errorMessage),
    ),
  );
  expect(work.editorDecisionTrace, contains(terminalDecision));
  expect(work.editorDecisionReads, expectedReads);
  expect(work.transactionImmutablePublicationCount, 0);
  expect(work.staleDecisionReadCount, 0);
}

void _expectNoFreezeOrPublication(FamilyTablesTelemetry work) {
  for (final kind in CanvasElementKind.values) {
    expect(work.transactionFreezeCount(kind), 0);
  }
  expect(work.transactionImmutablePublicationCount, 0);
  expect(work.transactionDiscardCount, 1);
}

void _expectClearBarrierDecision() {
  final store = documentStoreWithDocument(_baseDocument());
  final work = FamilyTablesTelemetry();

  FamilyTables.observeTelemetry(
    work.record,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.structural(),
        mutations: const [StoreSparseClearContent()],
      ),
    ),
  );
  expect(work.editorDecisionTrace, [
    FamilyTablesDecision.clear,
    FamilyTablesDecision.acceptedTouched,
  ]);
  expect(work.editorDecisionReads, [
    _read(
      FamilyTablesDecision.clear,
      FamilyTablesDecisionSubjectKind.content,
      'content',
      FamilyTablesDecisionResult.changed,
    ),
    _read(
      FamilyTablesDecision.acceptedTouched,
      FamilyTablesDecisionSubjectKind.element,
      'old',
      FamilyTablesDecisionResult.removed,
    ),
  ]);
  expect(work.staleDecisionReadCount, 0);
}

FamilyTablesDecisionRead _read(
  FamilyTablesDecision decision,
  FamilyTablesDecisionSubjectKind subjectKind,
  String subject,
  FamilyTablesDecisionResult result,
) {
  return FamilyTablesDecisionRead(
    decision: decision,
    subjectKind: subjectKind,
    subject: subject,
    result: result,
  );
}

StoreSparseUpdateElement _sourceMismatch() {
  return StoreSparseUpdateElement(
    before: CanvasImageElement(
      id: CanvasElementId('old'),
      resourceId: CanvasResourceId('resource'),
      size: const Size(9, 9),
    ),
    element: CanvasImageElement(
      id: CanvasElementId('old'),
      resourceId: CanvasResourceId('resource'),
      size: const Size(2, 2),
      revision: 1,
    ),
    elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
  );
}

StoreSparseUpdateElement _kindMismatch() {
  final old = _oldImage();

  return StoreSparseUpdateElement(
    before: old,
    element: CanvasVectorElement(
      id: old.id,
      resourceId: old.resourceId,
      size: old.size,
      revision: 1,
    ),
    elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
  );
}

CanvasImageElement _oldImage() {
  return CanvasImageElement(
    id: CanvasElementId('old'),
    resourceId: CanvasResourceId('resource'),
    size: const Size(1, 1),
  );
}

StoreSparseCommit _orderedTrace() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.structural().merge(
      const StoreRevisionDelta.resource(),
    ),
    mutations: [
      StoreSparseRemoveUnusedResource(CanvasResourceId('resource')),
      StoreSparseRemoveElement(CanvasElementId('old')),
      StoreSparseRemoveUnusedResource(CanvasResourceId('resource')),
      StoreSparseUpsertResource(
        CanvasImageResource(
          id: CanvasResourceId('resource'),
          source: CanvasResourceSource.appKey('new'),
        ),
      ),
      StoreSparseAddElement(
        element: CanvasImageElement(
          id: CanvasElementId('new'),
          resourceId: CanvasResourceId('resource'),
          size: const Size(2, 3),
        ),
      ),
    ],
  );
}

CanvasDocument _repeatedResourceTransitionDocument() {
  return CanvasDocument(
    resources: [
      for (final id in ['image-a', 'image-b', 'image-c'])
        CanvasImageResource(
          id: CanvasResourceId(id),
          source: CanvasResourceSource.appKey(id),
        ),
      for (final id in ['vector-a', 'vector-b', 'vector-c'])
        CanvasVectorResource(
          id: CanvasResourceId(id),
          source: CanvasResourceSource.appKey(id),
        ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          _resourceImage('image', 'image-a'),
          _resourceVector('vector', 'vector-a'),
        ],
      ),
    ],
  );
}

StoreSparseCommit _repeatedResourceTransitionCommit() {
  final imageA = _resourceImage('image', 'image-a');
  final imageB = _resourceImage('image', 'image-b', revision: 1);
  final imageC = _resourceImage('image', 'image-c', revision: 2);
  final vectorA = _resourceVector('vector', 'vector-a');
  final vectorB = _resourceVector('vector', 'vector-b', revision: 1);
  final vectorC = _resourceVector('vector', 'vector-c', revision: 2);

  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.elementVisual(),
    mutations: [
      StoreSparseUpdateElement(
        before: imageA,
        element: imageB,
        elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
      ),
      StoreSparseUpdateElement(
        before: imageB,
        element: imageC,
        elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
      ),
      StoreSparseUpdateElement(
        before: vectorA,
        element: vectorB,
        elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
      ),
      StoreSparseUpdateElement(
        before: vectorB,
        element: vectorC,
        elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
      ),
    ],
  );
}

CanvasImageElement _resourceImage(
  String id,
  String resourceId, {
  int revision = 0,
}) {
  return CanvasImageElement(
    id: CanvasElementId(id),
    resourceId: CanvasResourceId(resourceId),
    size: const Size(1, 1),
    revision: revision,
  );
}

CanvasVectorElement _resourceVector(
  String id,
  String resourceId, {
  int revision = 0,
}) {
  return CanvasVectorElement(
    id: CanvasElementId(id),
    resourceId: CanvasResourceId(resourceId),
    size: const Size(1, 1),
    revision: revision,
  );
}

CanvasDocument _baseDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource'),
        source: CanvasResourceSource.appKey('base'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('old'),
            resourceId: CanvasResourceId('resource'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}
