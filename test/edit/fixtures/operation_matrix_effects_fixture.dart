import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
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

  test('P5 operation matrix rows install expected public effects', () {
    expect(_expectP5OperationRowsInstallEffects, returnsNormally);
  });
}

void _expectAddElementInstallsAfterCommit() {
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
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

void _expectEnsureLayerRevisionFamilies() {
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
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
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
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
  final root = RuntimeRoot(
    initialDocument: _documentWithReferencedResource(),
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
  final root = RuntimeRoot(
    initialDocument: _documentWithReferencedResource(),
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
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
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

void _expectP5OperationRowsInstallEffects() {
  _expectBackgroundElementRow();
  _expectRemoveElementRow();
  _expectClearContentRow();
  _expectPersistedCameraRow();
  _expectBackgroundRow();
  _expectGridRow();
  _expectPaletteRow();
  _expectUpsertResourceRow();
}

void _expectBackgroundElementRow() {
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  final id = root.edits.edit((edit) {
    return edit.addBackgroundElement(_rect('background-1'));
  });

  expect(id, CanvasElementId('background-1'));
  expect(root.readDocument().backgroundElements.single.id, id);
  _expectFrameRevisions(root, structural: 1, bounds: 1, elementVisual: 1);
}

void _expectRemoveElementRow() {
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
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
  final root = RuntimeRoot(
    initialDocument: _documentWithReferencedResource(),
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
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  root.edits.edit((edit) {
    edit.setCameraOffset(const Offset(6, 7));
  });

  expect(root.readDocument().camera.offset, const Offset(6, 7));
  _expectFrameRevisions(root);
}

void _expectBackgroundRow() {
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
    config: const CanvasRuntimeConfig(),
  );

  root.edits.edit((edit) {
    edit.setBackgroundColor(const Color(0xFF112233));
  });

  expect(root.readDocument().background.color, const Color(0xFF112233));
  _expectFrameRevisions(root, background: 1);
}

void _expectGridRow() {
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
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
  final root = RuntimeRoot(
    initialDocument: _documentWithUnusedResource(),
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
  final root = RuntimeRoot(
    initialDocument: _documentWithReferencedResource(),
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

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}
