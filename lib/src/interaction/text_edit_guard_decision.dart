import '../contracts/public/canvas_ids.dart';
import 'interaction_request_registry.dart';

enum TextEditGuardDecisionKind {
  unknownOrConsumed,
  rejectedAndConsumed,
  accepted,
}

enum TextEditGuardValidityKind { unknownOrConsumed, rejected, accepted }

/// Non-consuming observation of one issued text-edit guard.
///
/// Runtime admission and stale-session observation use these same facts as the
/// command terminal. Only [InteractionEngine.textEditGuardDecision] retires a
/// rejected request.
final class TextEditGuardObservation {
  const TextEditGuardObservation.unknownOrConsumed()
    : kind = TextEditGuardValidityKind.unknownOrConsumed,
      guard = null,
      currentText = null;

  const TextEditGuardObservation.rejected({required this.guard})
    : kind = TextEditGuardValidityKind.rejected,
      currentText = null;

  const TextEditGuardObservation.accepted({
    required this.guard,
    required this.currentText,
  }) : kind = TextEditGuardValidityKind.accepted;

  final TextEditGuardValidityKind kind;
  final InteractionRequestGuardFacts? guard;
  final String? currentText;
}

final class TextEditGuardDecision {
  const TextEditGuardDecision.unknownOrConsumed()
    : kind = TextEditGuardDecisionKind.unknownOrConsumed,
      targetElementId = null,
      currentText = null;

  const TextEditGuardDecision.rejectedAndConsumed()
    : kind = TextEditGuardDecisionKind.rejectedAndConsumed,
      targetElementId = null,
      currentText = null;

  const TextEditGuardDecision.accepted({
    required CanvasElementId this.targetElementId,
    required String this.currentText,
  }) : kind = TextEditGuardDecisionKind.accepted;

  final TextEditGuardDecisionKind kind;
  final CanvasElementId? targetElementId;
  final String? currentText;
}
