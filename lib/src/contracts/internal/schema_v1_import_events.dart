import 'dart:ui';

import '../public/canvas_document.dart'
    show CanvasBackground, CanvasCamera, CanvasPalette;
import '../public/canvas_element.dart';
import '../public/canvas_geometry.dart';
import '../public/canvas_ids.dart';
import '../public/canvas_metadata.dart';

abstract interface class SchemaV1ImportSink {
  void beginDocument(SchemaV1DocumentImportEvent event);
  void imageResource(SchemaV1ImageResourceImportEvent event);
  void backgroundElement(SchemaV1ElementImportEvent event);
  void layer(SchemaV1LayerImportEvent event);
  void layerElement(CanvasLayerId layerId, SchemaV1ElementImportEvent event);
  void endDocument();
}

/// Sink whose partial import state cannot escape if schema decoding fails.
abstract interface class IsolatedSchemaV1ImportSink
    implements SchemaV1ImportSink {
  void abortDocument();
}

final class SchemaV1DocumentImportEvent {
  const SchemaV1DocumentImportEvent({
    required this.camera,
    required this.background,
    required this.palette,
    required this.metadata,
  });

  final CanvasCamera camera;
  final CanvasBackground background;
  final CanvasPalette palette;
  final CanvasMetadata metadata;
}

final class SchemaV1ImageResourceImportEvent {
  const SchemaV1ImageResourceImportEvent({
    required this.id,
    required this.appKey,
    required this.mimeType,
    required this.contentHash,
    required this.byteLength,
    required this.metadata,
  });

  final CanvasResourceId id;
  final String appKey;
  final String? mimeType;
  final String? contentHash;
  final int? byteLength;
  final CanvasMetadata metadata;
}

final class SchemaV1LayerImportEvent {
  const SchemaV1LayerImportEvent({required this.id, required this.metadata});

  final CanvasLayerId id;
  final CanvasMetadata metadata;
}

sealed class SchemaV1ElementImportEvent {
  const SchemaV1ElementImportEvent({required this.common});

  final SchemaV1ElementCommonImport common;
}

final class SchemaV1ImageElementImportEvent extends SchemaV1ElementImportEvent {
  const SchemaV1ImageElementImportEvent({
    required super.common,
    required this.resourceId,
    required this.size,
    required this.naturalSize,
  });

  final CanvasResourceId resourceId;
  final Size size;
  final Size? naturalSize;
}

final class SchemaV1PathElementImportEvent extends SchemaV1ElementImportEvent {
  const SchemaV1PathElementImportEvent({
    required super.common,
    required this.svgPathData,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.fillRule,
  });

  final String svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final CanvasPathFillRule fillRule;
}

final class SchemaV1TextElementImportEvent extends SchemaV1ElementImportEvent {
  const SchemaV1TextElementImportEvent({
    required super.common,
    required this.text,
    required this.fontSize,
    required this.color,
    required this.align,
    required this.textDirection,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.fontFamily,
    required this.maxWidth,
    required this.lineHeight,
  });

  final String text;
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

final class SchemaV1StrokeElementImportEvent
    extends SchemaV1ElementImportEvent {
  const SchemaV1StrokeElementImportEvent({
    required super.common,
    required this.points,
    required this.thickness,
    required this.color,
  });

  final List<Offset> points;
  final double thickness;
  final Color color;
}

final class SchemaV1LineElementImportEvent extends SchemaV1ElementImportEvent {
  const SchemaV1LineElementImportEvent({
    required super.common,
    required this.start,
    required this.end,
    required this.thickness,
    required this.color,
  });

  final Offset start;
  final Offset end;
  final double thickness;
  final Color color;
}

final class SchemaV1RectElementImportEvent extends SchemaV1ElementImportEvent {
  const SchemaV1RectElementImportEvent({
    required super.common,
    required this.size,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  final Size size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
}

final class SchemaV1ElementCommonImport {
  const SchemaV1ElementCommonImport({
    required this.id,
    required this.kind,
    required this.revision,
    required this.transform,
    required this.opacity,
    required this.hitPadding,
    required this.isVisible,
    required this.isSelectable,
    required this.isLocked,
    required this.isDeletable,
    required this.isTransformable,
    required this.metadata,
  });

  final CanvasElementId id;
  final CanvasElementKind kind;
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
