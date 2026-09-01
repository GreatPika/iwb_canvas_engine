import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/touched_set.dart';
import 'geometry_policy.dart';
import 'spatial_budget_counters.dart';
import 'spatial_candidate_handle_mapper.dart';
import 'spatial_entry_loader.dart';
import 'spatial_index_set.dart';
import 'spatial_kernel_query_state.dart';
import 'spatial_query_policy.dart';
import 'spatial_query_result.dart';

@visibleForTesting
enum SpatialKernelEraserWorkEvent { queryEraser }

final Object _eraserWorkZoneKey = Object();

// The owner observer belongs with queryEraser, and this kernel already owns
// the coupled index/query lifecycle that makes its operation meaningful.
// ignore: coupling-between-object-classes, number-of-methods
final class SpatialKernel {
  SpatialKernel({this.geometryPolicy = const GeometryPolicy()});

  final GeometryPolicy geometryPolicy;
  SpatialIndexSet _indexes = SpatialIndexSet();
  final SpatialKernelQueryState _queryState = SpatialKernelQueryState();
  final SpatialCandidateHandleMapper _candidateMapper =
      SpatialCandidateHandleMapper();
  FrameFactsPort? _pendingReplacementFrame;

  /// Observes actual eraser spatial queries in assertion builds only.
  @visibleForTesting
  static T observeEraserWork<T>(
    void Function(SpatialKernelEraserWorkEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_eraserWorkZoneKey: sink});

  static bool _recordEraserWork(SpatialKernelEraserWorkEvent event) {
    final sink = Zone.current[_eraserWorkZoneKey];
    if (sink is void Function(SpatialKernelEraserWorkEvent)) {
      sink(event);
    }
    return true;
  }

  SpatialKernelSnapshot get snapshot {
    final indexes = _indexes.snapshot;

    return SpatialKernelSnapshot(
      structuralRevision: _queryState.structuralRevision,
      isInvalid: _queryState.isInvalid,
      entryCount: indexes.entryCount,
      hitTilePageCount: indexes.hitTilePageCount,
      paintTilePageCount: indexes.paintTilePageCount,
      contextTilePageCount: indexes.contextTilePageCount,
      hitOutlierCount: indexes.hitOutlierCount,
      paintOutlierCount: indexes.paintOutlierCount,
      contextOutlierCount: indexes.contextOutlierCount,
    );
  }

  void rebuild(FrameFactsPort frame) {
    _pendingReplacementFrame = null;
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
    _pendingReplacementFrame = null;
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
      if (touchedSet.documentReplaced) {
        _scheduleReplacementRebuild(frame, structuralRevision);

        return;
      }
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
    final pendingReplacementFrame = _pendingReplacementFrame;
    if (pendingReplacementFrame != null) {
      rebuild(pendingReplacementFrame);
    }

    return _queryState.runQuery(
      SpatialKernelQueryContext(
        window: window,
        indexedEntryCount: _indexes.snapshot.entryCount,
        fallbackCandidates: _indexes.fallbackHandles,
        candidateMapper: _candidateMapper.call,
        query: query,
      ),
    );
  }

  void _scheduleReplacementRebuild(
    FrameFactsPort frame,
    int structuralRevision,
  ) {
    // Replacement drops the old index in O(1); the next spatial query rebuilds
    // against committed frame facts before exposing candidates.
    _indexes = SpatialIndexSet();
    _candidateMapper.bind(frame, structuralRevision);
    _pendingReplacementFrame = frame;
    _queryState.markRebuildNeeded(structuralRevision);
  }
}

extension SpatialKernelInteractionQueries on SpatialKernel {
  SpatialQueryResult queryMarquee(SpatialQueryWindow window) {
    return _queryIndex(window, _indexes.queryHit);
  }

  SpatialQueryResult queryEraser(SpatialQueryWindow window) {
    assert(
      SpatialKernel._recordEraserWork(SpatialKernelEraserWorkEvent.queryEraser),
      'spatial eraser work observation failed',
    );
    return _queryIndex(window, _indexes.queryPaint);
  }

  SpatialQueryResult queryContext(SpatialQueryWindow window) {
    return _queryIndex(window, _indexes.queryContext);
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
  return touchedSet.backgroundLayerChanged || touchedSet.background;
}

final class SpatialKernelSnapshot {
  const SpatialKernelSnapshot({
    required this.structuralRevision,
    required this.isInvalid,
    required this.entryCount,
    required this.hitTilePageCount,
    required this.paintTilePageCount,
    required this.contextTilePageCount,
    required this.hitOutlierCount,
    required this.paintOutlierCount,
    required this.contextOutlierCount,
  });

  final int structuralRevision;
  final bool isInvalid;
  final int entryCount;
  final int hitTilePageCount;
  final int paintTilePageCount;
  final int contextTilePageCount;
  final int hitOutlierCount;
  final int paintOutlierCount;
  final int contextOutlierCount;
}
// The spatial kernel owns all query kinds and the assertion-only eraser owner
// observer; splitting it would obscure which real query is being counted.
// ignore_for_file: number-of-imports
