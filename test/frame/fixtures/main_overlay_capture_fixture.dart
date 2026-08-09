// Frame capture fixtures import the full boundary because the test verifies
// every captured donor exactly once rather than isolated helper behavior.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
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
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

void main() {
  _testImmutableFrameCapture();
  _testPreviewRouting();
}

// Keeping the complete capture transaction in one test makes the no-live-read
// snapshot invariant visible across facts, descriptors, selection, and spatial
// candidates.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void _testImmutableFrameCapture() {
  test('main and overlay capture immutable frame facts once per request', () {
    final resourceId = CanvasResourceId('image-a');
    final handleA = _handle('a', orderToken: 1);
    final handleB = _handle('b', orderToken: 2);
    final handleC = _handle('offscreen', orderToken: 3);
    final frameFacts = _FakeFrameFactsPort(
      revisions: _revisions(document: 1, structural: 2),
      handles: [handleA, handleB, handleC],
      elements: {
        handleA.id: _rectFacts(handleA),
        handleB.id: _imageFacts(handleB, resourceId),
        handleC.id: _rectFacts(handleC),
      },
      descriptors: {
        resourceId: FrameImageResourceDescriptorFacts(
          id: resourceId,
          appKey: 'asset://image-a',
          mimeType: 'image/png',
          contentHash: 'hash-a',
          byteLength: 42,
          resourceRevision: 7,
          metadata: const CanvasMetadata.empty(),
        ),
      },
      committedBackground: const CanvasBackground(color: Color(0xFF224466)),
    );
    final selectionFacts = _FakeSelectionFactsPort(
      SelectionFacts(selectedElementIds: [handleA.id], selectionRevision: 3),
    );
    final spatialQueries = <SpatialQueryWindow>[];
    final capture = FrameCaptureService(
      frameFacts: frameFacts,
      selectionFacts: selectionFacts,
      queryPaint: (window) {
        spatialQueries.add(window);

        return SpatialCandidatesResult(orderedCandidates: [handleB]);
      },
    );
    final inputs = _inputs(
      preview: const CanvasMarqueePreview(rect: Rect.fromLTWH(4, 5, 6, 7)),
      previewRevision: 9,
      viewCameraOffset: const Offset(10, 20),
      viewCameraRevision: 12,
    );

    final main = capture.captureMainFrame(inputs);
    final overlay = capture.captureOverlayFrame(inputs);

    frameFacts.replaceFrameData(
      revisions: _revisions(document: 100, structural: 200),
      handles: [_handle('later', orderToken: 99)],
      elements: {},
    );
    selectionFacts.facts = SelectionFacts(
      selectedElementIds: [CanvasElementId('later')],
      selectionRevision: 99,
    );

    expect(main.snapshot.revisions.documentRevision, 1);
    expect(main.snapshot.revisions.structuralRevision, 2);
    expect(main.snapshot.capturedHandles.map((handle) => handle.id), [
      CanvasElementId('b'),
      CanvasElementId('a'),
    ]);
    expect(main.snapshot.elements.map((element) => element.id), [
      CanvasElementId('b'),
      CanvasElementId('a'),
    ]);
    expect(main.snapshot.resourceDescriptors.single.id, resourceId);
    expect(main.snapshot.selection.selectedElementIds, {CanvasElementId('a')});
    expect(main.snapshot.selection.selectionRevision, 3);
    expect(main.snapshot.background.color, const Color(0xFF224466));
    expect(
      main.snapshot.inputs.viewportWorldBounds,
      const Rect.fromLTWH(1, 2, 3, 4),
    );
    expect(main.snapshot.inputs.devicePixelRatio, 2);
    expect(main.snapshot.inputs.selectionStyle.color, const Color(0xFF123456));
    expect(main.snapshot.inputs.gridStyle.strokeWidth, 2.5);
    expect(main.snapshot.inputs.viewCameraOffset, const Offset(10, 20));
    expect(main.snapshot.inputs.viewCameraRevision, 12);
    expect(main.snapshot.preview, same(inputs.preview));
    expect(main.snapshot.previewRevision, 9);
    expect(main.snapshot.spatialPaintCandidates.map((handle) => handle.id), [
      CanvasElementId('b'),
    ]);
    expect(overlay.viewportWorldBounds, const Rect.fromLTWH(1, 2, 3, 4));
    expect(overlay.effectiveWorldBounds, const Rect.fromLTWH(11, 22, 3, 4));
    expect(overlay.previewRevision, 9);
    expect(overlay.viewCameraRevision, 12);
    expect(overlay.viewCameraOffset, const Offset(10, 20));
    expect(overlay.overlayPreview, same(inputs.preview));
    expect(overlay.selectionStyle.color, const Color(0xFF123456));

    expect(frameFacts.frameRevisionReads, 1);
    expect(frameFacts.backgroundReads, 1);
    expect(frameFacts.elementHandlesReads, 0);
    expect(frameFacts.elementHandleForIdReads, 1);
    expect(frameFacts.resolveElementReads, 2);
    expect(frameFacts.resolvedIds, [
      CanvasElementId('b'),
      CanvasElementId('a'),
    ]);
    expect(frameFacts.resourceDescriptorReads, 1);
    expect(selectionFacts.reads, 1);
    expect(spatialQueries, hasLength(1));
    expect(spatialQueries.single.structuralRevision, 2);
    expect(
      spatialQueries.single.boundsWorld,
      const Rect.fromLTWH(11, 22, 3, 4),
    );
  });
}

// Preview routing is a compact matrix over the public preview union; keeping it
// together prevents missing a variant in one frame path.
// ignore: halstead-volume, source-lines-of-code
void _testPreviewRouting() {
  test('preview variants are admitted to only their frame capture paths', () {
    final service = _emptyCaptureService();

    final selectedMove = const CanvasSelectedMovePreview(delta: Offset(3, 4));
    final selectedMain = service.captureMainFrame(
      _inputs(preview: selectedMove),
    );
    final selectedOverlay = service.captureOverlayFrame(
      _inputs(preview: selectedMove),
    );
    expect(selectedMain.selectedMovePreview, same(selectedMove));
    expect(selectedOverlay.overlayPreview, isNull);

    final overlayPreviews = <CanvasPreviewState>[
      const CanvasMarqueePreview(rect: Rect.fromLTWH(0, 0, 5, 6)),
      CanvasPencilStrokePreview(
        points: const [Offset(1, 1), Offset(2, 2)],
        color: const Color(0xFF00AA00),
        thickness: 1,
        opacity: 0.7,
      ),
      CanvasMarkerStrokePreview(
        points: const [Offset(1, 1), Offset(2, 2)],
        color: const Color(0xFFAA0000),
        thickness: 2,
        opacity: 0.5,
      ),
      const CanvasPendingLineStartPreview(
        start: Offset(7, 8),
        timestampMs: 10,
        color: Color(0xFF0000AA),
        thickness: 3,
      ),
      const CanvasLinePreview(
        start: Offset(1, 2),
        end: Offset(3, 4),
        color: Color(0xFF111111),
        thickness: 4,
      ),
      CanvasEraserPreview(corridor: const [Offset(9, 9)], thickness: 5),
    ];

    for (final preview in overlayPreviews) {
      final main = service.captureMainFrame(_inputs(preview: preview));
      final overlay = service.captureOverlayFrame(_inputs(preview: preview));

      expect(main.selectedMovePreview, isNull);
      expect(overlay.overlayPreview, same(preview));
    }

    final none = service.captureOverlayFrame(
      _inputs(preview: const CanvasNoPreview()),
    );
    expect(none.overlayPreview, isNull);
  });
}

FrameCaptureService _emptyCaptureService() {
  return FrameCaptureService(
    frameFacts: _FakeFrameFactsPort(
      revisions: _revisions(document: 1, structural: 1),
      handles: const [],
      elements: const {},
      descriptors: const {},
    ),
    selectionFacts: _FakeSelectionFactsPort(
      SelectionFacts(selectedElementIds: const {}, selectionRevision: 0),
    ),
    queryPaint: (_) => const SpatialCandidatesResult(orderedCandidates: []),
  );
}

FrameCaptureInputs _inputs({
  CanvasPreviewState preview = const CanvasNoPreview(),
  int previewRevision = 0,
  Offset viewCameraOffset = Offset.zero,
  int viewCameraRevision = 0,
}) {
  return FrameCaptureInputs(
    viewportWorldBounds: const Rect.fromLTWH(1, 2, 3, 4),
    devicePixelRatio: 2,
    selectionStyle: CanvasSelectionStyle(
      color: const Color(0xFF123456),
      strokeWidth: 1.5,
    ),
    gridStyle: CanvasGridStyle(strokeWidth: 2.5),
    preview: preview,
    previewRevision: previewRevision,
    viewCameraOffset: viewCameraOffset,
    viewCameraRevision: viewCameraRevision,
  );
}

FrameRevisionFacts _revisions({
  required int document,
  required int structural,
}) {
  return FrameRevisionFacts(
    documentRevision: document,
    structuralRevision: structural,
    boundsRevision: document + 1,
    elementVisualRevision: document + 2,
    backgroundRevision: document + 3,
    gridRevision: document + 4,
    resourceRevision: document + 5,
  );
}

FrameElementHandle _handle(String id, {required int orderToken}) {
  return FrameElementHandle(
    id: CanvasElementId(id),
    structuralRevision: 2,
    generation: orderToken * 10,
    orderToken: orderToken,
  );
}

FrameElementFacts _rectFacts(FrameElementHandle handle) {
  return _elementFacts(
    handle,
    kind: CanvasElementKind.rect,
    size: const Size(10, 20),
    fillColor: const Color(0xFFABCDEF),
  );
}

FrameElementFacts _imageFacts(
  FrameElementHandle handle,
  CanvasResourceId resourceId,
) {
  return _elementFacts(
    handle,
    kind: CanvasElementKind.image,
    size: const Size(30, 40),
    resourceId: resourceId,
  );
}

// The element fixture mirrors the frame facts boundary shape so rect and image
// rows share the same required identity fields.
// ignore: number-of-parameters
FrameElementFacts _elementFacts(
  FrameElementHandle handle, {
  required CanvasElementKind kind,
  Size? size,
  Color? fillColor,
  CanvasResourceId? resourceId,
}) {
  return FrameElementFacts(
    id: handle.id,
    kind: kind,
    revision: handle.orderToken,
    generation: handle.generation,
    orderToken: handle.orderToken,
    locationKind: FrameElementLocationKind.content,
    transform: CanvasTransform.identity,
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
    fillColor: fillColor,
  );
}

final class _FakeFrameFactsPort implements FrameFactsPort {
  _FakeFrameFactsPort({
    required FrameRevisionFacts revisions,
    required List<FrameElementHandle> handles,
    required Map<CanvasElementId, FrameElementFacts> elements,
    required Map<CanvasResourceId, FrameResourceDescriptorFacts> descriptors,
    CanvasBackground committedBackground = const CanvasBackground(),
  }) : _revisions = revisions,
       _handles = List.of(handles),
       _elements = Map.of(elements),
       _descriptors = Map.of(descriptors),
       _background = committedBackground;

  FrameRevisionFacts _revisions;
  List<FrameElementHandle> _handles;
  Map<CanvasElementId, FrameElementFacts> _elements;
  final Map<CanvasResourceId, FrameResourceDescriptorFacts> _descriptors;
  final CanvasBackground _background;
  int frameRevisionReads = 0;
  int backgroundReads = 0;
  int elementHandlesReads = 0;
  int elementHandleForIdReads = 0;
  int resolveElementReads = 0;
  int resourceDescriptorReads = 0;
  final List<CanvasElementId> resolvedIds = [];

  void replaceFrameData({
    required FrameRevisionFacts revisions,
    required List<FrameElementHandle> handles,
    required Map<CanvasElementId, FrameElementFacts> elements,
  }) {
    _revisions = revisions;
    _handles = List.of(handles);
    _elements = Map.of(elements);
  }

  @override
  FrameRevisionFacts get frameRevisions {
    frameRevisionReads += 1;

    return _revisions;
  }

  @override
  CanvasBackground get background {
    backgroundReads += 1;

    return _background;
  }

  @override
  int elementCount(int structuralRevision) => _handles.length;

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    elementHandlesReads += 1;

    return List.of(_handles);
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    elementHandleForIdReads += 1;

    return _handles.where((handle) => handle.id == id).firstOrNull;
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    resolveElementReads += 1;
    resolvedIds.add(handle.id);

    return _elements[handle.id];
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    resourceDescriptorReads += 1;

    return _descriptors[id];
  }
}

final class _FakeSelectionFactsPort implements SelectionFactsPort {
  _FakeSelectionFactsPort(this.facts);

  SelectionFacts facts;
  int reads = 0;

  @override
  SelectionFacts get selectionFacts {
    reads += 1;

    return facts;
  }
}
