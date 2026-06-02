import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import 'interaction_read_port.dart';

enum InteractionRequestTargetKind { contentElement, emptyCanvas }

enum TextEditGuardDecisionKind {
  unknownOrRetired,
  rejectedAndRetired,
  accepted,
}

final class TextEditGuardDecision {
  const TextEditGuardDecision.unknownOrRetired()
    : kind = TextEditGuardDecisionKind.unknownOrRetired,
      targetElementId = null,
      currentText = null;

  const TextEditGuardDecision.rejectedAndRetired()
    : kind = TextEditGuardDecisionKind.rejectedAndRetired,
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

final class InteractionRequestGuardFacts {
  const InteractionRequestGuardFacts({
    required this.requestId,
    required this.targetKind,
    required this.controllerEpoch,
    required this.documentRevision,
    required this.retired,
    this.contentElementId,
    this.contentElementKind,
    this.generation,
    this.elementRevision,
    this.family,
  });

  final CanvasInteractionRequestId requestId;
  final InteractionRequestTargetKind targetKind;
  final int controllerEpoch;
  final int documentRevision;
  final bool retired;
  final CanvasElementId? contentElementId;
  final CanvasElementKind? contentElementKind;
  final int? generation;
  final int? elementRevision;
  final InteractionElementFamily? family;

  InteractionRequestGuardFacts retire() {
    return InteractionRequestGuardFacts(
      requestId: requestId,
      targetKind: targetKind,
      controllerEpoch: controllerEpoch,
      documentRevision: documentRevision,
      retired: true,
      contentElementId: contentElementId,
      contentElementKind: contentElementKind,
      generation: generation,
      elementRevision: elementRevision,
      family: family,
    );
  }
}

final class InteractionRequestRegistry {
  int _nextRequestId = 0;
  final Map<CanvasInteractionRequestId, InteractionRequestGuardFacts> _facts =
      {};

  InteractionRequestGuardFacts issueContextRequest(
    ContextTargetReadFacts target,
  ) {
    final requestId = CanvasInteractionRequestId('request-${_nextRequestId++}');
    final facts = InteractionRequestGuardFacts(
      requestId: requestId,
      targetKind: switch (target.kind) {
        ContextActionReadTargetKind.contentElement =>
          InteractionRequestTargetKind.contentElement,
        ContextActionReadTargetKind.emptyCanvas =>
          InteractionRequestTargetKind.emptyCanvas,
      },
      controllerEpoch: target.controllerEpoch,
      documentRevision: target.documentRevision,
      retired: false,
      contentElementId: target.elementId,
      contentElementKind: target.elementKind,
      generation: target.generation,
      elementRevision: target.elementRevision,
      family: target.family,
    );
    _facts[requestId] = facts;

    return facts;
  }

  InteractionRequestGuardFacts? factsFor(CanvasInteractionRequestId requestId) {
    return _facts[requestId];
  }

  InteractionRequestGuardFacts? liveFactsFor(
    CanvasInteractionRequestId requestId,
  ) {
    final facts = _facts[requestId];
    if (facts == null || facts.retired) {
      return null;
    }

    return facts;
  }

  bool retire(CanvasInteractionRequestId requestId) {
    final facts = liveFactsFor(requestId);
    if (facts == null) {
      return false;
    }
    _facts[requestId] = facts.retire();

    return true;
  }
}
