// Keeping schema encode in one codec owner with direct public DTO imports is
// clearer than splitting the boundary only to satisfy the import-count metric.
// ignore_for_file: number-of-imports

import 'dart:ui';

import '../api/canvas_document.dart';
import '../api/canvas_element.dart';
import '../api/canvas_geometry.dart';
import '../api/canvas_metadata.dart';
import '../api/canvas_resource.dart';
import 'validated_import_draft.dart';

Map<String, Object?> encodeSchemaV1Document(CanvasDocument document) {
  ValidatedImportDraft.fromDocument(document);

  return {
    'schemaVersion': 1,
    'camera': _writeCamera(document.camera),
    'background': _writeBackground(document.background),
    'palette': _writePalette(document.palette),
    'resources': document.resources.map(_writeResource).toList(),
    'backgroundLayer': {
      'elements': document.backgroundElements.map(_writeElement).toList(),
    },
    'layers': document.layers.map(_writeLayer).toList(),
    'metadata': _writeMetadata(document.metadata),
  };
}

Map<String, Object?> _writeCamera(CanvasCamera camera) {
  return {'offset': _writeOffset(camera.offset)};
}

Map<String, Object?> _writeBackground(CanvasBackground background) {
  return {
    'color': _writeColor(background.color),
    'grid': _writeGrid(background.grid),
  };
}

Map<String, Object?> _writeGrid(CanvasGrid grid) {
  return {
    'enabled': grid.enabled,
    'cellSize': grid.cellSize,
    'color': _writeColor(grid.color),
  };
}

Map<String, Object?> _writePalette(CanvasPalette palette) {
  return {
    'penColors': palette.penColors.map(_writeColor).toList(),
    'backgroundColors': palette.backgroundColors.map(_writeColor).toList(),
    'gridSizes': [...palette.gridSizes],
  };
}

Map<String, Object?> _writeResource(CanvasResource resource) {
  return switch (resource) {
    CanvasImageResource() => {
      'id': resource.id.value,
      'kind': 'image',
      'source': _writeResourceSource(resource.source),
      'mimeType': resource.mimeType,
      'contentHash': resource.contentHash,
      'byteLength': resource.byteLength,
      'metadata': _writeMetadata(resource.metadata),
    },
  };
}

Map<String, Object?> _writeResourceSource(CanvasResourceSource source) {
  return switch (source) {
    CanvasAppKeyResourceSource() => {'kind': 'appKey', 'key': source.key},
  };
}

Map<String, Object?> _writeLayer(CanvasLayer layer) {
  return {
    'id': layer.id.value,
    'elements': layer.elements.map(_writeElement).toList(),
    'metadata': _writeMetadata(layer.metadata),
  };
}

Map<String, Object?> _writeElement(CanvasElement element) {
  return {
    ..._writeElementCommon(element),
    ...switch (element) {
      CanvasImageElement() => _writeImageElement(element),
      CanvasPathElement() => _writePathElement(element),
      CanvasTextElement() => _writeTextElement(element),
      CanvasStrokeElement() => _writeStrokeElement(element),
      CanvasLineElement() => _writeLineElement(element),
      CanvasRectElement() => _writeRectElement(element),
    },
  };
}

Map<String, Object?> _writeElementCommon(CanvasElement element) {
  return {
    'id': element.id.value,
    'kind': _writeElementKind(element.kind),
    'revision': element.revision,
    'transform': _writeTransform(element.transform),
    'opacity': element.opacity,
    'hitPadding': element.hitPadding,
    'isVisible': element.isVisible,
    'isSelectable': element.isSelectable,
    'isLocked': element.isLocked,
    'isDeletable': element.isDeletable,
    'isTransformable': element.isTransformable,
    'metadata': _writeMetadata(element.metadata),
  };
}

Map<String, Object?> _writeImageElement(CanvasImageElement element) {
  final naturalSize = element.naturalSize;

  return {
    'resourceId': element.resourceId.value,
    'size': _writeSize(element.size),
    if (naturalSize != null) 'naturalSize': _writeSize(naturalSize),
  };
}

Map<String, Object?> _writePathElement(CanvasPathElement element) {
  return {
    'svgPathData': element.svgPathData,
    'fillColor': _writeNullableColor(element.fillColor),
    'strokeColor': _writeNullableColor(element.strokeColor),
    'strokeWidth': element.strokeWidth,
    'fillRule': _writeFillRule(element.fillRule),
  };
}

Map<String, Object?> _writeTextElement(CanvasTextElement element) {
  return {
    'text': element.text,
    'fontSize': element.fontSize,
    'color': _writeColor(element.color),
    'align': _writeTextAlign(element.align),
    'textDirection': _writeTextDirection(element.textDirection),
    'isBold': element.isBold,
    'isItalic': element.isItalic,
    'isUnderline': element.isUnderline,
    'fontFamily': element.fontFamily,
    'maxWidth': element.maxWidth,
    'lineHeight': element.lineHeight,
  };
}

Map<String, Object?> _writeStrokeElement(CanvasStrokeElement element) {
  return {
    'points': element.points.map(_writeOffset).toList(),
    'thickness': element.thickness,
    'color': _writeColor(element.color),
  };
}

Map<String, Object?> _writeLineElement(CanvasLineElement element) {
  return {
    'start': _writeOffset(element.start),
    'end': _writeOffset(element.end),
    'thickness': element.thickness,
    'color': _writeColor(element.color),
  };
}

Map<String, Object?> _writeRectElement(CanvasRectElement element) {
  return {
    'size': _writeSize(element.size),
    'fillColor': _writeNullableColor(element.fillColor),
    'strokeColor': _writeNullableColor(element.strokeColor),
    'strokeWidth': element.strokeWidth,
  };
}

Map<String, Object?> _writeOffset(Offset offset) {
  return {'x': offset.dx, 'y': offset.dy};
}

Map<String, Object?> _writeSize(Size size) {
  return {'w': size.width, 'h': size.height};
}

Map<String, Object?> _writeTransform(CanvasTransform transform) {
  return transform.toJsonMap();
}

Map<String, Object?> _writeMetadata(CanvasMetadata metadata) {
  return canvasMetadataToJsonObject(metadata);
}

String _writeColor(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

String? _writeNullableColor(Color? color) {
  return color == null ? null : _writeColor(color);
}

String _writeElementKind(CanvasElementKind kind) {
  return switch (kind) {
    CanvasElementKind.image => 'image',
    CanvasElementKind.path => 'path',
    CanvasElementKind.text => 'text',
    CanvasElementKind.stroke => 'stroke',
    CanvasElementKind.line => 'line',
    CanvasElementKind.rect => 'rect',
  };
}

String _writeFillRule(CanvasPathFillRule fillRule) {
  return switch (fillRule) {
    CanvasPathFillRule.nonZero => 'nonZero',
    CanvasPathFillRule.evenOdd => 'evenOdd',
  };
}

String _writeTextAlign(TextAlign align) {
  return switch (align) {
    TextAlign.left => 'left',
    TextAlign.right => 'right',
    TextAlign.center => 'center',
    TextAlign.justify => 'justify',
    TextAlign.start => 'start',
    TextAlign.end => 'end',
  };
}

String _writeTextDirection(TextDirection direction) {
  return switch (direction) {
    TextDirection.ltr => 'ltr',
    TextDirection.rtl => 'rtl',
  };
}
