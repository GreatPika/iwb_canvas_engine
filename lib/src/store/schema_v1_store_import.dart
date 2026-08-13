// ignore_for_file: number-of-imports

import 'dart:async';

import 'package:flutter/foundation.dart' show internal, visibleForTesting;

import '../contracts/internal/schema_v1_import_events.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import 'committed_document.dart';
import 'element_registry.dart';
import 'family_tables.dart';
import 'layer_table.dart';
import 'resource_table.dart';
import 'revision_state.dart';
import 'store_revision_delta.dart';

/// Zone-scoped events keep scalar prepared-summary work observable without
/// retaining document-sized counters or inventories in production state.
@visibleForTesting
enum PreparedSummaryWorkEvent { capture, storeSummaryRead, loadSummaryRead }

final Object _preparedSummaryWorkZoneKey = Object();

enum _PreparedSummaryReadKind { store, load }

/// The common prepared-summary view retains only the scalar snapshot and the
/// owner-specific read event; payload owners cannot reach rows or ids here.
@internal
base class PreparedSummaryView {
  PreparedSummaryView.store(CanvasDocumentSummary summary)
    : _summary = summary,
      _readKind = _PreparedSummaryReadKind.store;

  PreparedSummaryView.load(CanvasDocumentSummary summary)
    : _summary = summary,
      _readKind = _PreparedSummaryReadKind.load;

  final CanvasDocumentSummary _summary;
  final _PreparedSummaryReadKind _readKind;

  CanvasDocumentSummary get summary {
    _recordPreparedSummaryWork(switch (_readKind) {
      _PreparedSummaryReadKind.store =>
        PreparedSummaryWorkEvent.storeSummaryRead,
      _PreparedSummaryReadKind.load => PreparedSummaryWorkEvent.loadSummaryRead,
    });
    return _summary;
  }
}

/// Captures the exact scalar facts supplied by a complete prepared payload.
@internal
CanvasDocumentSummary capturePreparedSummary({
  required int elementCount,
  required int layerCount,
  required int resourceCount,
}) {
  _recordPreparedSummaryWork(PreparedSummaryWorkEvent.capture);
  return CanvasDocumentSummary(
    elementCount: elementCount,
    layerCount: layerCount,
    resourceCount: resourceCount,
  );
}

void _recordPreparedSummaryWork(PreparedSummaryWorkEvent event) {
  assert(() {
    final sink = Zone.current[_preparedSummaryWorkZoneKey];
    if (sink is void Function(PreparedSummaryWorkEvent)) {
      sink(event);
    }
    return true;
  }(), 'prepared summary work observation failed');
}

// The builder is the single handoff from schema-v1 import events to committed
// store tables; splitting it would create another retained import graph.
// ignore: coupling-between-object-classes, number-of-methods
final class StoreSchemaV1ImportBuilder implements IsolatedSchemaV1ImportSink {
  SchemaV1DocumentImportEvent? _document;
  final StoreResourceDescriptorImportBuilder _resources =
      StoreResourceDescriptorImportBuilder();
  final FamilyTablesSchemaV1ImportBuilder _families =
      FamilyTablesSchemaV1ImportBuilder();
  final LayerTableSchemaV1ImportBuilder _layers =
      LayerTableSchemaV1ImportBuilder();
  final ElementRegistrySchemaV1OrderImportBuilder _elementOrder =
      ElementRegistrySchemaV1OrderImportBuilder();
  bool _started = false;
  bool _ended = false;
  bool _aborted = false;

  @override
  void beginDocument(SchemaV1DocumentImportEvent event) {
    _ensureNotConsumedOrAborted();
    if (_started) {
      throw StateError('schema v1 import stream has already started.');
    }
    _started = true;
    _document = event;
  }

  @override
  void resource(SchemaV1ResourceImportEvent event) {
    _acceptEvent(() {
      _resources.addSchemaV1Import(event);
    });
  }

  @override
  void backgroundElement(SchemaV1ElementImportEvent event) {
    _acceptEvent(() {
      _families.add(event);
      _elementOrder.addBackground(event.common.id);
    });
  }

  @override
  void layer(SchemaV1LayerImportEvent event) {
    _acceptEvent(() {
      _layers.addLayer(event);
    });
  }

  @override
  void layerElement(CanvasLayerId layerId, SchemaV1ElementImportEvent event) {
    _acceptEvent(() {
      _families.add(event);
      _layers.addElement(layerId, event.common.id);
      _elementOrder.addContent(layerId, event.common.id);
    });
  }

  @override
  void endDocument() {
    _ensureAcceptingEvents();
    _ended = true;
  }

  @override
  void abortDocument() {
    _document = null;
    _started = false;
    _ended = false;
    _aborted = true;
  }

  // Preparation keeps row construction, revision acceptance, and prepared
  // payload creation in one pass so no second document-sized graph appears.
  // ignore: halstead-volume, source-lines-of-code
  PreparedStoreDocumentImport prepare({
    required RevisionState baseRevisions,
    required StoreRevisionDelta revisionDelta,
  }) {
    if (_aborted) {
      throw StateError('schema v1 import stream was aborted.');
    }
    if (!_ended) {
      throw StateError('schema v1 import stream did not finish.');
    }
    final document = _document;
    if (document == null) {
      throw StateError('schema v1 import stream did not start.');
    }
    final acceptedRevisions = revisionDelta.advance(baseRevisions);
    final resourceTable = _resources.consume(
      resourceRevision: acceptedRevisions.resourceRevision,
    );
    final elements = ElementRegistry.fromSchemaV1ImportTables(
      familyTables: _families.consume(),
      layerTable: _layers.consume(),
      orderFacts: _elementOrder.consume(),
    );
    final committed = CommittedDocument.fromStoreTables(
      camera: document.camera,
      background: document.background,
      palette: document.palette,
      elements: elements,
      metadata: document.metadata,
      resourceTable: resourceTable,
      revisions: acceptedRevisions,
    );

    return PreparedStoreDocumentImport._(
      baseRevisions: baseRevisions,
      document: committed,
      revisionDelta: revisionDelta,
      summary: capturePreparedSummary(
        elementCount: committed.elements.elementCount,
        layerCount: committed.elements.layerTable.rows.length,
        resourceCount: committed.resourceTable.count,
      ),
    );
  }

  void _ensureNotConsumedOrAborted() {
    if (_aborted) {
      throw StateError('schema v1 import stream was aborted.');
    }
    _elementOrder.ensureNotConsumed();
  }

  void _ensureAcceptingEvents() {
    _ensureNotConsumedOrAborted();
    if (!_started) {
      throw StateError('schema v1 import stream did not start.');
    }
    if (_ended) {
      throw StateError('schema v1 import stream has already ended.');
    }
  }

  void _acceptEvent(void Function() accept) {
    _ensureAcceptingEvents();
    try {
      accept();
    } on Object {
      abortDocument();
      rethrow;
    }
  }
}

final class PreparedStoreDocumentImport extends PreparedSummaryView {
  PreparedStoreDocumentImport._({
    required this.baseRevisions,
    required this.document,
    required this.revisionDelta,
    required CanvasDocumentSummary summary,
  }) : super.store(summary);

  final RevisionState baseRevisions;
  final CommittedDocument document;
  final StoreRevisionDelta revisionDelta;
  bool _isConsumed = false;

  @visibleForTesting
  static T observeSummaryWork<T>(
    void Function(PreparedSummaryWorkEvent event) sink,
    T Function() operation,
  ) {
    return runZoned(operation, zoneValues: {_preparedSummaryWorkZoneKey: sink});
  }

  bool get hasChanges => revisionDelta.hasChanges;

  void consume(RevisionState currentRevisions) {
    if (_isConsumed) {
      throw StateError(
        'PreparedStoreDocumentImport has already been consumed.',
      );
    }
    if (baseRevisions != currentRevisions) {
      throw StateError('Prepared schema v1 store import is stale.');
    }
    _isConsumed = true;
  }
}
