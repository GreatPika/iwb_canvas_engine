import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/touched_set.dart';
import 'geometry_policy.dart';
import 'spatial_budget_counters.dart';
import 'spatial_candidate_handle_mapper.dart';
import 'spatial_entry_loader.dart';
import 'spatial_index_set.dart';
import 'spatial_kernel_query_state.dart';
import 'spatial_query_port.dart';
import 'spatial_query_result.dart';

final class SpatialKernel {
  SpatialKernel({this.geometryPolicy = const GeometryPolicy()});

  final GeometryPolicy geometryPolicy;
  final SpatialIndexSet _indexes = SpatialIndexSet();
  final SpatialKernelQueryState _queryState = SpatialKernelQueryState();
  final SpatialCandidateHandleMapper _candidateMapper =
      SpatialCandidateHandleMapper();

  SpatialKernelSnapshot get snapshot {
    final indexes = _indexes.snapshot;

    return SpatialKernelSnapshot(
      structuralRevision: _queryState.structuralRevision,
      isInvalid: _queryState.isInvalid,
      entryCount: indexes.entryCount,
      hitTilePageCount: indexes.hitTilePageCount,
      paintTilePageCount: indexes.paintTilePageCount,
      hitOutlierCount: indexes.hitOutlierCount,
      paintOutlierCount: indexes.paintOutlierCount,
    );
  }

  void rebuild(FrameFactsPort frame) {
    final structuralRevision = frame.frameRevisions.structuralRevision;
    try {
      final entries = spatialEntriesForFrame(
        frame: frame,
        geometryPolicy: geometryPolicy,
      );
      if (entries == null) {
        _queryState.markFailedUpdate();

        return;
      }
      _indexes.replaceWith(entries);
      _candidateMapper.bind(frame, structuralRevision);
      _queryState.markValid(structuralRevision);
    } on Object {
      _queryState.markFailedUpdate();

      return;
    }
  }

  void resetEmpty(int structuralRevision) {
    _indexes.clear();
    _queryState.markValid(structuralRevision);
  }

  void applyTouched(FrameFactsPort frame, TouchedSet touchedSet) {
    final structuralRevision = frame.frameRevisions.structuralRevision;
    _candidateMapper.bind(frame, structuralRevision);
    final isClearContentReset = _isClearContentReset(
      frame,
      touchedSet,
      structuralRevision,
    );
    if (touchedSet.documentReplaced ||
        (!isClearContentReset && _requiresRebuild(touchedSet))) {
      rebuild(frame);

      return;
    }
    if (isClearContentReset) {
      resetEmpty(structuralRevision);

      return;
    }
    if (!touchedSet.hasTouches) {
      return;
    }
    if (_queryState.isInvalid) {
      rebuild(frame);

      return;
    }
    _applyPreparedTouchedDelta(frame, touchedSet, structuralRevision);
  }

  void _applyPreparedTouchedDelta(
    FrameFactsPort frame,
    TouchedSet touchedSet,
    int structuralRevision,
  ) {
    try {
      final additions = spatialAdditionsForTouches(
        frame: frame,
        touchedSet: touchedSet,
        geometryPolicy: geometryPolicy,
      );
      for (final id in touchedSet.elementIds) {
        _indexes.removeEntry(id);
      }
      for (final entry in additions) {
        _indexes.addEntry(entry);
      }
      _queryState.markValid(structuralRevision);
    } on Object {
      _queryState.markFailedUpdate();
    }
  }

  SpatialQueryResult queryHit(SpatialQueryWindow window) {
    return _queryIndex(window, _indexes.queryHit);
  }

  SpatialQueryResult queryPaint(SpatialQueryWindow window) {
    return _queryIndex(window, _indexes.queryPaint);
  }

  SpatialQueryResult _queryIndex(
    SpatialQueryWindow window,
    SpatialIndexQuery query,
  ) {
    return _queryState.runQuery(
      SpatialKernelQueryContext(
        window: window,
        indexedEntryCount: _indexes.snapshot.entryCount,
        candidateMapper: _candidateMapper.call,
        query: query,
      ),
    );
  }
}

extension SpatialKernelInteractionQueries on SpatialKernel {
  SpatialQueryResult queryMarquee(SpatialQueryWindow window) {
    return _queryIndex(window, _indexes.queryHit);
  }

  SpatialQueryResult queryEraser(SpatialQueryWindow window) {
    return _queryIndex(window, _indexes.queryPaint);
  }
}

extension SpatialKernelBudgetCounterAccess on SpatialKernel {
  SpatialBudgetCounters get budgetCounters => _queryState.counters;
}

bool _isClearContentReset(
  FrameFactsPort frame,
  TouchedSet touchedSet,
  int structuralRevision,
) {
  return touchedSet.removedElementIds.isNotEmpty &&
      touchedSet.addedElementIds.isEmpty &&
      touchedSet.updatedElementIds.isEmpty &&
      touchedSet.transformedElementIds.isEmpty &&
      touchedSet.geometryElementIds.isEmpty &&
      touchedSet.visualElementIds.isEmpty &&
      frame.elementCount(structuralRevision) == 0;
}

bool _requiresRebuild(TouchedSet touchedSet) {
  return touchedSet.layerIds.isNotEmpty ||
      touchedSet.backgroundLayerChanged ||
      touchedSet.background;
}

final class SpatialKernelSnapshot {
  const SpatialKernelSnapshot({
    required this.structuralRevision,
    required this.isInvalid,
    required this.entryCount,
    required this.hitTilePageCount,
    required this.paintTilePageCount,
    required this.hitOutlierCount,
    required this.paintOutlierCount,
  });

  final int structuralRevision;
  final bool isInvalid;
  final int entryCount;
  final int hitTilePageCount;
  final int paintTilePageCount;
  final int hitOutlierCount;
  final int paintOutlierCount;
}
