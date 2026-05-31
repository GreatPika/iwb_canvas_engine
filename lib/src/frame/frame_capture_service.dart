import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import '../geometry/spatial_query_policy.dart';
import '../geometry/spatial_query_result.dart';
import 'captured_frame.dart';

typedef SpatialPaintQuery = SpatialQueryResult Function(SpatialQueryWindow);

// The capture boundary intentionally touches every frame input seam once so
// painters receive immutable data instead of live runtime/store reads.
// ignore: coupling-between-object-classes
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
    final selection = _selectionFacts.selectionFacts;
    final spatialResult = _queryPaint(
      _spatialWindow(inputs, structuralRevision),
    );
    final capturedHandles = _capturedHandles(
      spatialCandidates: spatialResult.candidates,
      selectedIds: selection.selectedElementIds,
      structuralRevision: structuralRevision,
    );
    final resolved = _resolvedElementsAndDescriptors(capturedHandles);

    return CapturedFrameSnapshot(
      revisions: revisions,
      capturedHandles: capturedHandles,
      elements: resolved.elements,
      resourceDescriptors: resolved.descriptors,
      selection: selection,
      inputs: inputs,
      spatialPaintResult: spatialResult,
      spatialPaintCandidates: spatialResult.candidates,
    );
  }

  List<FrameElementHandle> _capturedHandles({
    required Iterable<FrameElementHandle> spatialCandidates,
    required Iterable<CanvasElementId> selectedIds,
    required int structuralRevision,
  }) {
    final handles = <FrameElementHandle>[];
    final seen = <CanvasElementId>{};
    for (final handle in spatialCandidates) {
      if (seen.add(handle.id)) {
        handles.add(handle);
      }
    }
    for (final id in selectedIds) {
      if (seen.contains(id)) {
        continue;
      }
      final handle = _frameFacts.elementHandleForId(structuralRevision, id);
      if (handle != null && seen.add(id)) {
        handles.add(handle);
      }
    }

    return handles;
  }

  _ResolvedFrameRows _resolvedElementsAndDescriptors(
    Iterable<FrameElementHandle> handles,
  ) {
    final elements = <FrameElementFacts>[];
    final descriptors = <FrameResourceDescriptorFacts>[];
    final seenResources = <Object>{};

    for (final handle in handles) {
      final element = _frameFacts.resolveElement(handle);
      if (element == null) {
        continue;
      }
      elements.add(element);
      _addResourceDescriptor(
        element: element,
        seenResources: seenResources,
        descriptors: descriptors,
      );
    }

    return _ResolvedFrameRows(elements: elements, descriptors: descriptors);
  }

  void _addResourceDescriptor({
    required FrameElementFacts element,
    required Set<Object> seenResources,
    required List<FrameResourceDescriptorFacts> descriptors,
  }) {
    final resourceId = element.resourceId;
    if (resourceId == null || !seenResources.add(resourceId)) {
      return;
    }
    final descriptor = _frameFacts.resourceDescriptor(resourceId);
    if (descriptor != null) {
      descriptors.add(descriptor);
    }
  }

  SpatialQueryWindow _spatialWindow(
    FrameCaptureInputs inputs,
    int structuralRevision,
  ) {
    return SpatialQueryWindow(
      boundsWorld: inputs.viewportWorldBounds,
      structuralRevision: structuralRevision,
    );
  }
}

final class _ResolvedFrameRows {
  _ResolvedFrameRows({
    required Iterable<FrameElementFacts> elements,
    required Iterable<FrameResourceDescriptorFacts> descriptors,
  }) : elements = List.unmodifiable(elements),
       descriptors = List.unmodifiable(descriptors);

  final List<FrameElementFacts> elements;
  final List<FrameResourceDescriptorFacts> descriptors;
}
