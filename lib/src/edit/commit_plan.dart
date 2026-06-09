import '../contracts/internal/commit_action_intent.dart';
import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_ids.dart';
import '../store/store_revision_delta.dart';

final class CommitPlan {
  CommitPlan({
    required this.revisionDelta,
    required this.touchedSet,
    this.selectionEffect,
    Iterable<CommitEffect> effects = const [],
    Iterable<CommitActionIntent> actionIntents = const [],
  }) : effects = List.unmodifiable(effects),
       actionIntents = List.unmodifiable(actionIntents);

  factory CommitPlan.replaceSelection({
    required Iterable<CanvasElementId> elementIds,
    Iterable<CommitActionIntent> actionIntents = const [],
  }) {
    return CommitPlan(
      revisionDelta: const StoreRevisionDelta(),
      touchedSet: TouchedSet(selection: true),
      selectionEffect: ReplaceSelectionEffect(elementIds),
      effects: const [
        SelectionEffect(),
        RepaintEffect(mainCanvas: true),
        PublicStateEffect(),
      ],
      actionIntents: actionIntents,
    );
  }

  factory CommitPlan.empty() {
    return CommitPlan(
      revisionDelta: const StoreRevisionDelta(),
      touchedSet: TouchedSet(),
    );
  }

  CommitPlan withActionIntents(Iterable<CommitActionIntent> intents) {
    return CommitPlan(
      revisionDelta: revisionDelta,
      touchedSet: touchedSet,
      selectionEffect: selectionEffect,
      effects: effects,
      actionIntents: [...actionIntents, ...intents],
    );
  }

  final StoreRevisionDelta revisionDelta;
  final TouchedSet touchedSet;
  final CommitSelectionEffect? selectionEffect;
  final List<CommitEffect> effects;
  final List<CommitActionIntent> actionIntents;

  bool get hasChanges => revisionDelta.hasChanges || selectionEffect != null;
  bool get documentReplaced => touchedSet.documentReplaced;
}

sealed class CommitSelectionEffect {
  const CommitSelectionEffect();
}

final class PruneSelectionEffect extends CommitSelectionEffect {
  const PruneSelectionEffect();
}

final class ReplaceSelectionEffect extends CommitSelectionEffect {
  ReplaceSelectionEffect(Iterable<CanvasElementId> elementIds)
    : elementIds = List.unmodifiable(elementIds);

  final List<CanvasElementId> elementIds;
}

sealed class CommitEffect {
  const CommitEffect();
}

final class ProjectionEffect extends CommitEffect {
  const ProjectionEffect();
}

final class SpatialEffect extends CommitEffect {
  const SpatialEffect({required this.touchedSet});

  final TouchedSet touchedSet;
}

final class ResourceEffect extends CommitEffect {
  const ResourceEffect({required this.touchedSet});

  final TouchedSet touchedSet;
}

final class RepaintEffect extends CommitEffect {
  const RepaintEffect({required this.mainCanvas, this.overlayCanvas = false});

  final bool mainCanvas;
  final bool overlayCanvas;
}

final class SelectionEffect extends CommitEffect {
  const SelectionEffect();
}

final class PublicStateEffect extends CommitEffect {
  const PublicStateEffect();
}
