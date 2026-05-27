import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_transform_admission.dart';
import '../diagnostics/diagnostics_hub.dart';
import 'schema_v1_diagnostics.dart';

final class ValidatedImportDraft {
  ValidatedImportDraft.fromDocument(
    this.document, {
    DiagnosticsHub? diagnostics,
  }) : resourceIds = _validatedResourceIds(
         document.resources,
         diagnostics: diagnostics,
       ),
       layerIds = _validatedLayerIds(document.layers, diagnostics: diagnostics),
       elementIds = _validatedElementIds(document, diagnostics: diagnostics);

  final CanvasDocument document;
  final Set<CanvasResourceId> resourceIds;
  final Set<CanvasLayerId> layerIds;
  final Set<CanvasElementId> elementIds;
}

Set<CanvasResourceId> _validatedResourceIds(
  List<CanvasResource> resources, {
  required DiagnosticsHub? diagnostics,
}) {
  final ids = <CanvasResourceId>{};
  for (final resource in resources) {
    if (!ids.add(resource.id)) {
      throw recordSchemaV1FailureDiagnostic(
        diagnostics,
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

Set<CanvasLayerId> _validatedLayerIds(
  List<CanvasLayer> layers, {
  required DiagnosticsHub? diagnostics,
}) {
  final ids = <CanvasLayerId>{};
  for (final layer in layers) {
    if (!ids.add(layer.id)) {
      throw recordSchemaV1FailureDiagnostic(
        diagnostics,
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

Set<CanvasElementId> _validatedElementIds(
  CanvasDocument document, {
  required DiagnosticsHub? diagnostics,
}) {
  final ids = <CanvasElementId>{};
  final resourceIds = document.resources.map((resource) => resource.id).toSet();
  for (final element in _allElements(document)) {
    try {
      validateElementTransformAdmission(
        element.transform,
        path: 'element.transform',
      );
    } on CanvasDataException catch (error) {
      throw recordSchemaV1FailureDiagnostic(diagnostics, error);
    }
    if (!ids.add(element.id)) {
      throw recordSchemaV1FailureDiagnostic(
        diagnostics,
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
        diagnostics,
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
