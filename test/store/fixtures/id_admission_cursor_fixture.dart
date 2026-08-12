import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/codec/schema_v1_import_emitter.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/schema_v1_store_import.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

void main() {
  _testEmptyAdmissionStartsAtZero();
  _testSupportedPrefixResetAndCandidatePurity();
  _testGenerationConsumesCandidateAndReservesSynchronously();
  _testAcceptedAdmissionNormalizesBeforeItsConsumer();
  _testSequentialAcceptedAdmissionsDoNotRecrossOccupiedIds();
  _testAcceptedAdmissionCrossesOnlyNewlyRelevantIds();
  _testEveryCompleteLifecycleLeavesTheFirstFreeCursor();
  _testOrdinaryLayerAndResourcePrefixesNormalizeOnReset();
}

void _testEmptyAdmissionStartsAtZero() {
  test('empty reset establishes e0 without admission mutation', () {
    late DocumentStoreKernel store;
    final work = _observe(() {
      store = DocumentStoreKernel();
    });

    expect(store.observeElementIdCandidateForTesting().value, 'e0');
    _expectPhase(
      work,
      prefix: 'e',
      phase: IdAdmissionWorkPhase.reset,
      expected: const {IdAdmissionWorkKind.cursorProbe: 1},
    );
  });
}

void _testSupportedPrefixResetAndCandidatePurity() {
  test('reset normalizes the exact supported prefix once', () {
    final document = CommittedDocument(_contiguousPrefixDocument());
    late DocumentStoreKernel store;
    final resetWork = _observe(() {
      store = DocumentStoreKernel.withCommittedDocumentForTesting(document);
    });

    expect(store.observeElementIdCandidateForTesting().value, 'e200000');
    _expectPhase(
      resetWork,
      prefix: 'e',
      phase: IdAdmissionWorkPhase.reset,
      expected: const {
        IdAdmissionWorkKind.inputVisit: 200000,
        IdAdmissionWorkKind.cursorProbe: 200001,
        IdAdmissionWorkKind.collision: 200000,
        IdAdmissionWorkKind.advance: 200000,
      },
    );
  });

  test('repeated candidate observations are non-mutating', () {
    final document = CommittedDocument(_contiguousPrefixDocument());
    final store = DocumentStoreKernel.withCommittedDocumentForTesting(document);
    final work = _observe(() {
      expect(store.observeElementIdCandidateForTesting().value, 'e200000');
      expect(store.observeElementIdCandidateForTesting().value, 'e200000');
    });

    _expectPhase(
      work,
      prefix: 'e',
      phase: IdAdmissionWorkPhase.generation,
      expected: const {IdAdmissionWorkKind.candidateObservation: 2},
    );
  });
}

void _testGenerationConsumesCandidateAndReservesSynchronously() {
  test(
    'element generation observes then reserves the normalized candidate',
    () {
      final store = DocumentStoreKernel.withCommittedDocumentForTesting(
        CommittedDocument(_contiguousPrefixDocument()),
      );
      final work = _observe(() {
        expect(store.generateElementId().value, 'e200000');
      });

      _expectPhase(
        work,
        prefix: 'e',
        phase: IdAdmissionWorkPhase.generation,
        expected: const {
          IdAdmissionWorkKind.cursorProbe: 1,
          IdAdmissionWorkKind.advance: 1,
          IdAdmissionWorkKind.candidateObservation: 1,
          IdAdmissionWorkKind.reservation: 1,
        },
      );
    },
  );
}

void _testAcceptedAdmissionNormalizesBeforeItsConsumer() {
  test('sparse admission advances the cursor before a candidate read', () {
    final store = DocumentStoreKernel();
    final work = _observe(() {
      final prepared = store.prepareSparseCommit(
        StoreSparseCommit(
          mutations: [
            StoreSparseAddElement(element: _rect('e0'), background: true),
          ],
          revisionDelta: const StoreRevisionDelta.structural(),
        ),
      );
      store.installSparseCommit(prepared);
    });

    expect(store.observeElementIdCandidateForTesting().value, 'e1');
    _expectPhase(
      work,
      prefix: 'e',
      phase: IdAdmissionWorkPhase.acceptedAdmission,
      expected: const {
        IdAdmissionWorkKind.sparseLedgerVisit: 1,
        IdAdmissionWorkKind.inputVisit: 1,
        IdAdmissionWorkKind.cursorProbe: 2,
        IdAdmissionWorkKind.collision: 1,
        IdAdmissionWorkKind.advance: 1,
      },
    );
  });
}

void _testSequentialAcceptedAdmissionsDoNotRecrossOccupiedIds() {
  test('separate accepted admissions cross each occupied id only once', () {
    final store = DocumentStoreKernel();

    final firstWork = _observe(() {
      _installSparseElements(store, ['e0']);
    });
    expect(store.observeElementIdCandidateForTesting().value, 'e1');
    _expectOneAcceptedAdmissionCross(firstWork);

    final secondWork = _observe(() {
      _installSparseElements(store, ['e1']);
    });
    expect(store.observeElementIdCandidateForTesting().value, 'e2');
    _expectOneAcceptedAdmissionCross(secondWork);
  });
}

void _expectOneAcceptedAdmissionCross(_IdAdmissionWork work) {
  _expectPhase(
    work,
    prefix: 'e',
    phase: IdAdmissionWorkPhase.acceptedAdmission,
    expected: const {
      IdAdmissionWorkKind.sparseLedgerVisit: 1,
      IdAdmissionWorkKind.inputVisit: 1,
      IdAdmissionWorkKind.cursorProbe: 2,
      IdAdmissionWorkKind.collision: 1,
      IdAdmissionWorkKind.advance: 1,
    },
  );
}

void _testAcceptedAdmissionCrossesOnlyNewlyRelevantIds() {
  test('admission defers unrelated ids and normalizes one occupied run', () {
    final unrelatedStore = DocumentStoreKernel();
    final unrelatedWork = _observe(() {
      _installSparseElements(unrelatedStore, ['e2']);
    });

    expect(unrelatedStore.observeElementIdCandidateForTesting().value, 'e0');
    _expectPhase(
      unrelatedWork,
      prefix: 'e',
      phase: IdAdmissionWorkPhase.acceptedAdmission,
      expected: const {
        IdAdmissionWorkKind.sparseLedgerVisit: 1,
        IdAdmissionWorkKind.inputVisit: 1,
      },
    );

    final contiguousStore = DocumentStoreKernel();
    final contiguousWork = _observe(() {
      _installSparseElements(contiguousStore, ['e0', 'e1']);
    });

    expect(contiguousStore.observeElementIdCandidateForTesting().value, 'e2');
    _expectPhase(
      contiguousWork,
      prefix: 'e',
      phase: IdAdmissionWorkPhase.acceptedAdmission,
      expected: const {
        IdAdmissionWorkKind.sparseLedgerVisit: 2,
        IdAdmissionWorkKind.inputVisit: 2,
        IdAdmissionWorkKind.cursorProbe: 3,
        IdAdmissionWorkKind.collision: 2,
        IdAdmissionWorkKind.advance: 2,
      },
    );
  });
}

void _installSparseElements(DocumentStoreKernel store, List<String> ids) {
  final prepared = store.prepareSparseCommit(
    StoreSparseCommit(
      mutations: [
        for (final id in ids)
          StoreSparseAddElement(element: _rect(id), background: true),
      ],
      revisionDelta: const StoreRevisionDelta.structural(),
    ),
  );
  store.installSparseCommit(prepared);
}

void _testEveryCompleteLifecycleLeavesTheFirstFreeCursor() {
  test(
    'complete admission lifecycles preserve gapped first-free element ids',
    () {
      expect(
        [
          _candidateAfterConstruction(_gappedElementDocument()),
          _candidateAfterInstall(),
          _candidateAfterReplacement(),
          _candidateAfterPreparedLoad(),
          _candidateAfterMaterializedInstall(),
          _candidateAfterSchemaV1Import(),
        ],
        ['e1', 'e1', 'e1', 'e1', 'e1', 'e1'],
      );
    },
  );
}

void _testOrdinaryLayerAndResourcePrefixesNormalizeOnReset() {
  test('ordinary layer and resource prefixes normalize with reset', () {
    expect(_ordinaryPrefixIdsAfterReset(), ['l1', 'r1']);
  });
}

String _candidateAfterConstruction(CanvasDocument document) {
  late DocumentStoreKernel store;
  final work = _observe(() {
    store = DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(document),
    );
  });

  final candidate = store.observeElementIdCandidateForTesting().value;
  _expectOneOccupiedPrefixNormalization(
    work,
    phase: IdAdmissionWorkPhase.reset,
    inputVisits: 2,
  );
  return candidate;
}

String _candidateAfterInstall() {
  final store = DocumentStoreKernel();
  final work = _observe(() {
    store.installDocument(
      CommittedDocument(_singleElementDocument()),
      const StoreRevisionDelta.structural(),
    );
  });

  final candidate = store.observeElementIdCandidateForTesting().value;
  _expectOneOccupiedPrefixNormalization(
    work,
    phase: IdAdmissionWorkPhase.acceptedAdmission,
    inputVisits: 1,
  );
  return candidate;
}

String _candidateAfterReplacement() {
  final store = DocumentStoreKernel();
  final work = _observe(() {
    store.replaceDocument(
      CommittedDocument(_singleElementDocument()),
      const StoreRevisionDelta.structural(),
    );
  });

  final candidate = store.observeElementIdCandidateForTesting().value;
  _expectOneOccupiedPrefixNormalization(
    work,
    phase: IdAdmissionWorkPhase.reset,
    inputVisits: 1,
  );
  return candidate;
}

String _candidateAfterPreparedLoad() {
  final store = DocumentStoreKernel();
  final work = _observe(() {
    store.replacePreparedLoadDocument(
      CommittedDocument(_singleElementDocument()),
      const StoreRevisionDelta.structural(),
    );
  });

  final candidate = store.observeElementIdCandidateForTesting().value;
  _expectOneOccupiedPrefixNormalization(
    work,
    phase: IdAdmissionWorkPhase.reset,
    inputVisits: 1,
  );
  return candidate;
}

String _candidateAfterMaterializedInstall() {
  final store = DocumentStoreKernel();
  final prepared = store.prepareMaterializedCommit(
    _singleElementDocument(),
    const StoreRevisionDelta.structural(),
  );
  final work = _observe(() {
    store.installPreparedMaterializedCommit(prepared);
  });

  final candidate = store.observeElementIdCandidateForTesting().value;
  _expectOneOccupiedPrefixNormalization(
    work,
    phase: IdAdmissionWorkPhase.acceptedAdmission,
    inputVisits: 1,
  );
  return candidate;
}

String _candidateAfterSchemaV1Import() {
  final store = DocumentStoreKernel();
  final builder = StoreSchemaV1ImportBuilder();
  importSchemaV1Document(_schemaV1ElementDocument(), builder);
  final prepared = store.prepareSchemaV1Import(
    builder,
    const StoreRevisionDelta.structural(),
  );
  final work = _observe(() {
    store.installPreparedSchemaV1Import(prepared);
  });

  final candidate = store.observeElementIdCandidateForTesting().value;
  _expectOneOccupiedPrefixNormalization(
    work,
    phase: IdAdmissionWorkPhase.reset,
    inputVisits: 1,
  );
  return candidate;
}

List<String> _ordinaryPrefixIdsAfterReset() {
  late DocumentStoreKernel store;
  final work = _observe(() {
    store = DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(
        CanvasDocument(
          layers: [
            CanvasLayer(id: CanvasLayerId('l0')),
            CanvasLayer(id: CanvasLayerId('l2')),
          ],
          resources: [_imageResource('r0'), _imageResource('r2')],
        ),
      ),
    );
  });

  _expectOrdinaryPrefixReset(work, 'l');
  _expectOrdinaryPrefixReset(work, 'r');
  return [store.generateLayerId().value, store.generateResourceId().value];
}

void _expectOrdinaryPrefixReset(_IdAdmissionWork work, String prefix) {
  _expectPhase(
    work,
    prefix: prefix,
    phase: IdAdmissionWorkPhase.reset,
    expected: const {
      IdAdmissionWorkKind.inputVisit: 2,
      IdAdmissionWorkKind.cursorProbe: 2,
      IdAdmissionWorkKind.collision: 1,
      IdAdmissionWorkKind.advance: 1,
    },
  );
}

void _expectOneOccupiedPrefixNormalization(
  _IdAdmissionWork work, {
  required IdAdmissionWorkPhase phase,
  required int inputVisits,
}) {
  _expectPhase(
    work,
    prefix: 'e',
    phase: phase,
    expected: {
      IdAdmissionWorkKind.inputVisit: inputVisits,
      IdAdmissionWorkKind.cursorProbe: 2,
      IdAdmissionWorkKind.collision: 1,
      IdAdmissionWorkKind.advance: 1,
    },
  );
}

CanvasDocument _contiguousPrefixDocument() {
  return CanvasDocument(
    backgroundElements: List<CanvasElement>.generate(
      200000,
      (index) => _rect('e$index'),
      growable: false,
    ),
  );
}

CanvasDocument _gappedElementDocument() {
  return CanvasDocument(backgroundElements: [_rect('e0'), _rect('e2')]);
}

CanvasDocument _singleElementDocument() {
  return CanvasDocument(backgroundElements: [_rect('e0')]);
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}

CanvasImageResource _imageResource(String id) {
  return CanvasImageResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey('asset-$id'),
  );
}

Map<String, Object?> _schemaV1ElementDocument() {
  return {
    'schemaVersion': 1,
    'backgroundLayer': {
      'elements': [
        {
          'id': 'e0',
          'kind': 'rect',
          'size': {'w': 1, 'h': 1},
          'fillColor': '#FF000000',
          'strokeWidth': 0,
        },
      ],
    },
  };
}

_IdAdmissionWork _observe(void Function() operation) {
  final work = _IdAdmissionWork();
  DocumentStoreKernel.observeIdAdmissionWork(work.record, operation);
  return work;
}

void _expectPhase(
  _IdAdmissionWork work, {
  required String prefix,
  required IdAdmissionWorkPhase phase,
  required Map<IdAdmissionWorkKind, int> expected,
}) {
  for (final kind in IdAdmissionWorkKind.values) {
    expect(
      work.count(prefix: prefix, phase: phase, kind: kind),
      expected[kind] ?? 0,
    );
  }
}

final class _IdAdmissionWork {
  final Map<(String, IdAdmissionWorkPhase, IdAdmissionWorkKind), int> _counts =
      {};

  void record(IdAdmissionWorkEvent event) {
    final key = (event.prefix, event.phase, event.kind);
    _counts[key] = (_counts[key] ?? 0) + 1;
  }

  int count({
    required String prefix,
    required IdAdmissionWorkPhase phase,
    required IdAdmissionWorkKind kind,
  }) {
    return _counts[(prefix, phase, kind)] ?? 0;
  }
}
