import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import 'interaction_read_port.dart';

enum InteractionRequestTargetKind { contentElement, emptyCanvas, textCreation }

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
  });

  final CanvasInteractionRequestId requestId;
  final InteractionRequestTargetKind targetKind;
  final int controllerEpoch;
  final int documentRevision;
  final CanvasElementId? contentElementId;
  final CanvasElementKind? contentElementKind;
  final int? generation;
  final int? elementRevision;
}

final class InteractionRequestRegistry {
  int _nextRequestId = 0;
  final Map<CanvasInteractionRequestId, InteractionRequestGuardFacts> _facts =
      {};

  InteractionRequestGuardFacts issueContextRequest(
    ContextTargetReadFacts target,
  ) {
    return _issue(
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
    );
  }

  InteractionRequestGuardFacts issueTextEditRequest(
    TextCommitGuardReadFacts target,
  ) {
    return _issue(
      targetKind: InteractionRequestTargetKind.contentElement,
      controllerEpoch: target.controllerEpoch,
      documentRevision: target.documentRevision,
      contentElementId: target.targetElementId,
      contentElementKind: target.targetKind,
      generation: target.generation,
      elementRevision: target.elementRevision,
    );
  }

  InteractionRequestGuardFacts issueTextCreationRequest({
    required int controllerEpoch,
    required int documentRevision,
  }) {
    return _issue(
      targetKind: InteractionRequestTargetKind.textCreation,
      controllerEpoch: controllerEpoch,
      documentRevision: documentRevision,
      contentElementId: null,
      contentElementKind: null,
      generation: null,
      elementRevision: null,
    );
  }

  // Guard facts must cross the registry as one immutable capture. Packing them
  // into a second mutable request DTO would obscure the sole issuance owner.
  // ignore: number-of-parameters
  InteractionRequestGuardFacts _issue({
    required InteractionRequestTargetKind targetKind,
    required int controllerEpoch,
    required int documentRevision,
    required CanvasElementId? contentElementId,
    required CanvasElementKind? contentElementKind,
    required int? generation,
    required int? elementRevision,
  }) {
    final requestId = CanvasInteractionRequestId('request-${_nextRequestId++}');
    final facts = InteractionRequestGuardFacts(
      requestId: requestId,
      targetKind: targetKind,
      controllerEpoch: controllerEpoch,
      documentRevision: documentRevision,
      contentElementId: contentElementId,
      contentElementKind: contentElementKind,
      generation: generation,
      elementRevision: elementRevision,
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
