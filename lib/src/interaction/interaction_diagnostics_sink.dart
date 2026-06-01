abstract interface class InteractionDiagnosticsSink {
  void recordHitTestFallbackObserved({
    required String reason,
    required int? budget,
    required int? observed,
  });

  void recordInteractionQueryBudgetExceeded({
    required String reason,
    required int? budget,
    required int? observed,
  });

  void recordStaleCandidateRejected({
    required String reason,
    required int? expectedRevision,
    required int? observedRevision,
    required int skippedCandidateCount,
  });

  void recordStaleTerminalRejected({required String reason});

  void recordInvalidTerminalCleanup({required String reason});

  void recordSelectedMoveStartDeniedNotMovable({
    required int selectedCount,
    required int movableCount,
  });

  void recordResolverReentrantMutationRejected({required String operation});
}

final class NoopInteractionDiagnosticsSink
    implements InteractionDiagnosticsSink {
  const NoopInteractionDiagnosticsSink();

  @override
  void recordHitTestFallbackObserved({
    required String reason,
    required int? budget,
    required int? observed,
  }) {}

  @override
  void recordInteractionQueryBudgetExceeded({
    required String reason,
    required int? budget,
    required int? observed,
  }) {}

  @override
  void recordStaleCandidateRejected({
    required String reason,
    required int? expectedRevision,
    required int? observedRevision,
    required int skippedCandidateCount,
  }) {}

  @override
  void recordStaleTerminalRejected({required String reason}) {}

  @override
  void recordInvalidTerminalCleanup({required String reason}) {}

  @override
  void recordSelectedMoveStartDeniedNotMovable({
    required int selectedCount,
    required int movableCount,
  }) {}

  @override
  void recordResolverReentrantMutationRejected({required String operation}) {}
}
