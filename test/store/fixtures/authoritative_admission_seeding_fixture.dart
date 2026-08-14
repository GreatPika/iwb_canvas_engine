// This fixture observes all complete-admission identity owners together so
// direct feeding, one-pass work, and sparse-ledger isolation share one trace.
// ignore_for_file: number-of-imports

import 'dart:ui' show Color, Offset, Size, TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/codec/schema_v1_import_emitter.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';
import 'package:iwb_canvas_engine/src/store/layer_table.dart';
import 'package:iwb_canvas_engine/src/store/resource_table.dart';
import 'package:iwb_canvas_engine/src/store/schema_v1_store_import.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import 'family_tables_telemetry.dart';

void main() {
  _registerCompleteRouteTests();
  _registerSupportedSizeWitness();
  _registerSparseLedgerTest();
}

void _registerCompleteRouteTests() {
  for (final route in _completeRoutes) {
    // The helper asserts the complete semantic trace and generated results.
    // ignore: missing-test-assertion
    test(
      '${route.name} admits every owner directly for each owner variant',
      () {
        for (final variant in _OwnerVariant.values) {
          _expectCompleteRoute(route, _AdmissionSnapshot(variant));
        }
      },
    );
  }

  // The helper asserts the complete semantic trace and generated results.
  // ignore: missing-test-assertion
  test('every complete route stays single-pass at supported cardinality', () {
    final snapshot = _AdmissionSnapshot.maximum(
      elementCount: 4096,
      layerCount: 256,
      resourceCount: 256,
    );
    for (final route in _completeRoutes) {
      _expectCompleteRoute(route, snapshot);
    }
  });
}

void _registerSupportedSizeWitness() {
  test('maximum supported complete snapshot opens each owner once', () {
    const elementCount = 200000;
    const layerCount = 4096;
    const resourceCount = 4096;
    final snapshot = _AdmissionSnapshot.maximum(
      elementCount: elementCount,
      layerCount: layerCount,
      resourceCount: resourceCount,
    );

    final trace = _AdmissionTrace(IdAdmissionWorkPhase.reset);
    late DocumentStoreKernel store;
    trace.observe(() {
      store = DocumentStoreKernel.withCommittedDocumentForTesting(
        snapshot.committed,
      );
    });

    _expectCompleteTrace(trace, snapshot);
    expect(
      [
        store.generateElementId().value,
        store.generateLayerId().value,
        store.generateResourceId().value,
      ],
      ['e$elementCount', 'l$layerCount', 'r$resourceCount'],
    );
  });
}

void _registerSparseLedgerTest() {
  test('sparse install admits only its accepted ordered ledgers', () {
    final store = DocumentStoreKernel();
    final prepared = store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: _completeDelta,
        mutations: [
          StoreSparseEnsureLayer(CanvasLayerId('l0')),
          StoreSparseEnsureLayer(CanvasLayerId('l2')),
          StoreSparseAddElement(element: _rect('e0'), background: true),
          StoreSparseAddElement(element: _rect('e2'), background: true),
          StoreSparseUpsertResource(_resource('r0')),
          StoreSparseUpsertResource(_resource('r2')),
        ],
      ),
    );
    final trace = _AdmissionTrace(IdAdmissionWorkPhase.acceptedAdmission);

    trace.observe(() => store.installSparseCommit(prepared));

    expect(trace.events, _expectedSparseTrace);
    expect(
      [
        store.generateElementId().value,
        store.generateLayerId().value,
        store.generateResourceId().value,
      ],
      ['e1', 'l1', 'r1'],
    );
  });
}

void _expectCompleteRoute(_CompleteRoute route, _AdmissionSnapshot snapshot) {
  final trace = _AdmissionTrace(route.phase);
  final store = route.run(snapshot, trace);

  _expectFamilyOwnerMaps(snapshot);
  _expectCompleteTrace(trace, snapshot);
  expect(
    [
      store.generateElementId().value,
      store.generateLayerId().value,
      store.generateResourceId().value,
    ],
    snapshot.firstFreeIds,
    reason: '${route.name} must seed every current owner id.',
  );
}

void _expectFamilyOwnerMaps(_AdmissionSnapshot snapshot) {
  final tables = snapshot.committed.elements.familyTables;
  expect(tables.imageRows.keys, snapshot.idsFor(CanvasElementKind.image));
  expect(tables.vectorRows.keys, snapshot.idsFor(CanvasElementKind.vector));
  expect(tables.pathRows.keys, snapshot.idsFor(CanvasElementKind.path));
  expect(tables.textRows.keys, snapshot.idsFor(CanvasElementKind.text));
  expect(tables.strokeRows.keys, snapshot.idsFor(CanvasElementKind.stroke));
  expect(tables.lineRows.keys, snapshot.idsFor(CanvasElementKind.line));
  expect(tables.rectRows.keys, snapshot.idsFor(CanvasElementKind.rect));
}

void _expectCompleteTrace(_AdmissionTrace trace, _AdmissionSnapshot snapshot) {
  expect(trace.events, _expectedCompleteTrace(snapshot));
}

List<_TraceEvent> _expectedCompleteTrace(_AdmissionSnapshot snapshot) {
  return [
    _TraceEvent.familyOpen,
    for (final kind in _familyKinds) ..._expectedFamilyEntries(snapshot, kind),
    _TraceEvent.familyClose,
    _TraceEvent.layerOpen,
    for (var index = 0; index < snapshot.layerCount; index += 1) ...[
      _TraceEvent.layerEntry,
      _TraceEvent.layerInput,
    ],
    _TraceEvent.layerClose,
    _TraceEvent.resourceOpen,
    for (var index = 0; index < snapshot.resourceCount; index += 1) ...[
      _TraceEvent.resourceEntry,
      _TraceEvent.resourceInput,
    ],
    _TraceEvent.resourceClose,
  ];
}

List<_TraceEvent> _expectedFamilyEntries(
  _AdmissionSnapshot snapshot,
  CanvasElementKind kind,
) {
  final count = snapshot.elementCountFor(kind);
  return [
    for (var index = 0; index < count; index += 1) ...[
      _familyEntryEvent(kind),
      _TraceEvent.elementInput,
    ],
  ];
}

const _expectedSparseTrace = [
  _TraceEvent.elementLedger,
  _TraceEvent.elementInput,
  _TraceEvent.elementLedger,
  _TraceEvent.elementInput,
  _TraceEvent.layerLedger,
  _TraceEvent.layerInput,
  _TraceEvent.layerLedger,
  _TraceEvent.layerInput,
  _TraceEvent.resourceLedger,
  _TraceEvent.resourceInput,
  _TraceEvent.resourceLedger,
  _TraceEvent.resourceInput,
];

final _completeDelta = const StoreRevisionDelta.structural().merge(
  const StoreRevisionDelta.resource(),
);

final _completeRoutes = [
  const _CompleteRoute(
    name: 'construction',
    phase: IdAdmissionWorkPhase.reset,
    run: _runConstruction,
  ),
  const _CompleteRoute(
    name: 'installDocument',
    phase: IdAdmissionWorkPhase.acceptedAdmission,
    run: _runInstallDocument,
  ),
  const _CompleteRoute(
    name: 'replaceDocument',
    phase: IdAdmissionWorkPhase.reset,
    run: _runReplaceDocument,
  ),
  const _CompleteRoute(
    name: 'replacePreparedLoadDocument',
    phase: IdAdmissionWorkPhase.reset,
    run: _runReplacePreparedLoadDocument,
  ),
  const _CompleteRoute(
    name: 'installPreparedMaterializedCommit',
    phase: IdAdmissionWorkPhase.acceptedAdmission,
    run: _runInstallPreparedMaterializedCommit,
  ),
  const _CompleteRoute(
    name: 'installPreparedSchemaV1Import',
    phase: IdAdmissionWorkPhase.reset,
    run: _runInstallPreparedSchemaV1Import,
  ),
];

DocumentStoreKernel _runConstruction(
  _AdmissionSnapshot snapshot,
  _AdmissionTrace trace,
) {
  late DocumentStoreKernel store;
  trace.observe(() {
    store = DocumentStoreKernel.withCommittedDocumentForTesting(
      snapshot.committed,
    );
  });
  return store;
}

DocumentStoreKernel _runInstallDocument(
  _AdmissionSnapshot snapshot,
  _AdmissionTrace trace,
) {
  final store = DocumentStoreKernel();
  trace.observe(
    () => store.installDocument(snapshot.committed, _completeDelta),
  );
  return store;
}

DocumentStoreKernel _runReplaceDocument(
  _AdmissionSnapshot snapshot,
  _AdmissionTrace trace,
) {
  final store = DocumentStoreKernel();
  trace.observe(
    () => store.replaceDocument(snapshot.committed, _completeDelta),
  );
  return store;
}

DocumentStoreKernel _runReplacePreparedLoadDocument(
  _AdmissionSnapshot snapshot,
  _AdmissionTrace trace,
) {
  final store = DocumentStoreKernel();
  trace.observe(
    () => store.replacePreparedLoadDocument(snapshot.committed, _completeDelta),
  );
  return store;
}

DocumentStoreKernel _runInstallPreparedMaterializedCommit(
  _AdmissionSnapshot snapshot,
  _AdmissionTrace trace,
) {
  final store = DocumentStoreKernel();
  final prepared = store.prepareMaterializedCommit(
    snapshot.document,
    _completeDelta,
  );
  trace.observe(() => store.installPreparedMaterializedCommit(prepared));
  return store;
}

DocumentStoreKernel _runInstallPreparedSchemaV1Import(
  _AdmissionSnapshot snapshot,
  _AdmissionTrace trace,
) {
  final store = DocumentStoreKernel();
  final builder = StoreSchemaV1ImportBuilder();
  importSchemaV1Document(snapshot.schemaDocument, builder);
  final prepared = store.prepareSchemaV1Import(builder, _completeDelta);
  trace.observe(() => store.installPreparedSchemaV1Import(prepared));
  return store;
}

enum _OwnerVariant { allOwners, noElements, noLayers, noResources }

const _familyKinds = [
  CanvasElementKind.image,
  CanvasElementKind.vector,
  CanvasElementKind.path,
  CanvasElementKind.text,
  CanvasElementKind.stroke,
  CanvasElementKind.line,
  CanvasElementKind.rect,
];

final class _AdmissionSnapshot {
  _AdmissionSnapshot(_OwnerVariant variant)
    : this._(
        elements: _elementsFor(variant),
        layerIds: variant == _OwnerVariant.noLayers
            ? const []
            : const ['l0', 'l2', 'l4'],
        resourceIds: variant == _OwnerVariant.noResources
            ? const []
            : const ['r0', 'r2', 'r4'],
      );

  _AdmissionSnapshot.maximum({
    required int elementCount,
    required int layerCount,
    required int resourceCount,
  }) : this._(
         elements: List<CanvasElement>.generate(
           elementCount,
           (index) => _rect('e$index'),
           growable: false,
         ),
         layerIds: List<String>.generate(
           layerCount,
           (index) => 'l$index',
           growable: false,
         ),
         resourceIds: List<String>.generate(
           resourceCount,
           (index) => 'r$index',
           growable: false,
         ),
       );

  _AdmissionSnapshot._({
    required List<CanvasElement> elements,
    required this.layerIds,
    required this.resourceIds,
  }) : elements = List.unmodifiable(elements),
       elementIds = List.unmodifiable(
         elements.map((element) => element.id.value),
       ),
       document = CanvasDocument(
         backgroundElements: elements,
         layers: [
           for (final id in layerIds) CanvasLayer(id: CanvasLayerId(id)),
         ],
         resources: [for (final id in resourceIds) _resource(id)],
       );

  final List<String> elementIds;
  final List<CanvasElement> elements;
  final List<String> layerIds;
  final List<String> resourceIds;
  final CanvasDocument document;
  late final CommittedDocument committed = CommittedDocument(document);

  int get elementCount => elementIds.length;
  int get layerCount => layerIds.length;
  int get resourceCount => resourceIds.length;

  int elementCountFor(CanvasElementKind kind) {
    var count = 0;
    for (final element in elements) {
      if (_kindFor(element) == kind) {
        count += 1;
      }
    }
    return count;
  }

  List<String> get firstFreeIds => [
    _firstFree('e', elementIds),
    _firstFree('l', layerIds),
    _firstFree('r', resourceIds),
  ];

  Set<String> idsFor(CanvasElementKind kind) {
    return {
      for (final element in elements)
        if (_kindFor(element) == kind) element.id.value,
    };
  }

  Map<String, Object?> get schemaDocument {
    return encodeCanvasDocument(document);
  }
}

List<CanvasElement> _elementsFor(_OwnerVariant variant) {
  return switch (variant) {
    _OwnerVariant.noElements => const [],
    _OwnerVariant.noResources => _nonResourceFamilyElements(),
    _OwnerVariant.allOwners || _OwnerVariant.noLayers => _allFamilyElements(),
  };
}

final class _CompleteRoute {
  const _CompleteRoute({
    required this.name,
    required this.phase,
    required this.run,
  });

  final String name;
  final IdAdmissionWorkPhase phase;
  final DocumentStoreKernel Function(_AdmissionSnapshot, _AdmissionTrace) run;
}

enum _TraceEvent {
  familyOpen,
  familyImageEntry,
  familyVectorEntry,
  familyPathEntry,
  familyTextEntry,
  familyStrokeEntry,
  familyLineEntry,
  familyRectEntry,
  familyClose,
  layerOpen,
  layerEntry,
  layerClose,
  resourceOpen,
  resourceEntry,
  resourceClose,
  elementInput,
  layerInput,
  resourceInput,
  elementLedger,
  layerLedger,
  resourceLedger,
}

FamilyTablesTelemetrySink _familyTraceSink(List<_TraceEvent> events) {
  final telemetry = FamilyTablesTelemetry();
  return (event) {
    telemetry.record(event);
    _recordFamilyTrace(event, events);
  };
}

void _recordFamilyTrace(
  FamilyTablesTelemetryEvent event,
  List<_TraceEvent> events,
) {
  switch (event.kind) {
    case FamilyTablesTelemetryKind.enumerationOpen:
      events.add(_TraceEvent.familyOpen);
    case FamilyTablesTelemetryKind.enumerationEntry:
      final family = event.family;
      if (family == null) {
        throw StateError('Family enumeration telemetry requires a family.');
      }
      events.add(_familyEntryEvent(family));
    case FamilyTablesTelemetryKind.enumerationClose:
      events.add(_TraceEvent.familyClose);
    default:
      break;
  }
}

final class _AdmissionTrace {
  _AdmissionTrace(this.phase);

  final IdAdmissionWorkPhase phase;
  final events = <_TraceEvent>[];

  T observe<T>(T Function() operation) {
    return FamilyTables.observeTelemetry(
      _familyTraceSink(events),
      () => LayerTable.observeWork(
        _recordLayer,
        () => ResourceTable.observeEnumeration(
          _recordResource,
          () => DocumentStoreKernel.observeIdAdmissionWork(
            _recordAdmission,
            operation,
          ),
        ),
      ),
    );
  }

  void _recordLayer(LayerTableWorkEvent event) {
    switch (event) {
      case LayerTableWorkEvent.admissionEnumerationOpen:
        events.add(_TraceEvent.layerOpen);
      case LayerTableWorkEvent.admissionEnumerationEntry:
        events.add(_TraceEvent.layerEntry);
      case LayerTableWorkEvent.admissionEnumerationClose:
        events.add(_TraceEvent.layerClose);
      default:
        break;
    }
  }

  void _recordResource(ResourceTableEnumerationEvent event) {
    events.add(switch (event) {
      ResourceTableEnumerationEvent.open => _TraceEvent.resourceOpen,
      ResourceTableEnumerationEvent.entry => _TraceEvent.resourceEntry,
      ResourceTableEnumerationEvent.close => _TraceEvent.resourceClose,
    });
  }

  void _recordAdmission(IdAdmissionWorkEvent event) {
    if (event.phase != phase) {
      return;
    }
    switch (event.kind) {
      case IdAdmissionWorkKind.inputVisit:
        events.add(_inputEvent(event.prefix));
      case IdAdmissionWorkKind.sparseLedgerVisit:
        events.add(_ledgerEvent(event.prefix));
      default:
        break;
    }
  }
}

_TraceEvent _familyEntryEvent(CanvasElementKind kind) {
  return switch (kind) {
    CanvasElementKind.image => _TraceEvent.familyImageEntry,
    CanvasElementKind.vector => _TraceEvent.familyVectorEntry,
    CanvasElementKind.path => _TraceEvent.familyPathEntry,
    CanvasElementKind.text => _TraceEvent.familyTextEntry,
    CanvasElementKind.stroke => _TraceEvent.familyStrokeEntry,
    CanvasElementKind.line => _TraceEvent.familyLineEntry,
    CanvasElementKind.rect => _TraceEvent.familyRectEntry,
  };
}

_TraceEvent _inputEvent(String prefix) {
  return switch (prefix) {
    'e' => _TraceEvent.elementInput,
    'l' => _TraceEvent.layerInput,
    'r' => _TraceEvent.resourceInput,
    _ => throw StateError('Unexpected id admission prefix: $prefix'),
  };
}

_TraceEvent _ledgerEvent(String prefix) {
  return switch (prefix) {
    'e' => _TraceEvent.elementLedger,
    'l' => _TraceEvent.layerLedger,
    'r' => _TraceEvent.resourceLedger,
    _ => throw StateError('Unexpected sparse ledger prefix: $prefix'),
  };
}

String _firstFree(String prefix, Iterable<String> ids) {
  final occupied = ids.toSet();
  var suffix = 0;
  while (occupied.contains('$prefix$suffix')) {
    suffix += 1;
  }
  return '$prefix$suffix';
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}

List<CanvasElement> _allFamilyElements() {
  return [
    CanvasImageElement(
      id: CanvasElementId('e0'),
      resourceId: CanvasResourceId('r0'),
      size: const Size(1, 1),
    ),
    CanvasVectorElement(
      id: CanvasElementId('e2'),
      resourceId: CanvasResourceId('r2'),
      size: const Size(1, 1),
    ),
    CanvasPathElement(id: CanvasElementId('e4'), svgPathData: 'M0 0'),
    CanvasTextElement(
      id: CanvasElementId('e6'),
      text: 'text',
      color: const Color(0xFF000000),
      textDirection: TextDirection.ltr,
    ),
    CanvasStrokeElement(
      id: CanvasElementId('e8'),
      points: const [Offset.zero],
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    CanvasLineElement(
      id: CanvasElementId('e10'),
      start: Offset.zero,
      end: const Offset(1, 1),
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    _rect('e12'),
  ];
}

List<CanvasElement> _nonResourceFamilyElements() {
  return [
    CanvasPathElement(id: CanvasElementId('e0'), svgPathData: 'M0 0'),
    CanvasTextElement(
      id: CanvasElementId('e2'),
      text: 'text',
      color: const Color(0xFF000000),
      textDirection: TextDirection.ltr,
    ),
    CanvasStrokeElement(
      id: CanvasElementId('e4'),
      points: const [Offset.zero],
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    CanvasLineElement(
      id: CanvasElementId('e6'),
      start: Offset.zero,
      end: const Offset(1, 1),
      thickness: 1,
      color: const Color(0xFF000000),
    ),
    _rect('e8'),
  ];
}

CanvasResource _resource(String id) {
  return switch (id) {
    'r2' => CanvasVectorResource(
      id: CanvasResourceId(id),
      source: CanvasResourceSource.appKey('asset-$id'),
    ),
    _ => CanvasImageResource(
      id: CanvasResourceId(id),
      source: CanvasResourceSource.appKey('asset-$id'),
    ),
  };
}

CanvasElementKind _kindFor(CanvasElement element) {
  return switch (element) {
    CanvasImageElement() => CanvasElementKind.image,
    CanvasVectorElement() => CanvasElementKind.vector,
    CanvasPathElement() => CanvasElementKind.path,
    CanvasTextElement() => CanvasElementKind.text,
    CanvasStrokeElement() => CanvasElementKind.stroke,
    CanvasLineElement() => CanvasElementKind.line,
    CanvasRectElement() => CanvasElementKind.rect,
  };
}
