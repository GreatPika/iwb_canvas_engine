import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_element.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';
import 'element_update_compiler.dart' as element_update;

typedef ElementUpdateCompileResult = element_update.ElementUpdateCompileResult;

final class CommitCompiler {
  const CommitCompiler();

  CommitPlan compile({
    required StoreRevisionDelta revisionDelta,
    required TouchedSet touchedSet,
    CommitSelectionEffect? selectionEffect,
  }) {
    final effectiveSelectionEffect =
        selectionEffect ??
        (touchedSet.selection ? const PruneSelectionEffect() : null);
    if (!revisionDelta.hasChanges && effectiveSelectionEffect == null) {
      return CommitPlan.empty();
    }

    return CommitPlan(
      revisionDelta: revisionDelta,
      touchedSet: touchedSet,
      selectionEffect: effectiveSelectionEffect,
      effects: _effectsFor(
        revisionDelta,
        touchedSet,
        selectionChanged: effectiveSelectionEffect != null,
      ),
    );
  }

  ElementUpdateCompileResult compileElementUpdate({
    required CanvasElement before,
    required CanvasElement after,
  }) {
    return const element_update.ElementUpdateCompiler().compileElementUpdate(
      before: before,
      after: after,
    );
  }
}

List<CommitEffect> _effectsFor(
  StoreRevisionDelta revisionDelta,
  TouchedSet touchedSet, {
  required bool selectionChanged,
}) {
  if (touchedSet.documentReplaced) {
    return [
      const ProjectionEffect(),
      SpatialEffect(touchedSet: touchedSet),
      ResourceEffect(touchedSet: touchedSet),
      const RepaintEffect(mainCanvas: true),
      if (selectionChanged) const SelectionEffect(),
      const PublicStateEffect(),
    ];
  }

  return [
    if (revisionDelta.projection) const ProjectionEffect(),
    if (_needsSpatialEffect(revisionDelta, touchedSet))
      SpatialEffect(touchedSet: touchedSet),
    if (revisionDelta.resource) ResourceEffect(touchedSet: touchedSet),
    if (_needsMainRepaint(revisionDelta, touchedSet, selectionChanged))
      const RepaintEffect(mainCanvas: true),
    if (selectionChanged) const SelectionEffect(),
    if (revisionDelta.document || selectionChanged) const PublicStateEffect(),
  ];
}

bool _needsSpatialEffect(
  StoreRevisionDelta revisionDelta,
  TouchedSet touchedSet,
) {
  return revisionDelta.bounds ||
      touchedSet.geometryElementIds.isNotEmpty ||
      touchedSet.layerIds.isNotEmpty ||
      touchedSet.backgroundLayerChanged;
}

bool _needsMainRepaint(
  StoreRevisionDelta revisionDelta,
  TouchedSet touchedSet,
  bool selectionChanged,
) {
  return revisionDelta.structural ||
      revisionDelta.elementVisual ||
      revisionDelta.background ||
      revisionDelta.grid ||
      touchedSet.resourceVisualChangedIds.isNotEmpty ||
      selectionChanged;
}
