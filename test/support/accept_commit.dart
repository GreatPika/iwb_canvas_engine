import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

/// Test-only host confirmation used by fixtures that do not exercise commits.
const testAcceptingCommitLease = _TestAcceptingCommitLease();

CanvasCommitResolution acceptCommit(CanvasCommitRequest request) {
  if (request case CanvasMoveCommitRequest(:final proposedDelta)) {
    return CanvasMoveCommitAccept(
      delta: proposedDelta,
      lease: testAcceptingCommitLease,
    );
  }

  return const CanvasCommitAccept(lease: testAcceptingCommitLease);
}

final class _TestAcceptingCommitLease implements CanvasCommitLease {
  const _TestAcceptingCommitLease();

  @override
  void aborted() => _ignoreLeaseOutcome();

  @override
  void committed() => _ignoreLeaseOutcome();
}

void _ignoreLeaseOutcome() => Object.hash(null, null);
