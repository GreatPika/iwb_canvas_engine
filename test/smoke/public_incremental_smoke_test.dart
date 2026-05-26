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

    runtime.edits.edit((edit) {
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
    expect(editedState.revisions.document, 1);
    expect(editedState.revisions.selection, 1);
    expect(runtime.readDocument().layers.single.elements, hasLength(2));

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
