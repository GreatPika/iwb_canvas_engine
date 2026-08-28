import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import '../interaction/interaction_read_port.dart';
import '../geometry/spatial_query_result.dart';

@visibleForTesting
enum RuntimeCandidateResolutionWorkEvent { resolved }

final Object _candidateResolutionWorkZoneKey = Object();

@visibleForTesting
T observeRuntimeCandidateResolutionWork<T>(
  void Function(RuntimeCandidateResolutionWorkEvent event) sink,
  T Function() operation,
) => runZoned(operation, zoneValues: {_candidateResolutionWorkZoneKey: sink});

final class RuntimeResolvedSpatialCandidates {
  const RuntimeResolvedSpatialCandidates({
    this.handles = const [],
    this.facts = const [],
    this.skippedCandidateCount = 0,
  });

  final List<FrameElementHandle> handles;
  final List<FrameElementFacts> facts;
  final int skippedCandidateCount;
}

RuntimeResolvedSpatialCandidates resolveInteractionCandidates(
  SpatialQueryResult query, {
  required FrameElementFacts? Function(FrameElementHandle handle) resolve,
}) {
  assert(
    _recordCandidateResolutionWork(
      RuntimeCandidateResolutionWorkEvent.resolved,
    ),
    'candidate resolution work observation failed',
  );
  if (query is! SpatialCandidatesResult) {
    return const RuntimeResolvedSpatialCandidates();
  }
  final handles = <FrameElementHandle>[];
  final facts = <FrameElementFacts>[];
  var skipped = 0;
  for (final handle in query.orderedCandidates) {
    final resolved = resolve(handle);
    if (resolved == null) {
      skipped += 1;
      continue;
    }
    handles.add(handle);
    facts.add(resolved);
  }

  return RuntimeResolvedSpatialCandidates(
    handles: List.unmodifiable(handles),
    facts: List.unmodifiable(facts),
    skippedCandidateCount: skipped,
  );
}

bool _recordCandidateResolutionWork(RuntimeCandidateResolutionWorkEvent event) {
  final sink = Zone.current[_candidateResolutionWorkZoneKey];
  if (sink is void Function(RuntimeCandidateResolutionWorkEvent)) sink(event);
  return true;
}

bool interactionQueryHasCandidates(SpatialQueryResult query) {
  return query is SpatialCandidatesResult;
}

InteractionReadQueryFacts interactionQueryFacts(
  SpatialQueryResult query,
  RuntimeResolvedSpatialCandidates candidates,
) {
  return switch (query) {
    SpatialCandidatesResult(:final orderedCandidates) =>
      InteractionReadQueryFacts.candidates(
        candidateCount: orderedCandidates.length,
        skippedCandidateCount: candidates.skippedCandidateCount,
      ),
    SpatialInvalidIndexResult(:final reason) =>
      InteractionReadQueryFacts.invalidIndex(
        invalidIndexReason: _invalidIndexReason(reason),
      ),
    SpatialStaleCandidateResult(
      :final expectedStructuralRevision,
      :final observedStructuralRevision,
    ) =>
      InteractionReadQueryFacts.staleIndex(
        expectedStructuralRevision: expectedStructuralRevision,
        observedStructuralRevision: observedStructuralRevision,
      ),
    SpatialBudgetExceededResult(
      :final reason,
      :final budget,
      :final observed,
    ) =>
      InteractionReadQueryFacts.budgetExceeded(
        budgetExceededReason: _budgetExceededReason(reason),
        budget: budget,
        observed: observed,
      ),
  };
}

FrameElementFacts? interactionFactsForId(
  RuntimeResolvedSpatialCandidates candidates,
  CanvasElementId id,
) {
  for (final facts in candidates.facts) {
    if (facts.id == id) {
      return facts;
    }
  }

  return null;
}

String? interactionTextValue(FrameElementFacts facts) {
  return facts.kind == CanvasElementKind.text ? facts.text : null;
}

// Reconstructing the immutable public snapshot here keeps context requests on
// the frame/read boundary instead of exposing a full document projection.
// Each branch is the stable public element constructor for its family; splitting
// by family would duplicate the shared common-field copy rules.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
CanvasElement interactionElementSnapshot(FrameElementFacts facts) {
  return switch (facts.kind) {
    CanvasElementKind.image => CanvasImageElement(
      id: facts.id,
      resourceId: _requiredFact(facts.resourceId, facts, 'resourceId'),
      size: _requiredFact(facts.size, facts, 'size'),
      naturalSize: facts.naturalSize,
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.vector => CanvasVectorElement(
      id: facts.id,
      resourceId: _requiredFact(facts.resourceId, facts, 'resourceId'),
      size: _requiredFact(facts.size, facts, 'size'),
      naturalSize: facts.naturalSize,
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.path => CanvasPathElement(
      id: facts.id,
      svgPathData: _requiredFact(facts.svgPathData, facts, 'svgPathData'),
      fillColor: facts.fillColor,
      strokeColor: facts.strokeColor,
      strokeWidth: facts.strokeWidth ?? 0,
      fillRule: facts.fillRule ?? CanvasPathFillRule.nonZero,
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.text => CanvasTextElement(
      id: facts.id,
      text: _requiredFact(facts.text, facts, 'text'),
      color: facts.textColor ?? const Color(0xFF000000),
      textDirection: facts.textDirection ?? TextDirection.ltr,
      fontSize: facts.fontSize ?? 24,
      align: facts.textAlign ?? TextAlign.left,
      isBold: facts.isBold ?? false,
      isItalic: facts.isItalic ?? false,
      isUnderline: facts.isUnderline ?? false,
      fontFamily: facts.fontFamily,
      maxWidth: facts.maxWidth,
      lineHeight: facts.lineHeight,
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.stroke => CanvasStrokeElement(
      id: facts.id,
      points: facts.points,
      thickness: _requiredFact(facts.thickness, facts, 'thickness'),
      color: facts.color ?? const Color(0xFF000000),
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.line => CanvasLineElement(
      id: facts.id,
      start: _requiredFact(facts.start, facts, 'start'),
      end: _requiredFact(facts.end, facts, 'end'),
      thickness: _requiredFact(facts.thickness, facts, 'thickness'),
      color: facts.color ?? const Color(0xFF000000),
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.rect => CanvasRectElement(
      id: facts.id,
      size: _requiredFact(facts.size, facts, 'size'),
      fillColor: facts.fillColor,
      strokeColor: facts.strokeColor,
      strokeWidth: facts.strokeWidth ?? 0,
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
  };
}

InteractionReadInvalidIndexReason _invalidIndexReason(
  SpatialInvalidIndexReason reason,
) {
  return switch (reason) {
    SpatialInvalidIndexReason.rebuildNeeded =>
      InteractionReadInvalidIndexReason.rebuildNeeded,
    SpatialInvalidIndexReason.failedUpdate =>
      InteractionReadInvalidIndexReason.failedUpdate,
  };
}

InteractionReadBudgetExceededReason _budgetExceededReason(
  SpatialBudgetExceededReason reason,
) {
  return switch (reason) {
    SpatialBudgetExceededReason.queryTileBudgetExceeded =>
      InteractionReadBudgetExceededReason.queryTileBudgetExceeded,
    SpatialBudgetExceededReason.fallbackCandidateBudgetExceeded =>
      InteractionReadBudgetExceededReason.fallbackCandidateBudgetExceeded,
  };
}

T _requiredFact<T>(T? value, FrameElementFacts facts, String field) {
  if (value == null) {
    throw StateError(
      'Missing $field for ${facts.kind.name} element ${facts.id.value}.',
    );
  }

  return value;
}
