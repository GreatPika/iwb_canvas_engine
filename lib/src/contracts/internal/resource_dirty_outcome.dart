import '../public/canvas_ids.dart';

final class ResourceDirtyOutcome {
  ResourceDirtyOutcome({
    Iterable<CanvasResourceId> dirtyResourceIds = const [],
    this.allResourcesDirty = false,
  }) : dirtyResourceIds = Set.unmodifiable(dirtyResourceIds);

  final Set<CanvasResourceId> dirtyResourceIds;
  final bool allResourcesDirty;
  bool get hasDirtyResources =>
      allResourcesDirty || dirtyResourceIds.isNotEmpty;
}

abstract interface class ResourceDirtyOutcomeSink {
  void deliverResourceDirtyOutcome(ResourceDirtyOutcome outcome);
}
