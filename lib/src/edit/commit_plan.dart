import '../store/store_revision_delta.dart';
import 'touched_set.dart';

final class CommitPlan {
  CommitPlan({
    required this.revisionDelta,
    required this.touchedSet,
    Iterable<CommitEffect> effects = const [],
  }) : effects = List.unmodifiable(effects);

  factory CommitPlan.empty() {
    return CommitPlan(
      revisionDelta: const StoreRevisionDelta(),
      touchedSet: TouchedSet(),
    );
  }

  final StoreRevisionDelta revisionDelta;
  final TouchedSet touchedSet;
  final List<CommitEffect> effects;

  bool get hasChanges => revisionDelta.hasChanges;
  bool get documentReplaced => touchedSet.documentReplaced;
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
