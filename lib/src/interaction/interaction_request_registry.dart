import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import 'interaction_read_port.dart';

enum InteractionRequestTargetKind { contentElement, emptyCanvas }

final class InteractionRequestGuardFacts {
  const InteractionRequestGuardFacts({
    required this.requestId,
    required this.targetKind,
    required this.controllerEpoch,
    required this.documentRevision,
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
  final CanvasElementId? contentElementId;
  final CanvasElementKind? contentElementKind;
  final int? generation;
  final int? elementRevision;
  final InteractionElementFamily? family;
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

  InteractionRequestGuardFacts? consume(CanvasInteractionRequestId requestId) {
    return _facts.remove(requestId);
  }

  void clear() {
    _facts.clear();
  }
}
