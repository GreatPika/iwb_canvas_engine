import 'commit_action_intent.dart';
import 'touched_set.dart';

final class CommitDeliveryResult {
  CommitDeliveryResult({
    required this.shouldPublishState,
    this.replacedDocument = false,
    Iterable<CommitDeliveryEffect> effects = const [],
    Iterable<CommitActionIntent> actionIntents = const [],
  }) : effects = List.unmodifiable(effects),
       actionIntents = List.unmodifiable(actionIntents);

  // CommitApplier seals these lists before the first install. Keeping that
  // preparation separate means result assembly cannot traverse or rebuild
  // delivery payloads after accepted state has changed.
  const CommitDeliveryResult.sealed({
    required this.shouldPublishState,
    required this.effects,
    required this.actionIntents,
    this.replacedDocument = false,
  });

  final bool shouldPublishState;
  final bool replacedDocument;
  final List<CommitDeliveryEffect> effects;
  final List<CommitActionIntent> actionIntents;
}

sealed class CommitDeliveryEffect {
  const CommitDeliveryEffect();
}

final class ProjectionDeliveryEffect extends CommitDeliveryEffect {
  const ProjectionDeliveryEffect();
}

final class SpatialDeliveryEffect extends CommitDeliveryEffect {
  const SpatialDeliveryEffect({required this.touchedSet});

  final TouchedSet touchedSet;
}

final class ResourceDeliveryEffect extends CommitDeliveryEffect {
  const ResourceDeliveryEffect({required this.touchedSet});

  final TouchedSet touchedSet;
}

final class RepaintDeliveryEffect extends CommitDeliveryEffect {
  const RepaintDeliveryEffect({
    required this.mainCanvas,
    this.overlayCanvas = false,
  });

  final bool mainCanvas;
  final bool overlayCanvas;
}

final class SelectionDeliveryEffect extends CommitDeliveryEffect {
  const SelectionDeliveryEffect();
}

final class PublicStateDeliveryEffect extends CommitDeliveryEffect {
  const PublicStateDeliveryEffect();
}

typedef CommitEffectObserver =
    void Function(List<CommitDeliveryEffect> effects);

typedef CommitApplyResultDelivery = void Function(CommitDeliveryResult result);
