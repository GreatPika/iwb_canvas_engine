// The schema decoder imports each public API value owner directly so ownership
// stays visible after metadata moved out of the document owner.
// ignore_for_file: number-of-imports

import 'dart:convert';
import 'dart:ui';

import '../api/canvas_contract_limits.dart';
import '../api/canvas_document.dart';
import '../api/canvas_element.dart';
import '../api/canvas_errors.dart';
import '../api/canvas_geometry.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_metadata.dart';
import '../api/canvas_resource.dart';
import '../api/canvas_value_validators.dart';
import '../diagnostics/diagnostics_hub.dart';
import 'schema_v1_diagnostics.dart';
import 'schema_v1_validation.dart';

// The root decoder keeps the schema sections in document order so boundary
// validation, defaulting, construction, and reference checks are auditable.
// ignore: halstead-volume, source-lines-of-code
CanvasDocument decodeSchemaV1Document(
  Map<String, Object?> json, {
  DiagnosticsHub? diagnostics,
}) {
  validateSchemaV1Root(json, diagnostics: diagnostics);

  final resources = _readList(
    json,
    key: 'resources',
    path: 'resources',
    diagnostics: diagnostics,
  ).map((value) => _readResource(value, diagnostics: diagnostics)).toList();
  final resourceIds = _uniqueIds(
    resources.map((resource) => resource.id.value),
    path: 'resources.id',
    code: CanvasDataErrorCode.duplicateResourceId,
    diagnostics: diagnostics,
  );
  final backgroundElements = _readBackgroundElements(
    json,
    diagnostics: diagnostics,
  ).map((value) => _readElement(value, diagnostics: diagnostics)).toList();
  final layers = _readList(
    json,
    key: 'layers',
    path: 'layers',
    diagnostics: diagnostics,
  ).map((value) => _readLayer(value, diagnostics: diagnostics)).toList();
  final camera = _readCamera(json, key: 'camera', diagnostics: diagnostics);
  final background = _readBackground(
    json,
    key: 'background',
    diagnostics: diagnostics,
  );
  final palette = _readPalette(json, key: 'palette', diagnostics: diagnostics);
  final metadata = _readMetadata(
    json,
    key: 'metadata',
    path: 'metadata',
    diagnostics: diagnostics,
  );
  final document = _materialize(
    diagnostics,
    () => CanvasDocument(
      camera: camera,
      background: background,
      palette: palette,
      resources: resources,
      backgroundElements: backgroundElements,
      layers: layers,
      metadata: metadata,
    ),
  );

  _validateDocumentReferences(document, resourceIds, diagnostics: diagnostics);

  return document;
}

CanvasDocument decodeSchemaV1DocumentFromJson(
  String json, {
  DiagnosticsHub? diagnostics,
}) {
  try {
    validateRawJsonLength(json);
  } on CanvasDataException catch (exception) {
    throw recordSchemaV1FailureDiagnostic(diagnostics, exception);
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (_) {
    throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.invalidJson,
        message: 'canvas document JSON is malformed.',
        path: r'$',
      ),
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.invalidJson,
        message: 'canvas document JSON must decode to an object.',
        path: r'$',
      ),
    );
  }

  return decodeSchemaV1Document(decoded, diagnostics: diagnostics);
}

CanvasCamera _readCamera(
  Map<String, Object?> parent, {
  required String key,
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readMap(
    parent,
    key: key,
    path: 'camera',
    diagnostics: diagnostics,
  );
  final offset = _readOffsetDefault(
    map,
    key: 'offset',
    path: 'camera.offset',
    diagnostics: diagnostics,
  );

  return _materialize(diagnostics, () => CanvasCamera(offset: offset));
}

CanvasBackground _readBackground(
  Map<String, Object?> parent, {
  required String key,
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readMap(
    parent,
    key: key,
    path: 'background',
    diagnostics: diagnostics,
  );

  final color = map.containsKey('color')
      ? _readColor(
          map['color'],
          path: 'background.color',
          diagnostics: diagnostics,
        )
      : const Color(0xFFFFFFFF);
  final grid = _readGrid(map, key: 'grid', diagnostics: diagnostics);

  return _materialize(
    diagnostics,
    () => CanvasBackground(color: color, grid: grid),
  );
}

CanvasGrid _readGrid(
  Map<String, Object?> parent, {
  required String key,
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readMap(
    parent,
    key: key,
    path: 'background.grid',
    diagnostics: diagnostics,
  );

  final enabled = _readBoolDefault(
    map,
    key: 'enabled',
    path: 'background.grid.enabled',
    defaultValue: false,
    diagnostics: diagnostics,
  );
  final cellSize = _readDoubleDefault(
    map,
    key: 'cellSize',
    path: 'background.grid.cellSize',
    defaultValue: 10.0,
    diagnostics: diagnostics,
  );
  final color = map.containsKey('color')
      ? _readColor(
          map['color'],
          path: 'background.grid.color',
          diagnostics: diagnostics,
        )
      : const Color(0x1F000000);

  return _materialize(
    diagnostics,
    () => CanvasGrid(enabled: enabled, cellSize: cellSize, color: color),
  );
}

CanvasPalette _readPalette(
  Map<String, Object?> parent, {
  required String key,
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readMap(
    parent,
    key: key,
    path: 'palette',
    diagnostics: diagnostics,
  );
  final penColors = _readColorList(
    map,
    key: 'penColors',
    path: 'palette.penColors',
    diagnostics: diagnostics,
  );
  final backgroundColors = _readColorList(
    map,
    key: 'backgroundColors',
    path: 'palette.backgroundColors',
    diagnostics: diagnostics,
  );
  final gridSizes = _readDoubleList(
    map,
    key: 'gridSizes',
    path: 'palette.gridSizes',
    diagnostics: diagnostics,
  );

  return _materialize(
    diagnostics,
    () => CanvasPalette(
      penColors: penColors,
      backgroundColors: backgroundColors,
      gridSizes: gridSizes,
    ),
  );
}

CanvasResource _readResource(
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
    throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.invalidFieldType,
        message: 'unknown resource kind: $kind.',
        path: 'resource.kind',
      ),
    );
  }

  return _readImageResource(map, diagnostics: diagnostics);
}

CanvasImageResource _readImageResource(
  Map<String, Object?> map, {
  required DiagnosticsHub? diagnostics,
}) {
  final fields = _ImageResourceFields(map, diagnostics: diagnostics);

  return _materialize(
    diagnostics,
    () => CanvasImageResource(
      id: CanvasResourceId(fields.id),
      source: fields.source,
      mimeType: fields.mimeType,
      contentHash: fields.contentHash,
      byteLength: fields.byteLength,
      metadata: fields.metadata,
    ),
  );
}

List<Color> _readColorList(
  Map<String, Object?> map, {
  required String key,
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  return _readList(map, key: key, path: path, diagnostics: diagnostics)
      .map((value) => _readColor(value, path: path, diagnostics: diagnostics))
      .toList();
}

List<double> _readDoubleList(
  Map<String, Object?> map, {
  required String key,
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  return _readList(map, key: key, path: path, diagnostics: diagnostics)
      .map((value) => _readDouble(value, path: path, diagnostics: diagnostics))
      .toList();
}

final class _ImageResourceFields {
  _ImageResourceFields(
    Map<String, Object?> map, {
    required DiagnosticsHub? diagnostics,
  }) : id = _readString(
         map['id'],
         path: 'resource.id',
         diagnostics: diagnostics,
       ),
       source = _readResourceSource(map['source'], diagnostics: diagnostics),
       mimeType = _readNullableString(
         map['mimeType'],
         path: 'resource.mimeType',
         diagnostics: diagnostics,
       ),
       contentHash = _readNullableString(
         map['contentHash'],
         path: 'resource.contentHash',
         diagnostics: diagnostics,
       ),
       byteLength = _readNullableInt(
         map['byteLength'],
         path: 'resource.byteLength',
         diagnostics: diagnostics,
       ),
       metadata = _readMetadata(
         map,
         key: 'metadata',
         path: 'resource.metadata',
         diagnostics: diagnostics,
       );

  final String id;
  final CanvasResourceSource source;
  final String? mimeType;
  final String? contentHash;
  final int? byteLength;
  final CanvasMetadata metadata;
}

CanvasResourceSource _readResourceSource(
  Object? value, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(
    value,
    path: 'resource.source',
    diagnostics: diagnostics,
  );
  final kind = _readString(
    map['kind'],
    path: 'resource.source.kind',
    diagnostics: diagnostics,
  );
  if (kind != 'appKey') {
    throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.invalidFieldType,
        message: 'unknown resource source kind: $kind.',
        path: 'resource.source.kind',
      ),
    );
  }
  final keyValue = _readString(
    map['key'],
    path: 'resource.source.key',
    diagnostics: diagnostics,
  );

  return _materialize(diagnostics, () {
    final key = validateCanvasAppKeyValue(
      keyValue,
      path: 'resource.source.key',
      maxLength: canvasMaxResourceAppKeyLength,
    );

    return CanvasResourceSource.appKey(key);
  });
}

CanvasLayer _readLayer(Object? value, {required DiagnosticsHub? diagnostics}) {
  final map = _readRequiredMap(
    value,
    path: 'layers[]',
    diagnostics: diagnostics,
  );

  final idValue = _readString(
    map['id'],
    path: 'layer.id',
    diagnostics: diagnostics,
  );
  final elements = _readList(
    map,
    key: 'elements',
    path: 'layer.elements',
    diagnostics: diagnostics,
  ).map((value) => _readElement(value, diagnostics: diagnostics)).toList();
  final metadata = _readMetadata(
    map,
    key: 'metadata',
    path: 'layer.metadata',
    diagnostics: diagnostics,
  );

  return _materialize(
    diagnostics,
    () => CanvasLayer(
      id: CanvasLayerId(idValue),
      elements: elements,
      metadata: metadata,
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

CanvasElement _readElement(
  Object? value, {
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(
    value,
    path: 'elements[]',
    diagnostics: diagnostics,
  );
  final common = _ElementCommon(map, diagnostics: diagnostics);

  return switch (_readString(
    map['kind'],
    path: 'element.kind',
    diagnostics: diagnostics,
  )) {
    'image' => _readImageElement(map, common, diagnostics: diagnostics),
    'path' => _readPathElement(map, common, diagnostics: diagnostics),
    'text' => _readTextElement(map, common, diagnostics: diagnostics),
    'stroke' => _readStrokeElement(map, common, diagnostics: diagnostics),
    'line' => _readLineElement(map, common, diagnostics: diagnostics),
    'rect' => _readRectElement(map, common, diagnostics: diagnostics),
    final kind => throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.invalidFieldType,
        message: 'unknown element kind: $kind.',
        path: 'element.kind',
      ),
    ),
  };
}

CanvasImageElement _readImageElement(
  Map<String, Object?> map,
  _ElementCommon common, {
  required DiagnosticsHub? diagnostics,
}) {
  final resourceIdValue = _readString(
    map['resourceId'],
    path: 'image.resourceId',
    diagnostics: diagnostics,
  );
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

  return _materialize(
    diagnostics,
    () => CanvasImageElement(
      id: common.id,
      resourceId: CanvasResourceId(resourceIdValue),
      size: size,
      naturalSize: naturalSize,
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

CanvasPathElement _readPathElement(
  Map<String, Object?> map,
  _ElementCommon common, {
  required DiagnosticsHub? diagnostics,
}) {
  final path = _PathElementFields(map, diagnostics: diagnostics);

  return _materialize(
    diagnostics,
    () => CanvasPathElement(
      id: common.id,
      svgPathData: path.svgPathData,
      fillColor: path.fillColor,
      strokeColor: path.strokeColor,
      strokeWidth: path.strokeWidth,
      fillRule: path.fillRule,
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

CanvasTextElement _readTextElement(
  Map<String, Object?> map,
  _ElementCommon common, {
  required DiagnosticsHub? diagnostics,
}) {
  final text = _TextElementFields(map, diagnostics: diagnostics);

  return _materialize(
    diagnostics,
    () => CanvasTextElement(
      id: common.id,
      text: text.value,
      fontSize: text.fontSize,
      color: text.color,
      align: text.align,
      textDirection: text.textDirection,
      isBold: text.isBold,
      isItalic: text.isItalic,
      isUnderline: text.isUnderline,
      fontFamily: text.fontFamily,
      maxWidth: text.maxWidth,
      lineHeight: text.lineHeight,
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

CanvasStrokeElement _readStrokeElement(
  Map<String, Object?> map,
  _ElementCommon common, {
  required DiagnosticsHub? diagnostics,
}) {
  final stroke = _StrokeElementFields(map, diagnostics: diagnostics);

  return _materialize(
    diagnostics,
    () => CanvasStrokeElement(
      id: common.id,
      points: stroke.points,
      thickness: stroke.thickness,
      color: stroke.color,
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

CanvasLineElement _readLineElement(
  Map<String, Object?> map,
  _ElementCommon common, {
  required DiagnosticsHub? diagnostics,
}) {
  final start = _readRequiredOffset(
    map['start'],
    path: 'line.start',
    diagnostics: diagnostics,
  );
  final end = _readRequiredOffset(
    map['end'],
    path: 'line.end',
    diagnostics: diagnostics,
  );
  final thickness = _readDouble(
    map['thickness'],
    path: 'line.thickness',
    diagnostics: diagnostics,
  );
  final color = _readColor(
    map['color'],
    path: 'line.color',
    diagnostics: diagnostics,
  );

  return _materialize(
    diagnostics,
    () => CanvasLineElement(
      id: common.id,
      start: start,
      end: end,
      thickness: thickness,
      color: color,
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

CanvasRectElement _readRectElement(
  Map<String, Object?> map,
  _ElementCommon common, {
  required DiagnosticsHub? diagnostics,
}) {
  final size = _readSize(
    map['size'],
    path: 'rect.size',
    diagnostics: diagnostics,
  );
  final fillColor = _readNullableColor(
    map['fillColor'],
    path: 'rect.fillColor',
    diagnostics: diagnostics,
  );
  final strokeColor = _readNullableColor(
    map['strokeColor'],
    path: 'rect.strokeColor',
    diagnostics: diagnostics,
  );
  final strokeWidth = _readDouble(
    map['strokeWidth'],
    path: 'rect.strokeWidth',
    diagnostics: diagnostics,
  );

  return _materialize(
    diagnostics,
    () => CanvasRectElement(
      id: common.id,
      size: size,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
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

void _validateDocumentReferences(
  CanvasDocument document,
  Set<String> resourceIds, {
  required DiagnosticsHub? diagnostics,
}) {
  final elementIds = <String>{};
  final layerIds = <String>{};
  for (final element in document.backgroundElements) {
    _validateElementReferences(
      element,
      elementIds,
      resourceIds,
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
        resourceIds,
        diagnostics: diagnostics,
      );
    }
  }
}

void _validateElementReferences(
  CanvasElement element,
  Set<String> elementIds,
  Set<String> resourceIds, {
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
  if (element is CanvasImageElement &&
      !resourceIds.contains(element.resourceId.value)) {
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

Set<String> _uniqueIds(
  Iterable<String> ids, {
  required String path,
  required CanvasDataErrorCode code,
  required DiagnosticsHub? diagnostics,
}) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw recordSchemaV1FailureDiagnostic(
        diagnostics,
        CanvasDataException(
          code: code,
          message: 'duplicate id: $id.',
          path: path,
        ),
      );
    }
  }

  return seen;
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
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw recordSchemaV1FailureDiagnostic(
          diagnostics,
          CanvasDataException(
            code: CanvasDataErrorCode.invalidFieldType,
            message: '$path keys must be strings.',
            path: path,
          ),
        );
      }
      result[key] = entry.value;
    }

    return result;
  }

  throw recordSchemaV1FailureDiagnostic(
    diagnostics,
    CanvasDataException(
      code: value == null
          ? CanvasDataErrorCode.missingField
          : CanvasDataErrorCode.invalidFieldType,
      message: '$path must be an object.',
      path: path,
    ),
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

  throw recordSchemaV1FailureDiagnostic(
    diagnostics,
    CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: '$path must be a list.',
      path: path,
    ),
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

  throw recordSchemaV1FailureDiagnostic(
    diagnostics,
    CanvasDataException(
      code: value == null
          ? CanvasDataErrorCode.missingField
          : CanvasDataErrorCode.invalidFieldType,
      message: '$path must be a string.',
      path: path,
    ),
  );
}

String? _readNullableString(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value == null) {
    return null;
  }

  return _readString(value, path: path, diagnostics: diagnostics);
}

int _readInt(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value is int) {
    return value;
  }

  throw recordSchemaV1FailureDiagnostic(
    diagnostics,
    CanvasDataException(
      code: value == null
          ? CanvasDataErrorCode.missingField
          : CanvasDataErrorCode.invalidFieldType,
      message: '$path must be an int.',
      path: path,
    ),
  );
}

int? _readNullableInt(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value == null) {
    return null;
  }

  return _readInt(value, path: path, diagnostics: diagnostics);
}

// Default field readers keep key, error path, default, and diagnostics explicit
// at each boundary instead of hiding schema context inside a parameter object.
// ignore: number-of-parameters
int _readIntDefault(
  Map<String, Object?> map, {
  required String key,
  required String path,
  required int defaultValue,
  required DiagnosticsHub? diagnostics,
}) {
  if (!map.containsKey(key)) {
    return defaultValue;
  }

  return _readInt(map[key], path: path, diagnostics: diagnostics);
}

double _readDouble(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value is num) {
    return value.toDouble();
  }

  throw recordSchemaV1FailureDiagnostic(
    diagnostics,
    CanvasDataException(
      code: value == null
          ? CanvasDataErrorCode.missingField
          : CanvasDataErrorCode.invalidFieldType,
      message: '$path must be a number.',
      path: path,
    ),
  );
}

double? _readNullableDouble(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  if (value == null) {
    return null;
  }

  return _readDouble(value, path: path, diagnostics: diagnostics);
}

// Default field readers keep key, error path, default, and diagnostics explicit
// at each boundary instead of hiding schema context inside a parameter object.
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

  throw recordSchemaV1FailureDiagnostic(
    diagnostics,
    CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: '$path must be a bool.',
      path: path,
    ),
  );
}

// Default field readers keep key, error path, default, and diagnostics explicit
// at each boundary instead of hiding schema context inside a parameter object.
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
      int.tryParse(value.substring(1), radix: 16) == null) {
    throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.invalidFieldType,
        message: '$path must be #AARRGGBB.',
        path: path,
      ),
    );
  }

  return Color(int.parse(value.substring(1), radix: 16));
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

Offset _readRequiredOffset(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(value, path: path, diagnostics: diagnostics);

  return Offset(
    _readDouble(map['x'], path: '$path.x', diagnostics: diagnostics),
    _readDouble(map['y'], path: '$path.y', diagnostics: diagnostics),
  );
}

List<Offset> _readOffsetList(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  return _readRequiredList(value, path: path, diagnostics: diagnostics)
      .map(
        (value) =>
            _readRequiredOffset(value, path: path, diagnostics: diagnostics),
      )
      .toList();
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

  final map = _readRequiredMap(
    parent[key],
    path: path,
    diagnostics: diagnostics,
  );

  return Offset(
    _readDouble(map['x'], path: '$path.x', diagnostics: diagnostics),
    _readDouble(map['y'], path: '$path.y', diagnostics: diagnostics),
  );
}

Size _readSize(
  Object? value, {
  required String path,
  required DiagnosticsHub? diagnostics,
}) {
  final map = _readRequiredMap(value, path: path, diagnostics: diagnostics);

  return Size(
    _readDouble(map['w'], path: '$path.w', diagnostics: diagnostics),
    _readDouble(map['h'], path: '$path.h', diagnostics: diagnostics),
  );
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

  final a = _readDouble(
    map['a'],
    path: 'transform.a',
    diagnostics: diagnostics,
  );
  final b = _readDouble(
    map['b'],
    path: 'transform.b',
    diagnostics: diagnostics,
  );
  final c = _readDouble(
    map['c'],
    path: 'transform.c',
    diagnostics: diagnostics,
  );
  final d = _readDouble(
    map['d'],
    path: 'transform.d',
    diagnostics: diagnostics,
  );
  final tx = _readDouble(
    map['tx'],
    path: 'transform.tx',
    diagnostics: diagnostics,
  );
  final ty = _readDouble(
    map['ty'],
    path: 'transform.ty',
    diagnostics: diagnostics,
  );

  return _materialize(
    diagnostics,
    () => CanvasTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty),
  );
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
  required String key,
  required DiagnosticsHub? diagnostics,
}) {
  if (!map.containsKey(key)) {
    return CanvasPathFillRule.nonZero;
  }

  return switch (map[key]) {
    'nonZero' => CanvasPathFillRule.nonZero,
    'evenOdd' => CanvasPathFillRule.evenOdd,
    _ => throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.invalidFieldType,
        message: 'unknown path fill rule.',
        path: 'path.fillRule',
      ),
    ),
  };
}

TextAlign _readTextAlign(
  Map<String, Object?> map, {
  required String key,
  required DiagnosticsHub? diagnostics,
}) {
  if (!map.containsKey(key)) {
    return TextAlign.left;
  }

  return switch (map[key]) {
    'left' => TextAlign.left,
    'right' => TextAlign.right,
    'center' => TextAlign.center,
    'justify' => TextAlign.justify,
    'start' => TextAlign.start,
    'end' => TextAlign.end,
    _ => throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.invalidFieldType,
        message: 'unknown text alignment.',
        path: 'text.align',
      ),
    ),
  };
}

TextDirection _readTextDirection(
  Map<String, Object?> map, {
  required String key,
  required DiagnosticsHub? diagnostics,
}) {
  if (!map.containsKey(key)) {
    return TextDirection.ltr;
  }

  return switch (map[key]) {
    'ltr' => TextDirection.ltr,
    'rtl' => TextDirection.rtl,
    _ => throw recordSchemaV1FailureDiagnostic(
      diagnostics,
      CanvasDataException(
        code: CanvasDataErrorCode.invalidFieldType,
        message: 'unknown text direction.',
        path: 'text.textDirection',
      ),
    ),
  };
}

final class _ElementCommon {
  _ElementCommon(
    Map<String, Object?> map, {
    required DiagnosticsHub? diagnostics,
  }) : id = _readElementId(map, diagnostics: diagnostics),
       revision = _readIntDefault(
         map,
         key: 'revision',
         path: 'element.revision',
         defaultValue: 0,
         diagnostics: diagnostics,
       ),
       transform = _readTransformDefault(
         map,
         key: 'transform',
         diagnostics: diagnostics,
       ),
       opacity = _readDoubleDefault(
         map,
         key: 'opacity',
         path: 'element.opacity',
         defaultValue: 1.0,
         diagnostics: diagnostics,
       ),
       hitPadding = _readDoubleDefault(
         map,
         key: 'hitPadding',
         path: 'element.hitPadding',
         defaultValue: 0.0,
         diagnostics: diagnostics,
       ),
       isVisible = _readBoolDefault(
         map,
         key: 'isVisible',
         path: 'element.isVisible',
         defaultValue: true,
         diagnostics: diagnostics,
       ),
       isSelectable = _readBoolDefault(
         map,
         key: 'isSelectable',
         path: 'element.isSelectable',
         defaultValue: true,
         diagnostics: diagnostics,
       ),
       isLocked = _readBoolDefault(
         map,
         key: 'isLocked',
         path: 'element.isLocked',
         defaultValue: false,
         diagnostics: diagnostics,
       ),
       isDeletable = _readBoolDefault(
         map,
         key: 'isDeletable',
         path: 'element.isDeletable',
         defaultValue: true,
         diagnostics: diagnostics,
       ),
       isTransformable = _readBoolDefault(
         map,
         key: 'isTransformable',
         path: 'element.isTransformable',
         defaultValue: true,
         diagnostics: diagnostics,
       ),
       metadata = _readMetadata(
         map,
         key: 'metadata',
         path: 'element.metadata',
         diagnostics: diagnostics,
       );

  final CanvasElementId id;
  final int revision;
  final CanvasTransform transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
  final CanvasMetadata metadata;
}

CanvasElementId _readElementId(
  Map<String, Object?> map, {
  required DiagnosticsHub? diagnostics,
}) {
  final value = _readString(
    map['id'],
    path: 'element.id',
    diagnostics: diagnostics,
  );

  return _materialize(diagnostics, () => CanvasElementId(value));
}

T _materialize<T>(DiagnosticsHub? diagnostics, T Function() create) {
  try {
    return create();
  } on CanvasDataException catch (exception) {
    throw recordSchemaV1FailureDiagnostic(diagnostics, exception);
  }
}

final class _PathElementFields {
  _PathElementFields(
    Map<String, Object?> map, {
    required DiagnosticsHub? diagnostics,
  }) : svgPathData = _readString(
         map['svgPathData'],
         path: 'path.svgPathData',
         diagnostics: diagnostics,
       ),
       fillColor = _readNullableColor(
         map['fillColor'],
         path: 'path.fillColor',
         diagnostics: diagnostics,
       ),
       strokeColor = _readNullableColor(
         map['strokeColor'],
         path: 'path.strokeColor',
         diagnostics: diagnostics,
       ),
       strokeWidth = _readDouble(
         map['strokeWidth'],
         path: 'path.strokeWidth',
         diagnostics: diagnostics,
       ),
       fillRule = _readFillRule(map, key: 'fillRule', diagnostics: diagnostics);

  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final CanvasPathFillRule fillRule;
}

final class _StrokeElementFields {
  _StrokeElementFields(
    Map<String, Object?> map, {
    required DiagnosticsHub? diagnostics,
  }) : points = _readOffsetList(
         map['points'],
         path: 'stroke.points',
         diagnostics: diagnostics,
       ),
       thickness = _readDouble(
         map['thickness'],
         path: 'stroke.thickness',
         diagnostics: diagnostics,
       ),
       color = _readColor(
         map['color'],
         path: 'stroke.color',
         diagnostics: diagnostics,
       );

  final List<Offset> points;
  final double thickness;
  final Color color;
}

final class _TextElementFields {
  _TextElementFields(
    Map<String, Object?> map, {
    required DiagnosticsHub? diagnostics,
  }) : value = _readString(
         map['text'],
         path: 'text.text',
         diagnostics: diagnostics,
       ),
       fontSize = _readDouble(
         map['fontSize'],
         path: 'text.fontSize',
         diagnostics: diagnostics,
       ),
       color = _readColor(
         map['color'],
         path: 'text.color',
         diagnostics: diagnostics,
       ),
       align = _readTextAlign(map, key: 'align', diagnostics: diagnostics),
       textDirection = _readTextDirection(
         map,
         key: 'textDirection',
         diagnostics: diagnostics,
       ),
       isBold = _readBoolDefault(
         map,
         key: 'isBold',
         path: 'text.isBold',
         defaultValue: false,
         diagnostics: diagnostics,
       ),
       isItalic = _readBoolDefault(
         map,
         key: 'isItalic',
         path: 'text.isItalic',
         defaultValue: false,
         diagnostics: diagnostics,
       ),
       isUnderline = _readBoolDefault(
         map,
         key: 'isUnderline',
         path: 'text.isUnderline',
         defaultValue: false,
         diagnostics: diagnostics,
       ),
       fontFamily = _readNullableString(
         map['fontFamily'],
         path: 'text.fontFamily',
         diagnostics: diagnostics,
       ),
       maxWidth = _readNullableDouble(
         map['maxWidth'],
         path: 'text.maxWidth',
         diagnostics: diagnostics,
       ),
       lineHeight = _readNullableDouble(
         map['lineHeight'],
         path: 'text.lineHeight',
         diagnostics: diagnostics,
       );

  final String value;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final TextDirection textDirection;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
}
