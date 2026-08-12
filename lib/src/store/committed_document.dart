import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import 'element_registry.dart';
import 'revision_state.dart';
import 'resource_table.dart';

// This immutable aggregate owns committed document facts and derived variants
// together so row snapshots cannot become competing sources of truth.
// ignore: number-of-methods
final class CommittedDocument {
  factory CommittedDocument.empty() {
    return CommittedDocument.fromStoreTables(
      camera: CanvasCamera.origin,
      background: const CanvasBackground(),
      palette: const CanvasPalette.defaults(),
      elements: ElementRegistry.empty(),
      metadata: const CanvasMetadata.empty(),
      resourceTable: const ResourceTable.empty(),
      revisions: const RevisionState(),
    );
  }

  factory CommittedDocument(CanvasDocument document) {
    return CommittedDocument.withRevisions(
      document,
      revisions: const RevisionState(),
    );
  }

  factory CommittedDocument.withRevisions(
    CanvasDocument document, {
    required RevisionState revisions,
  }) {
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
      ),
      metadata: document.metadata,
      resourceTable: resourceTable,
      revisions: revisions,
    );
  }

  const CommittedDocument._({
    required this.camera,
    required this.background,
    required this.palette,
    required this.elements,
    required this.metadata,
    required this.resourceTable,
    required this.revisions,
  });

  factory CommittedDocument.fromStoreTables({
    required CanvasCamera camera,
    required CanvasBackground background,
    required CanvasPalette palette,
    required ElementRegistry elements,
    required CanvasMetadata metadata,
    required ResourceTable resourceTable,
    required RevisionState revisions,
  }) {
    return CommittedDocument._(
      camera: camera,
      background: background,
      palette: palette,
      elements: elements,
      metadata: metadata,
      resourceTable: resourceTable,
      revisions: revisions,
    );
  }

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
      resourceCount: resourceTable.count,
    );
  }

  StoreResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    return resourceTable.descriptors[id];
  }

  CommittedDocument copyWith({
    CanvasCamera? camera,
    CanvasBackground? background,
    CanvasPalette? palette,
    ElementRegistry? elements,
    CanvasMetadata? metadata,
    ResourceTable? resourceTable,
    RevisionState? revisions,
  }) {
    return CommittedDocument._(
      camera: camera ?? this.camera,
      background: background ?? this.background,
      palette: palette ?? this.palette,
      elements: elements ?? this.elements,
      metadata: metadata ?? this.metadata,
      resourceTable: resourceTable ?? this.resourceTable,
      revisions: revisions ?? this.revisions,
    );
  }
}
