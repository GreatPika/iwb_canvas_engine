import 'dart:async';
import 'dart:ui';

import 'package:meta/meta.dart' show visibleForTesting;

import '../contracts/internal/command_facts_port.dart';
import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_actions.dart';
import '../geometry/geometry_policy.dart';

@visibleForTesting
enum SelectionTransformOrderingWorkEvent {
  canonicalOrderComparison,
  sortStarted,
}

final _orderingWorkZoneKey = Object();

/// Assert-only observation distinguishes a canonical-order check from a sort
/// without retaining command state or adding release counters.
@visibleForTesting
T observeSelectionTransformOrderingWork<T>(
  void Function(SelectionTransformOrderingWorkEvent event) sink,
  T Function() operation,
) => runZoned(operation, zoneValues: {_orderingWorkZoneKey: sink});

bool _recordSelectionTransformOrderingWork(
  SelectionTransformOrderingWorkEvent event,
) {
  final sink = Zone.current[_orderingWorkZoneKey];
  if (sink is void Function(SelectionTransformOrderingWorkEvent)) {
    sink(event);
  }

  return true;
}

// Keeping the snapshot reads in one function ensures IDs, movable facts, and
// bounds are derived from the same frame revision.
// ignore: halstead-volume
SelectionTransformFacts readSelectionTransformFacts({
  required FrameFactsPort frame,
  required SelectionFactsPort selection,
  required GeometryPolicy geometryPolicy,
}) {
  final structuralRevision = frame.frameRevisions.structuralRevision;
  final selectedIdsUnordered = selection.selectionFacts.selectedElementIds;
  final selectedHandles = <FrameElementHandle>[];
  for (final id in selectedIdsUnordered) {
    final handle = frame.elementHandleForId(structuralRevision, id);
    if (handle != null) {
      selectedHandles.add(handle);
    }
  }

  if (!_areInDocumentOrder(selectedHandles)) {
    assert(
      _recordSelectionTransformOrderingWork(
        SelectionTransformOrderingWorkEvent.sortStarted,
      ),
      'selection transform ordering observation failed',
    );
    selectedHandles.sort((a, b) => a.orderToken.compareTo(b.orderToken));
  }
  final selectedIds = selectedHandles.map((handle) => handle.id).toList();
  final movable = <CanvasElementRead>[];
  for (final handle in selectedHandles) {
    if (frame.resolveElement(handle) case final facts?) {
      if (_isMovable(facts)) {
        movable.add(_elementRead(facts, geometryPolicy));
      }
    }
  }

  return SelectionTransformFacts(
    selectedIds: selectedIds,
    movableElements: movable,
    selectionBoundsWorld: _unionBounds(movable),
  );
}

bool _areInDocumentOrder(List<FrameElementHandle> handles) {
  for (var index = 1; index < handles.length; index += 1) {
    assert(
      _recordSelectionTransformOrderingWork(
        SelectionTransformOrderingWorkEvent.canonicalOrderComparison,
      ),
      'selection transform ordering observation failed',
    );
    if (handles[index - 1].orderToken > handles[index].orderToken) {
      return false;
    }
  }

  return true;
}

bool _isMovable(FrameElementFacts facts) {
  return facts.locationKind == FrameElementLocationKind.content &&
      !facts.isLocked &&
      facts.isTransformable;
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
