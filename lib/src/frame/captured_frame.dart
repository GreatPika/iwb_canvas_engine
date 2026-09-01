import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/internal/text_edit_paint_suppression.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_surface_styles.dart';
import '../geometry/spatial_query_result.dart';

final class FrameCaptureInputs {
  const FrameCaptureInputs({
    required this.viewportWorldBounds,
    required this.devicePixelRatio,
    required this.selectionStyle,
    required this.gridStyle,
    required this.preview,
    required this.previewRevision,
    this.viewCameraOffset = Offset.zero,
    this.viewCameraRevision = 0,
    this.textEditSuppression,
    this.selectedMoveParticipantIds = const [],
  });

  final Rect viewportWorldBounds;
  final Offset viewCameraOffset;
  final int viewCameraRevision;
  final double devicePixelRatio;
  final CanvasSelectionStyle selectionStyle;
  final CanvasGridStyle gridStyle;
  final CanvasPreviewState preview;
  final int previewRevision;
  final TextEditPaintSuppression? textEditSuppression;
  final Iterable<CanvasElementId> selectedMoveParticipantIds;

  Rect get effectiveWorldBounds => viewportWorldBounds.shift(viewCameraOffset);
}

final class CapturedFrameSnapshot {
  CapturedFrameSnapshot({
    required this.revisions,
    required Iterable<FrameElementHandle> capturedHandles,
    required Iterable<FrameElementFacts> elements,
    required Iterable<FrameResourceDescriptorFacts> resourceDescriptors,
    required this.background,
    required this.selection,
    required this.inputs,
    required this.spatialPaintResult,
    required Iterable<FrameElementHandle> spatialPaintCandidates,
  }) : capturedHandles = List.unmodifiable(capturedHandles),
       elements = List.unmodifiable(elements),
       resourceDescriptors = List.unmodifiable(resourceDescriptors),
       spatialPaintCandidates = List.unmodifiable(spatialPaintCandidates),
       _elementFactsById = Map.unmodifiable({
         for (final element in elements) element.id: element,
       });

  final FrameRevisionFacts revisions;
  final List<FrameElementHandle> capturedHandles;
  final List<FrameElementFacts> elements;
  final List<FrameResourceDescriptorFacts> resourceDescriptors;
  final CanvasBackground background;
  final SelectionFacts selection;
  final FrameCaptureInputs inputs;
  final SpatialQueryResult spatialPaintResult;
  final List<FrameElementHandle> spatialPaintCandidates;
  final Map<dynamic, FrameElementFacts> _elementFactsById;

  CanvasPreviewState get preview => inputs.preview;
  int get previewRevision => inputs.previewRevision;

  FrameElementFacts? elementFactsFor(FrameElementHandle handle) {
    final facts = _elementFactsById[handle.id];
    if (facts == null ||
        facts.generation != handle.generation ||
        facts.orderToken != handle.orderToken) {
      return null;
    }

    return facts;
  }
}

final class CapturedMainFrame {
  const CapturedMainFrame({
    required this.snapshot,
    required this.selectedMovePreview,
  });

  final CapturedFrameSnapshot snapshot;
  final CanvasSelectedMovePreview? selectedMovePreview;
}

final class CapturedOverlayFrame {
  const CapturedOverlayFrame({
    required this.viewportWorldBounds,
    required this.effectiveWorldBounds,
    required this.previewRevision,
    required this.viewCameraRevision,
    required this.viewCameraOffset,
    required this.overlayPreview,
    required this.selectionStyle,
  });

  final Rect viewportWorldBounds;
  final Rect effectiveWorldBounds;
  final int previewRevision;
  final int viewCameraRevision;
  final Offset viewCameraOffset;
  final CanvasPreviewState? overlayPreview;
  final CanvasSelectionStyle selectionStyle;
}
