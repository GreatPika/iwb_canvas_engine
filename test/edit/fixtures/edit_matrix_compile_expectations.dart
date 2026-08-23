import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/edit/commit_compiler.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

typedef EditMatrixTaxonomyExpectation = ({
  String token,
  CanvasElement before,
  CanvasElement after,
  EditMatrixExpectedRevisionDelta expectedDelta,
  bool transformsElement,
  bool prunesSelection,
  bool touchesSpatial,
});

void expectEditMatrixTaxonomyEffects(EditMatrixTaxonomyExpectation expected) {
  final result = const CommitCompiler().compileElementUpdate(
    before: expected.before,
    after: expected.after,
  );
  _expectTaxonomyCompileFacts(expected, result);
  _expectTaxonomyPlanEffects(expected, result);
}

void _expectTaxonomyCompileFacts(
  EditMatrixTaxonomyExpectation expected,
  ElementUpdateCompileResult result,
) {
  expect(
    result.revisionDelta,
    _matchesRevisionDelta(expected.expectedDelta),
    reason: expected.token,
  );
  expect(
    result.touchesGeometry,
    expected.expectedDelta.bounds,
    reason: expected.token,
  );
  expect(
    result.touchesSpatial,
    expected.touchesSpatial || expected.expectedDelta.bounds,
    reason: expected.token,
  );
  expect(
    result.touchesVisual,
    expected.expectedDelta.elementVisual,
    reason: expected.token,
  );
  expect(
    result.transformsElement,
    expected.transformsElement,
    reason: expected.token,
  );
  expect(
    result.prunesSelection,
    expected.prunesSelection,
    reason: expected.token,
  );
}

void _expectTaxonomyPlanEffects(
  EditMatrixTaxonomyExpectation expected,
  ElementUpdateCompileResult result,
) {
  final plan = const CommitCompiler().compile(
    revisionDelta: result.revisionDelta,
    touchedSet: TouchedSet(
      geometryElementIds: result.touchesSpatial
          ? [expected.after.id]
          : const [],
      selection: result.prunesSelection,
    ),
  );
  expect(
    plan.effects.whereType<ProjectionEffect>(),
    hasLength(1),
    reason: expected.token,
  );
  expect(
    plan.effects.whereType<SpatialEffect>(),
    result.touchesSpatial ? hasLength(1) : isEmpty,
    reason: expected.token,
  );
  expect(
    plan.effects.whereType<RepaintEffect>(),
    expected.expectedDelta.elementVisual || result.prunesSelection
        ? hasLength(1)
        : isEmpty,
    reason: expected.token,
  );
  expect(
    plan.effects.whereType<SelectionEffect>(),
    result.prunesSelection ? hasLength(1) : isEmpty,
    reason: expected.token,
  );
}

void expectEditMatrixPlanEffects(
  String row,
  CommitPlan plan,
  EditMatrixExpectedPlanEffects expected,
) {
  expect(
    plan.revisionDelta,
    _matchesRevisionDelta(expected.delta),
    reason: row,
  );
  expect(plan.documentReplaced, expected.documentReplaced, reason: row);
  expect(
    plan.effects.whereType<ProjectionEffect>(),
    expected.projectionEffect ? hasLength(1) : isEmpty,
    reason: row,
  );
  expect(
    plan.effects.whereType<SpatialEffect>(),
    expected.spatialEffect ? hasLength(1) : isEmpty,
    reason: row,
  );
  expect(
    plan.effects.whereType<ResourceEffect>(),
    expected.resourceEffect ? hasLength(1) : isEmpty,
    reason: row,
  );
  expect(
    plan.effects.whereType<RepaintEffect>(),
    expected.repaintEffect ? hasLength(1) : isEmpty,
    reason: row,
  );
  expect(
    plan.effects.whereType<SelectionEffect>(),
    expected.selectionEffect ? hasLength(1) : isEmpty,
    reason: row,
  );
  expect(
    plan.effects.whereType<PublicStateEffect>(),
    expected.publicStateEffect ? hasLength(1) : isEmpty,
    reason: row,
  );
}

Matcher _matchesRevisionDelta(EditMatrixExpectedRevisionDelta expected) {
  return isA<StoreRevisionDelta>()
      .having((delta) => delta.document, 'document', expected.document)
      .having((delta) => delta.projection, 'projection', expected.projection)
      .having((delta) => delta.structural, 'structural', expected.structural)
      .having((delta) => delta.bounds, 'bounds', expected.bounds)
      .having(
        (delta) => delta.elementVisual,
        'elementVisual',
        expected.elementVisual,
      )
      .having((delta) => delta.background, 'background', expected.background)
      .having((delta) => delta.grid, 'grid', expected.grid)
      .having((delta) => delta.resource, 'resource', expected.resource);
}

final class EditMatrixExpectedPlanEffects {
  const EditMatrixExpectedPlanEffects({
    required this.delta,
    required this.projectionEffect,
    required this.spatialEffect,
    required this.resourceEffect,
    required this.repaintEffect,
    required this.selectionEffect,
    required this.publicStateEffect,
    this.documentReplaced = false,
  });

  final EditMatrixExpectedRevisionDelta delta;
  final bool documentReplaced;
  final bool projectionEffect;
  final bool spatialEffect;
  final bool resourceEffect;
  final bool repaintEffect;
  final bool selectionEffect;
  final bool publicStateEffect;
}

const editMatrixEmptyPlanEffects = EditMatrixExpectedPlanEffects(
  delta: EditMatrixExpectedRevisionDelta(),
  projectionEffect: false,
  spatialEffect: false,
  resourceEffect: false,
  repaintEffect: false,
  selectionEffect: false,
  publicStateEffect: false,
);

const editMatrixStructuralPlanEffects = EditMatrixExpectedPlanEffects(
  delta: EditMatrixExpectedRevisionDelta(
    document: true,
    projection: true,
    structural: true,
    bounds: true,
    elementVisual: true,
  ),
  projectionEffect: true,
  spatialEffect: true,
  resourceEffect: false,
  repaintEffect: true,
  selectionEffect: false,
  publicStateEffect: true,
);

const editMatrixLayerStructuralPlanEffects = EditMatrixExpectedPlanEffects(
  delta: EditMatrixExpectedRevisionDelta(
    document: true,
    projection: true,
    structural: true,
  ),
  projectionEffect: true,
  spatialEffect: true,
  resourceEffect: false,
  repaintEffect: true,
  selectionEffect: false,
  publicStateEffect: true,
);

const editMatrixElementVisualPlanEffects = EditMatrixExpectedPlanEffects(
  delta: EditMatrixExpectedRevisionDelta(
    document: true,
    projection: true,
    elementVisual: true,
  ),
  projectionEffect: true,
  spatialEffect: false,
  resourceEffect: false,
  repaintEffect: true,
  selectionEffect: false,
  publicStateEffect: true,
);

const editMatrixProjectionOnlyPlanEffects = EditMatrixExpectedPlanEffects(
  delta: EditMatrixExpectedRevisionDelta(document: true, projection: true),
  projectionEffect: true,
  spatialEffect: false,
  resourceEffect: false,
  repaintEffect: false,
  selectionEffect: false,
  publicStateEffect: true,
);

const editMatrixBackgroundPlanEffects = EditMatrixExpectedPlanEffects(
  delta: EditMatrixExpectedRevisionDelta(
    document: true,
    projection: true,
    background: true,
  ),
  projectionEffect: true,
  spatialEffect: false,
  resourceEffect: false,
  repaintEffect: true,
  selectionEffect: false,
  publicStateEffect: true,
);

const editMatrixGridPlanEffects = EditMatrixExpectedPlanEffects(
  delta: EditMatrixExpectedRevisionDelta(
    document: true,
    projection: true,
    grid: true,
  ),
  projectionEffect: true,
  spatialEffect: false,
  resourceEffect: false,
  repaintEffect: true,
  selectionEffect: false,
  publicStateEffect: true,
);

const editMatrixClearContentPlanEffects = EditMatrixExpectedPlanEffects(
  delta: EditMatrixExpectedRevisionDelta(
    document: true,
    projection: true,
    structural: true,
    bounds: true,
    elementVisual: true,
    resource: true,
  ),
  projectionEffect: true,
  spatialEffect: true,
  resourceEffect: true,
  repaintEffect: true,
  selectionEffect: true,
  publicStateEffect: true,
);

const editMatrixReferencedResourcePlanEffects = EditMatrixExpectedPlanEffects(
  delta: EditMatrixExpectedRevisionDelta(
    document: true,
    projection: true,
    resource: true,
  ),
  projectionEffect: true,
  spatialEffect: false,
  resourceEffect: true,
  repaintEffect: true,
  selectionEffect: false,
  publicStateEffect: true,
);

const editMatrixUnusedResourceRemovalPlanEffects =
    EditMatrixExpectedPlanEffects(
      delta: EditMatrixExpectedRevisionDelta(
        document: true,
        projection: true,
        resource: true,
      ),
      projectionEffect: true,
      spatialEffect: false,
      resourceEffect: true,
      repaintEffect: false,
      selectionEffect: false,
      publicStateEffect: true,
    );

const editMatrixDocumentReplacementPlanEffectsWithSelection =
    EditMatrixExpectedPlanEffects(
      delta: EditMatrixExpectedRevisionDelta(
        document: true,
        projection: true,
        structural: true,
        bounds: true,
        elementVisual: true,
        background: true,
        grid: true,
        resource: true,
      ),
      documentReplaced: true,
      projectionEffect: true,
      spatialEffect: true,
      resourceEffect: true,
      repaintEffect: true,
      selectionEffect: true,
      publicStateEffect: true,
    );

final class EditMatrixExpectedRevisionDelta {
  const EditMatrixExpectedRevisionDelta({
    this.document = false,
    this.projection = false,
    this.structural = false,
    this.bounds = false,
    this.elementVisual = false,
    this.background = false,
    this.grid = false,
    this.resource = false,
  });

  const EditMatrixExpectedRevisionDelta.projectionOnly()
    : this(document: true, projection: true);

  const EditMatrixExpectedRevisionDelta.elementVisual()
    : this(document: true, projection: true, elementVisual: true);

  const EditMatrixExpectedRevisionDelta.elementBoundsOnly()
    : this(document: true, projection: true, bounds: true);

  const EditMatrixExpectedRevisionDelta.elementBounds()
    : this(document: true, projection: true, bounds: true, elementVisual: true);

  final bool document;
  final bool projection;
  final bool structural;
  final bool bounds;
  final bool elementVisual;
  final bool background;
  final bool grid;
  final bool resource;
}
