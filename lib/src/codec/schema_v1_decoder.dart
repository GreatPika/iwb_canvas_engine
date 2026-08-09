// The schema decoder is a public DTO materialization sink over the canonical
// schema v1 reader. Wire-format navigation and field admission stay in
// schema_v1_reader.dart.

import '../contracts/internal/schema_v1_import_events.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import '../diagnostics/diagnostics_hub.dart';
import 'schema_v1_diagnostics.dart';
import 'schema_v1_reader.dart';

CanvasDocument decodeSchemaV1Document(
  Map<String, Object?> json, {
  DiagnosticsHub? diagnostics,
}) {
  final builder = _CanvasDocumentBuilderSink(diagnostics);
  readSchemaV1Document(json, builder, diagnostics: diagnostics);

  return builder.build();
}

CanvasDocument decodeSchemaV1DocumentFromJson(
  String json, {
  DiagnosticsHub? diagnostics,
}) {
  final builder = _CanvasDocumentBuilderSink(diagnostics);
  readSchemaV1DocumentFromJson(json, builder, diagnostics: diagnostics);

  return builder.build();
}

// The decoder sink intentionally keeps the full schema event-to-public document
// assembly contract in one place; splitting it would hide the single target
// consumed by the canonical reader.
// ignore: coupling-between-object-classes
final class _CanvasDocumentBuilderSink implements SchemaV1ImportSink {
  _CanvasDocumentBuilderSink(this._diagnostics);

  final DiagnosticsHub? _diagnostics;
  final _resources = <CanvasResource>[];
  final _backgroundElements = <CanvasElement>[];
  final _layerDrafts = <_CanvasLayerDraft>[];
  SchemaV1DocumentImportEvent? _document;
  var _didEndDocument = false;

  @override
  void beginDocument(SchemaV1DocumentImportEvent event) {
    _document = event;
  }

  @override
  void resource(SchemaV1ResourceImportEvent event) {
    _resources.add(_materializeResource(event, _diagnostics));
  }

  @override
  void backgroundElement(SchemaV1ElementImportEvent event) {
    _backgroundElements.add(_materializeElement(event, _diagnostics));
  }

  @override
  void layer(SchemaV1LayerImportEvent event) {
    _layerDrafts.add(_CanvasLayerDraft(event));
  }

  @override
  void layerElement(CanvasLayerId layerId, SchemaV1ElementImportEvent event) {
    _layerDraftFor(
      layerId,
    ).elements.add(_materializeElement(event, _diagnostics));
  }

  @override
  void endDocument() {
    _didEndDocument = true;
  }

  CanvasDocument build() {
    final document = _document;
    if (document == null) {
      throw StateError('schema v1 reader did not emit a document event.');
    }
    if (!_didEndDocument) {
      throw StateError('schema v1 reader did not complete the document.');
    }
    final materialized = _materialize(
      _diagnostics,
      () => CanvasDocument(
        camera: document.camera,
        background: document.background,
        palette: document.palette,
        resources: _resources,
        backgroundElements: _backgroundElements,
        layers: _layerDrafts.map((draft) => draft.build(_diagnostics)),
        metadata: document.metadata,
      ),
    );
    _validateDocumentReferences(materialized, diagnostics: _diagnostics);

    return materialized;
  }

  _CanvasLayerDraft _layerDraftFor(CanvasLayerId layerId) {
    for (final draft in _layerDrafts.reversed) {
      if (draft.event.id == layerId) {
        return draft;
      }
    }

    throw StateError('schema v1 reader emitted an element before its layer.');
  }
}

CanvasElement _materializeElement(
  SchemaV1ElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  return switch (event) {
    SchemaV1ImageElementImportEvent() => _materializeImageElement(
      event,
      diagnostics,
    ),
    SchemaV1VectorElementImportEvent() => _materializeVectorElement(
      event,
      diagnostics,
    ),
    SchemaV1PathElementImportEvent() => _materializePathElement(
      event,
      diagnostics,
    ),
    SchemaV1TextElementImportEvent() => _materializeTextElement(
      event,
      diagnostics,
    ),
    SchemaV1StrokeElementImportEvent() => _materializeStrokeElement(
      event,
      diagnostics,
    ),
    SchemaV1LineElementImportEvent() => _materializeLineElement(
      event,
      diagnostics,
    ),
    SchemaV1RectElementImportEvent() => _materializeRectElement(
      event,
      diagnostics,
    ),
  };
}

CanvasResource _materializeResource(
  SchemaV1ResourceImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  return switch (event) {
    SchemaV1ImageResourceImportEvent() => _materialize(
      diagnostics,
      () => CanvasImageResource(
        id: event.id,
        source: CanvasResourceSource.appKey(event.appKey),
        mimeType: event.mimeType,
        contentHash: event.contentHash,
        byteLength: event.byteLength,
        metadata: event.metadata,
      ),
    ),
    SchemaV1VectorResourceImportEvent() => _materialize(
      diagnostics,
      () => CanvasVectorResource(
        id: event.id,
        source: CanvasResourceSource.appKey(event.appKey),
        contentHash: event.contentHash,
        byteLength: event.byteLength,
        metadata: event.metadata,
      ),
    ),
  };
}

CanvasImageElement _materializeImageElement(
  SchemaV1ImageElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  final common = event.common;

  return _materialize(
    diagnostics,
    () => CanvasImageElement(
      id: common.id,
      resourceId: event.resourceId,
      size: event.size,
      naturalSize: event.naturalSize,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    ),
  );
}

CanvasVectorElement _materializeVectorElement(
  SchemaV1VectorElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  final common = event.common;

  return _materialize(
    diagnostics,
    () => CanvasVectorElement(
      id: common.id,
      resourceId: event.resourceId,
      size: event.size,
      naturalSize: event.naturalSize,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    ),
  );
}

CanvasPathElement _materializePathElement(
  SchemaV1PathElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  final common = event.common;

  return _materialize(
    diagnostics,
    () => CanvasPathElement(
      id: common.id,
      svgPathData: event.svgPathData,
      fillColor: event.fillColor,
      strokeColor: event.strokeColor,
      strokeWidth: event.strokeWidth,
      fillRule: event.fillRule,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    ),
  );
}

CanvasTextElement _materializeTextElement(
  SchemaV1TextElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  final common = event.common;

  return _materialize(
    diagnostics,
    () => CanvasTextElement(
      id: common.id,
      text: event.text,
      fontSize: event.fontSize,
      color: event.color,
      align: event.align,
      textDirection: event.textDirection,
      isBold: event.isBold,
      isItalic: event.isItalic,
      isUnderline: event.isUnderline,
      fontFamily: event.fontFamily,
      maxWidth: event.maxWidth,
      lineHeight: event.lineHeight,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    ),
  );
}

CanvasStrokeElement _materializeStrokeElement(
  SchemaV1StrokeElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  final common = event.common;

  return _materialize(
    diagnostics,
    () => CanvasStrokeElement(
      id: common.id,
      points: event.points,
      thickness: event.thickness,
      color: event.color,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    ),
  );
}

CanvasLineElement _materializeLineElement(
  SchemaV1LineElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  final common = event.common;

  return _materialize(
    diagnostics,
    () => CanvasLineElement(
      id: common.id,
      start: event.start,
      end: event.end,
      thickness: event.thickness,
      color: event.color,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    ),
  );
}

CanvasRectElement _materializeRectElement(
  SchemaV1RectElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  final common = event.common;

  return _materialize(
    diagnostics,
    () => CanvasRectElement(
      id: common.id,
      size: event.size,
      fillColor: event.fillColor,
      strokeColor: event.strokeColor,
      strokeWidth: event.strokeWidth,
      revision: common.revision,
      transform: common.transform,
      opacity: common.opacity,
      hitPadding: common.hitPadding,
      isVisible: common.isVisible,
      isSelectable: common.isSelectable,
      isLocked: common.isLocked,
      isDeletable: common.isDeletable,
      isTransformable: common.isTransformable,
      metadata: common.metadata,
    ),
  );
}

final class _CanvasLayerDraft {
  _CanvasLayerDraft(this.event);

  final SchemaV1LayerImportEvent event;
  final elements = <CanvasElement>[];

  CanvasLayer build(DiagnosticsHub? diagnostics) {
    return _materialize(
      diagnostics,
      () => CanvasLayer(
        id: event.id,
        elements: elements,
        metadata: event.metadata,
      ),
    );
  }
}

void _validateDocumentReferences(
  CanvasDocument document, {
  required DiagnosticsHub? diagnostics,
}) {
  final resources = _resourcesById(
    document.resources,
    diagnostics: diagnostics,
  );
  final elementIds = <String>{};
  final layerIds = <String>{};
  for (final element in document.backgroundElements) {
    _validateElementReferences(
      element,
      elementIds,
      resources,
      diagnostics: diagnostics,
    );
  }
  for (final layer in document.layers) {
    if (!layerIds.add(layer.id.value)) {
      throw recordSchemaV1FailureDiagnostic(
        diagnostics,
        CanvasDataException(
          code: CanvasDataErrorCode.duplicateLayerId,
          message: 'duplicate layer id.',
          path: 'layers.id',
        ),
      );
    }
    for (final element in layer.elements) {
      _validateElementReferences(
        element,
        elementIds,
        resources,
        diagnostics: diagnostics,
      );
    }
  }
}

Map<String, CanvasResource> _resourcesById(
  Iterable<CanvasResource> resources, {
  required DiagnosticsHub? diagnostics,
}) {
  final byId = <String, CanvasResource>{};
  for (final resource in resources) {
    if (byId.containsKey(resource.id.value)) {
      throw recordSchemaV1FailureDiagnostic(
        diagnostics,
        CanvasDataException(
          code: CanvasDataErrorCode.duplicateResourceId,
          message: 'duplicate id: ${resource.id.value}.',
          path: 'resources.id',
        ),
      );
    }
    byId[resource.id.value] = resource;
  }

  return byId;
}

void _validateElementReferences(
  CanvasElement element,
  Set<String> elementIds,
  Map<String, CanvasResource> resources, {
  required DiagnosticsHub? diagnostics,
}) {
  if (!elementIds.add(element.id.value)) {
    throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.duplicateElementId,
        message: 'duplicate element id.',
        path: 'elements.id',
      ),
    );
  }
  final error = _resourceRelationshipError(element, resources);
  if (error != null) {
    throw recordSchemaV1FailureDiagnostic(diagnostics, error);
  }
}

CanvasDataException? _resourceRelationshipError(
  CanvasElement element,
  Map<String, CanvasResource> resources,
) {
  final relationship = switch (element) {
    CanvasImageElement() => (element.resourceId, 'image.resourceId', true),
    CanvasVectorElement() => (element.resourceId, 'vector.resourceId', false),
    _ => null,
  };
  if (relationship == null) {
    return null;
  }
  final resource = resources[relationship.$1.value];
  if (resource == null) {
    return CanvasDataException(
      code: CanvasDataErrorCode.missingResourceReference,
      message: 'resource element references a missing resource.',
      path: relationship.$2,
    );
  }
  final hasExpectedKind = (resource is CanvasImageResource) == relationship.$3;
  if (hasExpectedKind) {
    return null;
  }

  return CanvasDataException(
    code: CanvasDataErrorCode.resourceKindMismatch,
    message: 'resource kind does not match the referencing element.',
    path: relationship.$2,
  );
}

T _materialize<T>(DiagnosticsHub? diagnostics, T Function() materialize) {
  final hub = diagnostics;
  final recordsBefore = hub?.recordCount;
  try {
    return materialize();
  } on CanvasDataException catch (exception, stackTrace) {
    if (hub != null &&
        recordsBefore != null &&
        hub.recordCount > recordsBefore) {
      Error.throwWithStackTrace(exception, stackTrace);
    }
    Error.throwWithStackTrace(
      recordSchemaV1FailureDiagnostic(diagnostics, exception),
      stackTrace,
    );
  }
}
