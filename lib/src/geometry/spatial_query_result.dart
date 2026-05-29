import '../contracts/internal/frame_facts_port.dart';

sealed class SpatialQueryResult {
  const SpatialQueryResult();

  bool get hasCandidates => false;
  List<FrameElementHandle> get candidates => const [];
}

final class SpatialCandidatesResult extends SpatialQueryResult {
  const SpatialCandidatesResult({required this.orderedCandidates});

  final List<FrameElementHandle> orderedCandidates;

  @override
  bool get hasCandidates => orderedCandidates.isNotEmpty;

  @override
  List<FrameElementHandle> get candidates => orderedCandidates;
}

enum SpatialBudgetExceededReason {
  queryTileBudgetExceeded,
  fallbackCandidateBudgetExceeded,
}

final class SpatialBudgetExceededResult extends SpatialQueryResult {
  const SpatialBudgetExceededResult({
    required this.reason,
    required this.budget,
    required this.observed,
  });

  final SpatialBudgetExceededReason reason;
  final int budget;
  final int observed;
}

enum SpatialInvalidIndexReason { rebuildNeeded, failedUpdate }

final class SpatialInvalidIndexResult extends SpatialQueryResult {
  const SpatialInvalidIndexResult({required this.reason});

  final SpatialInvalidIndexReason reason;
}

final class SpatialStaleCandidateResult extends SpatialQueryResult {
  const SpatialStaleCandidateResult({
    required this.expectedStructuralRevision,
    required this.observedStructuralRevision,
  });

  final int expectedStructuralRevision;
  final int observedStructuralRevision;
}
