import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_preview.dart';
import '../geometry/spatial_query_policy.dart';
import '../geometry/spatial_query_result.dart';
import 'captured_frame.dart';

typedef SpatialPaintQuery = SpatialQueryResult Function(SpatialQueryWindow);

final class FrameCaptureService {
  const FrameCaptureService({
    required FrameFactsPort frameFacts,
    required SelectionFactsPort selectionFacts,
    required SpatialPaintQuery queryPaint,
  }) : _frameFacts = frameFacts,
       _selectionFacts = selectionFacts,
       _queryPaint = queryPaint;

  final FrameFactsPort _frameFacts;
  final SelectionFactsPort _selectionFacts;
  final SpatialPaintQuery _queryPaint;

  CapturedMainFrame captureMainFrame(FrameCaptureInputs inputs) {
    final snapshot = _captureSnapshot(inputs);

    return CapturedMainFrame(
      snapshot: snapshot,
      selectedMovePreview: switch (inputs.preview) {
        final CanvasSelectedMovePreview preview => preview,
        _ => null,
      },
    );
  }

  CapturedOverlayFrame captureOverlayFrame(FrameCaptureInputs inputs) {
    final snapshot = _captureSnapshot(inputs);

    return CapturedOverlayFrame(
      snapshot: snapshot,
      overlayPreview: switch (inputs.preview) {
        CanvasNoPreview() || CanvasSelectedMovePreview() => null,
        final preview => preview,
      },
    );
  }

  CapturedFrameSnapshot _captureSnapshot(FrameCaptureInputs inputs) {
    final revisions = _frameFacts.frameRevisions;
    final structuralRevision = revisions.structuralRevision;
    final orderedHandles = _frameFacts.elementHandles(structuralRevision);
    final elements = <FrameElementFacts>[];
    final descriptors = <FrameResourceDescriptorFacts>[];
    final seenResources = <Object>{};

    for (final handle in orderedHandles) {
      final element = _frameFacts.resolveElement(handle);
      if (element == null) {
        continue;
      }
      elements.add(element);
      final resourceId = element.resourceId;
      if (resourceId == null || !seenResources.add(resourceId)) {
        continue;
      }
      final descriptor = _frameFacts.resourceDescriptor(resourceId);
      if (descriptor != null) {
        descriptors.add(descriptor);
      }
    }

    final selection = _selectionFacts.selectionFacts;
    final spatialResult = _queryPaint(
      SpatialQueryWindow(
        boundsWorld: inputs.viewportWorldBounds,
        structuralRevision: structuralRevision,
      ),
    );

    return CapturedFrameSnapshot(
      revisions: revisions,
      orderedHandles: orderedHandles,
      elements: elements,
      resourceDescriptors: descriptors,
      selection: selection,
      inputs: inputs,
      spatialPaintResult: spatialResult,
      spatialPaintCandidates: spatialResult.candidates,
    );
  }
}
