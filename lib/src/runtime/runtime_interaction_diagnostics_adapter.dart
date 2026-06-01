import '../diagnostics/diagnostic_code.dart';
import '../diagnostics/diagnostics_hub.dart';
import '../interaction/interaction_diagnostics_sink.dart';

final class RuntimeInteractionDiagnosticsAdapter
    implements InteractionDiagnosticsSink {
  const RuntimeInteractionDiagnosticsAdapter(this._hub);

  final DiagnosticsHub? _hub;

  @override
  void recordHitTestFallbackObserved({
    required String reason,
    required int? budget,
    required int? observed,
  }) {
    recordInteractionReliabilityDiagnostic(
      _hub,
      code: InteractionDiagnosticCode.hitTestFallbackObserved,
      details: () =>
          _budgetDetails(reason: reason, budget: budget, observed: observed),
    );
  }

  @override
  void recordInteractionQueryBudgetExceeded({
    required String reason,
    required int? budget,
    required int? observed,
  }) {
    recordInteractionReliabilityDiagnostic(
      _hub,
      code: InteractionDiagnosticCode.interactionQueryBudgetExceeded,
      details: () =>
          _budgetDetails(reason: reason, budget: budget, observed: observed),
    );
  }

  @override
  void recordStaleCandidateRejected({
    required String reason,
    required int? expectedRevision,
    required int? observedRevision,
    required int skippedCandidateCount,
  }) {
    recordInteractionReliabilityDiagnostic(
      _hub,
      code: InteractionDiagnosticCode.staleCandidateRejected,
      details: () => _staleCandidateDetails(
        reason: reason,
        expectedRevision: expectedRevision,
        observedRevision: observedRevision,
        skippedCandidateCount: skippedCandidateCount,
      ),
    );
  }

  @override
  void recordStaleTerminalRejected({required String reason}) {
    recordInteractionReliabilityDiagnostic(
      _hub,
      code: InteractionDiagnosticCode.staleTerminalRejected,
      details: () => {'reason': reason},
    );
  }

  @override
  void recordInvalidTerminalCleanup({required String reason}) {
    recordInteractionReliabilityDiagnostic(
      _hub,
      code: InteractionDiagnosticCode.invalidTerminalCleanup,
      details: () => {'reason': reason},
    );
  }

  @override
  void recordSelectedMoveStartDeniedNotMovable({
    required int selectedCount,
    required int movableCount,
  }) {
    recordInteractionReliabilityDiagnostic(
      _hub,
      code: InteractionDiagnosticCode.selectedMoveStartDeniedNotMovable,
      details: () => {
        'selectedCount': selectedCount,
        'movableCount': movableCount,
      },
    );
  }

  @override
  void recordResolverReentrantMutationRejected({required String operation}) {
    recordInteractionReliabilityDiagnostic(
      _hub,
      code: InteractionDiagnosticCode.resolverReentrantMutationRejected,
      details: () => {'operation': operation},
    );
  }
}

Map<String, Object?> _budgetDetails({
  required String reason,
  required int? budget,
  required int? observed,
}) {
  final details = <String, Object?>{'reason': reason};
  if (budget != null) {
    details['budget'] = budget;
  }
  if (observed != null) {
    details['observed'] = observed;
  }

  return details;
}

Map<String, Object?> _staleCandidateDetails({
  required String reason,
  required int? expectedRevision,
  required int? observedRevision,
  required int skippedCandidateCount,
}) {
  final details = <String, Object?>{
    'reason': reason,
    'skippedCandidateCount': skippedCandidateCount,
  };
  if (expectedRevision != null) {
    details['expectedRevision'] = expectedRevision;
  }
  if (observedRevision != null) {
    details['observedRevision'] = observedRevision;
  }

  return details;
}
