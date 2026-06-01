import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/frame/frame_spatial_paint_admission.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

void main() {
  _testCandidateResultAdmission();
  _testTypedRejectionAdmission();
}

void _testCandidateResultAdmission() {
  test('candidate result admits ordered candidates, including valid empty', () {
    final admitted = admitFrameSpatialPaint(
      SpatialCandidatesResult(
        orderedCandidates: [
          FrameElementHandle(
            id: CanvasElementId('candidate'),
            structuralRevision: 1,
            generation: 0,
            orderToken: 3,
          ),
        ],
      ),
    );
    final empty = admitFrameSpatialPaint(
      const SpatialCandidatesResult(orderedCandidates: []),
    );

    expect(admitted, isA<FrameSpatialPaintAdmitted>());
    expect(
      (admitted as FrameSpatialPaintAdmitted).candidates.single.id,
      CanvasElementId('candidate'),
    );
    expect(empty, isA<FrameSpatialPaintAdmitted>());
    expect((empty as FrameSpatialPaintAdmitted).candidates, isEmpty);
  });
}

void _testTypedRejectionAdmission() {
  test('typed non-candidate results reject with specific reasons', () {
    expect(
      _rejectionReason(
        const SpatialBudgetExceededResult(
          reason: SpatialBudgetExceededReason.queryTileBudgetExceeded,
          budget: 1,
          observed: 2,
        ),
      ),
      FrameSpatialPaintRejectionReason.budgetExceeded,
    );
    expect(
      _rejectionReason(
        const SpatialInvalidIndexResult(
          reason: SpatialInvalidIndexReason.rebuildNeeded,
        ),
      ),
      FrameSpatialPaintRejectionReason.invalidIndex,
    );
    expect(
      _rejectionReason(
        const SpatialStaleCandidateResult(
          expectedStructuralRevision: 1,
          observedStructuralRevision: 2,
        ),
      ),
      FrameSpatialPaintRejectionReason.staleCandidate,
    );
  });
}

FrameSpatialPaintRejectionReason _rejectionReason(SpatialQueryResult result) {
  final admission = admitFrameSpatialPaint(result);
  expect(admission, isA<FrameSpatialPaintRejected>());

  return (admission as FrameSpatialPaintRejected).reason;
}
