import 'dart:ui';

import '../contracts/internal/command_facts_port.dart';
import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/resource_catalog_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/geometry_policy.dart';

typedef CommandDocumentSummaryReader = CanvasDocumentSummary Function();

// This adapter is the runtime-owned command read boundary: it intentionally
// gathers frame, selection, resource, document-summary, and geometry facts in
// one auditable place instead of scattering command eligibility reads.
// ignore: coupling-between-object-classes
final class RuntimeCommandFactsAdapter implements CommandFactsPort {
  const RuntimeCommandFactsAdapter({
    required FrameFactsPort frame,
    required SelectionFactsPort selection,
    required ResourceCatalogPort resources,
    required CommandDocumentSummaryReader documentSummary,
    GeometryPolicy geometryPolicy = const GeometryPolicy(),
  }) : _frame = frame,
       _selection = selection,
       _resources = resources,
       _documentSummary = documentSummary,
       _geometryPolicy = geometryPolicy;

  final FrameFactsPort _frame;
  final SelectionFactsPort _selection;
  final ResourceCatalogPort _resources;
  final CommandDocumentSummaryReader _documentSummary;
  final GeometryPolicy _geometryPolicy;

  @override
  SelectionTransformFacts selectionTransformFacts() {
    final context = _context();
    final selectedIds = _documentOrderIds(
      handles: context.handles,
      ids: context.selection.selectedElementIds,
    );
    final selectedSet = selectedIds.toSet();
    final movable = [
      for (final handle in context.handles)
        if (selectedSet.contains(handle.id))
          if (_frame.resolveElement(handle) case final facts?)
            if (_isMovable(facts)) _elementRead(facts),
    ];

    return SelectionTransformFacts(
      selectedIds: selectedIds,
      movableElements: movable,
      selectionBoundsWorld: _unionBounds(movable),
    );
  }

  @override
  SelectionDeleteFacts selectionDeleteFacts() {
    final context = _context();
    final selected = context.selection.selectedElementIds;

    return SelectionDeleteFacts(
      deletableIds: [
        for (final handle in context.handles)
          if (selected.contains(handle.id))
            if (_frame.resolveElement(handle) case final facts?)
              if (_isDeletable(facts)) handle.id,
      ],
    );
  }

  @override
  RemoveElementFacts removeElementFacts(CanvasElementId id) {
    final structuralRevision = _frame.frameRevisions.structuralRevision;
    final handle = _frame.elementHandleForId(structuralRevision, id);
    if (handle == null) {
      return const RemoveElementFacts(canRemove: false);
    }
    final facts = _frame.resolveElement(handle);

    return RemoveElementFacts(canRemove: facts != null);
  }

  @override
  ClearContentFacts clearContentFacts({required bool removeUnusedResources}) {
    final structuralRevision = _frame.frameRevisions.structuralRevision;
    final handles = _frame.elementHandles(structuralRevision);
    final contentIds = <CanvasElementId>[];
    final backgroundResourceIds = <CanvasResourceId>{};
    for (final handle in handles) {
      final facts = _frame.resolveElement(handle);
      if (facts == null) {
        continue;
      }
      if (facts.locationKind == FrameElementLocationKind.content) {
        contentIds.add(handle.id);
        continue;
      }
      final resourceId = facts.resourceId;
      if (resourceId != null) {
        backgroundResourceIds.add(resourceId);
      }
    }

    return ClearContentFacts(
      summary: _documentSummary(),
      removableElementIds: contentIds,
      removableResourceIds: removeUnusedResources
          ? [
              for (final resource in _resources.resources)
                if (!backgroundResourceIds.contains(resource.id)) resource.id,
            ]
          : const [],
    );
  }

  _CommandReadContext _context() {
    final structuralRevision = _frame.frameRevisions.structuralRevision;

    return _CommandReadContext(
      handles: _frame.elementHandles(structuralRevision),
      selection: _selection.selectionFacts,
    );
  }

  bool _isMovable(FrameElementFacts facts) {
    return facts.locationKind == FrameElementLocationKind.content &&
        !facts.isLocked &&
        facts.isTransformable;
  }

  bool _isDeletable(FrameElementFacts facts) {
    return facts.locationKind == FrameElementLocationKind.content &&
        facts.isDeletable;
  }

  CanvasElementRead _elementRead(FrameElementFacts facts) {
    return CanvasElementRead(
      id: facts.id,
      kind: facts.kind,
      revision: facts.revision,
      boundsWorld: _geometryPolicy.boundsFor(facts).paintBoundsWorld,
      transform: facts.transform,
      isLocked: facts.isLocked,
      isTransformable: facts.isTransformable,
    );
  }
}

final class _CommandReadContext {
  const _CommandReadContext({required this.handles, required this.selection});

  final List<FrameElementHandle> handles;
  final SelectionFacts selection;
}

List<CanvasElementId> _documentOrderIds({
  required Iterable<FrameElementHandle> handles,
  required Iterable<CanvasElementId> ids,
}) {
  final selected = ids.toSet();

  return List.unmodifiable([
    for (final handle in handles)
      if (selected.contains(handle.id)) handle.id,
  ]);
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
