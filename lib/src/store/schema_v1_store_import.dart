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
  final List<SchemaV1ImageResourceImportEvent> _resources = [];
  final List<SchemaV1ElementImportEvent> _backgroundElements = [];
  final List<_ImportedLayer> _layers = [];
  _ImportedLayer? _currentLayer;
  bool _ended = false;

  @override
  void beginDocument(SchemaV1DocumentImportEvent event) {
    _document = event;
  }

  @override
  void imageResource(SchemaV1ImageResourceImportEvent event) {
    _resources.add(event);
  }

  @override
  void backgroundElement(SchemaV1ElementImportEvent event) {
    _backgroundElements.add(event);
  }

  @override
  void layer(SchemaV1LayerImportEvent event) {
    final imported = _ImportedLayer(event);
    _layers.add(imported);
    _currentLayer = imported;
  }

  @override
  void layerElement(CanvasLayerId layerId, SchemaV1ElementImportEvent event) {
    final layer = _currentLayer;
    if (layer == null || layer.event.id != layerId) {
      throw StateError('schema v1 layer element arrived before its layer.');
    }
    layer.elements.add(event);
  }

  @override
  void endDocument() {
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
    final resourceTable = ResourceTable.fromSchemaV1Import(
      _resources,
      resourceRevision: acceptedRevisions.resourceRevision,
    );
    final elements = ElementRegistry.fromTables(
      backgroundElementIds: [
        for (final element in _backgroundElements) element.common.id,
      ],
      familyTables: FamilyTables.fromSchemaV1Import([
        ..._backgroundElements,
        for (final layer in _layers) ...layer.elements,
      ], resourceIds: resourceTable.admittedIds),
      layerTable: LayerTable([
        for (final layer in _layers)
          LayerRow(
            id: layer.event.id,
            elementIds: [
              for (final element in layer.elements) element.common.id,
            ],
            metadata: layer.event.metadata,
          ),
      ]),
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
      elementIds: Set.unmodifiable(elements.frameElementOrder),
    );
  }
}

final class PreparedStoreDocumentImport {
  PreparedStoreDocumentImport._({
    required this.baseRevisions,
    required this.document,
    required this.revisionDelta,
    required this.resourceIds,
    required this.layerIds,
    required this.elementIds,
  });

  final RevisionState baseRevisions;
  final CommittedDocument document;
  final StoreRevisionDelta revisionDelta;
  final Set<CanvasResourceId> resourceIds;
  final Set<CanvasLayerId> layerIds;
  final Set<CanvasElementId> elementIds;
  bool _isConsumed = false;

  CanvasDocumentSummary get summary => document.summary;
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

final class _ImportedLayer {
  _ImportedLayer(this.event);

  final SchemaV1LayerImportEvent event;
  final List<SchemaV1ElementImportEvent> elements = [];
}
