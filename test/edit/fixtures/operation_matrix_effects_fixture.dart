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
