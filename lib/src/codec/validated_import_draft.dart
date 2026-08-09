import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_transform_admission.dart';
import '../diagnostics/diagnostics_hub.dart';
import 'schema_v1_diagnostics.dart';

final class ValidatedImportDraft {
  factory ValidatedImportDraft.fromDraftReplacement(
    CanvasDocument document, {
    DiagnosticsHub? diagnostics,
  }) {
    final resources = _validatedResources(
      document.resources,
      diagnostics: diagnostics,
    );
    final layerIds = _validatedLayerIds(
      document.layers,
      diagnostics: diagnostics,
    );
    final elementIds = _validatedElementIds(
      _allElements(document.backgroundElements, document.layers),
      resources: resources,
      diagnostics: diagnostics,
    );

    return ValidatedImportDraft._(
      document: document,
      resourceIds: resources.keys.toSet(),
      layerIds: layerIds,
      elementIds: elementIds,
    );
  }

  factory ValidatedImportDraft.fromEncodeDocument(
    CanvasDocument document, {
    DiagnosticsHub? diagnostics,
  }) {
    final resources = _validatedResources(
      document.resources,
      diagnostics: diagnostics,
    );
    final layerIds = _validatedLayerIds(
      document.layers,
      diagnostics: diagnostics,
    );
    final elementIds = _validatedElementIds(
      _allElements(document.backgroundElements, document.layers),
      resources: resources,
      diagnostics: diagnostics,
    );

    return ValidatedImportDraft._(
      document: document,
      resourceIds: resources.keys.toSet(),
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

Map<CanvasResourceId, CanvasResource> _validatedResources(
  List<CanvasResource> resources, {
  required DiagnosticsHub? diagnostics,
}) {
  final byId = <CanvasResourceId, CanvasResource>{};
  for (final resource in resources) {
    if (byId.containsKey(resource.id)) {
      throw recordSchemaV1FailureDiagnostic(
        diagnostics,
        CanvasDataException(
          code: CanvasDataErrorCode.duplicateResourceId,
          message: 'duplicate resource id.',
          path: 'resources.id',
        ),
      );
    }
    byId[resource.id] = resource;
  }

  return Map.unmodifiable(byId);
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
  required Map<CanvasResourceId, CanvasResource> resources,
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
    _validateResourceRelationship(element, resources, diagnostics);
  }

  return Set.unmodifiable(ids);
}

void _validateResourceRelationship(
  CanvasElement element,
  Map<CanvasResourceId, CanvasResource> resources,
  DiagnosticsHub? diagnostics,
) {
  final relationship = switch (element) {
    CanvasImageElement() => (element.resourceId, 'image.resourceId', true),
    CanvasVectorElement() => (element.resourceId, 'vector.resourceId', false),
    _ => null,
  };
  if (relationship == null) {
    return;
  }
  final descriptor = resources[relationship.$1];
  final error = switch (descriptor) {
    null => CanvasDataException(
      code: CanvasDataErrorCode.missingResourceReference,
      message: 'resource element references a missing resource.',
      path: relationship.$2,
    ),
    CanvasImageResource() when !relationship.$3 => CanvasDataException(
      code: CanvasDataErrorCode.resourceKindMismatch,
      message: 'resource kind does not match the referencing element.',
      path: relationship.$2,
    ),
    CanvasVectorResource() when relationship.$3 => CanvasDataException(
      code: CanvasDataErrorCode.resourceKindMismatch,
      message: 'resource kind does not match the referencing element.',
      path: relationship.$2,
    ),
    _ => null,
  };
  if (error != null) {
    throw recordSchemaV1FailureDiagnostic(diagnostics, error);
  }
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
