import 'dart:ui';

import '../public/canvas_document.dart';
import '../public/canvas_element.dart';
import '../public/canvas_geometry.dart';
import '../public/canvas_ids.dart';
import '../public/canvas_metadata.dart';
import 'measured_text_layout.dart';

final class FrameRevisionFacts {
  const FrameRevisionFacts({
    required this.documentRevision,
    required this.structuralRevision,
    required this.boundsRevision,
    required this.elementVisualRevision,
    required this.backgroundRevision,
    required this.gridRevision,
    required this.resourceRevision,
  });

  final int documentRevision;
  final int structuralRevision;
  final int boundsRevision;
  final int elementVisualRevision;
  final int backgroundRevision;
  final int gridRevision;
  final int resourceRevision;
}

final class FrameElementHandle {
  const FrameElementHandle({
    required this.id,
    required this.structuralRevision,
    required this.generation,
    required this.orderToken,
  });

  final CanvasElementId id;
  final int structuralRevision;
  final int generation;
  final int orderToken;
}

enum FrameElementLocationKind { background, content }

final class FrameElementFacts {
  FrameElementFacts({
    required this.id,
    required this.kind,
    required this.revision,
    required this.generation,
    required this.orderToken,
    required this.locationKind,
    required this.transform,
    required this.opacity,
    required this.hitPadding,
    required this.isVisible,
    required this.isSelectable,
    required this.isLocked,
    required this.isDeletable,
    required this.isTransformable,
    required this.metadata,
    this.resourceId,
    this.layerId,
    this.size,
    this.naturalSize,
    this.svgPathData,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth,
    this.fillRule,
    this.text,
    this.fontSize,
    this.textColor,
    this.textAlign,
    this.textDirection,
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.fontFamily,
    this.maxWidth,
    this.lineHeight,
    this.measuredTextLayout,
    Iterable<Offset> points = const [],
    this.start,
    this.end,
    this.color,
    this.thickness,
  }) : points = List.unmodifiable(points);

  final CanvasElementId id;
  final CanvasElementKind kind;
  final int revision;
  final int generation;
  final int orderToken;
  final FrameElementLocationKind locationKind;
  final CanvasTransform transform;
  final double opacity;
  final double hitPadding;
  final bool isVisible;
  final bool isSelectable;
  final bool isLocked;
  final bool isDeletable;
  final bool isTransformable;
  final CanvasMetadata metadata;
  final CanvasResourceId? resourceId;
  final CanvasLayerId? layerId;
  final Size? size;
  final Size? naturalSize;
  final String? svgPathData;
  final Color? fillColor;
  final Color? strokeColor;
  final double? strokeWidth;
  final CanvasPathFillRule? fillRule;
  final String? text;
  final double? fontSize;
  final Color? textColor;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final String? fontFamily;
  final double? maxWidth;
  final double? lineHeight;
  final MeasuredTextLayout? measuredTextLayout;
  final List<Offset> points;
  final Offset? start;
  final Offset? end;
  final Color? color;
  final double? thickness;
}

sealed class FrameResourceDescriptorFacts {
  const FrameResourceDescriptorFacts({
    required this.id,
    required this.appKey,
    required this.contentHash,
    required this.byteLength,
    required this.resourceRevision,
    required this.metadata,
  });

  final CanvasResourceId id;
  final String appKey;
  final String? contentHash;
  final int? byteLength;
  final int resourceRevision;
  final CanvasMetadata metadata;
}

final class FrameImageResourceDescriptorFacts
    extends FrameResourceDescriptorFacts {
  const FrameImageResourceDescriptorFacts({
    required super.id,
    required super.appKey,
    required this.mimeType,
    required super.contentHash,
    required super.byteLength,
    required super.resourceRevision,
    required super.metadata,
  });

  final String? mimeType;
}

abstract interface class FrameFactsPort {
  FrameRevisionFacts get frameRevisions;
  CanvasBackground get background;
  int elementCount(int structuralRevision);
  List<FrameElementHandle> elementHandles(int structuralRevision);
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  );
  FrameElementFacts? resolveElement(FrameElementHandle handle);
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id);
}
