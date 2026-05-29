import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test('public consumer decodes, reads, and selects through runtime', () async {
    await expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_public_incremental_smoke',
        testFileName: 'public_incremental_smoke_test.dart',
        testSource: _publicIncrementalSmokeSource,
      ),
      completes,
    );
  });
}

const _publicIncrementalSmokeSource = r'''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('schema v1 document reaches runtime state and selection', () {
    final decodedDocument = decodeCanvasDocument(_smallSchemaV1Document());
    final runtime = CanvasRuntime(initialDocument: decodedDocument);
    addTearDown(runtime.dispose);

    final initialState = runtime.state.value;
    expect(initialState.revisions, _runtimeRevisions(document: 0, selection: 0));
    expect(
      initialState.summary,
      const CanvasRuntimeSummary(
        elementCount: 1,
        layerCount: 1,
        resourceCount: 0,
        selectedCount: 0,
      ),
    );

    final document = runtime.readDocument();
    expect(document.camera, CanvasCamera(offset: const Offset(32, -16)));
    expect(document.resources, isEmpty);
    expect(document.backgroundElements, isEmpty);
    expect(document.layers, hasLength(1));
    expect(document.layers.single.id, CanvasLayerId('layer-a'));
    expect(document.layers.single.elements.single.id, CanvasElementId('element-a'));

    runtime.selection.setSelection([CanvasElementId('element-a')]);

    final selectedState = runtime.state.value;
    expect(selectedState.summary.selectedCount, 1);
    expect(selectedState.revisions.selection, 1);
    expect(selectedState.revisions.document, 0);
    expect(runtime.selection.selectedElementIds, {CanvasElementId('element-a')});

    final imageResource = CanvasImageResource(
      id: CanvasResourceId('resource-a'),
      source: CanvasResourceSource.appKey('smoke-image'),
      mimeType: 'image/png',
      byteLength: 24,
      metadata: CanvasMetadata.fromMap({'label': 'Smoke image'}),
    );
    expect(imageResource.source, CanvasResourceSource.appKey('smoke-image'));
    expect(imageResource.metadata['label'], 'Smoke image');

    runtime.edits.edit((edit) {
      expect(edit.upsertResource(imageResource), isTrue);
      edit.addElement(
        CanvasRectElement(
          id: CanvasElementId('element-b'),
          size: const Size(12, 8),
        ),
        layerId: CanvasLayerId('layer-a'),
      );
    });

    final editedState = runtime.state.value;
    expect(editedState.summary.elementCount, 2);
    expect(editedState.summary.resourceCount, 1);
    expect(editedState.revisions.document, 1);
    expect(editedState.revisions.selection, 1);
    final editedDocument = runtime.readDocument();
    expect(editedDocument.layers.single.elements, hasLength(2));
    expect(editedDocument.resources.single.id, CanvasResourceId('resource-a'));
    final resources = runtime.resources;
    expect(resources.resources.single.id, CanvasResourceId('resource-a'));
    expect(
      resources.resourceById(CanvasResourceId('resource-a'))?.id,
      CanvasResourceId('resource-a'),
    );
    expect(resources.resourceById(CanvasResourceId('missing')), isNull);
    expect(() => resources.resources.clear(), throwsUnsupportedError);

    final dirtySnapshots = <CanvasRuntimeState>[];
    runtime.state.addListener(() {
      dirtySnapshots.add(runtime.state.value);
    });
    resources.markResourceDirty(CanvasResourceId('resource-a'));

    expect(dirtySnapshots, hasLength(1));
    final dirtyState = dirtySnapshots.single;
    expect(dirtyState.revisions.resourceVisual, 1);
    expect(dirtyState.revisions.document, editedState.revisions.document);
    expect(dirtyState.revisions.selection, editedState.revisions.selection);
    expect(dirtyState.revisions.preview, editedState.revisions.preview);
    expect(dirtyState.revisions.viewCamera, editedState.revisions.viewCamera);
    expect(dirtyState.revisions.interaction, editedState.revisions.interaction);
    expect(dirtyState.revisions.epoch, editedState.revisions.epoch);

    final secondDocument = decodeCanvasDocument(_secondSchemaV1Document());
    final loadSnapshots = <CanvasRuntimeState>[];
    runtime.state.addListener(() {
      loadSnapshots.add(runtime.state.value);
    });

    runtime.edits.loadDocument(secondDocument);

    expect(loadSnapshots, hasLength(1));
    final loadedState = loadSnapshots.single;
    expect(
      loadedState.summary,
      const CanvasRuntimeSummary(
        elementCount: 1,
        layerCount: 1,
        resourceCount: 0,
        selectedCount: 0,
      ),
    );
    expect(loadedState.revisions.document, 2);
    expect(loadedState.revisions.selection, 2);
    expect(loadedState.revisions.viewCamera, 1);
    expect(loadedState.revisions.epoch, 1);
    expect(runtime.selection.selectedElementIds, isEmpty);
    expect(runtime.camera.offset, const Offset(-8, 12));

    final loadedDocument = runtime.readDocument();
    expect(loadedDocument.camera, CanvasCamera(offset: const Offset(-8, 12)));
    expect(loadedDocument.layers.single.id, CanvasLayerId('layer-second'));
    expect(
      loadedDocument.layers.single.elements.single.id,
      CanvasElementId('element-second'),
    );
    expect(loadedDocument.metadata['source'], 'public incremental smoke load');

    runtime.edits.loadDocument(
      decodeCanvasDocument(_geometryRichSchemaV1Document()),
    );

    final geometryState = runtime.state.value;
    expect(
      geometryState.summary,
      const CanvasRuntimeSummary(
        elementCount: 3,
        layerCount: 1,
        resourceCount: 0,
        selectedCount: 0,
      ),
    );
    expect(geometryState.revisions.document, 3);
    expect(geometryState.revisions.selection, 3);

    final geometryDocument = runtime.readDocument();
    expect(geometryDocument.backgroundElements.single.id, CanvasElementId('geometry-bg'));
    expect(geometryDocument.layers.single.id, CanvasLayerId('geometry-layer'));
    expect(
      geometryDocument.layers.single.elements.map((element) => element.id),
      [
        CanvasElementId('overlap-bottom'),
        CanvasElementId('overlap-top'),
      ],
    );
    final overlapTop = geometryDocument.layers.single.elements.last as CanvasRectElement;
    expect(overlapTop.transform.translation, const Offset(16, 12));
    expect(overlapTop.size, const Size(36, 20));

    runtime.edits.edit((edit) {
      expect(
        edit.updateElement(
          CanvasRectElementUpdate(
            id: CanvasElementId('overlap-top'),
            transform: CanvasFieldSet(
              CanvasTransform.trs(
                translation: const Offset(24, 18),
                rotationDegrees: 8,
              ),
            ),
            size: const CanvasFieldSet(Size(44, 24)),
          ),
        ),
        isTrue,
      );
    });

    final geometryEditedState = runtime.state.value;
    expect(geometryEditedState.summary.elementCount, 3);
    expect(geometryEditedState.revisions.document, 4);
    final geometryEditedDocument = runtime.readDocument();
    final movedTop = geometryEditedDocument.layers.single.elements.last as CanvasRectElement;
    expect(movedTop.transform.translation, const Offset(24, 18));
    expect(movedTop.size, const Size(44, 24));

    runtime.edits.loadDocument(
      decodeCanvasDocument(_replacementGeometryRichSchemaV1Document()),
    );

    final replacementState = runtime.state.value;
    expect(
      replacementState.summary,
      const CanvasRuntimeSummary(
        elementCount: 2,
        layerCount: 1,
        resourceCount: 0,
        selectedCount: 0,
      ),
    );
    expect(replacementState.revisions.document, 5);
    expect(runtime.selection.selectedElementIds, isEmpty);
    final replacementDocument = runtime.readDocument();
    expect(
      replacementDocument.backgroundElements.single.id,
      CanvasElementId('replacement-bg'),
    );
    expect(replacementDocument.layers.single.id, CanvasLayerId('replacement-layer'));
    expect(
      replacementDocument.layers.single.elements.single.id,
      CanvasElementId('replacement-content'),
    );
  });
}

Map<String, Object?> _smallSchemaV1Document() {
  return {
    'schemaVersion': 1,
    'camera': {
      'offset': {'x': 32.0, 'y': -16.0},
    },
    'background': {
      'color': '#FFFFFFFF',
      'grid': {
        'enabled': true,
        'cellSize': 20.0,
        'color': '#1F000000',
      },
    },
    'palette': {
      'penColors': ['#FF000000'],
      'backgroundColors': ['#FFFFFFFF'],
      'gridSizes': [10.0, 20.0],
    },
    'resources': [],
    'backgroundLayer': {'elements': []},
    'layers': [
      {
        'id': 'layer-a',
        'elements': [
          {
            'id': 'element-a',
            'kind': 'rect',
            'revision': 0,
            'transform': {'a': 1.0, 'b': 0.0, 'c': 0.0, 'd': 1.0, 'tx': 0.0, 'ty': 0.0},
            'opacity': 1.0,
            'hitPadding': 0.0,
            'isVisible': true,
            'isSelectable': true,
            'isLocked': false,
            'isDeletable': true,
            'isTransformable': true,
            'metadata': {'label': 'First smoke element'},
            'size': {'w': 40.0, 'h': 24.0},
            'fillColor': '#330000FF',
            'strokeColor': '#FF0000FF',
            'strokeWidth': 2.0,
          },
        ],
        'metadata': {'name': 'Smoke layer'},
      },
    ],
    'metadata': {'source': 'public incremental smoke'},
  };
}

Map<String, Object?> _secondSchemaV1Document() {
  return {
    'schemaVersion': 1,
    'camera': {
      'offset': {'x': -8.0, 'y': 12.0},
    },
    'background': {
      'color': '#FFFFFFFF',
      'grid': {
        'enabled': true,
        'cellSize': 16.0,
        'color': '#14000000',
      },
    },
    'palette': {
      'penColors': ['#FF000000'],
      'backgroundColors': ['#FFFFFFFF'],
      'gridSizes': [8.0, 16.0],
    },
    'resources': [],
    'backgroundLayer': {'elements': []},
    'layers': [
      {
        'id': 'layer-second',
        'elements': [
          {
            'id': 'element-second',
            'kind': 'rect',
            'revision': 0,
            'transform': {'a': 1.0, 'b': 0.0, 'c': 0.0, 'd': 1.0, 'tx': 4.0, 'ty': 6.0},
            'opacity': 1.0,
            'hitPadding': 0.0,
            'isVisible': true,
            'isSelectable': true,
            'isLocked': false,
            'isDeletable': true,
            'isTransformable': true,
            'metadata': {'label': 'Loaded smoke element'},
            'size': {'w': 18.0, 'h': 14.0},
            'fillColor': '#3300FF00',
            'strokeColor': '#FF00AA00',
            'strokeWidth': 1.0,
          },
        ],
        'metadata': {'name': 'Loaded smoke layer'},
      },
    ],
    'metadata': {'source': 'public incremental smoke load'},
  };
}

Map<String, Object?> _geometryRichSchemaV1Document() {
  return {
    'schemaVersion': 1,
    'camera': {
      'offset': {'x': 4.0, 'y': -6.0},
    },
    'background': {
      'color': '#FFF8FAFC',
      'grid': {
        'enabled': true,
        'cellSize': 12.0,
        'color': '#220F172A',
      },
    },
    'palette': {
      'penColors': ['#FF0F172A', '#FF2563EB'],
      'backgroundColors': ['#FFF8FAFC'],
      'gridSizes': [12.0, 24.0],
    },
    'resources': [],
    'backgroundLayer': {
      'elements': [
        {
          'id': 'geometry-bg',
          'kind': 'rect',
          'revision': 0,
          'transform': {'a': 1.0, 'b': 0.0, 'c': 0.0, 'd': 1.0, 'tx': -8.0, 'ty': -8.0},
          'opacity': 1.0,
          'hitPadding': 0.0,
          'isVisible': true,
          'isSelectable': false,
          'isLocked': true,
          'isDeletable': false,
          'isTransformable': false,
          'metadata': {'role': 'background geometry'},
          'size': {'w': 96.0, 'h': 64.0},
          'fillColor': '#FFE2E8F0',
          'strokeColor': null,
          'strokeWidth': 0.0,
        },
      ],
    },
    'layers': [
      {
        'id': 'geometry-layer',
        'elements': [
          {
            'id': 'overlap-bottom',
            'kind': 'rect',
            'revision': 0,
            'transform': {'a': 1.0, 'b': 0.0, 'c': 0.0, 'd': 1.0, 'tx': 8.0, 'ty': 8.0},
            'opacity': 1.0,
            'hitPadding': 2.0,
            'isVisible': true,
            'isSelectable': true,
            'isLocked': false,
            'isDeletable': true,
            'isTransformable': true,
            'metadata': {'role': 'bottom overlap'},
            'size': {'w': 40.0, 'h': 28.0},
            'fillColor': '#662563EB',
            'strokeColor': '#FF1D4ED8',
            'strokeWidth': 1.0,
          },
          {
            'id': 'overlap-top',
            'kind': 'rect',
            'revision': 0,
            'transform': {'a': 0.984807753, 'b': 0.173648178, 'c': -0.173648178, 'd': 0.984807753, 'tx': 16.0, 'ty': 12.0},
            'opacity': 0.9,
            'hitPadding': 3.0,
            'isVisible': true,
            'isSelectable': true,
            'isLocked': false,
            'isDeletable': true,
            'isTransformable': true,
            'metadata': {'role': 'top overlap'},
            'size': {'w': 36.0, 'h': 20.0},
            'fillColor': '#66F97316',
            'strokeColor': '#FFEA580C',
            'strokeWidth': 2.0,
          },
        ],
        'metadata': {'name': 'Geometry layer'},
      },
    ],
    'metadata': {'source': 'public geometry smoke'},
  };
}

Map<String, Object?> _replacementGeometryRichSchemaV1Document() {
  return {
    'schemaVersion': 1,
    'camera': {
      'offset': {'x': -12.0, 'y': 18.0},
    },
    'background': {
      'color': '#FFFFFFFF',
      'grid': {
        'enabled': false,
        'cellSize': 20.0,
        'color': '#00000000',
      },
    },
    'palette': {
      'penColors': ['#FF111827'],
      'backgroundColors': ['#FFFFFFFF'],
      'gridSizes': [10.0, 20.0],
    },
    'resources': [],
    'backgroundLayer': {
      'elements': [
        {
          'id': 'replacement-bg',
          'kind': 'rect',
          'revision': 0,
          'transform': {'a': 1.0, 'b': 0.0, 'c': 0.0, 'd': 1.0, 'tx': 0.0, 'ty': 0.0},
          'opacity': 1.0,
          'hitPadding': 0.0,
          'isVisible': true,
          'isSelectable': false,
          'isLocked': true,
          'isDeletable': false,
          'isTransformable': false,
          'metadata': {'role': 'replacement background'},
          'size': {'w': 32.0, 'h': 32.0},
          'fillColor': '#FFF1F5F9',
          'strokeColor': null,
          'strokeWidth': 0.0,
        },
      ],
    },
    'layers': [
      {
        'id': 'replacement-layer',
        'elements': [
          {
            'id': 'replacement-content',
            'kind': 'rect',
            'revision': 0,
            'transform': {'a': 1.0, 'b': 0.0, 'c': 0.0, 'd': 1.0, 'tx': 6.0, 'ty': 10.0},
            'opacity': 1.0,
            'hitPadding': 1.0,
            'isVisible': true,
            'isSelectable': true,
            'isLocked': false,
            'isDeletable': true,
            'isTransformable': true,
            'metadata': {'role': 'replacement content'},
            'size': {'w': 18.0, 'h': 18.0},
            'fillColor': '#6650C878',
            'strokeColor': '#FF16A34A',
            'strokeWidth': 1.0,
          },
        ],
        'metadata': {'name': 'Replacement geometry layer'},
      },
    ],
    'metadata': {'source': 'replacement public geometry smoke'},
  };
}

CanvasRuntimeRevisions _runtimeRevisions({
  required int document,
  required int selection,
}) {
  return CanvasRuntimeRevisions(
    document: document,
    selection: selection,
    preview: 0,
    viewCamera: 0,
    resourceVisual: 0,
    interaction: 0,
    epoch: 0,
  );
}
''';
