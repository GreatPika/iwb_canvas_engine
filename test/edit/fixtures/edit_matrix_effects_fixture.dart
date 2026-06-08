import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/edit/commit_compiler.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

void main() {
  _registerBasicEditRows();
  _registerOperationMatrixRows();
  _registerTaxonomyRows();
}

void _registerBasicEditRows() {
  test('accepted content add installs after callback commit', () {
    expect(_expectAddElementInstallsAfterCommit, returnsNormally);
  });

  test('ensureLayer advances structural revision without frame facts', () {
    expect(_expectEnsureLayerRevisionFamilies, returnsNormally);
  });

  test('duplicate and missing resource admission use public error codes', () {
    expect(_expectAdmissionErrorsUsePublicCodes, returnsNormally);
  });

  test('image resource update validates descriptors before install', () {
    expect(_expectImageResourceUpdatePreflightsDescriptor, returnsNormally);
  });

  test('removeUnusedResource is false for missing or referenced resources', () {
    expect(_expectRemoveUnusedResourceNoOps, returnsNormally);
  });

  test('removeUnusedResource removes only unused descriptors', () {
    expect(_expectUnusedResourceRemovalInstalls, returnsNormally);
  });
}

void _registerOperationMatrixRows() {
  test('edit operation matrix rows install expected public effects', () {
    expect(_expectEditOperationRowsInstallEffects, returnsNormally);
  });

  test('edit operation matrix coverage lists every required row once', () {
    expect(_expectEditOperationMatrixCoverage, returnsNormally);
  });

  test('edit operation matrix rows compile expected typed effects', () {
    expect(_expectEditOperationRowsCompileEffects, returnsNormally);
  });

  test('edit operation matrix rows rollback without public effects', () {
    return expectLater(_expectEditOperationRowsRollback(), completes);
  });

  test('edit operation matrix rows emit no user actions', () {
    return expectLater(_expectEditOperationRowsEmitNoActions(), completes);
  });
}

void _registerTaxonomyRows() {
  test('updateElement taxonomy tokens compile expected effects', () {
    expect(_expectUpdateTaxonomyEffects, returnsNormally);
  });
}

final _editOperationMatrixCases = [
  const _EditOperationMatrixCase(
    'addElement content',
    _expectAddElementInstallsAfterCommit,
    _documentWithUnusedResource,
    _draftAddElement,
    _editAddElement,
    _ExpectedPlanEffects.structural(),
  ),
  const _EditOperationMatrixCase(
    'addBackgroundElement',
    _expectBackgroundElementRow,
    _documentWithUnusedResource,
    _draftAddBackgroundElement,
    _editAddBackgroundElement,
    _ExpectedPlanEffects.structural(),
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.updateElement',
    _expectUpdateElementRow,
    _documentWithUnusedResource,
    _draftUpdateElementVisual,
    _editUpdateElementVisual,
    _ExpectedPlanEffects.elementVisual(),
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.removeElement',
    _expectRemoveElementRow,
    _documentWithUnusedResource,
    _draftRemoveElement,
    _editRemoveElement,
    _ExpectedPlanEffects.structural(),
  ),
  const _EditOperationMatrixCase(
    'ensureLayer no-op',
    _expectEnsureLayerNoOpRow,
    _documentWithUnusedResource,
    _draftEnsureLayerNoOp,
    _editEnsureLayerNoOp,
    _ExpectedPlanEffects.empty(),
  ),
  const _EditOperationMatrixCase(
    'ensureLayer changed',
    _expectEnsureLayerRevisionFamilies,
    _documentWithUnusedResource,
    _draftEnsureLayerChanged,
    _editEnsureLayerChanged,
    _ExpectedPlanEffects.layerStructural(),
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.clearContent',
    _expectClearContentRow,
    _documentWithReferencedResource,
    _draftClearContent,
    _editClearContent,
    _ExpectedPlanEffects.clearContent(),
    selectedElementIds: {'image-1'},
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.setCameraOffset',
    _expectPersistedCameraRow,
    _documentWithUnusedResource,
    _draftSetCameraOffset,
    _editSetCameraOffset,
    _ExpectedPlanEffects.projectionOnly(),
  ),
  const _EditOperationMatrixCase(
    'setBackgroundColor',
    _expectBackgroundRow,
    _documentWithUnusedResource,
    _draftSetBackgroundColor,
    _editSetBackgroundColor,
    _ExpectedPlanEffects.background(),
  ),
  const _EditOperationMatrixCase(
    'setGrid',
    _expectGridRow,
    _documentWithUnusedResource,
    _draftSetGrid,
    _editSetGrid,
    _ExpectedPlanEffects.grid(),
  ),
  const _EditOperationMatrixCase(
    'setPalette',
    _expectPaletteRow,
    _documentWithUnusedResource,
    _draftSetPalette,
    _editSetPalette,
    _ExpectedPlanEffects.projectionOnly(),
  ),
  const _EditOperationMatrixCase(
    'upsertResource new/changed',
    _expectUpsertResourceRow,
    _documentWithReferencedResource,
    _draftUpsertReferencedResource,
    _editUpsertReferencedResource,
    _ExpectedPlanEffects.referencedResource(),
  ),
  const _EditOperationMatrixCase(
    'removeUnusedResource removed',
    _expectUnusedResourceRemovalInstalls,
    _documentWithUnusedResource,
    _draftRemoveUnusedResource,
    _editRemoveUnusedResource,
    _ExpectedPlanEffects.unusedResourceRemoval(),
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.replaceDraftDocument',
    _expectReplaceDraftDocumentRow,
    _documentWithUnusedResource,
    _draftReplaceDocument,
    _editReplaceDocument,
    _ExpectedPlanEffects.documentReplacement(selectionEffect: true),
    selectedElementIds: {'rect-1'},
  ),
  const _EditOperationMatrixCase(
    'no-op edit',
    _expectNoOpEditRow,
    _documentWithUnusedResource,
    _draftNoOp,
    _editNoOp,
    _ExpectedPlanEffects.empty(),
  ),
];

const _requiredEditOperationRows = {
  'addElement content',
  'addBackgroundElement',
  'CanvasEdit.updateElement',
  'CanvasEdit.removeElement',
  'ensureLayer no-op',
  'ensureLayer changed',
  'CanvasEdit.clearContent',
  'CanvasEdit.setCameraOffset',
  'setBackgroundColor',
  'setGrid',
  'setPalette',
  'upsertResource new/changed',
  'removeUnusedResource removed',
  'CanvasEdit.replaceDraftDocument',
  'no-op edit',
};

final _updateTaxonomyCases = [
  _UpdateTaxonomyCase(
    'CanvasElementUpdate.transform',
    _rectElement(),
    _rectElement(transform: CanvasTransform.translation(const Offset(1, 2))),
    const _ExpectedRevisionDelta.elementBounds(),
    transformsElement: true,
  ),
  _UpdateTaxonomyCase(
    'CanvasElementUpdate.opacity',
    _rectElement(),
    _rectElement(opacity: 0.5),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasElementUpdate.hitPadding',
    _rectElement(),
    _rectElement(hitPadding: 4),
    const _ExpectedRevisionDelta.elementBoundsOnly(),
  ),
  _UpdateTaxonomyCase(
    'CanvasElementUpdate.isVisible',
    _rectElement(),
    _rectElement(isVisible: false),
    const _ExpectedRevisionDelta.elementBounds(),
    prunesSelection: true,
  ),
  _UpdateTaxonomyCase(
    'CanvasElementUpdate.isSelectable',
    _rectElement(),
    _rectElement(isSelectable: false),
    const _ExpectedRevisionDelta.projectionOnly(),
    prunesSelection: true,
    touchesSpatial: true,
  ),
  _UpdateTaxonomyCase(
    'CanvasElementUpdate.isLocked',
    _rectElement(),
    _rectElement(isLocked: true),
    const _ExpectedRevisionDelta.projectionOnly(),
  ),
  _UpdateTaxonomyCase(
    'CanvasElementUpdate.isDeletable',
    _rectElement(),
    _rectElement(isDeletable: false),
    const _ExpectedRevisionDelta.projectionOnly(),
  ),
  _UpdateTaxonomyCase(
    'CanvasElementUpdate.isTransformable',
    _rectElement(),
    _rectElement(isTransformable: false),
    const _ExpectedRevisionDelta.projectionOnly(),
  ),
  _UpdateTaxonomyCase(
    'CanvasElementUpdate.metadata',
    _rectElement(),
    _rectElement(metadata: CanvasMetadata.fromMap({'role': 'button'})),
    const _ExpectedRevisionDelta.projectionOnly(),
  ),
  _UpdateTaxonomyCase(
    'CanvasImageElementUpdate.resourceId',
    _imageElement(),
    _imageElement(resourceId: CanvasResourceId('resource-2')),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasImageElementUpdate.size',
    _imageElement(),
    _imageElement(size: const Size(2, 2)),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasImageElementUpdate.naturalSize',
    _imageElement(),
    _imageElement(naturalSize: const Size(4, 4)),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasPathElementUpdate.svgPathData',
    _pathElement(),
    _pathElement(svgPathData: 'M 0 0 L 2 2'),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasPathElementUpdate.fillColor',
    _pathElement(),
    _pathElement(fillColor: const Color(0xFF0000FF)),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasPathElementUpdate.strokeColor',
    _pathElement(strokeWidth: 2),
    _pathElement(strokeColor: const Color(0xFF00FF00), strokeWidth: 2),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasPathElementUpdate.strokeWidth',
    _pathElement(),
    _pathElement(strokeWidth: 2),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasPathElementUpdate.fillRule',
    _pathElement(),
    _pathElement(fillRule: CanvasPathFillRule.evenOdd),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.text',
    _textElement(),
    _textElement(text: 'changed'),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.fontSize',
    _textElement(),
    _textElement(fontSize: 32),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.align',
    _textElement(),
    _textElement(align: TextAlign.center),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.textDirection',
    _textElement(),
    _textElement(textDirection: TextDirection.rtl),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.isBold',
    _textElement(),
    _textElement(isBold: true),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.isItalic',
    _textElement(),
    _textElement(isItalic: true),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.fontFamily',
    _textElement(),
    _textElement(fontFamily: 'Inter'),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.maxWidth',
    _textElement(),
    _textElement(maxWidth: 42),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.lineHeight',
    _textElement(),
    _textElement(lineHeight: 1.4),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.color',
    _textElement(),
    _textElement(color: const Color(0xFF0000FF)),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasTextElementUpdate.isUnderline',
    _textElement(),
    _textElement(isUnderline: true),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasStrokeElementUpdate.points',
    _strokeElement(),
    _strokeElement(points: const [Offset.zero, Offset(2, 2)]),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasStrokeElementUpdate.thickness',
    _strokeElement(),
    _strokeElement(thickness: 3),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasStrokeElementUpdate.color',
    _strokeElement(),
    _strokeElement(color: const Color(0xFF0000FF)),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasLineElementUpdate.start',
    _lineElement(),
    _lineElement(start: const Offset(1, 1)),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasLineElementUpdate.end',
    _lineElement(),
    _lineElement(end: const Offset(3, 3)),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasLineElementUpdate.thickness',
    _lineElement(),
    _lineElement(thickness: 3),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasLineElementUpdate.color',
    _lineElement(),
    _lineElement(color: const Color(0xFF0000FF)),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasRectElementUpdate.size',
    _rectElement(),
    _rectElement(size: const Size(2, 2)),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasRectElementUpdate.strokeWidth',
    _rectElement(),
    _rectElement(strokeWidth: 2),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
  _UpdateTaxonomyCase(
    'CanvasRectElementUpdate.fillColor',
    _rectElement(),
    _rectElement(fillColor: const Color(0xFF0000FF)),
    const _ExpectedRevisionDelta.elementVisual(),
  ),
  _UpdateTaxonomyCase(
    'CanvasRectElementUpdate.strokeColor',
    _rectElement(strokeWidth: 2),
    _rectElement(strokeColor: const Color(0xFF00FF00), strokeWidth: 2),
    const _ExpectedRevisionDelta.elementBounds(),
  ),
];

void _expectAddElementInstallsAfterCommit() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final id = root.edits.edit((edit) {
    final addedId = edit.addElement(
      _rect('rect-2'),
      layerId: CanvasLayerId('layer-1'),
    );
    expect(root.readDocument().layers.single.elements, hasLength(1));
    expect(edit.readDraftDocument().layers.single.elements, hasLength(2));

    return addedId;
  });

  expect(id, CanvasElementId('rect-2'));
  expect(root.readDocument().layers.single.elements, hasLength(2));
  expect(root.documentFacts.documentRevision, 1);
  expect(root.documentFacts.structuralRevision, 1);
}

void _expectEnsureLayerNoOpRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final changed = root.edits.edit((edit) {
    return edit.ensureLayer(CanvasLayerId('layer-1'));
  });

  expect(changed, isFalse);
  expect(root.documentFacts.documentRevision, 0);
  expect(root.documentFacts.structuralRevision, 0);
  expect(root.frameRevisions.documentRevision, 0);
}

void _expectEnsureLayerRevisionFamilies() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final changed = root.edits.edit((edit) {
    return edit.ensureLayer(CanvasLayerId('layer-2'));
  });

  expect(changed, isTrue);
  expect(root.documentFacts.documentRevision, 1);
  expect(root.documentFacts.structuralRevision, 1);
  expect(root.frameRevisions.boundsRevision, 0);
  expect(root.frameRevisions.elementVisualRevision, 0);
}

void _expectAdmissionErrorsUsePublicCodes() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  expect(
    () => root.edits.edit((edit) {
      edit.addElement(_rect('rect-1'), layerId: CanvasLayerId('layer-1'));
    }),
    _throwsCanvasDataCode(CanvasDataErrorCode.duplicateElementId),
  );
  expect(
    () => root.edits.edit((edit) {
      edit.addElement(
        CanvasImageElement(
          id: CanvasElementId('image-2'),
          resourceId: CanvasResourceId('missing-resource'),
          size: const Size(1, 1),
        ),
        layerId: CanvasLayerId('layer-1'),
      );
    }),
    _throwsCanvasDataCode(CanvasDataErrorCode.missingResourceReference),
  );
  expect(root.readDocument().layers.single.elements, hasLength(1));
  expect(root.documentFacts.documentRevision, 0);
}

void _expectImageResourceUpdatePreflightsDescriptor() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithReferencedResource(),
    config: const CanvasRuntimeConfig(),
  );

  expect(
    () => root.edits.edit((edit) {
      edit.updateElement(
        CanvasImageElementUpdate(
          id: CanvasElementId('image-1'),
          resourceId: CanvasFieldSet(CanvasResourceId('missing-resource')),
        ),
      );
    }),
    _throwsCanvasDataCode(CanvasDataErrorCode.missingResourceReference),
  );

  expect(root.documentFacts.documentRevision, 0);
  expect(
    (root.readDocument().layers.single.elements.single as CanvasImageElement)
        .resourceId,
    CanvasResourceId('resource-1'),
  );
}

void _expectRemoveUnusedResourceNoOps() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithReferencedResource(),
    config: const CanvasRuntimeConfig(),
  );
  final before = root.readDocument();

  final missing = root.edits.edit((edit) {
    return edit.removeUnusedResource(CanvasResourceId('missing-resource'));
  });
  final referenced = root.edits.edit((edit) {
    return edit.removeUnusedResource(CanvasResourceId('resource-1'));
  });

  expect(missing, isFalse);
  expect(referenced, isFalse);
  expect(root.readDocument(), same(before));
  expect(root.documentFacts.documentRevision, 0);
  expect(root.frameRevisions.resourceRevision, 0);
}

void _expectUnusedResourceRemovalInstalls() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final removed = root.edits.edit((edit) {
    return edit.removeUnusedResource(CanvasResourceId('resource-1'));
  });

  expect(removed, isTrue);
  expect(root.readDocument().resources, isEmpty);
  expect(root.documentFacts.documentRevision, 1);
  expect(root.frameRevisions.resourceRevision, 1);
}

void _expectEditOperationRowsInstallEffects() {
  for (final operationCase in _editOperationMatrixCases) {
    expect(operationCase.row, isNotEmpty);
    operationCase.run();
  }
}

void _expectEditOperationMatrixCoverage() {
  final rows = [
    for (final operationCase in _editOperationMatrixCases) operationCase.row,
  ];

  expect(rows.toSet(), _requiredEditOperationRows);
  expect(rows, hasLength(rows.toSet().length));
}

void _expectEditOperationRowsCompileEffects() {
  for (final operationCase in _editOperationMatrixCases) {
    final draft = DraftDocument(
      operationCase.document(),
      selectedElementIds: [
        for (final id in operationCase.selectedElementIds) CanvasElementId(id),
      ],
    );
    operationCase.mutateDraft(draft);
    _expectPlanEffects(
      operationCase.row,
      draft.commitPlan,
      operationCase.expectedPlanEffects,
    );
  }
}

Future<void> _expectEditOperationRowsRollback() async {
  for (final operationCase in _editOperationMatrixCases) {
    final root = runtimeRootWithCommittedDocumentSeed(
      operationCase.document(),
      config: const CanvasRuntimeConfig(),
    );
    final actions = <CanvasActionCommitted>[];
    final subscription = root.actions.listen(actions.add);
    final beforeDocument = root.readDocument();
    final beforeState = root.state.value;

    expect(
      () => root.edits.edit((edit) {
        operationCase.mutateEdit(edit);
        throw StateError('rollback ${operationCase.row}');
      }),
      throwsStateError,
      reason: operationCase.row,
    );
    await Future<void>.delayed(Duration.zero);

    expect(root.readDocument(), beforeDocument, reason: operationCase.row);
    expect(root.state.value, beforeState, reason: operationCase.row);
    expect(actions, isEmpty, reason: operationCase.row);
    await subscription.cancel();
  }
}

Future<void> _expectEditOperationRowsEmitNoActions() async {
  for (final operationCase in _editOperationMatrixCases) {
    final root = runtimeRootWithCommittedDocumentSeed(
      operationCase.document(),
      config: const CanvasRuntimeConfig(),
    );
    final actions = <CanvasActionCommitted>[];
    final subscription = root.actions.listen(actions.add);

    root.edits.edit(operationCase.mutateEdit);
    await Future<void>.delayed(Duration.zero);

    expect(actions, isEmpty, reason: operationCase.row);
    await subscription.cancel();
  }
}

void _expectUpdateTaxonomyEffects() {
  for (final taxonomyCase in _updateTaxonomyCases) {
    final result = const CommitCompiler().compileElementUpdate(
      before: taxonomyCase.before,
      after: taxonomyCase.after,
    );
    _expectTaxonomyCompileResult(taxonomyCase, result);
    _expectTaxonomyPlanEffects(taxonomyCase, result);
  }
}

void _expectTaxonomyCompileResult(
  _UpdateTaxonomyCase taxonomyCase,
  ElementUpdateCompileResult result,
) {
  expect(
    result.revisionDelta,
    _matchesRevisionDelta(taxonomyCase.expectedDelta),
    reason: taxonomyCase.token,
  );
  expect(
    result.touchesGeometry,
    taxonomyCase.expectedDelta.bounds,
    reason: taxonomyCase.token,
  );
  expect(
    result.touchesSpatial,
    taxonomyCase.touchesSpatial || taxonomyCase.expectedDelta.bounds,
    reason: taxonomyCase.token,
  );
  expect(
    result.touchesVisual,
    taxonomyCase.expectedDelta.elementVisual,
    reason: taxonomyCase.token,
  );
  expect(
    result.transformsElement,
    taxonomyCase.transformsElement,
    reason: taxonomyCase.token,
  );
  expect(
    result.prunesSelection,
    taxonomyCase.prunesSelection,
    reason: taxonomyCase.token,
  );
}

void _expectTaxonomyPlanEffects(
  _UpdateTaxonomyCase taxonomyCase,
  ElementUpdateCompileResult result,
) {
  final plan = const CommitCompiler().compile(
    revisionDelta: result.revisionDelta,
    touchedSet: TouchedSet(
      geometryElementIds: result.touchesSpatial
          ? [taxonomyCase.after.id]
          : const [],
      selection: result.prunesSelection,
    ),
  );
  expect(
    plan.effects.whereType<ProjectionEffect>(),
    hasLength(1),
    reason: taxonomyCase.token,
  );
  expect(
    plan.effects.whereType<SpatialEffect>(),
    result.touchesSpatial ? hasLength(1) : isEmpty,
    reason: taxonomyCase.token,
  );
  expect(
    plan.effects.whereType<RepaintEffect>(),
    taxonomyCase.expectedDelta.elementVisual || result.prunesSelection
        ? hasLength(1)
        : isEmpty,
    reason: taxonomyCase.token,
  );
  expect(
    plan.effects.whereType<SelectionEffect>(),
    result.prunesSelection ? hasLength(1) : isEmpty,
    reason: taxonomyCase.token,
  );
}

void _expectPlanEffects(
  String row,
  CommitPlan plan,
  _ExpectedPlanEffects expected,
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

void _expectBackgroundElementRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final id = root.edits.edit((edit) {
    return edit.addBackgroundElement(_rect('background-1'));
  });

  expect(id, CanvasElementId('background-1'));
  expect(root.readDocument().backgroundElements.single.id, id);
  _expectFrameRevisions(root, structural: 1, bounds: 1, elementVisual: 1);
}

void _expectUpdateElementRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final changed = root.edits.edit((edit) {
    return edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('rect-1'),
        fillColor: const CanvasFieldSet(Color(0xFF0000FF)),
      ),
    );
  });

  expect(changed, isTrue);
  _expectFrameRevisions(root, elementVisual: 1);
}

void _expectRemoveElementRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final removed = root.edits.edit((edit) {
    return edit.removeElement(CanvasElementId('rect-1'));
  });

  expect(removed, isTrue);
  expect(root.readDocument().layers.single.elements, isEmpty);
  _expectFrameRevisions(root, structural: 1, bounds: 1, elementVisual: 1);
}

void _expectClearContentRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithReferencedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final result = root.edits.edit((edit) {
    return edit.clearContent(removeUnusedResources: true);
  });

  expect(result.didClearContent, isTrue);
  expect(result.removedElementIds, {CanvasElementId('image-1')});
  expect(result.removedResourceIds, {CanvasResourceId('resource-1')});
  expect(root.readDocument().layers.single.elements, isEmpty);
  expect(root.readDocument().resources, isEmpty);
  _expectFrameRevisions(
    root,
    structural: 1,
    bounds: 1,
    elementVisual: 1,
    resource: 1,
  );
}

void _expectPersistedCameraRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  root.edits.edit((edit) {
    edit.setCameraOffset(const Offset(6, 7));
  });

  expect(root.readDocument().camera.offset, const Offset(6, 7));
  _expectFrameRevisions(root);
}

void _expectBackgroundRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  root.edits.edit((edit) {
    edit.setBackgroundColor(const Color(0xFF112233));
  });

  expect(root.readDocument().background.color, const Color(0xFF112233));
  _expectFrameRevisions(root, background: 1);
}

void _expectGridRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );
  final grid = CanvasGrid(enabled: true, cellSize: 24);

  root.edits.edit((edit) {
    edit.setGrid(grid);
  });

  expect(root.readDocument().background.grid, grid);
  _expectFrameRevisions(root, grid: 1);
}

void _expectPaletteRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );
  final palette = CanvasPalette(
    penColors: const [Color(0xFF000000), Color(0xFFFFFFFF)],
    backgroundColors: const [Color(0xFF112233)],
    gridSizes: const [8, 16],
  );

  root.edits.edit((edit) {
    edit.setPalette(palette);
  });

  final installed = root.readDocument().palette;
  expect(installed.penColors, palette.penColors);
  expect(installed.backgroundColors, palette.backgroundColors);
  expect(installed.gridSizes, palette.gridSizes);
  _expectFrameRevisions(root);
}

void _expectUpsertResourceRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithReferencedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final changed = root.edits.edit((edit) {
    return edit.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1-updated'),
      ),
    );
  });

  expect(changed, isTrue);
  expect(
    root.resourceDescriptor(CanvasResourceId('resource-1'))?.appKey,
    'resource-1-updated',
  );
  _expectFrameRevisions(root, resource: 1);
}

void _expectNoOpEditRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );
  var notifications = 0;
  root.state.addListener(() {
    notifications += 1;
  });

  root.edits.edit((edit) {
    expect(edit.draftSummary.elementCount, 1);
  });

  expect(notifications, 0);
  expect(root.documentFacts.documentRevision, 0);
  expect(root.frameRevisions.documentRevision, 0);
}

void _expectReplaceDraftDocumentRow() {
  _expectReplacementClearsRemovedSelection();
  _expectReplacementClearsIneligibleSelection();
}

void _expectReplacementClearsRemovedSelection() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );
  root.selection.setSelection([CanvasElementId('rect-1')]);
  final beforeSelectionRevision = root.state.value.revisions.selection;

  root.edits.edit(_editReplaceDocument);

  expect(root.readDocument().backgroundElements.single.id.value, 'replacement');
  expect(root.readDocument().layers, isEmpty);
  expect(root.selectedElementIds, isEmpty);
  _expectFrameRevisions(
    root,
    structural: 1,
    bounds: 1,
    elementVisual: 1,
    background: 1,
    grid: 1,
    resource: 1,
  );
  expect(root.state.value.revisions.selection, beforeSelectionRevision + 1);
  expect(root.state.value.revisions.epoch, 1);
  expect(root.generateElementId(), CanvasElementId('e0'));
}

void _expectReplacementClearsIneligibleSelection() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );
  root.selection.setSelection([CanvasElementId('rect-1')]);

  root.edits.edit((edit) {
    edit.replaceDraftDocument(
      CanvasDocument(
        backgroundElements: [
          CanvasRectElement(
            id: CanvasElementId('rect-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    );
  });

  expect(root.selectedElementIds, isEmpty);
}

void _draftAddElement(DraftDocument draft) {
  draft.addElement(_rect('rect-2'), layerId: CanvasLayerId('layer-1'));
}

void _editAddElement(CanvasEdit edit) {
  edit.addElement(_rect('rect-2'), layerId: CanvasLayerId('layer-1'));
}

void _draftAddBackgroundElement(DraftDocument draft) {
  draft.addBackgroundElement(_rect('background-1'));
}

void _editAddBackgroundElement(CanvasEdit edit) {
  edit.addBackgroundElement(_rect('background-1'));
}

void _draftUpdateElementVisual(DraftDocument draft) {
  draft.updateElement(
    CanvasRectElementUpdate(
      id: CanvasElementId('rect-1'),
      fillColor: const CanvasFieldSet(Color(0xFF0000FF)),
    ),
  );
}

void _editUpdateElementVisual(CanvasEdit edit) {
  edit.updateElement(
    CanvasRectElementUpdate(
      id: CanvasElementId('rect-1'),
      fillColor: const CanvasFieldSet(Color(0xFF0000FF)),
    ),
  );
}

void _draftRemoveElement(DraftDocument draft) {
  draft.removeElement(CanvasElementId('rect-1'));
}

void _editRemoveElement(CanvasEdit edit) {
  edit.removeElement(CanvasElementId('rect-1'));
}

void _draftEnsureLayerNoOp(DraftDocument draft) {
  draft.ensureLayer(CanvasLayerId('layer-1'));
}

void _editEnsureLayerNoOp(CanvasEdit edit) {
  edit.ensureLayer(CanvasLayerId('layer-1'));
}

void _draftEnsureLayerChanged(DraftDocument draft) {
  draft.ensureLayer(CanvasLayerId('layer-2'));
}

void _editEnsureLayerChanged(CanvasEdit edit) {
  edit.ensureLayer(CanvasLayerId('layer-2'));
}

void _draftClearContent(DraftDocument draft) {
  draft.clearContent(removeUnusedResources: true);
}

void _editClearContent(CanvasEdit edit) {
  edit.clearContent(removeUnusedResources: true);
}

void _draftSetCameraOffset(DraftDocument draft) {
  draft.setCameraOffset(const Offset(6, 7));
}

void _editSetCameraOffset(CanvasEdit edit) {
  edit.setCameraOffset(const Offset(6, 7));
}

void _draftSetBackgroundColor(DraftDocument draft) {
  draft.setBackgroundColor(const Color(0xFF112233));
}

void _editSetBackgroundColor(CanvasEdit edit) {
  edit.setBackgroundColor(const Color(0xFF112233));
}

void _draftSetGrid(DraftDocument draft) {
  draft.setGrid(CanvasGrid(enabled: true, cellSize: 24));
}

void _editSetGrid(CanvasEdit edit) {
  edit.setGrid(CanvasGrid(enabled: true, cellSize: 24));
}

void _draftSetPalette(DraftDocument draft) {
  draft.setPalette(
    CanvasPalette(
      penColors: const [Color(0xFF000000), Color(0xFFFFFFFF)],
      backgroundColors: const [Color(0xFF112233)],
      gridSizes: const [8, 16],
    ),
  );
}

void _editSetPalette(CanvasEdit edit) {
  edit.setPalette(
    CanvasPalette(
      penColors: const [Color(0xFF000000), Color(0xFFFFFFFF)],
      backgroundColors: const [Color(0xFF112233)],
      gridSizes: const [8, 16],
    ),
  );
}

void _draftUpsertReferencedResource(DraftDocument draft) {
  draft.upsertResource(
    CanvasImageResource(
      id: CanvasResourceId('resource-1'),
      source: CanvasResourceSource.appKey('resource-1-updated'),
    ),
  );
}

void _editUpsertReferencedResource(CanvasEdit edit) {
  edit.upsertResource(
    CanvasImageResource(
      id: CanvasResourceId('resource-1'),
      source: CanvasResourceSource.appKey('resource-1-updated'),
    ),
  );
}

void _draftRemoveUnusedResource(DraftDocument draft) {
  draft.removeUnusedResource(CanvasResourceId('resource-1'));
}

void _editRemoveUnusedResource(CanvasEdit edit) {
  edit.removeUnusedResource(CanvasResourceId('resource-1'));
}

void _draftReplaceDocument(DraftDocument draft) {
  draft.replaceDocument(_replacementDocument());
}

void _editReplaceDocument(CanvasEdit edit) {
  edit.replaceDraftDocument(_replacementDocument());
}

void _draftNoOp(DraftDocument draft) {
  expect(draft.summary.elementCount, 1);
}

void _editNoOp(CanvasEdit edit) {
  expect(edit.draftSummary.elementCount, 1);
}

// Revision-family names are part of the matrix proof. Keeping them as explicit
// call-site parameters makes each row's expected effects auditable.
// ignore: number-of-parameters
void _expectFrameRevisions(
  RuntimeRoot root, {
  int structural = 0,
  int bounds = 0,
  int elementVisual = 0,
  int background = 0,
  int grid = 0,
  int resource = 0,
}) {
  expect(root.documentFacts.documentRevision, 1);
  expect(root.frameRevisions.documentRevision, 1);
  expect(root.documentFacts.structuralRevision, structural);
  expect(root.frameRevisions.structuralRevision, structural);
  expect(root.frameRevisions.boundsRevision, bounds);
  expect(root.frameRevisions.elementVisualRevision, elementVisual);
  expect(root.frameRevisions.backgroundRevision, background);
  expect(root.frameRevisions.gridRevision, grid);
  expect(root.frameRevisions.resourceRevision, resource);
}

Matcher _matchesRevisionDelta(_ExpectedRevisionDelta expected) {
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

Matcher _throwsCanvasDataCode(CanvasDataErrorCode code) {
  return throwsA(
    isA<CanvasDataException>().having((error) => error.code, 'code', code),
  );
}

CanvasDocument _documentWithUnusedResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
    ],
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-1'), elements: [_rect('rect-1')]),
    ],
  );
}

CanvasDocument _documentWithReferencedResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-1'),
            resourceId: CanvasResourceId('resource-1'),
            size: const Size(1, 1),
            isVisible: false,
            isLocked: true,
            isDeletable: false,
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _replacementDocument() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('replacement'),
        size: const Size(1, 1),
      ),
    ],
  );
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}

// Taxonomy fixtures need compact element builders so each field-effect case can
// name the one changed field without hiding expected deltas behind setup noise.
// ignore: number-of-parameters
CanvasRectElement _rectElement({
  String id = 'rect-1',
  Size size = const Size(1, 1),
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth = 0,
  CanvasTransform transform = CanvasTransform.identity,
  double opacity = 1,
  double hitPadding = 0,
  bool isVisible = true,
  bool isSelectable = true,
  bool isLocked = false,
  bool isDeletable = true,
  bool isTransformable = true,
  CanvasMetadata metadata = const CanvasMetadata.empty(),
}) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: size,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    transform: transform,
    opacity: opacity,
    hitPadding: hitPadding,
    isVisible: isVisible,
    isSelectable: isSelectable,
    isLocked: isLocked,
    isDeletable: isDeletable,
    isTransformable: isTransformable,
    metadata: metadata,
  );
}

CanvasImageElement _imageElement({
  String id = 'image-1',
  CanvasResourceId? resourceId,
  Size size = const Size(1, 1),
  Size? naturalSize,
}) {
  return CanvasImageElement(
    id: CanvasElementId(id),
    resourceId: resourceId ?? CanvasResourceId('resource-1'),
    size: size,
    naturalSize: naturalSize,
  );
}

// The path builder keeps every taxonomy-owned field visible at call sites.
// ignore: number-of-parameters
CanvasPathElement _pathElement({
  String id = 'path-1',
  String svgPathData = 'M 0 0 L 1 1',
  Color? fillColor,
  Color? strokeColor,
  double strokeWidth = 0,
  CanvasPathFillRule fillRule = CanvasPathFillRule.nonZero,
}) {
  return CanvasPathElement(
    id: CanvasElementId(id),
    svgPathData: svgPathData,
    fillColor: fillColor,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
    fillRule: fillRule,
  );
}

// The text builder keeps every taxonomy-owned field visible at call sites.
// ignore: number-of-parameters
CanvasTextElement _textElement({
  String id = 'text-1',
  String text = 'text',
  double fontSize = 24,
  Color color = const Color(0xFF000000),
  TextAlign align = TextAlign.left,
  TextDirection textDirection = TextDirection.ltr,
  bool isBold = false,
  bool isItalic = false,
  bool isUnderline = false,
  String? fontFamily,
  double? maxWidth,
  double? lineHeight,
}) {
  return CanvasTextElement(
    id: CanvasElementId(id),
    text: text,
    fontSize: fontSize,
    color: color,
    align: align,
    textDirection: textDirection,
    isBold: isBold,
    isItalic: isItalic,
    isUnderline: isUnderline,
    fontFamily: fontFamily,
    maxWidth: maxWidth,
    lineHeight: lineHeight,
  );
}

CanvasStrokeElement _strokeElement({
  String id = 'stroke-1',
  Iterable<Offset> points = const [Offset.zero, Offset(1, 1)],
  double thickness = 1,
  Color color = const Color(0xFF000000),
}) {
  return CanvasStrokeElement(
    id: CanvasElementId(id),
    points: points,
    thickness: thickness,
    color: color,
  );
}

// The line builder keeps every taxonomy-owned field visible at call sites.
// ignore: number-of-parameters
CanvasLineElement _lineElement({
  String id = 'line-1',
  Offset start = Offset.zero,
  Offset end = const Offset(1, 1),
  double thickness = 1,
  Color color = const Color(0xFF000000),
}) {
  return CanvasLineElement(
    id: CanvasElementId(id),
    start: start,
    end: end,
    thickness: thickness,
    color: color,
  );
}

final class _EditOperationMatrixCase {
  const _EditOperationMatrixCase(
    this.row,
    this.run,
    this.document,
    this.mutateDraft,
    this.mutateEdit,
    this.expectedPlanEffects, {
    this.selectedElementIds = const {},
  });

  final String row;
  final void Function() run;
  final CanvasDocument Function() document;
  final void Function(DraftDocument draft) mutateDraft;
  final void Function(CanvasEdit edit) mutateEdit;
  final _ExpectedPlanEffects expectedPlanEffects;
  final Set<String> selectedElementIds;
}

final class _UpdateTaxonomyCase {
  const _UpdateTaxonomyCase(
    this.token,
    this.before,
    this.after,
    this.expectedDelta, {
    this.transformsElement = false,
    this.prunesSelection = false,
    this.touchesSpatial = false,
  });

  final String token;
  final CanvasElement before;
  final CanvasElement after;
  final _ExpectedRevisionDelta expectedDelta;
  final bool transformsElement;
  final bool prunesSelection;
  final bool touchesSpatial;
}

// Named constructors mirror operation-matrix effect families; keeping the
// expected effect vocabulary together makes each row assertion auditable.
// ignore: number-of-methods
final class _ExpectedPlanEffects {
  const _ExpectedPlanEffects({
    required this.delta,
    required this.projectionEffect,
    required this.spatialEffect,
    required this.resourceEffect,
    required this.repaintEffect,
    required this.selectionEffect,
    required this.publicStateEffect,
    this.documentReplaced = false,
  });

  const _ExpectedPlanEffects.empty()
    : this(
        delta: const _ExpectedRevisionDelta(),
        documentReplaced: false,
        projectionEffect: false,
        spatialEffect: false,
        resourceEffect: false,
        repaintEffect: false,
        selectionEffect: false,
        publicStateEffect: false,
      );

  const _ExpectedPlanEffects.documentReplacement({
    required bool selectionEffect,
  }) : this(
         delta: const _ExpectedRevisionDelta(
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
         selectionEffect: selectionEffect,
         publicStateEffect: true,
       );

  const _ExpectedPlanEffects.structural()
    : this(
        delta: const _ExpectedRevisionDelta(
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

  const _ExpectedPlanEffects.layerStructural()
    : this(
        delta: const _ExpectedRevisionDelta(
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

  const _ExpectedPlanEffects.elementVisual()
    : this(
        delta: const _ExpectedRevisionDelta(
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

  const _ExpectedPlanEffects.projectionOnly()
    : this(
        delta: const _ExpectedRevisionDelta(document: true, projection: true),
        projectionEffect: true,
        spatialEffect: false,
        resourceEffect: false,
        repaintEffect: false,
        selectionEffect: false,
        publicStateEffect: true,
      );

  const _ExpectedPlanEffects.background()
    : this(
        delta: const _ExpectedRevisionDelta(
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

  const _ExpectedPlanEffects.grid()
    : this(
        delta: const _ExpectedRevisionDelta(
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

  const _ExpectedPlanEffects.clearContent()
    : this(
        delta: const _ExpectedRevisionDelta(
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

  const _ExpectedPlanEffects.referencedResource()
    : this(
        delta: const _ExpectedRevisionDelta(
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

  const _ExpectedPlanEffects.unusedResourceRemoval()
    : this(
        delta: const _ExpectedRevisionDelta(
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

  final _ExpectedRevisionDelta delta;
  final bool documentReplaced;
  final bool projectionEffect;
  final bool spatialEffect;
  final bool resourceEffect;
  final bool repaintEffect;
  final bool selectionEffect;
  final bool publicStateEffect;
}

final class _ExpectedRevisionDelta {
  const _ExpectedRevisionDelta({
    this.document = false,
    this.projection = false,
    this.structural = false,
    this.bounds = false,
    this.elementVisual = false,
    this.background = false,
    this.grid = false,
    this.resource = false,
  });

  const _ExpectedRevisionDelta.projectionOnly()
    : this(document: true, projection: true);

  const _ExpectedRevisionDelta.elementVisual()
    : this(document: true, projection: true, elementVisual: true);

  const _ExpectedRevisionDelta.elementBoundsOnly()
    : this(document: true, projection: true, bounds: true);

  const _ExpectedRevisionDelta.elementBounds()
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
