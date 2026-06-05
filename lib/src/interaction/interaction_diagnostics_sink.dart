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
  }) => _discardDiagnosticEvent();

  @override
  void recordInteractionQueryBudgetExceeded({
    required String reason,
    required int? budget,
    required int? observed,
  }) => _discardDiagnosticEvent();

  @override
  void recordStaleCandidateRejected({
    required String reason,
    required int? expectedRevision,
    required int? observedRevision,
    required int skippedCandidateCount,
  }) => _discardDiagnosticEvent();

  @override
  void recordStaleTerminalRejected({required String reason}) =>
      _discardDiagnosticEvent();

  @override
  void recordInvalidTerminalCleanup({required String reason}) =>
      _discardDiagnosticEvent();

  @override
  void recordSelectedMoveStartDeniedNotMovable({
    required int selectedCount,
    required int movableCount,
  }) => _discardDiagnosticEvent();

  @override
  void recordResolverReentrantMutationRejected({required String operation}) =>
      _discardDiagnosticEvent();
}

int _discardDiagnosticEvent() => 0;
