// The schema decoder imports each public API value owner directly so ownership
// stays visible after metadata moved out of the document owner.
// ignore_for_file: number-of-imports

import 'dart:convert';
import 'dart:ui';

import '../api/canvas_document.dart';
import '../api/canvas_element.dart';
import '../api/canvas_errors.dart';
import '../api/canvas_geometry.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_metadata.dart';
import '../api/canvas_resource.dart';
import '../api/canvas_value_validators.dart';
import 'schema_v1_validation.dart';

CanvasDocument decodeSchemaV1Document(Map<String, Object?> json) {
  validateSchemaV1Root(json);

  final resources = _readList(
    json,
    key: 'resources',
    path: 'resources',
  ).map(_readResource).toList();
  final resourceIds = _uniqueIds(
    resources.map((resource) => resource.id.value),
    path: 'resources.id',
    code: CanvasDataErrorCode.duplicateResourceId,
  );
  final backgroundElements = _readBackgroundElements(json).map(_readElement);
  final layers = _readList(json, key: 'layers', path: 'layers').map(_readLayer);
  final document = CanvasDocument(
    camera: _readCamera(json, key: 'camera'),
    background: _readBackground(json, key: 'background'),
    palette: _readPalette(json, key: 'palette'),
    resources: resources,
    backgroundElements: backgroundElements,
    layers: layers,
    metadata: _readMetadata(json, key: 'metadata', path: 'metadata'),
  );

  _validateDocumentReferences(document, resourceIds);

  return document;
}

CanvasDocument decodeSchemaV1DocumentFromJson(String json) {
  validateRawJsonLength(json);
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (_) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidJson,
      message: 'canvas document JSON is malformed.',
      path: r'$',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidJson,
      message: 'canvas document JSON must decode to an object.',
      path: r'$',
    );
  }

  return decodeSchemaV1Document(decoded);
}

CanvasCamera _readCamera(Map<String, Object?> parent, {required String key}) {
  final map = _readMap(parent, key: key, path: 'camera');
  final offset = _readOffsetDefault(map, key: 'offset', path: 'camera.offset');

  return CanvasCamera(offset: offset);
}

CanvasBackground _readBackground(
  Map<String, Object?> parent, {
  required String key,
}) {
  final map = _readMap(parent, key: key, path: 'background');

  return CanvasBackground(
    color: map.containsKey('color')
        ? _readColor(map['color'], path: 'background.color')
        : const Color(0xFFFFFFFF),
    grid: _readGrid(map, key: 'grid'),
  );
}

CanvasGrid _readGrid(Map<String, Object?> parent, {required String key}) {
  final map = _readMap(parent, key: key, path: 'background.grid');

  return CanvasGrid(
    enabled: _readBoolDefault(
      map,
      key: 'enabled',
      path: 'background.grid.enabled',
      defaultValue: false,
    ),
    cellSize: _readDoubleDefault(
      map,
      key: 'cellSize',
      path: 'background.grid.cellSize',
      defaultValue: 10.0,
    ),
    color: map.containsKey('color')
        ? _readColor(map['color'], path: 'background.grid.color')
        : const Color(0x1F000000),
  );
}

CanvasPalette _readPalette(Map<String, Object?> parent, {required String key}) {
  final map = _readMap(parent, key: key, path: 'palette');
  final penColors = _readList(
    map,
    key: 'penColors',
    path: 'palette.penColors',
  ).map((value) => _readColor(value, path: 'palette.penColors'));
  final backgroundColors = _readList(
    map,
    key: 'backgroundColors',
    path: 'palette.backgroundColors',
  ).map((value) => _readColor(value, path: 'palette.backgroundColors'));
  final gridSizes = _readList(
    map,
    key: 'gridSizes',
    path: 'palette.gridSizes',
  ).map((value) => _readDouble(value, path: 'palette.gridSizes'));

  return CanvasPalette(
    penColors: penColors,
    backgroundColors: backgroundColors,
    gridSizes: gridSizes,
  );
}

CanvasResource _readResource(Object? value) {
  final map = _readRequiredMap(value, path: 'resources[]');
  final kind = _readString(map['kind'], path: 'resource.kind');
  if (kind != 'image') {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: 'unknown resource kind: $kind.',
      path: 'resource.kind',
    );
  }

  return CanvasImageResource(
    id: CanvasResourceId(_readString(map['id'], path: 'resource.id')),
    source: _readResourceSource(map['source']),
    mimeType: _readNullableString(map['mimeType'], path: 'resource.mimeType'),
    contentHash: _readNullableString(
      map['contentHash'],
      path: 'resource.contentHash',
    ),
    byteLength: _readNullableInt(
      map['byteLength'],
      path: 'resource.byteLength',
    ),
    metadata: _readMetadata(map, key: 'metadata', path: 'resource.metadata'),
  );
}

CanvasResourceSource _readResourceSource(Object? value) {
  final map = _readRequiredMap(value, path: 'resource.source');
  final kind = _readString(map['kind'], path: 'resource.source.kind');
  if (kind != 'appKey') {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: 'unknown resource source kind: $kind.',
      path: 'resource.source.kind',
    );
  }

  return CanvasResourceSource.appKey(
    _readString(map['key'], path: 'resource.source.key'),
  );
}

CanvasLayer _readLayer(Object? value) {
  final map = _readRequiredMap(value, path: 'layers[]');

  return CanvasLayer(
    id: CanvasLayerId(_readString(map['id'], path: 'layer.id')),
    elements: _readList(
      map,
      key: 'elements',
      path: 'layer.elements',
    ).map(_readElement),
    metadata: _readMetadata(map, key: 'metadata', path: 'layer.metadata'),
  );
}

Iterable<Object?> _readBackgroundElements(Map<String, Object?> json) {
  if (json.containsKey('backgroundElements')) {
    return _readList(
      json,
      key: 'backgroundElements',
      path: 'backgroundElements',
    );
  }
  if (!json.containsKey('backgroundLayer')) {
    return const [];
  }

  final map = _readMap(json, key: 'backgroundLayer', path: 'backgroundLayer');

  return _readList(map, key: 'elements', path: 'backgroundLayer.elements');
}

CanvasElement _readElement(Object? value) {
  final map = _readRequiredMap(value, path: 'elements[]');
  final common = _ElementCommon(map);

  return switch (_readString(map['kind'], path: 'element.kind')) {
    'image' => _readImageElement(map, common),
    'path' => _readPathElement(map, common),
    'text' => _readTextElement(map, common),
    'stroke' => _readStrokeElement(map, common),
    'line' => _readLineElement(map, common),
    'rect' => _readRectElement(map, common),
    final kind => throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: 'unknown element kind: $kind.',
      path: 'element.kind',
    ),
  };
}

CanvasImageElement _readImageElement(
  Map<String, Object?> map,
  _ElementCommon common,
) {
  return CanvasImageElement(
    id: common.id,
    resourceId: CanvasResourceId(
      _readString(map['resourceId'], path: 'image.resourceId'),
    ),
    size: _readSize(map['size'], path: 'image.size'),
    naturalSize: _readNullableSize(
      map['naturalSize'],
      path: 'image.naturalSize',
    ),
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
  );
}

CanvasPathElement _readPathElement(
  Map<String, Object?> map,
  _ElementCommon common,
) {
  return CanvasPathElement(
    id: common.id,
    svgPathData: _readString(map['svgPathData'], path: 'path.svgPathData'),
    fillColor: _readNullableColor(map['fillColor'], path: 'path.fillColor'),
    strokeColor: _readNullableColor(
      map['strokeColor'],
      path: 'path.strokeColor',
    ),
    strokeWidth: _readDouble(map['strokeWidth'], path: 'path.strokeWidth'),
    fillRule: _readFillRule(map, key: 'fillRule'),
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
  );
}

CanvasTextElement _readTextElement(
  Map<String, Object?> map,
  _ElementCommon common,
) {
  final text = _TextElementFields(map);

  return CanvasTextElement(
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
  );
}

CanvasStrokeElement _readStrokeElement(
  Map<String, Object?> map,
  _ElementCommon common,
) {
  return CanvasStrokeElement(
    id: common.id,
    points: _readRequiredList(
      map['points'],
      path: 'stroke.points',
    ).map((value) => _readRequiredOffset(value, path: 'stroke.points')),
    thickness: _readDouble(map['thickness'], path: 'stroke.thickness'),
    color: _readColor(map['color'], path: 'stroke.color'),
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
  );
}

CanvasLineElement _readLineElement(
  Map<String, Object?> map,
  _ElementCommon common,
) {
  return CanvasLineElement(
    id: common.id,
    start: _readRequiredOffset(map['start'], path: 'line.start'),
    end: _readRequiredOffset(map['end'], path: 'line.end'),
    thickness: _readDouble(map['thickness'], path: 'line.thickness'),
    color: _readColor(map['color'], path: 'line.color'),
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
  );
}

CanvasRectElement _readRectElement(
  Map<String, Object?> map,
  _ElementCommon common,
) {
  return CanvasRectElement(
    id: common.id,
    size: _readSize(map['size'], path: 'rect.size'),
    fillColor: _readNullableColor(map['fillColor'], path: 'rect.fillColor'),
    strokeColor: _readNullableColor(
      map['strokeColor'],
      path: 'rect.strokeColor',
    ),
    strokeWidth: _readDouble(map['strokeWidth'], path: 'rect.strokeWidth'),
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
  );
}

void _validateDocumentReferences(
  CanvasDocument document,
  Set<String> resourceIds,
) {
  final elementIds = <String>{};
  final layerIds = <String>{};
  for (final element in document.backgroundElements) {
    _validateElementReferences(element, elementIds, resourceIds);
  }
  for (final layer in document.layers) {
    if (!layerIds.add(layer.id.value)) {
      throw CanvasDataException(
        code: CanvasDataErrorCode.duplicateLayerId,
        message: 'duplicate layer id.',
        path: 'layers.id',
      );
    }
    for (final element in layer.elements) {
      _validateElementReferences(element, elementIds, resourceIds);
    }
  }
}

void _validateElementReferences(
  CanvasElement element,
  Set<String> elementIds,
  Set<String> resourceIds,
) {
  if (!elementIds.add(element.id.value)) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.duplicateElementId,
      message: 'duplicate element id.',
      path: 'elements.id',
    );
  }
  if (element is CanvasImageElement &&
      !resourceIds.contains(element.resourceId.value)) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.missingResourceReference,
      message: 'image element references a missing resource.',
      path: 'image.resourceId',
    );
  }
}

Set<String> _uniqueIds(
  Iterable<String> ids, {
  required String path,
  required CanvasDataErrorCode code,
}) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw CanvasDataException(
        code: code,
        message: 'duplicate id: $id.',
        path: path,
      );
    }
  }

  return seen;
}

Map<String, Object?> _readMap(
  Map<String, Object?> parent, {
  required String key,
  required String path,
}) {
  if (!parent.containsKey(key)) {
    return const {};
  }

  return _readRequiredMap(parent[key], path: path);
}

Map<String, Object?> _readRequiredMap(Object? value, {required String path}) {
  if (value is Map<String, Object?>) {
    return value;
  }

  throw CanvasDataException(
    code: value == null
        ? CanvasDataErrorCode.missingField
        : CanvasDataErrorCode.invalidFieldType,
    message: '$path must be an object.',
    path: path,
  );
}

List<Object?> _readList(
  Map<String, Object?> parent, {
  required String key,
  required String path,
}) {
  if (!parent.containsKey(key)) {
    return const [];
  }

  return _readRequiredList(parent[key], path: path);
}

List<Object?> _readRequiredList(Object? value, {required String path}) {
  if (value is List<Object?>) {
    return value;
  }

  throw CanvasDataException(
    code: CanvasDataErrorCode.invalidFieldType,
    message: '$path must be a list.',
    path: path,
  );
}

String _readString(Object? value, {required String path}) {
  if (value is String) {
    return value;
  }

  throw CanvasDataException(
    code: value == null
        ? CanvasDataErrorCode.missingField
        : CanvasDataErrorCode.invalidFieldType,
    message: '$path must be a string.',
    path: path,
  );
}

String? _readNullableString(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }

  return _readString(value, path: path);
}

int _readInt(Object? value, {required String path}) {
  if (value is int) {
    return value;
  }

  throw CanvasDataException(
    code: value == null
        ? CanvasDataErrorCode.missingField
        : CanvasDataErrorCode.invalidFieldType,
    message: '$path must be an int.',
    path: path,
  );
}

int? _readNullableInt(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }

  return _readInt(value, path: path);
}

int _readIntDefault(
  Map<String, Object?> map, {
  required String key,
  required String path,
  required int defaultValue,
}) {
  if (!map.containsKey(key)) {
    return defaultValue;
  }

  return _readInt(map[key], path: path);
}

double _readDouble(Object? value, {required String path}) {
  if (value is num) {
    return value.toDouble();
  }

  throw CanvasDataException(
    code: value == null
        ? CanvasDataErrorCode.missingField
        : CanvasDataErrorCode.invalidFieldType,
    message: '$path must be a number.',
    path: path,
  );
}

double? _readNullableDouble(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }

  return _readDouble(value, path: path);
}

double _readDoubleDefault(
  Map<String, Object?> map, {
  required String key,
  required String path,
  required double defaultValue,
}) {
  if (!map.containsKey(key)) {
    return defaultValue;
  }

  return _readDouble(map[key], path: path);
}

bool _readBool(Object? value, {required String path}) {
  if (value is bool) {
    return value;
  }

  throw CanvasDataException(
    code: CanvasDataErrorCode.invalidFieldType,
    message: '$path must be a bool.',
    path: path,
  );
}

bool _readBoolDefault(
  Map<String, Object?> map, {
  required String key,
  required String path,
  required bool defaultValue,
}) {
  if (!map.containsKey(key)) {
    return defaultValue;
  }

  return _readBool(map[key], path: path);
}

Color _readColor(Object? value, {required String path}) {
  if (value is! String ||
      value.length != 9 ||
      !value.startsWith('#') ||
      int.tryParse(value.substring(1), radix: 16) == null) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: '$path must be #AARRGGBB.',
      path: path,
    );
  }

  return Color(int.parse(value.substring(1), radix: 16));
}

Color? _readNullableColor(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }

  return _readColor(value, path: path);
}

Offset _readRequiredOffset(Object? value, {required String path}) {
  final map = _readRequiredMap(value, path: path);

  return Offset(
    _readDouble(map['x'], path: '$path.x'),
    _readDouble(map['y'], path: '$path.y'),
  );
}

Offset _readOffsetDefault(
  Map<String, Object?> parent, {
  required String key,
  required String path,
}) {
  if (!parent.containsKey(key)) {
    return Offset.zero;
  }

  final map = _readRequiredMap(parent[key], path: path);

  return Offset(
    _readDouble(map['x'], path: '$path.x'),
    _readDouble(map['y'], path: '$path.y'),
  );
}

Size _readSize(Object? value, {required String path}) {
  final map = _readRequiredMap(value, path: path);

  return Size(
    _readDouble(map['w'], path: '$path.w'),
    _readDouble(map['h'], path: '$path.h'),
  );
}

Size? _readNullableSize(Object? value, {required String path}) {
  if (value == null) {
    return null;
  }

  return _readSize(value, path: path);
}

CanvasTransform _readTransform(Object? value) {
  final map = _readRequiredMap(value, path: 'element.transform');

  return CanvasTransform(
    a: _readDouble(map['a'], path: 'transform.a'),
    b: _readDouble(map['b'], path: 'transform.b'),
    c: _readDouble(map['c'], path: 'transform.c'),
    d: _readDouble(map['d'], path: 'transform.d'),
    tx: _readDouble(map['tx'], path: 'transform.tx'),
    ty: _readDouble(map['ty'], path: 'transform.ty'),
  );
}

CanvasTransform _readTransformDefault(
  Map<String, Object?> map, {
  required String key,
}) {
  if (!map.containsKey(key)) {
    return CanvasTransform.identity;
  }

  return _readTransform(map[key]);
}

CanvasMetadata _readMetadata(
  Map<String, Object?> parent, {
  required String key,
  required String path,
}) {
  if (!parent.containsKey(key)) {
    return const CanvasMetadata.empty();
  }
  final map = _readRequiredMap(parent[key], path: path);

  return CanvasMetadata.fromMap(map);
}

CanvasPathFillRule _readFillRule(
  Map<String, Object?> map, {
  required String key,
}) {
  if (!map.containsKey(key)) {
    return CanvasPathFillRule.nonZero;
  }

  return switch (map[key]) {
    'nonZero' => CanvasPathFillRule.nonZero,
    'evenOdd' => CanvasPathFillRule.evenOdd,
    _ => throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: 'unknown path fill rule.',
      path: 'path.fillRule',
    ),
  };
}

TextAlign _readTextAlign(Map<String, Object?> map, {required String key}) {
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
    _ => throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: 'unknown text alignment.',
      path: 'text.align',
    ),
  };
}

TextDirection _readTextDirection(
  Map<String, Object?> map, {
  required String key,
}) {
  if (!map.containsKey(key)) {
    return TextDirection.ltr;
  }

  return switch (map[key]) {
    'ltr' => TextDirection.ltr,
    'rtl' => TextDirection.rtl,
    _ => throw CanvasDataException(
      code: CanvasDataErrorCode.invalidFieldType,
      message: 'unknown text direction.',
      path: 'text.textDirection',
    ),
  };
}

final class _ElementCommon {
  _ElementCommon(Map<String, Object?> map)
    : id = CanvasElementId(_readString(map['id'], path: 'element.id')),
      revision = _readIntDefault(
        map,
        key: 'revision',
        path: 'element.revision',
        defaultValue: 0,
      ),
      transform = _readTransformDefault(map, key: 'transform'),
      opacity = _readDoubleDefault(
        map,
        key: 'opacity',
        path: 'element.opacity',
        defaultValue: 1.0,
      ),
      hitPadding = _readDoubleDefault(
        map,
        key: 'hitPadding',
        path: 'element.hitPadding',
        defaultValue: 0.0,
      ),
      isVisible = _readBoolDefault(
        map,
        key: 'isVisible',
        path: 'element.isVisible',
        defaultValue: true,
      ),
      isSelectable = _readBoolDefault(
        map,
        key: 'isSelectable',
        path: 'element.isSelectable',
        defaultValue: true,
      ),
      isLocked = _readBoolDefault(
        map,
        key: 'isLocked',
        path: 'element.isLocked',
        defaultValue: false,
      ),
      isDeletable = _readBoolDefault(
        map,
        key: 'isDeletable',
        path: 'element.isDeletable',
        defaultValue: true,
      ),
      isTransformable = _readBoolDefault(
        map,
        key: 'isTransformable',
        path: 'element.isTransformable',
        defaultValue: true,
      ),
      metadata = _readMetadata(map, key: 'metadata', path: 'element.metadata');

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

final class _TextElementFields {
  _TextElementFields(Map<String, Object?> map)
    : value = _readString(map['text'], path: 'text.text'),
      fontSize = _readDouble(map['fontSize'], path: 'text.fontSize'),
      color = _readColor(map['color'], path: 'text.color'),
      align = _readTextAlign(map, key: 'align'),
      textDirection = _readTextDirection(map, key: 'textDirection'),
      isBold = _readBoolDefault(
        map,
        key: 'isBold',
        path: 'text.isBold',
        defaultValue: false,
      ),
      isItalic = _readBoolDefault(
        map,
        key: 'isItalic',
        path: 'text.isItalic',
        defaultValue: false,
      ),
      isUnderline = _readBoolDefault(
        map,
        key: 'isUnderline',
        path: 'text.isUnderline',
        defaultValue: false,
      ),
      fontFamily = _readNullableString(
        map['fontFamily'],
        path: 'text.fontFamily',
      ),
      maxWidth = _readNullableDouble(map['maxWidth'], path: 'text.maxWidth'),
      lineHeight = _readNullableDouble(
        map['lineHeight'],
        path: 'text.lineHeight',
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
