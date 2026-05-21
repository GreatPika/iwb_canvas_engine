import '../api/canvas_document.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_metadata.dart';
import 'element_registry.dart';
import 'revision_state.dart';
import 'resource_table.dart';

final class CommittedDocument {
  factory CommittedDocument(CanvasDocument document) {
    const revisions = RevisionState();
    final resourceTable = ResourceTable(
      document.resources,
      resourceRevision: revisions.resourceRevision,
    );

    return CommittedDocument._(
      camera: document.camera,
      background: document.background,
      palette: document.palette,
      elements: ElementRegistry(
        backgroundElements: document.backgroundElements,
        layers: document.layers,
        resourceIds: resourceTable.admittedIds,
      ),
      metadata: document.metadata,
      resourceTable: resourceTable,
      revisions: revisions,
    );
  }

  CommittedDocument._({
    required this.camera,
    required this.background,
    required this.palette,
    required this.elements,
    required this.metadata,
    required this.resourceTable,
    required this.revisions,
  });

  final CanvasCamera camera;
  final CanvasBackground background;
  final CanvasPalette palette;
  final ElementRegistry elements;
  final CanvasMetadata metadata;
  final ResourceTable resourceTable;
  final RevisionState revisions;

  CanvasDocumentSummary get summary {
    return CanvasDocumentSummary(
      elementCount: elements.elementCount,
      layerCount: elements.layerTable.rows.length,
      resourceCount: resourceTable.rows.length,
    );
  }

  Set<String> get admittedElementIds => elements.admittedElementIds;
  Set<String> get admittedLayerIds => elements.admittedLayerIds;
  Set<String> get admittedResourceIds => resourceTable.admittedIds;

  StoreResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    return resourceTable.descriptors[id];
  }
}
