// Shared frame fixtures import the same seams as the planners under test so
// individual tests do not duplicate boundary setup with weaker defaults.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/measured_text_layout.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_document.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_element.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_metadata.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_capture_service.dart';
import 'package:iwb_canvas_engine/src/frame/frame_text_layout_measurer.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

// This helper exposes the frame-capture inputs directly so each test can vary a
// single boundary value without introducing per-test builders.
// ignore: number-of-parameters
CapturedMainFrame capturedMainFrame({
  required TestFrameFactsPort frameFacts,
  SpatialQueryResult? spatialPaintResult,
  CanvasPreviewState preview = const CanvasNoPreview(),
  int previewRevision = 0,
  Rect viewport = const Rect.fromLTWH(0, 0, 100, 100),
  Offset viewCameraOffset = Offset.zero,
  double devicePixelRatio = 1,
  SelectionFacts? selectionFacts,
  CanvasSelectionStyle selectionStyle = CanvasSelectionStyle.defaultStyle,
  CanvasGridStyle gridStyle = CanvasGridStyle.defaultStyle,
  SpatialPaintQuery? queryPaint,
}) {
  final capture = FrameCaptureService(
    frameFacts: frameFacts,
    selectionFacts: TestSelectionFactsPort(
      selectionFacts ??
          SelectionFacts(selectedElementIds: const {}, selectionRevision: 0),
    ),
    queryPaint:
        queryPaint ??
        (_) =>
            spatialPaintResult ??
            SpatialCandidatesResult(
              orderedCandidates: frameFacts.spatialCandidates,
            ),
  );

  return capture.captureMainFrame(
    FrameCaptureInputs(
      viewportWorldBounds: viewport,
      devicePixelRatio: devicePixelRatio,
      selectionStyle: selectionStyle,
      gridStyle: gridStyle,
      preview: preview,
      previewRevision: previewRevision,
      viewCameraOffset: viewCameraOffset,
    ),
  );
}

CapturedOverlayFrame capturedOverlayFrameFor(
  CanvasPreviewState preview, {
  Rect viewport = const Rect.fromLTWH(0, 0, 10, 10),
  Offset viewCameraOffset = Offset.zero,
  CanvasSelectionStyle selectionStyle = CanvasSelectionStyle.defaultStyle,
}) {
  final frameFacts = frameFactsPort(elements: const []);
  final capture = FrameCaptureService(
    frameFacts: frameFacts,
    selectionFacts: TestSelectionFactsPort.empty(),
    queryPaint: (_) => const SpatialCandidatesResult(orderedCandidates: []),
  );

  return capture.captureOverlayFrame(
    FrameCaptureInputs(
      viewportWorldBounds: viewport,
      devicePixelRatio: 1,
      selectionStyle: selectionStyle,
      gridStyle: CanvasGridStyle.defaultStyle,
      preview: preview,
      previewRevision: 1,
      viewCameraOffset: viewCameraOffset,
    ),
  );
}

CanvasSelectionStyle selectionStyleFor({
  required Color color,
  required double strokeWidth,
}) {
  return CanvasSelectionStyle(color: color, strokeWidth: strokeWidth);
}

// The shared frame-facts builder exposes the same knobs as the frame port so
// cache, resource, stale-row, and spatial tests can vary one boundary at a time.
// ignore: number-of-parameters
TestFrameFactsPort frameFactsPort({
  FrameRevisionFacts? revisions,
  CanvasBackground background = const CanvasBackground(),
  List<FrameElementFacts>? elements,
  List<FrameResourceDescriptorFacts> resourceDescriptors = const [],
  List<FrameElementHandle>? spatialCandidates,
  Set<CanvasElementId> staleIds = const {},
}) {
  final rows = elements ?? [rectFacts('a', orderToken: 1)];

  return TestFrameFactsPort(
    revisions: revisions ?? revisionsFor(),
    elements: rows,
    spatialCandidates:
        spatialCandidates ??
        [
          for (final row in rows)
            FrameElementHandle(
              id: row.id,
              structuralRevision:
                  revisions?.structuralRevision ??
                  revisionsFor().structuralRevision,
              generation: row.generation,
              orderToken: row.orderToken,
            ),
        ],
    staleIds: staleIds,
    resourceDescriptors: resourceDescriptors,
    background: background,
  );
}

// Revision fixtures keep every frame revision explicit because cache-key tests
// need to prove which revisions do and do not participate.
// ignore: number-of-parameters
FrameRevisionFacts revisionsFor({
  int document = 1,
  int structural = 2,
  int bounds = 3,
  int visual = 4,
  int background = 5,
  int grid = 6,
  int resource = 7,
}) {
  return FrameRevisionFacts(
    documentRevision: document,
    structuralRevision: structural,
    boundsRevision: bounds,
    elementVisualRevision: visual,
    backgroundRevision: background,
    gridRevision: grid,
    resourceRevision: resource,
  );
}

// Rect facts are the common committed-row fixture and keep visual, ordering,
// transform, and location knobs at the call site for cache-boundary tests.
// ignore: number-of-parameters
FrameElementFacts rectFacts(
  String id, {
  required int orderToken,
  int generation = 1,
  double opacity = 1,
  FrameElementLocationKind locationKind = FrameElementLocationKind.content,
  CanvasTransform transform = CanvasTransform.identity,
  bool isLocked = false,
  bool isTransformable = true,
}) {
  return FrameElementFacts(
    id: CanvasElementId(id),
    kind: CanvasElementKind.rect,
    revision: orderToken,
    generation: generation,
    orderToken: orderToken,
    locationKind: locationKind,
    transform: transform,
    opacity: opacity,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: isLocked,
    isDeletable: true,
    isTransformable: isTransformable,
    metadata: const CanvasMetadata.empty(),
    size: const Size(10, 10),
    fillColor: const Color(0xFF336699),
  );
}

FrameElementFacts translatedRectFacts(
  String id, {
  required int orderToken,
  required Offset translation,
}) {
  return rectFacts(
    id,
    orderToken: orderToken,
    transform: CanvasTransform.translation(translation),
  );
}

FrameElementFacts textFacts(String id, {required int orderToken}) {
  return _baseFacts(
    id,
    kind: CanvasElementKind.text,
    orderToken: orderToken,
    text: 'hello',
    fontSize: 12,
    textColor: const Color(0xFF111111),
    textDirection: TextDirection.ltr,
  );
}

FrameElementFacts pathFacts(
  String id, {
  required int orderToken,
  String svgPathData = 'M0,0 L10,10',
}) {
  return _baseFacts(
    id,
    kind: CanvasElementKind.path,
    orderToken: orderToken,
    svgPathData: svgPathData,
    fillRule: CanvasPathFillRule.nonZero,
    strokeWidth: 1,
  );
}

FrameElementFacts imageFacts(
  String id, {
  required int orderToken,
  required CanvasResourceId resourceId,
  Size size = const Size(10, 10),
}) {
  return _baseFacts(
    id,
    kind: CanvasElementKind.image,
    orderToken: orderToken,
    resourceId: resourceId,
    size: size,
  );
}

FrameElementFacts strokeFacts(
  String id, {
  required int orderToken,
  CanvasTransform transform = CanvasTransform.identity,
}) {
  return _baseFacts(
    id,
    kind: CanvasElementKind.stroke,
    orderToken: orderToken,
    transform: transform,
    points: const [Offset(0, 0), Offset(10, 10)],
    thickness: 2,
    color: const Color(0xFF222222),
  );
}

FrameElementFacts translatedStrokeFacts(
  String id, {
  required int orderToken,
  required Offset translation,
}) {
  return strokeFacts(
    id,
    orderToken: orderToken,
    transform: CanvasTransform.translation(translation),
  );
}

FrameElementFacts lineFacts(String id, {required int orderToken}) {
  return _baseFacts(
    id,
    kind: CanvasElementKind.line,
    orderToken: orderToken,
    start: Offset.zero,
    end: const Offset(10, 0),
    thickness: 2,
    color: const Color(0xFF222222),
  );
}

// The base row fixture mirrors the internal port shape; keeping one complete
// constructor avoids inconsistent test facts across element families.
// ignore: number-of-parameters
FrameElementFacts _baseFacts(
  String id, {
  required CanvasElementKind kind,
  required int orderToken,
  String? text,
  double? fontSize,
  Color? textColor,
  TextDirection? textDirection,
  String? svgPathData,
  CanvasPathFillRule? fillRule,
  double? strokeWidth,
  CanvasTransform transform = CanvasTransform.identity,
  CanvasResourceId? resourceId,
  Size? size,
  List<Offset> points = const [],
  Offset? start,
  Offset? end,
  double? thickness,
  Color? color,
}) {
  return FrameElementFacts(
    id: CanvasElementId(id),
    kind: kind,
    revision: orderToken,
    generation: 1,
    orderToken: orderToken,
    locationKind: FrameElementLocationKind.content,
    transform: transform,
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: false,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    resourceId: resourceId,
    size: size,
    text: text,
    fontSize: fontSize,
    textColor: textColor,
    textDirection: textDirection,
    measuredTextLayout: _measuredTextLayout(
      text: text,
      fontSize: fontSize,
      color: textColor,
      direction: textDirection,
    ),
    svgPathData: svgPathData,
    fillRule: fillRule,
    strokeWidth: strokeWidth,
    points: points,
    start: start,
    end: end,
    thickness: thickness,
    color: color,
  );
}

MeasuredTextLayout? _measuredTextLayout({
  required String? text,
  required double? fontSize,
  required Color? color,
  required TextDirection? direction,
}) {
  if (text == null) {
    return null;
  }
  final result = FrameTextLayoutMeasurer().measureTextLayout(
    MeasuredTextLayoutInput(
      text: text,
      fontSize: fontSize ?? 24,
      color: color ?? const Color(0xFF000000),
      align: TextAlign.left,
      direction: direction ?? TextDirection.ltr,
      isBold: false,
      isItalic: false,
      isUnderline: false,
      fontFamily: null,
      maxWidth: null,
      lineHeight: null,
    ),
  );

  return switch (result) {
    MeasuredTextLayoutReady(:final layout) => layout,
    MeasuredTextLayoutFailed() => null,
  };
}

final class TestFrameFactsPort implements FrameFactsPort {
  TestFrameFactsPort({
    required this.revisions,
    required List<FrameElementFacts> elements,
    required List<FrameElementHandle> spatialCandidates,
    required Set<CanvasElementId> staleIds,
    required List<FrameResourceDescriptorFacts> resourceDescriptors,
    this.background = const CanvasBackground(),
  }) : _elements = {for (final element in elements) element.id: element},
       spatialCandidates = List.unmodifiable(spatialCandidates),
       _staleIds = Set.unmodifiable(staleIds),
       _resourceDescriptors = Map.unmodifiable({
         for (final descriptor in resourceDescriptors)
           descriptor.id: descriptor,
       });

  FrameRevisionFacts revisions;
  @override
  final CanvasBackground background;
  final Map<CanvasElementId, FrameElementFacts> _elements;
  final List<FrameElementHandle> spatialCandidates;
  final Set<CanvasElementId> _staleIds;
  final Map<CanvasResourceId, FrameResourceDescriptorFacts>
  _resourceDescriptors;
  int resolveElementCalls = 0;

  @override
  FrameRevisionFacts get frameRevisions => revisions;

  @override
  int elementCount(int structuralRevision) => _elements.length;

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    return [
      for (final element in _elements.values)
        FrameElementHandle(
          id: element.id,
          structuralRevision: structuralRevision,
          generation: element.generation,
          orderToken: element.orderToken,
        ),
    ];
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    final element = _elements[id];
    if (element == null) {
      return null;
    }

    return FrameElementHandle(
      id: element.id,
      structuralRevision: structuralRevision,
      generation: element.generation,
      orderToken: element.orderToken,
    );
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    resolveElementCalls += 1;
    if (_staleIds.contains(handle.id)) {
      return null;
    }

    return _elements[handle.id];
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    return _resourceDescriptors[id];
  }
}

final class TestSelectionFactsPort implements SelectionFactsPort {
  const TestSelectionFactsPort(this.facts);
  TestSelectionFactsPort.empty()
    : facts = SelectionFacts(
        selectedElementIds: const {},
        selectionRevision: 0,
      );

  final SelectionFacts facts;

  @override
  SelectionFacts get selectionFacts => facts;
}
