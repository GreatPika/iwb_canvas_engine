import '../contracts/public/canvas_ids.dart';

enum TextEditGuardDecisionKind {
  unknownOrConsumed,
  rejectedAndConsumed,
  accepted,
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
