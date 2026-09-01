import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import '../geometry/spatial_query_policy.dart';
import '../geometry/spatial_query_result.dart';
import 'captured_frame.dart';
import 'frame_spatial_paint_admission.dart';

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
    return CapturedOverlayFrame(
      viewportWorldBounds: inputs.viewportWorldBounds,
      effectiveWorldBounds: inputs.effectiveWorldBounds,
      previewRevision: inputs.previewRevision,
      viewCameraRevision: inputs.viewCameraRevision,
      viewCameraOffset: inputs.viewCameraOffset,
      overlayPreview: switch (inputs.preview) {
        CanvasNoPreview() || CanvasSelectedMovePreview() => null,
        final preview => preview,
      },
      selectionStyle: inputs.selectionStyle,
    );
  }

  CapturedFrameSnapshot _captureSnapshot(FrameCaptureInputs inputs) {
    final revisions = _frameFacts.frameRevisions;
    final structuralRevision = revisions.structuralRevision;
    final selection = _selectionFacts.selectionFacts;
    final spatialResult = _queryPaint(
      _spatialWindow(inputs, structuralRevision),
    );
    final spatialAdmission = admitFrameSpatialPaint(spatialResult);
    final spatialCandidates = switch (spatialAdmission) {
      FrameSpatialPaintAdmitted(:final candidates) => candidates,
      FrameSpatialPaintRejected() => const <FrameElementHandle>[],
    };
    final capturedHandles = _capturedHandles(
      spatialCandidates: spatialCandidates,
      selectedIds: selection.selectedElementIds,
      selectedMoveParticipantIds: inputs.selectedMoveParticipantIds,
      structuralRevision: structuralRevision,
    );
    final resolved = _resolvedElementsAndDescriptors(capturedHandles);

    return CapturedFrameSnapshot(
      revisions: revisions,
      capturedHandles: capturedHandles,
      elements: resolved.elements,
      resourceDescriptors: resolved.descriptors,
      background: _frameFacts.background,
      selection: selection,
      inputs: inputs,
      spatialPaintResult: spatialResult,
      spatialPaintCandidates: spatialCandidates,
    );
  }

  List<FrameElementHandle> _capturedHandles({
    required Iterable<FrameElementHandle> spatialCandidates,
    required Iterable<CanvasElementId> selectedIds,
    required Iterable<CanvasElementId> selectedMoveParticipantIds,
    required int structuralRevision,
  }) {
    final handles = <FrameElementHandle>[];
    final seen = <CanvasElementId>{};
    _appendUniqueHandles(handles, seen, spatialCandidates);
    _appendHandlesForIds(
      handles: handles,
      seen: seen,
      ids: selectedIds,
      structuralRevision: structuralRevision,
    );
    _appendHandlesForIds(
      handles: handles,
      seen: seen,
      ids: selectedMoveParticipantIds,
      structuralRevision: structuralRevision,
    );

    return handles;
  }

  void _appendUniqueHandles(
    List<FrameElementHandle> handles,
    Set<CanvasElementId> seen,
    Iterable<FrameElementHandle> candidates,
  ) {
    for (final handle in candidates) {
      if (seen.add(handle.id)) {
        handles.add(handle);
      }
    }
  }

  void _appendHandlesForIds({
    required List<FrameElementHandle> handles,
    required Set<CanvasElementId> seen,
    required Iterable<CanvasElementId> ids,
    required int structuralRevision,
  }) {
    for (final id in ids) {
      if (seen.contains(id)) {
        continue;
      }
      final handle = _frameFacts.elementHandleForId(structuralRevision, id);
      if (handle != null && seen.add(id)) {
        handles.add(handle);
      }
    }
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
      boundsWorld: inputs.effectiveWorldBounds,
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
