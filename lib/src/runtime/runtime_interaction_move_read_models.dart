import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/geometry_policy.dart';

typedef RuntimeDocumentSummaryReader = CanvasDocumentSummary Function();

final class RuntimeSelectedMoveReadModels {
  RuntimeSelectedMoveReadModels({
    required Iterable<CanvasElementRead> movedElements,
    required this.documentSummary,
  }) : movedElements = List.unmodifiable(movedElements),
       selectionBoundsWorld = _unionBounds(List.unmodifiable(movedElements));

  final List<CanvasElementRead> movedElements;
  final CanvasDocumentSummary documentSummary;
  final Rect selectionBoundsWorld;
}

final class RuntimeSelectedMoveReadModelInputs {
  const RuntimeSelectedMoveReadModelInputs({
    required this.frame,
    required this.documentSummary,
    required this.handles,
    required this.movableIds,
    this.geometryPolicy = const GeometryPolicy(),
  });

  final FrameFactsPort frame;
  final RuntimeDocumentSummaryReader documentSummary;
  final GeometryPolicy geometryPolicy;
  final Iterable<FrameElementHandle> handles;
  final Iterable<CanvasElementId> movableIds;
}

RuntimeSelectedMoveReadModels selectedMoveReadModels(
  RuntimeSelectedMoveReadModelInputs inputs,
) {
  final requestedIds = inputs.movableIds.toSet();

  return RuntimeSelectedMoveReadModels(
    movedElements: [
      for (final handle in inputs.handles)
        if (requestedIds.contains(handle.id))
          if (inputs.frame.resolveElement(handle) case final facts?)
            _elementRead(facts, inputs.geometryPolicy),
    ],
    documentSummary: inputs.documentSummary(),
  );
}

CanvasElementRead _elementRead(
  FrameElementFacts facts,
  GeometryPolicy geometryPolicy,
) {
  return CanvasElementRead(
    id: facts.id,
    kind: facts.kind,
    revision: facts.revision,
    boundsWorld: geometryPolicy.boundsFor(facts).paintBoundsWorld,
    transform: facts.transform,
    isLocked: facts.isLocked,
    isTransformable: facts.isTransformable,
  );
}

Rect _unionBounds(List<CanvasElementRead> elements) {
  if (elements.isEmpty) {
    return Rect.zero;
  }
  var bounds = elements.first.boundsWorld;
  for (final element in elements.skip(1)) {
    bounds = bounds.expandToInclude(element.boundsWorld);
  }

  return bounds;
}
