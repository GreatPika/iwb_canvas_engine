import '../contracts/internal/frame_facts_port.dart';
import '../geometry/spatial_query_result.dart';

enum FrameSpatialPaintRejectionReason {
  budgetExceeded,
  invalidIndex,
  staleCandidate,
}

sealed class FrameSpatialPaintAdmission {
  const FrameSpatialPaintAdmission();
}

final class FrameSpatialPaintAdmitted extends FrameSpatialPaintAdmission {
  FrameSpatialPaintAdmitted({required Iterable<FrameElementHandle> candidates})
    : candidates = List.unmodifiable(candidates);

  final List<FrameElementHandle> candidates;
}

final class FrameSpatialPaintRejected extends FrameSpatialPaintAdmission {
  const FrameSpatialPaintRejected({required this.reason, required this.result});

  final FrameSpatialPaintRejectionReason reason;
  final SpatialQueryResult result;
}

FrameSpatialPaintAdmission admitFrameSpatialPaint(SpatialQueryResult result) {
  return switch (result) {
    SpatialCandidatesResult(:final orderedCandidates) =>
      FrameSpatialPaintAdmitted(candidates: orderedCandidates),
    SpatialBudgetExceededResult() => FrameSpatialPaintRejected(
      reason: FrameSpatialPaintRejectionReason.budgetExceeded,
      result: result,
    ),
    SpatialInvalidIndexResult() => FrameSpatialPaintRejected(
      reason: FrameSpatialPaintRejectionReason.invalidIndex,
      result: result,
    ),
    SpatialStaleCandidateResult() => FrameSpatialPaintRejected(
      reason: FrameSpatialPaintRejectionReason.staleCandidate,
      result: result,
    ),
  };
}
