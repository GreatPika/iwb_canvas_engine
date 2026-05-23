import '../api/canvas_document.dart';
import '../api/canvas_element.dart';
import '../api/canvas_errors.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_resource.dart';
import 'schema_v1_diagnostics.dart';

final class ValidatedImportDraft {
  ValidatedImportDraft.fromDocument(this.document)
    : resourceIds = _validatedResourceIds(document.resources),
      layerIds = _validatedLayerIds(document.layers),
      elementIds = _validatedElementIds(document);

  final CanvasDocument document;
  final Set<CanvasResourceId> resourceIds;
  final Set<CanvasLayerId> layerIds;
  final Set<CanvasElementId> elementIds;
}

Set<CanvasResourceId> _validatedResourceIds(List<CanvasResource> resources) {
  final ids = <CanvasResourceId>{};
  for (final resource in resources) {
    if (!ids.add(resource.id)) {
      throw recordSchemaV1FailureDiagnostic(
        null,
        CanvasDataException(
          code: CanvasDataErrorCode.duplicateResourceId,
          message: 'duplicate resource id.',
          path: 'resources.id',
        ),
      );
    }
  }

  return Set.unmodifiable(ids);
}

Set<CanvasLayerId> _validatedLayerIds(List<CanvasLayer> layers) {
  final ids = <CanvasLayerId>{};
  for (final layer in layers) {
    if (!ids.add(layer.id)) {
      throw recordSchemaV1FailureDiagnostic(
        null,
        CanvasDataException(
          code: CanvasDataErrorCode.duplicateLayerId,
          message: 'duplicate layer id.',
          path: 'layers.id',
        ),
      );
    }
  }

  return Set.unmodifiable(ids);
}

Set<CanvasElementId> _validatedElementIds(CanvasDocument document) {
  final ids = <CanvasElementId>{};
  final resourceIds = document.resources.map((resource) => resource.id).toSet();
  for (final element in _allElements(document)) {
    if (!ids.add(element.id)) {
      throw recordSchemaV1FailureDiagnostic(
        null,
        CanvasDataException(
          code: CanvasDataErrorCode.duplicateElementId,
          message: 'duplicate element id.',
          path: 'elements.id',
        ),
      );
    }
    if (element is CanvasImageElement &&
        !resourceIds.contains(element.resourceId)) {
      throw recordSchemaV1FailureDiagnostic(
        null,
        CanvasDataException(
          code: CanvasDataErrorCode.missingResourceReference,
          message: 'image element references a missing resource.',
          path: 'image.resourceId',
        ),
      );
    }
  }

  return Set.unmodifiable(ids);
}

Iterable<CanvasElement> _allElements(CanvasDocument document) sync* {
  yield* document.backgroundElements;
  for (final layer in document.layers) {
    yield* layer.elements;
  }
}
