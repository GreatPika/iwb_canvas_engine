// Schema v1 import events are the codec-owned load handoff. They intentionally
// avoid public document/resource/element DTOs and store-owned row types.
// ignore_for_file: number-of-imports

import 'dart:convert';
import 'dart:ui';

import '../contracts/internal/schema_v1_import_events.dart';
import '../contracts/public/canvas_contract_limits.dart';
import '../contracts/public/canvas_document.dart'
    show CanvasBackground, CanvasCamera, CanvasGrid, CanvasPalette;
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_errors.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_metadata.dart';
import '../contracts/public/canvas_transform_admission.dart';
import '../contracts/public/canvas_value_validators.dart';
import '../diagnostics/diagnostics_hub.dart';
import 'schema_v1_diagnostics.dart';
import 'schema_v1_validation.dart';

void importSchemaV1DocumentFromJson(
  String json,
  SchemaV1ImportSink sink, {
  DiagnosticsHub? diagnostics,
}) {
  final root = _decodeRoot(json, diagnostics: diagnostics);
  importSchemaV1Document(root, sink, diagnostics: diagnostics);
}

void importSchemaV1Document(
  Map<String, Object?> json,
  SchemaV1ImportSink sink, {
  DiagnosticsHub? diagnostics,
}) {
  validateSchemaV1Root(json, diagnostics: diagnostics);
  _deliverDocumentEvent(
    sink,
    _readDocumentEvent(json, diagnostics: diagnostics),
    diagnostics,
  );

  final resources = _readList(
    json,
    key: 'resources',
    path: 'resources',
    diagnostics: diagnostics,
  );
  if (resources.length > canvasMaxResources) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.maxItems,
      'document resources exceed the maximum count.',
      'resources',
    );
  }
  for (final resource in resources) {
    _deliverResourceEvent(
      sink,
      _readResource(resource, diagnostics: diagnostics),
      diagnostics,
    );
  }

  var elementCount = 0;
  for (final element in _readBackgroundElements(
    json,
    diagnostics: diagnostics,
  )) {
    elementCount += 1;
    _validateElementCount(elementCount, diagnostics);
    _deliverBackgroundElementEvent(
      sink,
      _readElement(element, diagnostics: diagnostics),
      diagnostics,
    );
  }

  final layers = _readList(
    json,
    key: 'layers',
    path: 'layers',
    diagnostics: diagnostics,
  );
  if (layers.length > canvasMaxContentLayers) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.maxItems,
      'document layers exceed the maximum count.',
      'layers',
    );
  }
  for (final value in layers) {
    final layer = _readLayer(value, diagnostics: diagnostics);
    _deliverLayerEvent(sink, layer.event, diagnostics);
    for (final element in layer.elements) {
      elementCount += 1;
      _validateElementCount(elementCount, diagnostics);
      _deliverLayerElementEvent(
        sink,
        layer.event.id,
        _readElement(element, diagnostics: diagnostics),
        diagnostics,
      );
    }
  }

  sink.endDocument();
}

void _deliverDocumentEvent(
  SchemaV1ImportSink sink,
  SchemaV1DocumentImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  if (diagnostics == null) {
    sink.beginDocument(event);

    return;
  }
  try {
    sink.beginDocument(event);
  } on CanvasDataException catch (exception, stackTrace) {
    Error.throwWithStackTrace(
      recordSchemaV1FailureDiagnostic(diagnostics, exception),
      stackTrace,
    );
  }
}

void _deliverResourceEvent(
  SchemaV1ImportSink sink,
  SchemaV1ImageResourceImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  if (diagnostics == null) {
    sink.imageResource(event);

    return;
  }
  try {
    sink.imageResource(event);
  } on CanvasDataException catch (exception, stackTrace) {
    Error.throwWithStackTrace(
      recordSchemaV1FailureDiagnostic(diagnostics, exception),
      stackTrace,
    );
  }
}

void _deliverBackgroundElementEvent(
  SchemaV1ImportSink sink,
  SchemaV1ElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  if (diagnostics == null) {
    sink.backgroundElement(event);

    return;
  }
  try {
    sink.backgroundElement(event);
  } on CanvasDataException catch (exception, stackTrace) {
    Error.throwWithStackTrace(
      recordSchemaV1FailureDiagnostic(diagnostics, exception),
      stackTrace,
    );
  }
}

void _deliverLayerEvent(
  SchemaV1ImportSink sink,
  SchemaV1LayerImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  if (diagnostics == null) {
    sink.layer(event);

    return;
  }
  try {
    sink.layer(event);
  } on CanvasDataException catch (exception, stackTrace) {
    Error.throwWithStackTrace(
      recordSchemaV1FailureDiagnostic(diagnostics, exception),
      stackTrace,
    );
  }
}

void _deliverLayerElementEvent(
  SchemaV1ImportSink sink,
  CanvasLayerId layerId,
  SchemaV1ElementImportEvent event,
  DiagnosticsHub? diagnostics,
) {
  if (diagnostics == null) {
    sink.layerElement(layerId, event);

    return;
  }
  try {
    sink.layerElement(layerId, event);
  } on CanvasDataException catch (exception, stackTrace) {
    Error.throwWithStackTrace(
      recordSchemaV1FailureDiagnostic(diagnostics, exception),
      stackTrace,
    );
  }
}

Map<String, Object?> _decodeRoot(
  String source, {
  required DiagnosticsHub? diagnostics,
}) {
  try {
    validateRawJsonLength(source);
  } on CanvasDataException catch (exception, stackTrace) {
    Error.throwWithStackTrace(
      recordSchemaV1FailureDiagnostic(diagnostics, exception),
      stackTrace,
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (_, stackTrace) {
    Error.throwWithStackTrace(
      recordSchemaV1FailureDiagnostic(
        diagnostics,
        CanvasDataException(
          code: CanvasDataErrorCode.invalidJson,
          message: 'canvas document JSON is malformed.',
          path: r'$',
        ),
      ),
      stackTrace,
    );
  }
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  if (decoded is Map<Object?, Object?>) {
    return _stringKeyedMap(decoded, path: r'$', diagnostics: diagnostics);
  }

  throw recordSchemaV1FailureDiagnostic(
    diagnostics,
    CanvasDataException(
      code: CanvasDataErrorCode.invalidJson,
      message: 'canvas document JSON must decode to an object.',
      path: r'$',
    ),
  );
}

SchemaV1DocumentImportEvent _readDocumentEvent(
  Map<String, Object?> json, {
  required DiagnosticsHub? diagnostics,
}) {
  return SchemaV1DocumentImportEvent(
    camera: _readCamera(json, diagnostics: diagnostics),
    background: _readBackground(json, diagnostics: diagnostics),
    palette: _readPalette(json, diagnostics: diagnostics),
    metadata: _readMetadata(
      json,
      key: 'metadata',
      path: 'metadata',
      diagnostics: diagnostics,
    ),
  );
}

CanvasCamera _readCamera(
  Map<String, Object?> json, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readMap(
    json,
    key: 'camera',
    path: 'camera',
    diagnostics: diagnostics,
  );

  return _materialize(
    diagnostics,
    () => CanvasCamera(
      offset: _readOffsetDefault(
        map,
        key: 'offset',
        path: 'camera.offset',
        diagnostics: diagnostics,
      ),
    ),
  );
}

CanvasBackground _readBackground(
  Map<String, Object?> json, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readMap(
    json,
    key: 'background',
    path: 'background',
    diagnostics: diagnostics,
  );
  final grid = _readGrid(map, diagnostics: diagnostics);
  final color = map.containsKey('color')
      ? _readColor(
          map['color'],
          path: 'background.color',
          diagnostics: diagnostics,
        )
      : const Color(0xFFFFFFFF);

  return _materialize(
    diagnostics,
    () => CanvasBackground(color: color, grid: grid),
  );
}

CanvasGrid _readGrid(
  Map<String, Object?> background, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readMap(
    background,
    key: 'grid',
    path: 'background.grid',
    diagnostics: diagnostics,
  );

  return _materialize(
    diagnostics,
    () => CanvasGrid(
      enabled: _readBoolDefault(
        map,
        key: 'enabled',
        path: 'background.grid.enabled',
        defaultValue: false,
        diagnostics: diagnostics,
      ),
      cellSize: _readDoubleDefault(
        map,
        key: 'cellSize',
        path: 'background.grid.cellSize',
        defaultValue: 10,
        diagnostics: diagnostics,
      ),
      color: map.containsKey('color')
          ? _readColor(
              map['color'],
              path: 'background.grid.color',
              diagnostics: diagnostics,
            )
          : const Color(0x1F000000),
    ),
  );
}

CanvasPalette _readPalette(
  Map<String, Object?> json, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readMap(
    json,
    key: 'palette',
    path: 'palette',
    diagnostics: diagnostics,
  );

  return _materialize(
    diagnostics,
    () => CanvasPalette(
      penColors: _readColorList(
        map,
        key: 'penColors',
        path: 'palette.penColors',
        diagnostics: diagnostics,
      ),
      backgroundColors: _readColorList(
        map,
        key: 'backgroundColors',
        path: 'palette.backgroundColors',
        diagnostics: diagnostics,
      ),
      gridSizes: _readDoubleList(
        map,
        key: 'gridSizes',
        path: 'palette.gridSizes',
        diagnostics: diagnostics,
      ),
    ),
  );
}

SchemaV1ImageResourceImportEvent _readResource(
  Object? value, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(
    value,
    path: 'resources[]',
    diagnostics: diagnostics,
  );
  final kind = _readString(
    map['kind'],
    path: 'resource.kind',
    diagnostics: diagnostics,
  );
  if (kind != 'image') {
    _fail(
      diagnostics,
      CanvasDataErrorCode.invalidFieldType,
      'unknown resource kind: $kind.',
      'resource.kind',
    );
  }
  final source = _readRequiredMap(
    map['source'],
    path: 'resource.source',
    diagnostics: diagnostics,
  );
  final sourceKind = _readString(
    source['kind'],
    path: 'resource.source.kind',
    diagnostics: diagnostics,
  );
  if (sourceKind != 'appKey') {
    _fail(
      diagnostics,
      CanvasDataErrorCode.invalidFieldType,
      'unknown resource source kind: $sourceKind.',
      'resource.source.kind',
    );
  }

  final appKey = _readString(
    source['key'],
    path: 'resource.source.key',
    diagnostics: diagnostics,
  );

  return _materialize(
    diagnostics,
    () => SchemaV1ImageResourceImportEvent(
      id: CanvasResourceId(
        _readString(map['id'], path: 'resource.id', diagnostics: diagnostics),
      ),
      appKey: validateCanvasAppKeyValue(
        appKey,
        path: 'resource.source.key',
        maxLength: canvasMaxResourceAppKeyLength,
      ),
      mimeType: _validatedOptionalString(
        map['mimeType'],
        path: 'resource.mimeType',
        maxLength: canvasMaxResourceMimeTypeLength,
        diagnostics: diagnostics,
      ),
      contentHash: _validatedOptionalString(
        map['contentHash'],
        path: 'resource.contentHash',
        maxLength: canvasMaxResourceContentHashLength,
        diagnostics: diagnostics,
      ),
      byteLength: _validatedOptionalByteLength(
        map['byteLength'],
        diagnostics: diagnostics,
      ),
      metadata: _readMetadata(
        map,
        key: 'metadata',
        path: 'resource.metadata',
        diagnostics: diagnostics,
      ),
    ),
  );
}

_LayerImportRead _readLayer(
  Object? value, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(
    value,
    path: 'layers[]',
    diagnostics: diagnostics,
  );

  return _LayerImportRead(
    event: _materialize(
      diagnostics,
      () => SchemaV1LayerImportEvent(
        id: CanvasLayerId(
          _readString(map['id'], path: 'layer.id', diagnostics: diagnostics),
        ),
        metadata: _readMetadata(
          map,
          key: 'metadata',
          path: 'layer.metadata',
          diagnostics: diagnostics,
        ),
      ),
    ),
    elements: _readList(
      map,
      key: 'elements',
      path: 'layer.elements',
      diagnostics: diagnostics,
    ),
  );
}

Iterable<Object?> _readBackgroundElements(
  Map<String, Object?> json, {
  required DiagnosticsHub? diagnostics,
}) {
  if (!json.containsKey('backgroundLayer')) {
    return const [];
  }
  final map = _readMap(
    json,
    key: 'backgroundLayer',
    path: 'backgroundLayer',
    diagnostics: diagnostics,
  );

  return _readList(
    map,
    key: 'elements',
    path: 'backgroundLayer.elements',
    diagnostics: diagnostics,
  );
}

SchemaV1ElementImportEvent _readElement(
  Object? value, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(
    value,
    path: 'elements[]',
    diagnostics: diagnostics,
  );
  final kind = _readElementKind(map['kind'], diagnostics: diagnostics);
  final common = _readElementCommon(map, kind: kind, diagnostics: diagnostics);

  return switch (kind) {
    CanvasElementKind.image => _readImageElement(
      map,
      common,
      diagnostics: diagnostics,
    ),
    CanvasElementKind.path => _readPathElement(
      map,
      common,
      diagnostics: diagnostics,
    ),
    CanvasElementKind.text => _readTextElement(
      map,
      common,
      diagnostics: diagnostics,
    ),
    CanvasElementKind.stroke => _readStrokeElement(
      map,
      common,
      diagnostics: diagnostics,
    ),
    CanvasElementKind.line => _readLineElement(
      map,
      common,
      diagnostics: diagnostics,
    ),
    CanvasElementKind.rect => _readRectElement(
      map,
      common,
      diagnostics: diagnostics,
    ),
  };
}

SchemaV1ElementCommonImport _readElementCommon(
  Map<String, Object?> map, {
  required CanvasElementKind kind,
  required DiagnosticsHub? diagnostics,
}) {
  return _materialize(
    diagnostics,
    () => SchemaV1ElementCommonImport(
      id: CanvasElementId(
        _readString(map['id'], path: 'element.id', diagnostics: diagnostics),
      ),
      kind: kind,
      revision: _validatedNonNegativeInt(
        map.containsKey('revision') ? map['revision'] : 0,
        path: 'element.revision',
        diagnostics: diagnostics,
      ),
      transform: _readTransformDefault(
        map,
        key: 'transform',
        diagnostics: diagnostics,
      ),
      opacity: _validatedDoubleRange(
        map.containsKey('opacity') ? map['opacity'] : 1.0,
        path: 'element.opacity',
        min: 0,
        max: 1,
        diagnostics: diagnostics,
      ),
      hitPadding: _validatedNonNegativeDouble(
        map.containsKey('hitPadding') ? map['hitPadding'] : 0.0,
        path: 'element.hitPadding',
        max: canvasMaxHitPadding,
        diagnostics: diagnostics,
      ),
      isVisible: _readBoolDefault(
        map,
        key: 'isVisible',
        path: 'element.isVisible',
        defaultValue: true,
        diagnostics: diagnostics,
      ),
      isSelectable: _readBoolDefault(
        map,
        key: 'isSelectable',
        path: 'element.isSelectable',
        defaultValue: true,
        diagnostics: diagnostics,
      ),
      isLocked: _readBoolDefault(
        map,
        key: 'isLocked',
        path: 'element.isLocked',
        defaultValue: false,
        diagnostics: diagnostics,
      ),
      isDeletable: _readBoolDefault(
        map,
        key: 'isDeletable',
        path: 'element.isDeletable',
        defaultValue: true,
        diagnostics: diagnostics,
      ),
      isTransformable: _readBoolDefault(
        map,
        key: 'isTransformable',
        path: 'element.isTransformable',
        defaultValue: true,
        diagnostics: diagnostics,
      ),
      metadata: _readMetadata(
        map,
        key: 'metadata',
        path: 'element.metadata',
        diagnostics: diagnostics,
      ),
    ),
  );
}

SchemaV1ImageElementImportEvent _readImageElement(
  Map<String, Object?> map,
  SchemaV1ElementCommonImport common, {
  required DiagnosticsHub? diagnostics,
}) {
  return _materialize(diagnostics, () {
    final size = _readSize(
      map['size'],
      path: 'image.size',
      diagnostics: diagnostics,
    );
    final naturalSize = _readNullableSize(
      map['naturalSize'],
      path: 'image.naturalSize',
      diagnostics: diagnostics,
    );

    return SchemaV1ImageElementImportEvent(
      common: common,
      resourceId: CanvasResourceId(
        _readString(
          map['resourceId'],
          path: 'image.resourceId',
          diagnostics: diagnostics,
        ),
      ),
      size: size,
      naturalSize: naturalSize,
    );
  });
}

SchemaV1PathElementImportEvent _readPathElement(
  Map<String, Object?> map,
  SchemaV1ElementCommonImport common, {
  required DiagnosticsHub? diagnostics,
}) {
  final svgPathData = _readString(
    map['svgPathData'],
    path: 'path.svgPathData',
    diagnostics: diagnostics,
  );
  if (svgPathData.isEmpty) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.fieldMustNotBeEmpty,
      'path data must not be empty.',
      'path.svgPathData',
    );
  }
  if (svgPathData.length > canvasMaxSvgPathDataLength) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.fieldMaxLength,
      'path data exceeds the maximum length.',
      'path.svgPathData',
    );
  }

  return SchemaV1PathElementImportEvent(
    common: common,
    svgPathData: svgPathData,
    fillColor: _readNullableColor(
      map['fillColor'],
      path: 'path.fillColor',
      diagnostics: diagnostics,
    ),
    strokeColor: _readNullableColor(
      map['strokeColor'],
      path: 'path.strokeColor',
      diagnostics: diagnostics,
    ),
    strokeWidth: _validatedNonNegativeDouble(
      map['strokeWidth'],
      path: 'path.strokeWidth',
      max: canvasMaxThickness,
      diagnostics: diagnostics,
    ),
    fillRule: _readFillRule(map, diagnostics: diagnostics),
  );
}

SchemaV1TextElementImportEvent _readTextElement(
  Map<String, Object?> map,
  SchemaV1ElementCommonImport common, {
  required DiagnosticsHub? diagnostics,
}) {
  final text = _readString(
    map['text'],
    path: 'text.text',
    diagnostics: diagnostics,
  );
  if (text.length > canvasMaxTextLength) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.fieldMaxLength,
      'text exceeds the maximum length.',
      'text.text',
    );
  }
  final fontFamily = _validatedOptionalString(
    map['fontFamily'],
    path: 'text.fontFamily',
    maxLength: canvasMaxFontFamilyLength,
    allowEmpty: false,
    diagnostics: diagnostics,
  );

  return SchemaV1TextElementImportEvent(
    common: common,
    text: text,
    fontSize: _validatedPositiveDouble(
      map.containsKey('fontSize') ? map['fontSize'] : 24.0,
      path: 'text.fontSize',
      max: canvasMaxThickness,
      diagnostics: diagnostics,
    ),
    color: _readColor(
      map['color'],
      path: 'text.color',
      diagnostics: diagnostics,
    ),
    align: _readTextAlign(map, diagnostics: diagnostics),
    textDirection: _readTextDirection(
      map['textDirection'],
      diagnostics: diagnostics,
    ),
    isBold: _readBoolDefault(
      map,
      key: 'isBold',
      path: 'text.isBold',
      defaultValue: false,
      diagnostics: diagnostics,
    ),
    isItalic: _readBoolDefault(
      map,
      key: 'isItalic',
      path: 'text.isItalic',
      defaultValue: false,
      diagnostics: diagnostics,
    ),
    isUnderline: _readBoolDefault(
      map,
      key: 'isUnderline',
      path: 'text.isUnderline',
      defaultValue: false,
      diagnostics: diagnostics,
    ),
    fontFamily: fontFamily,
    maxWidth: _validatedOptionalPositiveDouble(
      map['maxWidth'],
      path: 'text.maxWidth',
      max: canvasMaxPositiveSize,
      diagnostics: diagnostics,
    ),
    lineHeight: _validatedOptionalPositiveDouble(
      map['lineHeight'],
      path: 'text.lineHeight',
      max: canvasMaxPositiveSize,
      diagnostics: diagnostics,
    ),
  );
}

SchemaV1StrokeElementImportEvent _readStrokeElement(
  Map<String, Object?> map,
  SchemaV1ElementCommonImport common, {
  required DiagnosticsHub? diagnostics,
}) {
  final points = _readOffsetList(
    map['points'],
    path: 'stroke.points',
    diagnostics: diagnostics,
  );
  if (points.isEmpty) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.fieldMustNotBeEmpty,
      'stroke points must not be empty.',
      'stroke.points',
    );
  }
  if (points.length > canvasMaxStrokePointsPerElement) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.maxItems,
      'stroke points exceed the maximum count.',
      'stroke.points',
    );
  }

  return SchemaV1StrokeElementImportEvent(
    common: common,
    points: List.unmodifiable(points),
    thickness: _validatedPositiveDouble(
      map['thickness'],
      path: 'stroke.thickness',
      max: canvasMaxThickness,
      diagnostics: diagnostics,
    ),
    color: _readColor(
      map['color'],
      path: 'stroke.color',
      diagnostics: diagnostics,
    ),
  );
}

SchemaV1LineElementImportEvent _readLineElement(
  Map<String, Object?> map,
  SchemaV1ElementCommonImport common, {
  required DiagnosticsHub? diagnostics,
}) {
  return SchemaV1LineElementImportEvent(
    common: common,
    start: _readOffset(
      map['start'],
      path: 'line.start',
      diagnostics: diagnostics,
    ),
    end: _readOffset(map['end'], path: 'line.end', diagnostics: diagnostics),
    thickness: _validatedPositiveDouble(
      map['thickness'],
      path: 'line.thickness',
      max: canvasMaxThickness,
      diagnostics: diagnostics,
    ),
    color: _readColor(
      map['color'],
      path: 'line.color',
      diagnostics: diagnostics,
    ),
  );
}

SchemaV1RectElementImportEvent _readRectElement(
  Map<String, Object?> map,
  SchemaV1ElementCommonImport common, {
  required DiagnosticsHub? diagnostics,
}) {
  return SchemaV1RectElementImportEvent(
    common: common,
    size: _readSize(map['size'], path: 'rect.size', diagnostics: diagnostics),
    fillColor: _readNullableColor(
      map['fillColor'],
      path: 'rect.fillColor',
      diagnostics: diagnostics,
    ),
    strokeColor: _readNullableColor(
      map['strokeColor'],
      path: 'rect.strokeColor',
      diagnostics: diagnostics,
    ),
    strokeWidth: _validatedNonNegativeDouble(
      map['strokeWidth'],
      path: 'rect.strokeWidth',
      max: canvasMaxThickness,
      diagnostics: diagnostics,
    ),
  );
}

final class _LayerImportRead {
  const _LayerImportRead({required this.event, required this.elements});

  final SchemaV1LayerImportEvent event;
  final List<Object?> elements;
}

Map<String, Object?> _readMap(
  Map<String, Object?> parent, {
  required String key,
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (!parent.containsKey(key)) {
    return const {};
  }

  return _readRequiredMap(parent[key], path: path, diagnostics: diagnostics);
}

Map<String, Object?> _readRequiredMap(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value is Map<Object?, Object?>) {
    return _stringKeyedMap(value, path: path, diagnostics: diagnostics);
  }

  _fail(
    diagnostics,
    value == null
        ? CanvasDataErrorCode.missingField
        : CanvasDataErrorCode.invalidFieldType,
    '$path must be an object.',
    path,
  );
}

List<Object?> _readList(
  Map<String, Object?> parent, {
  required String key,
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (!parent.containsKey(key)) {
    return const [];
  }

  return _readRequiredList(parent[key], path: path, diagnostics: diagnostics);
}

List<Object?> _readRequiredList(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value is List<Object?>) {
    return value;
  }

  _fail(
    diagnostics,
    CanvasDataErrorCode.invalidFieldType,
    '$path must be a list.',
    path,
  );
}

String _readString(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value is String) {
    return value;
  }

  _fail(
    diagnostics,
    value == null
        ? CanvasDataErrorCode.missingField
        : CanvasDataErrorCode.invalidFieldType,
    '$path must be a string.',
    path,
  );
}

int _readInt(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value is int) {
    return value;
  }

  _fail(
    diagnostics,
    value == null
        ? CanvasDataErrorCode.missingField
        : CanvasDataErrorCode.invalidFieldType,
    '$path must be an int.',
    path,
  );
}

double _readDouble(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value is num) {
    return value.toDouble();
  }

  _fail(
    diagnostics,
    value == null
        ? CanvasDataErrorCode.missingField
        : CanvasDataErrorCode.invalidFieldType,
    '$path must be a number.',
    path,
  );
}

// Default field readers keep schema paths explicit at each call site.
// ignore: number-of-parameters
double _readDoubleDefault(
  Map<String, Object?> map, {
  required String key,
  required String path,
  required double defaultValue,
  required DiagnosticsHub? diagnostics,
}) {
  if (!map.containsKey(key)) {
    return defaultValue;
  }

  return _readDouble(map[key], path: path, diagnostics: diagnostics);
}

bool _readBool(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value is bool) {
    return value;
  }

  _fail(
    diagnostics,
    CanvasDataErrorCode.invalidFieldType,
    '$path must be a bool.',
    path,
  );
}

// Default field readers keep schema paths explicit at each call site.
// ignore: number-of-parameters
bool _readBoolDefault(
  Map<String, Object?> map, {
  required String key,
  required String path,
  required bool defaultValue,
  required DiagnosticsHub? diagnostics,
}) {
  if (!map.containsKey(key)) {
    return defaultValue;
  }

  return _readBool(map[key], path: path, diagnostics: diagnostics);
}

Color _readColor(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value is! String ||
      value.length != 9 ||
      !value.startsWith('#') ||
      int.tryParse(value.replaceFirst('#', ''), radix: 16) == null) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.invalidFieldType,
      '$path must be #AARRGGBB.',
      path,
    );
  }

  return Color(int.parse(value.replaceFirst('#', ''), radix: 16));
}

Color? _readNullableColor(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value == null) {
    return null;
  }

  return _readColor(value, path: path, diagnostics: diagnostics);
}

List<Color> _readColorList(
  Map<String, Object?> parent, {
  required String key,
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  return _readList(parent, key: key, path: path, diagnostics: diagnostics)
      .map((value) => _readColor(value, path: path, diagnostics: diagnostics))
      .toList();
}

List<double> _readDoubleList(
  Map<String, Object?> parent, {
  required String key,
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  return _readList(parent, key: key, path: path, diagnostics: diagnostics)
      .map((value) => _readDouble(value, path: path, diagnostics: diagnostics))
      .toList();
}

Offset _readOffset(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(value, path: path, diagnostics: diagnostics);
  final offset = Offset(
    _readDouble(map['x'], path: '$path.x', diagnostics: diagnostics),
    _readDouble(map['y'], path: '$path.y', diagnostics: diagnostics),
  );

  return _materialize(diagnostics, () {
    validateOffset(offset, path: path);

    return offset;
  });
}

Offset _readOffsetDefault(
  Map<String, Object?> parent, {
  required String key,
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (!parent.containsKey(key)) {
    return Offset.zero;
  }

  return _readOffset(parent[key], path: path, diagnostics: diagnostics);
}

List<Offset> _readOffsetList(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  return _readRequiredList(value, path: path, diagnostics: diagnostics)
      .map((value) => _readOffset(value, path: path, diagnostics: diagnostics))
      .toList();
}

Size _readSize(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(value, path: path, diagnostics: diagnostics);
  final size = Size(
    _readDouble(map['w'], path: '$path.w', diagnostics: diagnostics),
    _readDouble(map['h'], path: '$path.h', diagnostics: diagnostics),
  );

  return _materialize(diagnostics, () {
    validateSize(size, path: path);

    return size;
  });
}

Size? _readNullableSize(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value == null) {
    return null;
  }

  return _readSize(value, path: path, diagnostics: diagnostics);
}

CanvasTransform _readTransform(
  Object? value, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(
    value,
    path: 'element.transform',
    diagnostics: diagnostics,
  );

  return _materialize(diagnostics, () {
    final transform = CanvasTransform(
      a: _readDouble(map['a'], path: 'transform.a', diagnostics: diagnostics),
      b: _readDouble(map['b'], path: 'transform.b', diagnostics: diagnostics),
      c: _readDouble(map['c'], path: 'transform.c', diagnostics: diagnostics),
      d: _readDouble(map['d'], path: 'transform.d', diagnostics: diagnostics),
      tx: _readDouble(
        map['tx'],
        path: 'transform.tx',
        diagnostics: diagnostics,
      ),
      ty: _readDouble(
        map['ty'],
        path: 'transform.ty',
        diagnostics: diagnostics,
      ),
    );
    validateElementTransformAdmission(transform, path: 'element.transform');

    return transform;
  });
}

CanvasTransform _readTransformDefault(
  Map<String, Object?> map, {
  required String key,
  required DiagnosticsHub? diagnostics,
}) {
  if (!map.containsKey(key)) {
    return CanvasTransform.identity;
  }

  return _readTransform(map[key], diagnostics: diagnostics);
}

CanvasMetadata _readMetadata(
  Map<String, Object?> parent, {
  required String key,
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (!parent.containsKey(key)) {
    return const CanvasMetadata.empty();
  }
  final map = _readRequiredMap(
    parent[key],
    path: path,
    diagnostics: diagnostics,
  );

  return _materialize(diagnostics, () => CanvasMetadata.fromMap(map));
}

CanvasPathFillRule _readFillRule(
  Map<String, Object?> map, {
  required DiagnosticsHub? diagnostics,
}) {
  if (!map.containsKey('fillRule')) {
    return CanvasPathFillRule.nonZero;
  }

  return switch (map['fillRule']) {
    'nonZero' => CanvasPathFillRule.nonZero,
    'evenOdd' => CanvasPathFillRule.evenOdd,
    _ => _fail(
      diagnostics,
      CanvasDataErrorCode.invalidFieldType,
      'unknown path fill rule.',
      'path.fillRule',
    ),
  };
}

TextAlign _readTextAlign(
  Map<String, Object?> map, {
  required DiagnosticsHub? diagnostics,
}) {
  if (!map.containsKey('align')) {
    return TextAlign.left;
  }

  return switch (map['align']) {
    'left' => TextAlign.left,
    'right' => TextAlign.right,
    'center' => TextAlign.center,
    'justify' => TextAlign.justify,
    'start' => TextAlign.start,
    'end' => TextAlign.end,
    _ => _fail(
      diagnostics,
      CanvasDataErrorCode.invalidFieldType,
      'unknown text alignment.',
      'text.align',
    ),
  };
}

TextDirection _readTextDirection(
  Object? value, {
  required DiagnosticsHub? diagnostics,
}) {
  return switch (value) {
    null || 'ltr' => TextDirection.ltr,
    'rtl' => TextDirection.rtl,
    _ => _fail(
      diagnostics,
      CanvasDataErrorCode.invalidFieldType,
      'unknown text direction.',
      'text.textDirection',
    ),
  };
}

CanvasElementKind _readElementKind(
  Object? value, {
  required DiagnosticsHub? diagnostics,
}) {
  return switch (value) {
    'image' => CanvasElementKind.image,
    'path' => CanvasElementKind.path,
    'text' => CanvasElementKind.text,
    'stroke' => CanvasElementKind.stroke,
    'line' => CanvasElementKind.line,
    'rect' => CanvasElementKind.rect,
    _ => _fail(
      diagnostics,
      value == null
          ? CanvasDataErrorCode.missingField
          : CanvasDataErrorCode.invalidFieldType,
      'unknown element kind.',
      'element.kind',
    ),
  };
}

String? _validatedOptionalString(
  Object? value, {
  required String path,
  required int maxLength,
  required DiagnosticsHub? diagnostics,
  bool allowEmpty = true,
}) {
  final string = value == null
      ? null
      : _readString(value, path: path, diagnostics: diagnostics);
  if (string == null) {
    return null;
  }
  if (!allowEmpty && string.isEmpty) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.fieldMustNotBeEmpty,
      '$path must not be empty.',
      path,
    );
  }

  return _materialize(diagnostics, () {
    validateOptionalBoundedString(string, path: path, maxLength: maxLength);

    return string;
  });
}

int _validatedNonNegativeInt(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  final intValue = _readInt(value, path: path, diagnostics: diagnostics);

  return _materialize(diagnostics, () {
    validateNonNegativeInt(intValue, path: path);

    return intValue;
  });
}

int? _validatedOptionalByteLength(
  Object? value, {
  required DiagnosticsHub? diagnostics,
}) {
  if (value == null) {
    return null;
  }
  final byteLength = _validatedNonNegativeInt(
    value,
    path: 'resource.byteLength',
    diagnostics: diagnostics,
  );
  if (byteLength > canvasMaxRawJsonLength) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.fieldMustBeInRange,
      'resource.byteLength exceeds the maximum supported length.',
      'resource.byteLength',
      details: {'max': canvasMaxRawJsonLength, 'actual': byteLength},
    );
  }

  return byteLength;
}

double _validatedDoubleRange(
  Object? value, {
  required String path,
  required double min,
  required double max,
  required DiagnosticsHub? diagnostics,
}) {
  final doubleValue = _readDouble(value, path: path, diagnostics: diagnostics);

  return _materialize(diagnostics, () {
    validateDoubleRange(doubleValue, path: path, min: min, max: max);

    return doubleValue;
  });
}

double _validatedNonNegativeDouble(
  Object? value, {
  required String path,
  required double max,
  required DiagnosticsHub? diagnostics,
}) {
  final doubleValue = _readDouble(value, path: path, diagnostics: diagnostics);

  return _materialize(diagnostics, () {
    validateNonNegativeDouble(doubleValue, path: path, max: max);

    return doubleValue;
  });
}

double _validatedPositiveDouble(
  Object? value, {
  required String path,
  required double max,
  required DiagnosticsHub? diagnostics,
}) {
  final doubleValue = _readDouble(value, path: path, diagnostics: diagnostics);

  return _materialize(diagnostics, () {
    validatePositiveDouble(doubleValue, path: path, max: max);

    return doubleValue;
  });
}

double? _validatedOptionalPositiveDouble(
  Object? value, {
  required String path,
  required double max,
  required DiagnosticsHub? diagnostics,
}) {
  if (value == null) {
    return null;
  }

  return _validatedPositiveDouble(
    value,
    path: path,
    max: max,
    diagnostics: diagnostics,
  );
}

T _materialize<T>(DiagnosticsHub? diagnostics, T Function() materialize) {
  try {
    return materialize();
  } on CanvasDataException catch (exception, stackTrace) {
    Error.throwWithStackTrace(
      recordSchemaV1FailureDiagnostic(diagnostics, exception),
      stackTrace,
    );
  }
}

Never _fail(
  DiagnosticsHub? diagnostics,
  CanvasDataErrorCode code,
  String message,
  String path, {
  Map<String, Object?> details = const {},
}) {
  throw recordSchemaV1FailureDiagnostic(
    diagnostics,
    CanvasDataException(
      code: code,
      message: message,
      path: path,
      details: details,
    ),
  );
}

void _validateElementCount(int elementCount, DiagnosticsHub? diagnostics) {
  if (elementCount > canvasMaxTotalElements) {
    _fail(
      diagnostics,
      CanvasDataErrorCode.maxNodes,
      'document elements exceed the maximum count.',
      'elements',
    );
  }
}

Map<String, Object?> _stringKeyedMap(
  Map<Object?, Object?> value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      _fail(
        diagnostics,
        CanvasDataErrorCode.invalidFieldType,
        '$path keys must be strings.',
        path,
      );
    }
    result[key] = entry.value;
  }

  return result;
}
