import '../contracts/internal/touched_set.dart';
import '../contracts/public/canvas_element.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

final class CommitCompiler {
  const CommitCompiler();

  CommitPlan compile({
    required StoreRevisionDelta revisionDelta,
    required TouchedSet touchedSet,
  }) {
    if (!revisionDelta.hasChanges) {
      return CommitPlan.empty();
    }

    return CommitPlan(
      revisionDelta: revisionDelta,
      touchedSet: touchedSet,
      effects: _effectsFor(revisionDelta, touchedSet),
    );
  }

  ElementUpdateCompileResult compileElementUpdate({
    required CanvasElement before,
    required CanvasElement after,
  }) {
    final delta = _elementUpdateDelta(before, after);

    return ElementUpdateCompileResult(
      revisionDelta: delta,
      touchesGeometry: delta.bounds,
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
    required this.touchesVisual,
    required this.transformsElement,
    required this.prunesSelection,
  });

  final StoreRevisionDelta revisionDelta;
  final bool touchesGeometry;
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
    if (revisionDelta.bounds) SpatialEffect(touchedSet: touchedSet),
    if (revisionDelta.resource) ResourceEffect(touchedSet: touchedSet),
    if (_needsMainRepaint(revisionDelta, touchedSet))
      const RepaintEffect(mainCanvas: true),
    if (touchedSet.selection) const SelectionEffect(),
    if (revisionDelta.document) const PublicStateEffect(),
  ];
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

StoreRevisionDelta _elementUpdateDelta(
  CanvasElement before,
  CanvasElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.transform != after.transform ||
      before.isVisible != after.isVisible) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.opacity != after.opacity) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }
  if (before.hitPadding != after.hitPadding) {
    delta = delta.merge(const StoreRevisionDelta.elementBoundsOnly());
  }
  if (before.isSelectable != after.isSelectable ||
      before.isLocked != after.isLocked ||
      before.isDeletable != after.isDeletable ||
      before.isTransformable != after.isTransformable ||
      before.metadata != after.metadata) {
    delta = delta.merge(const StoreRevisionDelta.projectionOnly());
  }

  return delta.merge(_familyElementUpdateDelta(before, after));
}

bool _requiresSelectionPrune(CanvasElement before, CanvasElement after) {
  return (before.isVisible && !after.isVisible) ||
      (before.isSelectable && !after.isSelectable);
}

StoreRevisionDelta _familyElementUpdateDelta(
  CanvasElement before,
  CanvasElement after,
) {
  return switch ((before, after)) {
    (final CanvasImageElement before, final CanvasImageElement after) =>
      _imageUpdateDelta(before, after),
    (final CanvasPathElement before, final CanvasPathElement after) =>
      _pathUpdateDelta(before, after),
    (final CanvasTextElement before, final CanvasTextElement after) =>
      _textUpdateDelta(before, after),
    (final CanvasStrokeElement before, final CanvasStrokeElement after) =>
      _strokeUpdateDelta(before, after),
    (final CanvasLineElement before, final CanvasLineElement after) =>
      _lineUpdateDelta(before, after),
    (final CanvasRectElement before, final CanvasRectElement after) =>
      _rectUpdateDelta(before, after),
    _ => const StoreRevisionDelta(),
  };
}

StoreRevisionDelta _imageUpdateDelta(
  CanvasImageElement before,
  CanvasImageElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.size != after.size) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.resourceId != after.resourceId ||
      before.naturalSize != after.naturalSize) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _pathUpdateDelta(
  CanvasPathElement before,
  CanvasPathElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.svgPathData != after.svgPathData ||
      before.strokeWidth != after.strokeWidth) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.fillColor != after.fillColor ||
      before.strokeColor != after.strokeColor ||
      before.fillRule != after.fillRule) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _textUpdateDelta(
  CanvasTextElement before,
  CanvasTextElement after,
) {
  var delta = const StoreRevisionDelta();
  if (_anyChanged([
    before.text != after.text,
    before.fontSize != after.fontSize,
    before.align != after.align,
    before.textDirection != after.textDirection,
    before.isBold != after.isBold,
    before.isItalic != after.isItalic,
    before.fontFamily != after.fontFamily,
    before.maxWidth != after.maxWidth,
    before.lineHeight != after.lineHeight,
  ])) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.color != after.color || before.isUnderline != after.isUnderline) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _strokeUpdateDelta(
  CanvasStrokeElement before,
  CanvasStrokeElement after,
) {
  var delta = const StoreRevisionDelta();
  if (!_sameList(before.points, after.points) ||
      before.thickness != after.thickness) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.color != after.color) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _lineUpdateDelta(
  CanvasLineElement before,
  CanvasLineElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.start != after.start ||
      before.end != after.end ||
      before.thickness != after.thickness) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.color != after.color) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

StoreRevisionDelta _rectUpdateDelta(
  CanvasRectElement before,
  CanvasRectElement after,
) {
  var delta = const StoreRevisionDelta();
  if (before.size != after.size || before.strokeWidth != after.strokeWidth) {
    delta = delta.merge(const StoreRevisionDelta.elementBounds());
  }
  if (before.fillColor != after.fillColor ||
      before.strokeColor != after.strokeColor) {
    delta = delta.merge(const StoreRevisionDelta.elementVisual());
  }

  return delta;
}

bool _anyChanged(Iterable<bool> changes) {
  return changes.any((changed) => changed);
}

bool _sameList<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}
