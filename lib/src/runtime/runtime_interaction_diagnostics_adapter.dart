import 'dart:async';

import 'package:meta/meta.dart' show visibleForTesting;

import '../diagnostics/diagnostic_code.dart';
import '../diagnostics/diagnostics_hub.dart';
import '../interaction/interaction_diagnostics_sink.dart';

@visibleForTesting
enum ResolverCallbackDiagnosticWorkEvent { eventBuilt, detailsBuilt }

// The adapter deliberately keeps every InteractionDiagnosticsSink delegation
// visible at this boundary; splitting the callback-failure test observer out would
// obscure the direct RuntimeRoot-to-Hub diagnostic route.
// ignore: number-of-methods
final class RuntimeInteractionDiagnosticsAdapter
    implements InteractionDiagnosticsSink {
  const RuntimeInteractionDiagnosticsAdapter(this._hub);

  static final Object _resolverCallbackDiagnosticWorkZoneKey = Object();
  final DiagnosticsHub? _hub;

  /// Observes callback-failure diagnostic construction under assertions.
  @visibleForTesting
  static T observeResolverCallbackDiagnosticWork<T>(
    void Function(ResolverCallbackDiagnosticWorkEvent event) sink,
    T Function() operation,
  ) => runZoned(
    operation,
    zoneValues: {_resolverCallbackDiagnosticWorkZoneKey: sink},
  );

  static bool _recordResolverCallbackDiagnosticWork(
    ResolverCallbackDiagnosticWorkEvent event,
  ) {
    final sink = Zone.current[_resolverCallbackDiagnosticWorkZoneKey];
    if (sink is void Function(ResolverCallbackDiagnosticWorkEvent)) {
      sink(event);
    }
    return true;
  }

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

  @override
  void recordResolverCallbackFailed({
    required String operation,
    required String errorKind,
  }) {
    try {
      _hub?.record(_resolverCallbackFailureEvent(operation, errorKind));
    } on Object {
      // Callback containment must survive a diagnostics implementation fault.
    }
  }

  DiagnosticEvent _resolverCallbackFailureEvent(
    String operation,
    String errorKind,
  ) {
    assert(
      _recordResolverCallbackDiagnosticWork(
        ResolverCallbackDiagnosticWorkEvent.eventBuilt,
      ),
      'resolver callback diagnostic work observation failed',
    );
    return DiagnosticEvent(
      code: const DiagnosticCode.interaction(
        InteractionDiagnosticCode.resolverCallbackFailed,
      ),
      severity: DiagnosticSeverity.warning,
      source: DiagnosticSource.interaction,
      details: () {
        assert(
          _recordResolverCallbackDiagnosticWork(
            ResolverCallbackDiagnosticWorkEvent.detailsBuilt,
          ),
          'resolver callback diagnostic work observation failed',
        );
        return {'operation': operation, 'errorKind': errorKind};
      },
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
