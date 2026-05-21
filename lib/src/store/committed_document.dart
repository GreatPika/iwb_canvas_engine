import '../api/canvas_document.dart';
import '../api/canvas_errors.dart';
import '../api/canvas_metadata.dart';
import '../api/canvas_resource.dart';
import 'element_registry.dart';
import 'family_tables.dart';
import 'revision_state.dart';

final class CommittedDocument {
  factory CommittedDocument(CanvasDocument document) {
    final resources = List<CanvasResource>.unmodifiable(
      _admitResources(document.resources),
    );

    return CommittedDocument._(
      camera: document.camera,
      background: document.background,
      palette: document.palette,
      resources: resources,
      elements: ElementRegistry(
        backgroundElements: document.backgroundElements,
        layers: document.layers,
        resourceIds: {for (final resource in resources) resource.id.value},
      ),
      metadata: document.metadata,
    );
  }

  CommittedDocument._({
    required this.camera,
    required this.background,
    required this.palette,
    required this.resources,
    required this.elements,
    required this.metadata,
  });

  final CanvasCamera camera;
  final CanvasBackground background;
  final CanvasPalette palette;
  final List<CanvasResource> resources;
  final ElementRegistry elements;
  final CanvasMetadata metadata;
  final RevisionState revisions = const RevisionState();

  CanvasDocumentSummary get summary {
    return CanvasDocumentSummary(
      elementCount: elements.elementCount,
      layerCount: elements.layerTable.rows.length,
      resourceCount: resources.length,
    );
  }

  Set<String> get admittedElementIds => elements.admittedElementIds;
  Set<String> get admittedLayerIds => elements.admittedLayerIds;
  Set<String> get admittedResourceIds {
    return {for (final resource in resources) resource.id.value};
  }
}

List<CanvasResource> _admitResources(Iterable<CanvasResource> resources) {
  final admittedIds = <String>{};
  final admittedResources = <CanvasResource>[];
  for (final resource in resources) {
    if (!admittedIds.add(resource.id.value)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateResourceId,
        message: 'duplicate resource id.',
        path: 'resources.id',
      );
    }
    admittedResources.add(copyResource(resource));
  }

  return admittedResources;
}
