import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_element.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';
import 'element_revision_delta.dart';

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
    final delta = elementRevisionDelta(before: before, after: after);

    return ElementUpdateCompileResult(
      revisionDelta: delta,
      touchesGeometry: delta.bounds,
      touchesSpatial: delta.bounds || before.isSelectable != after.isSelectable,
      touchesVisual: delta.elementVisual,
      transformsElement: before.transform != after.transform,
      prunesSelection: _requiresSelectionPrune(before, after),
    );
  }
}

final class ElementUpdateCompileResult {
  const ElementUpdateCompileResult({
    required this.revisionDelta,
    required this.touchesGeometry,
    required this.touchesSpatial,
    required this.touchesVisual,
    required this.transformsElement,
    required this.prunesSelection,
  });

  final StoreRevisionDelta revisionDelta;
  final bool touchesGeometry;
  final bool touchesSpatial;
  final bool touchesVisual;
  final bool transformsElement;
  final bool prunesSelection;
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

bool _requiresSelectionPrune(CanvasElement before, CanvasElement after) {
  return (before.isVisible && !after.isVisible) ||
      (before.isSelectable && !after.isSelectable);
}
