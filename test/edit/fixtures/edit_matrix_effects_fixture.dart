import 'dart:ui';

import 'edit_matrix_compile_expectations.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/draft_resources.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  _registerBasicEditRows();
  _registerOperationMatrixRows();
  _registerTaxonomyRows();
}

// Direct edit-operation registrations stay together so this fixture shows the
// complete behavior owner; splitting the list only for metrics would hide it.
// ignore: halstead-volume, source-lines-of-code
void _registerBasicEditRows() {
  test('accepted content add installs after callback commit', () {
    expect(_expectAddElementInstallsAfterCommit, returnsNormally);
  });

  test('ensureLayer advances structural revision without frame facts', () {
    expect(_expectEnsureLayerRevisionFamilies, returnsNormally);
  });

  test(
    'duplicate and unresolved resource rejection use public error codes',
    () {
      expect(_expectAdmissionErrorsUsePublicCodes, returnsNormally);
    },
  );

  test('image resource update rejects unresolved resource without install', () {
    expect(
      _expectImageResourceUpdateRejectsUnresolvedResource,
      returnsNormally,
    );
  });

  test('sparse image reference and resource accept both callback orders', () {
    expect(
      () =>
          _expectImageReferenceAndResourceAcceptBothOrders(materialized: false),
      returnsNormally,
    );
  });

  test(
    'materialized image reference and resource accept both callback orders',
    () {
      expect(
        () => _expectImageReferenceAndResourceAcceptBothOrders(
          materialized: true,
        ),
        returnsNormally,
      );
    },
  );

  test('removeUnusedResource is false for missing or referenced resources', () {
    expect(_expectRemoveUnusedResourceNoOps, returnsNormally);
  });

  test('materialized vector reference keeps its resource installed', () {
    expect(_expectMaterializedVectorReferenceKeepsResource, returnsNormally);
  });

  test('sparse vector override keeps its resource installed', () {
    expect(_expectSparseVectorOverrideKeepsResource, returnsNormally);
  });

  test('materialized identical vector resource upsert is a no-op', () {
    expect(
      () => _expectIdenticalVectorResourceUpsertIsNoOp(materialized: true),
      returnsNormally,
    );
  });

  test('sparse identical vector resource upsert is a no-op', () {
    expect(
      () => _expectIdenticalVectorResourceUpsertIsNoOp(materialized: false),
      returnsNormally,
    );
  });

  test('removeUnusedResource removes only unused descriptors', () {
    expect(_expectUnusedResourceRemovalInstalls, returnsNormally);
  });

  test('replaceDraftDocument resource descriptors use accepted revision', () {
    expect(
      _expectReplaceDraftDocumentResourceDescriptorsUseAcceptedRevision,
      returnsNormally,
    );
  });

  test(
    'materialized non-resource edit preserves resource descriptor revision',
    () {
      expect(
        _expectMaterializedNonResourceEditPreservesResourceDescriptorRevision,
        returnsNormally,
      );
    },
  );

  test('materialized clear retains background image and vector resources', () {
    expect(_expectMaterializedClearResourceWork, returnsNormally);
  });
}

void _registerOperationMatrixRows() {
  test('edit operation matrix rows install expected public effects', () {
    expect(_expectEditOperationRowsInstallEffects, returnsNormally);
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
    editMatrixStructuralPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'addBackgroundElement',
    _expectBackgroundElementRow,
    _documentWithUnusedResource,
    _draftAddBackgroundElement,
    _editAddBackgroundElement,
    editMatrixStructuralPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.updateElement',
    _expectUpdateElementRow,
    _documentWithUnusedResource,
    _draftUpdateElementVisual,
    _editUpdateElementVisual,
    editMatrixElementVisualPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.removeElement',
    _expectRemoveElementRow,
    _documentWithUnusedResource,
    _draftRemoveElement,
    _editRemoveElement,
    editMatrixStructuralPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'ensureLayer no-op',
    _expectEnsureLayerNoOpRow,
    _documentWithUnusedResource,
    _draftEnsureLayerNoOp,
    _editEnsureLayerNoOp,
    editMatrixEmptyPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'ensureLayer changed',
    _expectEnsureLayerRevisionFamilies,
    _documentWithUnusedResource,
    _draftEnsureLayerChanged,
    _editEnsureLayerChanged,
    editMatrixLayerStructuralPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.clearContent',
    _expectClearContentRow,
    _documentWithClearContentReferences,
    _draftClearContent,
    _editClearContent,
    editMatrixClearContentPlanEffects,
    selectedElementIds: {'image-1'},
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.setCameraOffset',
    _expectPersistedCameraRow,
    _documentWithUnusedResource,
    _draftSetCameraOffset,
    _editSetCameraOffset,
    editMatrixProjectionOnlyPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'setBackgroundColor',
    _expectBackgroundRow,
    _documentWithUnusedResource,
    _draftSetBackgroundColor,
    _editSetBackgroundColor,
    editMatrixBackgroundPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'setGrid',
    _expectGridRow,
    _documentWithUnusedResource,
    _draftSetGrid,
    _editSetGrid,
    editMatrixGridPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'setPalette',
    _expectPaletteRow,
    _documentWithUnusedResource,
    _draftSetPalette,
    _editSetPalette,
    editMatrixProjectionOnlyPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'upsertResource new/changed',
    _expectUpsertResourceRow,
    _documentWithReferencedResource,
    _draftUpsertReferencedResource,
    _editUpsertReferencedResource,
    editMatrixReferencedResourcePlanEffects,
  ),
  const _EditOperationMatrixCase(
    'removeUnusedResource removed',
    _expectUnusedResourceRemovalInstalls,
    _documentWithUnusedResource,
    _draftRemoveUnusedResource,
    _editRemoveUnusedResource,
    editMatrixUnusedResourceRemovalPlanEffects,
  ),
  const _EditOperationMatrixCase(
    'CanvasEdit.replaceDraftDocument',
    _expectReplaceDraftDocumentRow,
    _documentWithUnusedResource,
    _draftReplaceDocument,
    _editReplaceDocument,
    editMatrixDocumentReplacementPlanEffectsWithSelection,
    selectedElementIds: {'rect-1'},
  ),
  const _EditOperationMatrixCase(
    'no-op edit',
    _expectNoOpEditRow,
    _documentWithUnusedResource,
    _draftNoOp,
    _editNoOp,
    editMatrixEmptyPlanEffects,
  ),
];

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
  );

  expect(
    () => root.edits.edit((edit) {
      edit.addElement(_rect('rect-1'), layerId: CanvasLayerId('layer-1'));
    }),
    _throwsCanvasDataCode(CanvasDataErrorCode.duplicateElementId),
  );
  var missingImageMutationCompleted = false;
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
      missingImageMutationCompleted = true;
    }),
    _throwsCanvasDataCode(CanvasDataErrorCode.missingResourceReference),
  );
  expect(missingImageMutationCompleted, isTrue);
  expect(root.readDocument().layers.single.elements, hasLength(1));
  expect(root.documentFacts.documentRevision, 0);
}

void _expectImageResourceUpdateRejectsUnresolvedResource() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithReferencedResource(),
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

// This single assertion intentionally covers all four final transaction cases.
// Separating them would repeat the same external result.
// ignore: halstead-volume
void _expectImageReferenceAndResourceAcceptBothOrders({
  required bool materialized,
}) {
  for (final resourceFirst in [true, false]) {
    final root = runtimeRootWithCommittedDocumentSeed(
      _documentWithUnusedResource(),
    );
    final resource = CanvasImageResource(
      id: CanvasResourceId('new-image-resource'),
      source: CanvasResourceSource.appKey('new-image-resource'),
    );
    final element = _imageElement(id: 'new-image', resourceId: resource.id);

    final changed = root.edits.edit((edit) {
      if (materialized) {
        edit.readDraftDocument();
      }
      if (resourceFirst) {
        expect(edit.upsertResource(resource), isTrue);
      }
      edit.addElement(element, layerId: CanvasLayerId('layer-1'));
      if (!resourceFirst) {
        expect(edit.upsertResource(resource), isTrue);
      }

      return true;
    });

    expect(changed, isTrue);
    final document = root.readDocument();
    expect(document.resources.map((item) => item.id), contains(resource.id));
    expect(
      document.layers.single.elements.map((item) => item.id),
      contains(element.id),
    );
    expect(root.documentFacts.documentRevision, 1);
  }
}

void _expectRemoveUnusedResourceNoOps() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithReferencedResource(),
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

void _expectMaterializedVectorReferenceKeepsResource() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithReferencedVectorResource(),
  );
  final beforeDocument = root.readDocument();
  final beforeState = root.state.value;

  final removed = root.edits.edit((edit) {
    edit.readDraftDocument();

    return edit.removeUnusedResource(CanvasResourceId('vector-resource-1'));
  });

  expect(removed, isFalse);
  expect(root.readDocument(), same(beforeDocument));
  expect(root.state.value, same(beforeState));
  expect(root.documentFacts.documentRevision, 0);
  expect(root.frameRevisions.resourceRevision, 0);
}

void _expectSparseVectorOverrideKeepsResource() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithReferencedVectorResource(),
  );
  final beforeResourceRevision = root.frameRevisions.resourceRevision;

  final removed = root.edits.edit((edit) {
    expect(
      edit.updateElement(
        CanvasVectorElementUpdate(
          id: CanvasElementId('vector-1'),
          opacity: const CanvasFieldSet(0.5),
        ),
      ),
      isTrue,
    );

    return edit.removeUnusedResource(CanvasResourceId('vector-resource-1'));
  });

  final vector =
      root.readDocument().layers.single.elements.single as CanvasVectorElement;
  expect(removed, isFalse);
  expect(vector.opacity, 0.5);
  expect(
    root.readDocument().resources.single.id,
    CanvasResourceId('vector-resource-1'),
  );
  expect(root.documentFacts.documentRevision, 1);
  expect(root.frameRevisions.resourceRevision, beforeResourceRevision);
}

void _expectIdenticalVectorResourceUpsertIsNoOp({required bool materialized}) {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithReferencedVectorResource(),
  );
  final beforeDocument = root.readDocument();
  final beforeState = root.state.value;
  final beforeResourceRevision = root.frameRevisions.resourceRevision;

  final changed = root.edits.edit((edit) {
    if (materialized) {
      edit.readDraftDocument();
    }

    return edit.upsertResource(_vectorResource());
  });

  expect(changed, isFalse);
  expect(root.readDocument(), same(beforeDocument));
  expect(root.state.value, same(beforeState));
  expect(root.documentFacts.documentRevision, 0);
  expect(root.frameRevisions.resourceRevision, beforeResourceRevision);
}

void _expectUnusedResourceRemovalInstalls() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
  );

  final removed = root.edits.edit((edit) {
    return edit.removeUnusedResource(CanvasResourceId('resource-1'));
  });

  expect(removed, isTrue);
  expect(root.readDocument().resources, isEmpty);
  expect(root.documentFacts.documentRevision, 1);
  expect(root.frameRevisions.resourceRevision, 1);
}

void _expectReplaceDraftDocumentResourceDescriptorsUseAcceptedRevision() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
  );

  root.edits.edit((edit) {
    edit.replaceDraftDocument(_replacementDocumentWithResource());
  });

  final descriptor = root.resourceDescriptor(
    CanvasResourceId('replacement-resource'),
  );
  expect(root.frameRevisions.resourceRevision, 1);
  expect(descriptor?.appKey, 'replacement-resource');
  expect(descriptor?.resourceRevision, root.frameRevisions.resourceRevision);
}

// This regression keeps the mixed resource revision setup, materialized edit,
// and descriptor assertions together so the per-resource invariant is visible.
// ignore: halstead-volume
void _expectMaterializedNonResourceEditPreservesResourceDescriptorRevision() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithTwoReferencedResources(),
  );
  root.edits.edit((edit) {
    edit.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('resource-2'),
        source: CanvasResourceSource.appKey('resource-2-updated'),
      ),
    );
  });
  expect(root.frameRevisions.resourceRevision, 1);

  root.edits.edit((edit) {
    edit.readDraftDocument();
    edit.setBackgroundColor(const Color(0xFF112233));
  });

  final unchanged = root.resourceDescriptor(CanvasResourceId('resource-1'));
  final changed = root.resourceDescriptor(CanvasResourceId('resource-2'));
  expect(root.documentFacts.documentRevision, 2);
  expect(root.frameRevisions.backgroundRevision, 1);
  expect(root.frameRevisions.resourceRevision, 1);
  expect(unchanged?.appKey, 'resource-1');
  expect(unchanged?.resourceRevision, 0);
  expect(changed?.appKey, 'resource-2-updated');
  expect(changed?.resourceRevision, root.frameRevisions.resourceRevision);
}

void _expectEditOperationRowsInstallEffects() {
  for (final operationCase in _editOperationMatrixCases) {
    expect(operationCase.row, isNotEmpty);
    operationCase.run();
  }
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
    expectEditMatrixPlanEffects(
      operationCase.row,
      draft.commitPlan,
      operationCase.expectedPlanEffects,
    );
  }
}

Future<void> _expectEditOperationRowsRollback() async {
  for (final operationCase in _editOperationMatrixCases) {
    final root = runtimeRootWithCommittedDocumentSeed(operationCase.document());
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
    final root = runtimeRootWithCommittedDocumentSeed(operationCase.document());
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
    expectEditMatrixTaxonomyEffects((
      token: taxonomyCase.token,
      before: taxonomyCase.before,
      after: taxonomyCase.after,
      expectedDelta: taxonomyCase.expectedDelta,
      transformsElement: taxonomyCase.transformsElement,
      prunesSelection: taxonomyCase.prunesSelection,
      touchesSpatial: taxonomyCase.touchesSpatial,
    ));
  }
}

void _expectBackgroundElementRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
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
    _documentWithClearContentReferences(),
  );

  final result = root.edits.edit((edit) {
    edit.readDraftDocument();

    return edit.clearContent(removeUnusedResources: true);
  });

  final document = root.readDocument();
  _expectClearContentResultAndRetainedOrder(result, document);
  _expectPreservedBackgroundImage(document.backgroundElements.first);
  _expectPreservedBackgroundVector(document.backgroundElements.last);
  _expectClearContentStoreDescriptors(root);
  _expectFrameRevisions(
    root,
    structural: 1,
    bounds: 1,
    elementVisual: 1,
    resource: 1,
  );
}

void _expectClearContentResultAndRetainedOrder(
  CanvasClearResult result,
  CanvasDocument document,
) {
  expect(result.didClearContent, isTrue);
  expect(result.removedElementIds, [CanvasElementId('image-1')]);
  expect(result.removedResourceIds, [
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('unused-resource'),
  ]);
  expect(document.layers.single.elements, isEmpty);
  expect(document.backgroundElements.map((element) => element.id), [
    CanvasElementId('background-image'),
    CanvasElementId('background-vector'),
  ]);
  expect(document.backgroundElements.first, isA<CanvasImageElement>());
  expect(document.backgroundElements.last, isA<CanvasVectorElement>());
  expect(document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
  ]);
  expect(document.resources.first, isA<CanvasImageResource>());
  expect(document.resources.last, isA<CanvasVectorResource>());
}

void _expectPreservedBackgroundImage(CanvasElement element) {
  final backgroundImage = element as CanvasImageElement;
  expect(
    backgroundImage.resourceId,
    CanvasResourceId('background-image-resource'),
  );
  expect(backgroundImage.revision, 7);
  expect(backgroundImage.size, const Size(2, 3));
  expect(backgroundImage.naturalSize, const Size(20, 30));
  expect(
    backgroundImage.transform,
    CanvasTransform.translation(const Offset(8, 9)),
  );
  expect(backgroundImage.opacity, 0.75);
  expect(backgroundImage.hitPadding, 3);
  expect(backgroundImage.isVisible, isFalse);
  expect(backgroundImage.isSelectable, isFalse);
  expect(backgroundImage.isLocked, isTrue);
  expect(backgroundImage.isDeletable, isFalse);
  expect(backgroundImage.isTransformable, isFalse);
  expect(
    backgroundImage.metadata,
    CanvasMetadata.fromMap({'role': 'background-image', 'rank': 1}),
  );
}

void _expectPreservedBackgroundVector(CanvasElement element) {
  final backgroundVector = element as CanvasVectorElement;
  expect(
    backgroundVector.resourceId,
    CanvasResourceId('background-vector-resource'),
  );
  expect(backgroundVector.revision, 8);
  expect(backgroundVector.size, const Size(4, 5));
  expect(backgroundVector.naturalSize, const Size(40, 50));
  expect(
    backgroundVector.transform,
    CanvasTransform.translation(const Offset(10, 11)),
  );
  expect(backgroundVector.opacity, 0.5);
  expect(backgroundVector.hitPadding, 4);
  expect(backgroundVector.isVisible, isFalse);
  expect(backgroundVector.isSelectable, isFalse);
  expect(backgroundVector.isLocked, isTrue);
  expect(backgroundVector.isDeletable, isFalse);
  expect(backgroundVector.isTransformable, isFalse);
  expect(
    backgroundVector.metadata,
    CanvasMetadata.fromMap({'role': 'background-vector', 'rank': 2}),
  );
}

void _expectClearContentStoreDescriptors(RuntimeRoot root) {
  final imageDescriptor = root.resourceDescriptor(
    CanvasResourceId('background-image-resource'),
  );
  expect(imageDescriptor, isA<FrameImageResourceDescriptorFacts>());
  expect(imageDescriptor?.appKey, 'background-image-source');
  expect(imageDescriptor?.contentHash, 'sha256:background-image');
  expect(imageDescriptor?.byteLength, 101);
  expect(
    imageDescriptor?.metadata,
    CanvasMetadata.fromMap({'asset': 'image', 'scale': 2}),
  );
  expect(
    (imageDescriptor as FrameImageResourceDescriptorFacts).mimeType,
    'image/png',
  );
  final vectorDescriptor = root.resourceDescriptor(
    CanvasResourceId('background-vector-resource'),
  );
  expect(vectorDescriptor, isA<FrameVectorResourceDescriptorFacts>());
  expect(vectorDescriptor?.appKey, 'background-vector-source');
  expect(vectorDescriptor?.contentHash, 'sha256:background-vector');
  expect(vectorDescriptor?.byteLength, 202);
  expect(
    vectorDescriptor?.metadata,
    CanvasMetadata.fromMap({'asset': 'vector', 'scale': 3}),
  );
  expect(imageDescriptor.resourceRevision, 0);
  expect(vectorDescriptor?.resourceRevision, 0);
}

void _expectPersistedCameraRow() {
  final root = runtimeRootWithCommittedDocumentSeed(
    _documentWithUnusedResource(),
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
  edit.readDraftDocument();
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

CanvasDocument _documentWithClearContentReferences() {
  return CanvasDocument(
    resources: _clearContentResources(),
    backgroundElements: _clearContentBackgroundElements(),
    layers: [_clearContentLayer()],
  );
}

List<CanvasResource> _clearContentResources() {
  return [
    CanvasImageResource(
      id: CanvasResourceId('background-image-resource'),
      source: CanvasResourceSource.appKey('background-image-source'),
      mimeType: 'image/png',
      contentHash: 'sha256:background-image',
      byteLength: 101,
      metadata: CanvasMetadata.fromMap({'asset': 'image', 'scale': 2}),
    ),
    CanvasVectorResource(
      id: CanvasResourceId('background-vector-resource'),
      source: CanvasResourceSource.appKey('background-vector-source'),
      contentHash: 'sha256:background-vector',
      byteLength: 202,
      metadata: CanvasMetadata.fromMap({'asset': 'vector', 'scale': 3}),
    ),
    CanvasImageResource(
      id: CanvasResourceId('content-image-resource'),
      source: CanvasResourceSource.appKey('content-image-resource'),
    ),
    CanvasImageResource(
      id: CanvasResourceId('unused-resource'),
      source: CanvasResourceSource.appKey('unused-resource'),
    ),
  ];
}

List<CanvasElement> _clearContentBackgroundElements() {
  return [_clearContentBackgroundImage(), _clearContentBackgroundVector()];
}

CanvasImageElement _clearContentBackgroundImage() {
  return CanvasImageElement(
    id: CanvasElementId('background-image'),
    resourceId: CanvasResourceId('background-image-resource'),
    size: const Size(2, 3),
    naturalSize: const Size(20, 30),
    revision: 7,
    transform: CanvasTransform.translation(const Offset(8, 9)),
    opacity: 0.75,
    hitPadding: 3,
    isVisible: false,
    isSelectable: false,
    isLocked: true,
    isDeletable: false,
    isTransformable: false,
    metadata: CanvasMetadata.fromMap({'role': 'background-image', 'rank': 1}),
  );
}

CanvasVectorElement _clearContentBackgroundVector() {
  return CanvasVectorElement(
    id: CanvasElementId('background-vector'),
    resourceId: CanvasResourceId('background-vector-resource'),
    size: const Size(4, 5),
    naturalSize: const Size(40, 50),
    revision: 8,
    transform: CanvasTransform.translation(const Offset(10, 11)),
    opacity: 0.5,
    hitPadding: 4,
    isVisible: false,
    isSelectable: false,
    isLocked: true,
    isDeletable: false,
    isTransformable: false,
    metadata: CanvasMetadata.fromMap({'role': 'background-vector', 'rank': 2}),
  );
}

CanvasLayer _clearContentLayer() {
  return CanvasLayer(
    id: CanvasLayerId('layer-1'),
    elements: [
      CanvasImageElement(
        id: CanvasElementId('image-1'),
        resourceId: CanvasResourceId('content-image-resource'),
        size: const Size(1, 1),
        isVisible: false,
        isLocked: true,
        isDeletable: false,
      ),
    ],
  );
}

void _expectMaterializedClearResourceWork() {
  final draft = DraftDocument(_documentWithManyClearResources());
  final work = <DraftResourceWorkEvent>[];

  final result = observeDraftResourceWork(
    work.add,
    () => draft.clearContent(removeUnusedResources: true),
  );

  expect(result.removedElementIds, [CanvasElementId('content-image')]);
  expect(result.removedResourceIds, [
    CanvasResourceId('content-resource'),
    CanvasResourceId('unused-resource-a'),
    CanvasResourceId('unused-resource-b'),
  ]);
  expect(
    _resourceWorkEventCount(work, DraftResourceWorkKind.imageCountTransition),
    1,
  );
  expect(
    _resourceWorkEventCount(work, DraftResourceWorkKind.vectorCountTransition),
    0,
  );
  expect(
    _resourceWorkEventCount(work, DraftResourceWorkKind.referenceQuery),
    5,
  );
  expect(
    _resourceWorkEventCount(work, DraftResourceWorkKind.descriptorRemove),
    3,
  );
  _expectManyResourceDraftOperationsStayDirect();
}

// One supported-size resource trace exercises descriptor lookup/reinsert,
// split-family transitions, clear, and one ordered publication together.
// Keeping those transitions in one trace preserves their current-state order.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _expectManyResourceDraftOperationsStayDirect() {
  const resourceCount = 4096;
  final source = CanvasDocument(
    resources: [
      for (var index = 0; index < resourceCount; index += 1)
        if (index == 3 || index == 4)
          CanvasVectorResource(
            id: CanvasResourceId('many-resource-$index'),
            source: CanvasResourceSource.appKey('many-resource-$index'),
          )
        else
          CanvasImageResource(
            id: CanvasResourceId('many-resource-$index'),
            source: CanvasResourceSource.appKey('many-resource-$index'),
          ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('many-background'),
        resourceId: CanvasResourceId('many-resource-0'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('many-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('many-content'),
            resourceId: CanvasResourceId('many-resource-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
  final events = <DraftResourceWorkEvent>[];
  final reinsertedId = CanvasResourceId('many-reinserted');
  late DraftDocument draft;
  late CanvasDocument document;

  final clear = observeDraftResourceWork(events.add, () {
    draft = DraftDocument(source);
    expect(
      draft.upsertResource(
        CanvasImageResource(
          id: reinsertedId,
          source: CanvasResourceSource.appKey('many-reinserted'),
        ),
      ),
      isTrue,
    );
    expect(draft.removeUnusedResource(reinsertedId), isTrue);
    expect(
      draft.upsertResource(
        CanvasImageResource(
          id: reinsertedId,
          source: CanvasResourceSource.appKey('many-reinserted'),
        ),
      ),
      isTrue,
    );
    expect(
      draft.updateElement(
        CanvasImageElementUpdate(
          id: CanvasElementId('many-content'),
          resourceId: CanvasFieldSet(CanvasResourceId('many-resource-2')),
        ),
      ),
      isTrue,
    );
    expect(
      draft.removeUnusedResource(CanvasResourceId('many-resource-1')),
      isTrue,
    );
    final vector = CanvasVectorElement(
      id: CanvasElementId('many-vector'),
      resourceId: CanvasResourceId('many-resource-3'),
      size: const Size(1, 1),
    );
    draft.addElement(vector, layerId: CanvasLayerId('many-layer'));
    expect(
      draft.updateElement(
        CanvasVectorElementUpdate(
          id: vector.id,
          resourceId: CanvasFieldSet(CanvasResourceId('many-resource-4')),
        ),
      ),
      isTrue,
    );
    expect(
      draft.removeUnusedResource(CanvasResourceId('many-resource-3')),
      isTrue,
    );
    expect(draft.removeElement(vector.id), isTrue);
    expect(
      draft.removeUnusedResource(CanvasResourceId('many-resource-4')),
      isTrue,
    );
    final clear = draft.clearContent(removeUnusedResources: true);
    document = draft.readDocument();
    return clear;
  });

  expect(clear.removedElementIds, [CanvasElementId('many-content')]);
  expect(clear.removedResourceIds, hasLength(resourceCount - 3));
  expect(document.resources.map((resource) => resource.id), [
    CanvasResourceId('many-resource-0'),
  ]);
  expect(
    _resourceWorkEventCount(events, DraftResourceWorkKind.descriptorRead),
    6,
  );
  expect(
    _resourceWorkEventCount(events, DraftResourceWorkKind.descriptorWrite),
    2,
  );
  expect(
    _resourceWorkEventCount(events, DraftResourceWorkKind.imageCountTransition),
    5,
  );
  expect(
    _resourceWorkEventCount(
      events,
      DraftResourceWorkKind.vectorCountTransition,
    ),
    4,
  );
  expect(
    _resourceWorkEventCount(events, DraftResourceWorkKind.referenceQuery),
    resourceCount + 4,
  );
  expect(
    _resourceWorkEventCount(events, DraftResourceWorkKind.descriptorRemove),
    resourceCount + 1,
  );
  expect(
    _resourceWorkEventCount(
      events,
      DraftResourceWorkKind.descriptorMaterialization,
    ),
    1,
  );
  expect(
    _resourceWorkEventCount(events, DraftResourceWorkKind.countEntryVisit),
    0,
  );
  _expectResourceQueryCounts(
    events,
    CanvasResourceId('many-resource-1'),
    const [(image: 0, vector: 0)],
  );
  _expectResourceQueryCounts(
    events,
    CanvasResourceId('many-resource-3'),
    const [(image: 0, vector: 0)],
  );
  _expectResourceQueryCounts(
    events,
    CanvasResourceId('many-resource-0'),
    const [(image: 1, vector: 0)],
  );
  _expectResourceTransitionCounts(
    events,
    CanvasResourceId('many-resource-1'),
    const [(image: 1, vector: 0), (image: 0, vector: 0)],
  );
  _expectResourceTransitionCounts(
    events,
    CanvasResourceId('many-resource-2'),
    const [(image: 1, vector: 0), (image: 0, vector: 0)],
  );
  _expectResourceTransitionCounts(
    events,
    CanvasResourceId('many-resource-3'),
    const [(image: 0, vector: 1), (image: 0, vector: 0)],
  );
  _expectResourceTransitionCounts(
    events,
    CanvasResourceId('many-resource-4'),
    const [(image: 0, vector: 1), (image: 0, vector: 0)],
  );
}

void _expectResourceQueryCounts(
  Iterable<DraftResourceWorkEvent> events,
  CanvasResourceId id,
  List<({int image, int vector})> expected,
) {
  final actual = [
    for (final event in events)
      if (event.kind == DraftResourceWorkKind.referenceQuery &&
          event.resourceId == id)
        (image: event.imageCount, vector: event.vectorCount),
  ];
  expect(actual, expected);
}

void _expectResourceTransitionCounts(
  Iterable<DraftResourceWorkEvent> events,
  CanvasResourceId id,
  List<({int image, int vector})> expected,
) {
  final actual = [
    for (final event in events)
      if ((event.kind == DraftResourceWorkKind.imageCountTransition ||
              event.kind == DraftResourceWorkKind.vectorCountTransition) &&
          event.resourceId == id)
        (image: event.imageCount, vector: event.vectorCount),
  ];
  expect(actual, expected);
}

int _resourceWorkEventCount(
  Iterable<DraftResourceWorkEvent> work,
  DraftResourceWorkKind kind,
) {
  return work.where((item) => item.kind == kind).length;
}

CanvasDocument _documentWithManyClearResources() {
  return CanvasDocument(
    resources: [
      ..._manyClearRetainedResources(),
      ..._manyClearRemovableResources(),
    ],
    backgroundElements: _manyClearBackgroundElements(),
    layers: [_manyClearContentLayer()],
  );
}

List<CanvasResource> _manyClearRetainedResources() {
  return [
    CanvasImageResource(
      id: CanvasResourceId('background-image-resource'),
      source: CanvasResourceSource.appKey('background-image-resource'),
    ),
    CanvasVectorResource(
      id: CanvasResourceId('background-vector-resource'),
      source: CanvasResourceSource.appKey('background-vector-resource'),
    ),
  ];
}

List<CanvasResource> _manyClearRemovableResources() {
  return [
    CanvasImageResource(
      id: CanvasResourceId('content-resource'),
      source: CanvasResourceSource.appKey('content-resource'),
    ),
    CanvasImageResource(
      id: CanvasResourceId('unused-resource-a'),
      source: CanvasResourceSource.appKey('unused-resource-a'),
    ),
    CanvasVectorResource(
      id: CanvasResourceId('unused-resource-b'),
      source: CanvasResourceSource.appKey('unused-resource-b'),
    ),
  ];
}

List<CanvasElement> _manyClearBackgroundElements() {
  return [
    CanvasImageElement(
      id: CanvasElementId('background-image'),
      resourceId: CanvasResourceId('background-image-resource'),
      size: const Size(2, 3),
    ),
    CanvasVectorElement(
      id: CanvasElementId('background-vector'),
      resourceId: CanvasResourceId('background-vector-resource'),
      size: const Size(4, 5),
    ),
  ];
}

CanvasLayer _manyClearContentLayer() {
  return CanvasLayer(
    id: CanvasLayerId('layer-1'),
    elements: [
      CanvasImageElement(
        id: CanvasElementId('content-image'),
        resourceId: CanvasResourceId('content-resource'),
        size: const Size(6, 7),
        isDeletable: false,
      ),
    ],
  );
}

CanvasDocument _documentWithReferencedVectorResource() {
  return CanvasDocument(
    resources: [_vectorResource()],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasVectorElement(
            id: CanvasElementId('vector-1'),
            resourceId: CanvasResourceId('vector-resource-1'),
            size: const Size(20, 10),
          ),
        ],
      ),
    ],
  );
}

CanvasVectorResource _vectorResource() {
  return CanvasVectorResource(
    id: CanvasResourceId('vector-resource-1'),
    source: CanvasResourceSource.appKey('vector-resource-1'),
    contentHash: 'sha256:vector-resource-1',
    byteLength: 42,
    metadata: CanvasMetadata.fromMap({'label': 'Vector resource'}),
  );
}

CanvasDocument _documentWithTwoReferencedResources() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
      CanvasImageResource(
        id: CanvasResourceId('resource-2'),
        source: CanvasResourceSource.appKey('resource-2'),
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
          ),
          CanvasImageElement(
            id: CanvasElementId('image-2'),
            resourceId: CanvasResourceId('resource-2'),
            size: const Size(1, 1),
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

CanvasDocument _replacementDocumentWithResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('replacement-resource'),
        source: CanvasResourceSource.appKey('replacement-resource'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('replacement-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('replacement-image'),
            resourceId: CanvasResourceId('replacement-resource'),
            size: const Size(1, 1),
          ),
        ],
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
  final EditMatrixExpectedPlanEffects expectedPlanEffects;
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

typedef _ExpectedRevisionDelta = EditMatrixExpectedRevisionDelta;
