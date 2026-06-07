import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_transform_admission.dart';
import '../diagnostics/diagnostics_hub.dart';
import 'schema_v1_diagnostics.dart';
import 'schema_v1_decoder.dart';

final class ValidatedImportDraft {
  factory ValidatedImportDraft.fromSchemaV1Json(
    String json, {
    DiagnosticsHub? diagnostics,
  }) {
    final document = decodeSchemaV1DocumentFromJson(
      json,
      diagnostics: diagnostics,
    );
    final resourceIds = _validatedResourceIds(
      document.resources,
      diagnostics: diagnostics,
    );
    final layerIds = _validatedLayerIds(
      document.layers,
      diagnostics: diagnostics,
    );
    final elementIds = _validatedElementIds(
      _allElements(document.backgroundElements, document.layers),
      resourceIds: resourceIds,
      diagnostics: diagnostics,
    );

    return ValidatedImportDraft._(
      document: document,
      resourceIds: resourceIds,
      layerIds: layerIds,
      elementIds: elementIds,
    );
  }

  factory ValidatedImportDraft.fromDraftReplacement(
    CanvasDocument document, {
    DiagnosticsHub? diagnostics,
  }) {
    final resourceIds = _validatedResourceIds(
      document.resources,
      diagnostics: diagnostics,
    );
    final layerIds = _validatedLayerIds(
      document.layers,
      diagnostics: diagnostics,
    );
    final elementIds = _validatedElementIds(
      _allElements(document.backgroundElements, document.layers),
      resourceIds: resourceIds,
      diagnostics: diagnostics,
    );

    return ValidatedImportDraft._(
      document: document,
      resourceIds: resourceIds,
      layerIds: layerIds,
      elementIds: elementIds,
    );
  }

  factory ValidatedImportDraft.fromEncodeDocument(
    CanvasDocument document, {
    DiagnosticsHub? diagnostics,
  }) {
    final resourceIds = _validatedResourceIds(
      document.resources,
      diagnostics: diagnostics,
    );
    final layerIds = _validatedLayerIds(
      document.layers,
      diagnostics: diagnostics,
    );
    final elementIds = _validatedElementIds(
      _allElements(document.backgroundElements, document.layers),
      resourceIds: resourceIds,
      diagnostics: diagnostics,
    );

    return ValidatedImportDraft._(
      document: document,
      resourceIds: resourceIds,
      layerIds: layerIds,
      elementIds: elementIds,
    );
  }

  const ValidatedImportDraft._({
    required this.document,
    required this.resourceIds,
    required this.layerIds,
    required this.elementIds,
  });

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
  Iterable<CanvasElement> elements, {
  required Set<CanvasResourceId> resourceIds,
  required DiagnosticsHub? diagnostics,
}) {
  final ids = <CanvasElementId>{};
  for (final element in elements) {
    try {
      validateElementTransformAdmission(
        element.transform,
        path: 'element.transform',
      );
    } on CanvasDataException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        recordSchemaV1FailureDiagnostic(diagnostics, error),
        stackTrace,
      );
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

Iterable<CanvasElement> _allElements(
  Iterable<CanvasElement> backgroundElements,
  Iterable<CanvasLayer> layers,
) sync* {
  yield* backgroundElements;
  for (final layer in layers) {
    yield* layer.elements;
  }
}
