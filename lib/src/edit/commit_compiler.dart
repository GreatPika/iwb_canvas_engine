import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_element.dart';
import '../store/element_update_compiler.dart' as store_update;
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

typedef ElementUpdateCompileResult = store_update.ElementUpdateCompileResult;

final class CommitCompiler {
  const CommitCompiler();

  CommitPlan compile({
    required StoreRevisionDelta revisionDelta,
    required TouchedSet touchedSet,
  }) {
    final selectionEffect = touchedSet.selection
        ? const PruneSelectionEffect()
        : null;
    if (!revisionDelta.hasChanges && selectionEffect == null) {
      return CommitPlan.empty();
    }

    return CommitPlan(
      revisionDelta: revisionDelta,
      touchedSet: touchedSet,
      selectionEffect: selectionEffect,
      effects: _effectsFor(revisionDelta, touchedSet),
    );
  }

  ElementUpdateCompileResult compileElementUpdate({
    required CanvasElement before,
    required CanvasElement after,
  }) {
    return const store_update.ElementUpdateCompiler().compileElementUpdate(
      before: before,
      after: after,
    );
  }
}

List<CommitEffect> _effectsFor(
  StoreRevisionDelta revisionDelta,
  TouchedSet touchedSet,
) {
  if (touchedSet.documentReplaced) {
    return [
      const ProjectionEffect(),
      SpatialEffect(touchedSet: touchedSet),
      ResourceEffect(touchedSet: touchedSet),
      const RepaintEffect(mainCanvas: true),
      if (touchedSet.selection) const SelectionEffect(),
      const PublicStateEffect(),
    ];
  }

  return [
    if (revisionDelta.projection) const ProjectionEffect(),
    if (_needsSpatialEffect(revisionDelta, touchedSet))
      SpatialEffect(touchedSet: touchedSet),
    if (revisionDelta.resource) ResourceEffect(touchedSet: touchedSet),
    if (_needsMainRepaint(revisionDelta, touchedSet))
      const RepaintEffect(mainCanvas: true),
    if (touchedSet.selection) const SelectionEffect(),
    if (revisionDelta.document || touchedSet.selection)
      const PublicStateEffect(),
  ];
}

bool _needsSpatialEffect(
  StoreRevisionDelta revisionDelta,
  TouchedSet touchedSet,
) {
  return revisionDelta.bounds ||
      touchedSet.geometryElementIds.isNotEmpty ||
      touchedSet.layerIds.isNotEmpty;
}

bool _needsMainRepaint(
  StoreRevisionDelta revisionDelta,
  TouchedSet touchedSet,
) {
  return revisionDelta.structural ||
      revisionDelta.elementVisual ||
      revisionDelta.background ||
      revisionDelta.grid ||
      touchedSet.resourceVisualChangedIds.isNotEmpty ||
      touchedSet.selection;
}
