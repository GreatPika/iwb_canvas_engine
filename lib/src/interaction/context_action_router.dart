import 'dart:ui';

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_ids.dart';
import 'interaction_runtime_intents.dart';
import 'interaction_read_port.dart';
import 'pointer_sample_normalizer.dart';

final class ContextActionRouter {
  const ContextActionRouter();

  PendingContextTap pendingTap({
    required NormalizedPointerSample sample,
    required ContextTargetReadFacts facts,
  }) {
    return PendingContextTap(
      viewPosition: sample.viewPosition,
      worldPosition: sample.worldPosition,
      timestampMs: sample.timestampMs,
      controllerEpoch: sample.controllerEpoch,
      target: _targetKey(facts),
    );
  }

  bool matchesSecondTap(ContextSecondTapMatchInput input) {
    final pending = input.pending;
    final sample = input.sample;
    if (pending.controllerEpoch != sample.controllerEpoch) {
      return false;
    }
    if (!_withinSlop(
      pending.worldPosition,
      sample.worldPosition,
      input.doubleTapSlop,
    )) {
      return false;
    }
    if (!_withinDelay(
      pending.timestampMs,
      sample.timestampMs,
      input.doubleTapMaxDelayMs,
    )) {
      return false;
    }

    return pending.target == _targetKey(input.facts);
  }

  ContextActionRequestIntent requestIntent(ContextRequestIntentInput input) {
    return ContextActionRequestIntent(
      pendingRequest: PendingContextActionRequest(
        requestId: input.requestId,
        trigger: CanvasContextActionTrigger.doubleTap,
        target: _publicTarget(input.facts),
        controllerEpoch: input.facts.controllerEpoch,
        documentRevision: input.facts.documentRevision,
        timestampHintMs: input.timestampHintMs,
        viewPosition: input.viewPosition,
        worldPosition: input.worldPosition,
      ),
    );
  }
}

typedef ContextSecondTapMatchInput = ({
  PendingContextTap pending,
  NormalizedPointerSample sample,
  ContextTargetReadFacts facts,
  double doubleTapSlop,
  int doubleTapMaxDelayMs,
});

typedef ContextRequestIntentInput = ({
  CanvasInteractionRequestId requestId,
  ContextTargetReadFacts facts,
  int? timestampHintMs,
  Offset viewPosition,
  Offset worldPosition,
});

final class PendingContextTap {
  const PendingContextTap({
    required this.viewPosition,
    required this.worldPosition,
    required this.timestampMs,
    required this.controllerEpoch,
    required ContextTargetKey target,
  }) : _target = target;

  final Offset viewPosition;
  final Offset worldPosition;
  final int? timestampMs;
  final int controllerEpoch;
  final ContextTargetKey _target;

  ContextTargetKey get target => _target;
}

sealed class ContextTargetKey {
  const ContextTargetKey();
}

final class EmptyContextTargetKey extends ContextTargetKey {
  const EmptyContextTargetKey();

  // Context target keys are immutable value objects; the interaction owner must
  // not import Flutter foundation only to carry the @immutable annotation.
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, immutable key type with final fields
  bool operator ==(Object other) => other is EmptyContextTargetKey;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, immutable key type with final fields
  int get hashCode => 0;
}

final class ContentContextTargetKey extends ContextTargetKey {
  const ContentContextTargetKey({
    required this.elementId,
    required this.generation,
    required this.elementRevision,
    required this.family,
  });

  final CanvasElementId elementId;
  final int generation;
  final int elementRevision;
  final InteractionElementFamily family;

  // Context target keys are immutable value objects; the interaction owner must
  // not import Flutter foundation only to carry the @immutable annotation.
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, immutable key type with final fields
  bool operator ==(Object other) {
    return other is ContentContextTargetKey &&
        other.elementId == elementId &&
        other.generation == generation &&
        other.elementRevision == elementRevision &&
        other.family == family;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, immutable key type with final fields
  int get hashCode =>
      Object.hash(elementId, generation, elementRevision, family);
}

ContextTargetKey _targetKey(ContextTargetReadFacts facts) {
  return switch (facts.kind) {
    ContextActionReadTargetKind.emptyCanvas => const EmptyContextTargetKey(),
    ContextActionReadTargetKind.contentElement => ContentContextTargetKey(
      elementId: _required(facts.elementId, 'elementId'),
      generation: _required(facts.generation, 'generation'),
      elementRevision: _required(facts.elementRevision, 'elementRevision'),
      family: _required(facts.family, 'family'),
    ),
  };
}

CanvasContextActionTarget _publicTarget(ContextTargetReadFacts facts) {
  return switch (facts.kind) {
    ContextActionReadTargetKind.emptyCanvas =>
      const CanvasEmptyCanvasContextActionTarget(),
    ContextActionReadTargetKind.contentElement =>
      CanvasContentElementContextActionTarget(
        elementSnapshot: _required(facts.elementSnapshot, 'elementSnapshot'),
        boundsWorld: _required(facts.boundsWorld, 'boundsWorld'),
      ),
  };
}

bool _withinSlop(Offset first, Offset second, double slop) {
  return (second - first).distance <= slop;
}

bool _withinDelay(int? firstMs, int? secondMs, int maxDelayMs) {
  if (firstMs == null || secondMs == null) {
    return true;
  }

  return secondMs >= firstMs && secondMs - firstMs <= maxDelayMs;
}

T _required<T>(T? value, String name) {
  if (value == null) {
    throw StateError('Context target facts missing $name.');
  }

  return value;
}
