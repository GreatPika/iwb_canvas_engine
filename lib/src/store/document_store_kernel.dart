import 'dart:ui';

import '../api/canvas_document.dart';
import '../api/canvas_element.dart';
import '../api/canvas_geometry.dart';
import '../api/canvas_ids.dart';
import '../api/canvas_metadata.dart';
import '../api/canvas_resource.dart';
import 'committed_document.dart';
import 'document_projection_cache.dart';
import 'family_tables.dart';

// DocumentStoreKernel is the single owner for committed document facts, read
// projection, id admission, and selection normalization inputs; splitting these
// accessors would obscure the shared committed-state source of truth.
// ignore: metrics
final class DocumentStoreKernel {
  DocumentStoreKernel(CanvasDocument initialDocument)
    : _document = CommittedDocument(initialDocument);

  final CommittedDocument _document;
  final DocumentProjectionCache _projectionCache = DocumentProjectionCache();
  final _IdAdmission _elementIds = _IdAdmission(prefix: 'e');
  final _IdAdmission _layerIds = _IdAdmission(prefix: 'l');
  final _IdAdmission _resourceIds = _IdAdmission(prefix: 'r');

  CanvasDocument readDocument() => _projectionCache.projectionFor(_document);

  CanvasDocumentSummary get documentSummary => _document.summary;
  int get documentRevision => _document.revisions.documentRevision;
  int get structuralRevision => _document.revisions.structuralRevision;
  int get boundsRevision => _document.revisions.boundsRevision;
  int get elementVisualRevision => _document.revisions.elementVisualRevision;
  int get backgroundRevision => _document.revisions.backgroundRevision;
  int get gridRevision => _document.revisions.gridRevision;
  int get resourceRevision => _document.revisions.resourceRevision;
  int get projectionBuildCount => _projectionCache.buildCount;
  Set<CanvasElementId> get selectableElementIds {
    return Set.unmodifiable(_document.elements.selectableElementIds);
  }

  Set<CanvasElementId> get contentElementIds {
    return Set.unmodifiable(_document.elements.contentElementIds);
  }

  List<StoreElementHandle> elementHandles(int structuralRevision) {
    return List.unmodifiable([
      for (final indexed in _document.elements.frameElementOrder.indexed)
        StoreElementHandle(
          id: indexed.$2,
          structuralRevision: structuralRevision,
          generation: 0,
        ),
    ]);
  }

  StoreElementFacts? resolveElement(StoreElementHandle handle) {
    if (handle.structuralRevision != _document.revisions.structuralRevision ||
        handle.generation != 0) {
      return null;
    }
    final facts = _document.elements.elementFrameFacts(handle.id);
    if (facts == null) {
      return null;
    }
    final orderToken = _document.elements.frameElementOrder.indexOf(handle.id);
    if (orderToken < 0) {
      return null;
    }

    return StoreElementFacts.fromFrameFacts(facts, orderToken: orderToken);
  }

  StoreResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    for (final resource in _document.resources) {
      if (resource.id != id) {
        continue;
      }
      final source = resource.source;
      if (resource is CanvasImageResource &&
          source is CanvasAppKeyResourceSource) {
        return StoreResourceDescriptorFacts(
          id: resource.id,
          appKey: source.key,
          resourceRevision: _document.revisions.resourceRevision,
          metadata: resource.metadata,
        );
      }
    }

    return null;
  }

  Set<CanvasElementId> normalizeSelection(Iterable<CanvasElementId> ids) {
    final selectable = _document.elements.selectableElementIds;

    return {
      for (final id in ids)
        if (selectable.contains(id)) id,
    };
  }

  CanvasElementId generateElementId() {
    return CanvasElementId(_elementIds.nextValue(_document.admittedElementIds));
  }

  CanvasLayerId generateLayerId() {
    return CanvasLayerId(_layerIds.nextValue(_document.admittedLayerIds));
  }

  CanvasResourceId generateResourceId() {
    return CanvasResourceId(
      _resourceIds.nextValue(_document.admittedResourceIds),
    );
  }
}

final class StoreElementHandle {
  const StoreElementHandle({
    required this.id,
    required this.structuralRevision,
    required this.generation,
  });

  final CanvasElementId id;
  final int structuralRevision;
  final int generation;
}

final class StoreElementFacts {
  StoreElementFacts({
    required this.id,
    required this.kind,
    required this.revision,
    required this.generation,
    required this.orderToken,
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
    Iterable<Offset> points = const [],
    this.start,
    this.end,
    this.color,
    this.thickness,
  }) : points = List.unmodifiable(points);

  // This mapper intentionally lists every immutable row field crossing from the
  // family tables into the store fact; splitting it would make the read-port
  // contract harder to audit.
  // ignore: metrics
  factory StoreElementFacts.fromFrameFacts(
    ElementFrameFacts facts, {
    required int orderToken,
  }) {
    return StoreElementFacts(
      id: facts.id,
      kind: facts.kind,
      revision: facts.revision,
      generation: facts.generation,
      orderToken: orderToken,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
      resourceId: facts.resourceId,
      size: facts.size,
      naturalSize: facts.naturalSize,
      svgPathData: facts.svgPathData,
      fillColor: facts.fillColor,
      strokeColor: facts.strokeColor,
      strokeWidth: facts.strokeWidth,
      fillRule: facts.fillRule,
      text: facts.text,
      fontSize: facts.fontSize,
      textColor: facts.textColor,
      textAlign: facts.textAlign,
      textDirection: facts.textDirection,
      isBold: facts.isBold,
      isItalic: facts.isItalic,
      isUnderline: facts.isUnderline,
      fontFamily: facts.fontFamily,
      maxWidth: facts.maxWidth,
      lineHeight: facts.lineHeight,
      points: facts.points,
      start: facts.start,
      end: facts.end,
      color: facts.color,
      thickness: facts.thickness,
    );
  }

  final CanvasElementId id;
  final CanvasElementKind kind;
  final int revision;
  final int generation;
  final int orderToken;
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
  final List<Offset> points;
  final Offset? start;
  final Offset? end;
  final Color? color;
  final double? thickness;
}

final class StoreResourceDescriptorFacts {
  const StoreResourceDescriptorFacts({
    required this.id,
    required this.appKey,
    required this.resourceRevision,
    required this.metadata,
  });

  final CanvasResourceId id;
  final String appKey;
  final int resourceRevision;
  final CanvasMetadata metadata;
}

final class _IdAdmission {
  _IdAdmission({required this.prefix});

  final String prefix;
  final Set<String> _generated = {};
  int _next = 0;

  String nextValue(Set<String> committedIds) {
    while (true) {
      final candidate = '$prefix$_next';
      _next += 1;
      if (committedIds.contains(candidate) || _generated.contains(candidate)) {
        continue;
      }
      _generated.add(candidate);

      return candidate;
    }
  }
}
