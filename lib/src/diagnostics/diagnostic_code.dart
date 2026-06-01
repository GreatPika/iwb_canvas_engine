import 'package:flutter/foundation.dart';

import '../contracts/public/canvas_errors.dart';

sealed class DiagnosticCode {
  const DiagnosticCode();

  const factory DiagnosticCode.data(CanvasDataErrorCode code) =
      DiagnosticDataCode;

  const factory DiagnosticCode.interaction(InteractionDiagnosticCode code) =
      DiagnosticInteractionCode;
}

@immutable
final class DiagnosticDataCode extends DiagnosticCode {
  const DiagnosticDataCode(this.code);

  final CanvasDataErrorCode code;

  @override
  bool operator ==(Object other) {
    return other is DiagnosticDataCode && other.code == code;
  }

  @override
  int get hashCode => Object.hash(DiagnosticDataCode, code);

  @override
  String toString() => 'DiagnosticCode.data($code)';
}

@immutable
final class DiagnosticInteractionCode extends DiagnosticCode {
  const DiagnosticInteractionCode(this.code);

  final InteractionDiagnosticCode code;

  @override
  bool operator ==(Object other) {
    return other is DiagnosticInteractionCode && other.code == code;
  }

  @override
  int get hashCode => Object.hash(DiagnosticInteractionCode, code);

  @override
  String toString() => 'DiagnosticCode.interaction($code)';
}

enum InteractionDiagnosticCode {
  hitTestFallbackObserved,
  interactionQueryBudgetExceeded,
  staleCandidateRejected,
  staleTerminalRejected,
  invalidTerminalCleanup,
  selectedMoveStartDeniedNotMovable,
  resolverReentrantMutationRejected,
}
