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

// The builder is the single handoff from schema-v1 import events to committed
// store tables; splitting it would create another retained import graph.
// ignore: coupling-between-object-classes
final class StoreSchemaV1ImportBuilder implements SchemaV1ImportSink {
  SchemaV1DocumentImportEvent? _document;
  final StoreResourceDescriptorImportBuilder _resources =
      StoreResourceDescriptorImportBuilder();
  final FamilyTablesSchemaV1ImportBuilder _families =
      FamilyTablesSchemaV1ImportBuilder();
  final LayerTableSchemaV1ImportBuilder _layers =
      LayerTableSchemaV1ImportBuilder();
  final ElementRegistrySchemaV1OrderImportBuilder _elementOrder =
      ElementRegistrySchemaV1OrderImportBuilder();
  bool _ended = false;

  @override
  void beginDocument(SchemaV1DocumentImportEvent event) {
    _ensureNotConsumed();
    _document = event;
  }

  @override
  void imageResource(SchemaV1ImageResourceImportEvent event) {
    _resources.addSchemaV1Import(event);
  }

  @override
  void backgroundElement(SchemaV1ElementImportEvent event) {
    _families.add(event, _resources.admittedIds);
    _elementOrder.addBackground(event.common.id);
  }

  @override
  void layer(SchemaV1LayerImportEvent event) {
    _layers.addLayer(event);
  }

  @override
  void layerElement(CanvasLayerId layerId, SchemaV1ElementImportEvent event) {
    _families.add(event, _resources.admittedIds);
    _layers.addElement(layerId, event.common.id);
    _elementOrder.addContent(layerId, event.common.id);
  }

  @override
  void endDocument() {
    _ensureNotConsumed();
    _ended = true;
  }

  // Preparation keeps row construction, revision acceptance, and prepared
  // payload creation in one pass so no second document-sized graph appears.
  // ignore: halstead-volume, source-lines-of-code
  PreparedStoreDocumentImport prepare({
    required RevisionState baseRevisions,
    required StoreRevisionDelta revisionDelta,
  }) {
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
      resourceIds: Set.unmodifiable(resourceTable.descriptors.keys),
      layerIds: Set.unmodifiable([
        for (final row in elements.layerTable.rows) row.id,
      ]),
      elementCount: elements.elementCount,
    );
  }

  void _ensureNotConsumed() {
    _elementOrder.ensureNotConsumed();
  }
}

final class PreparedStoreDocumentImport {
  PreparedStoreDocumentImport._({
    required this.baseRevisions,
    required this.document,
    required this.revisionDelta,
    required this.resourceIds,
    required this.layerIds,
    required this.elementCount,
  });

  final RevisionState baseRevisions;
  final CommittedDocument document;
  final StoreRevisionDelta revisionDelta;
  final Set<CanvasResourceId> resourceIds;
  final Set<CanvasLayerId> layerIds;
  final int elementCount;
  Set<CanvasElementId>? _elementIds;
  bool _isConsumed = false;

  Set<CanvasElementId> get elementIds {
    return _elementIds ??= Set.unmodifiable(
      document.elements.frameElementOrder,
    );
  }

  CanvasDocumentSummary get summary {
    return CanvasDocumentSummary(
      elementCount: elementCount,
      layerCount: layerIds.length,
      resourceCount: resourceIds.length,
    );
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
