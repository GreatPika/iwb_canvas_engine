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
import 'dart:ui' hide Image;
import 'dart:ui' as ui show Image;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  testWidgets('schema v1 document reaches runtime state and selection', (tester) async {
    final decodedDocument = decodeCanvasDocument(_smallSchemaV1Document());
    final runtime = CanvasRuntime(initialDocument: decodedDocument);
    final resolver = _NoopResolver();
    addTearDown(runtime.dispose);

    expect(runtime.preview, isA<CanvasNoPreview>());
    expect(runtime.preview.kind, CanvasPreviewKind.none);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 120,
          height: 80,
          child: CanvasSurface(
            runtime: runtime,
            resourceResolver: resolver,
            interactive: false,
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host')),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsOneWidget);
    expect(resolver.calls, 0);

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

  test('public consumer uses selection move and command actions', () async {
    await _exercisePublicSelectionMoveAndCommandSurface();
  });

  testWidgets('public consumer draws pencil marker and line', (tester) async {
    await _exercisePublicDrawWorkflow(tester);
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

Future<void> _exercisePublicSelectionMoveAndCommandSurface() async {
  CanvasMoveCommitRequest? moveRequest;
  var resolverCalls = 0;
  final runtime = CanvasRuntime(
    initialDocument: _selectionMoveCommandDocument(),
    config: CanvasRuntimeConfig(
      clearSelectionOnDrawModeEnter: true,
      moveCommitResolver: (request) {
        resolverCalls += 1;
        moveRequest = request;

        return const CanvasMoveCommit(delta: Offset(7, 8));
      },
    ),
  );
  final actions = <CanvasActionCommitted>[];
  final actionSubscription = runtime.actions.listen(actions.add);
  var actionSubscriptionCanceled = false;
  var disposed = false;

  try {
    expect(runtime.tools.mode, CanvasInteractionMode.move);
    expect(runtime.contextActionRequests.isBroadcast, isTrue);
    runtime.tools.setDrawTool(CanvasDrawTool.marker);
    runtime.tools.setDrawColor(const Color(0xFF123456));
    runtime.tools.setPointerPolicy(CanvasPointerPolicy(tapSlop: 4));
    expect(runtime.tools.drawStyle.tool, CanvasDrawTool.marker);
    expect(runtime.tools.drawStyle.color, const Color(0xFF123456));
    expect(runtime.tools.pointerPolicy, CanvasPointerPolicy(tapSlop: 4));

    runtime.selection.setSelection([CanvasElementId('a')]);
    runtime.tools.setMode(CanvasInteractionMode.draw);
    expect(runtime.selection.selectedElementIds, isEmpty);
    expect(runtime.tools.mode, CanvasInteractionMode.draw);
    runtime.tools.setMode(CanvasInteractionMode.move);

    expect(
      () => runtime.tools.handleDoubleTap(position: Offset.zero),
      throwsA(isA<UnsupportedError>()),
    );

    _dragPointer(
      runtime.tools,
      start: const Offset(-20, -20),
      end: const Offset(45, 12),
      timestampMs: 17,
    );
    await Future<void>.delayed(Duration.zero);

    expect(runtime.preview, isA<CanvasNoPreview>());
    expect(runtime.selection.selectedElementIds, {
      CanvasElementId('a'),
      CanvasElementId('b'),
      CanvasElementId('locked'),
    });
    expect(actions, hasLength(1));
    final marqueeAction = actions.single;
    expect(marqueeAction.type, CanvasActionType.selectMarquee);
    expect(marqueeAction.timestampMs, 17);
    expect(marqueeAction.elementIds, [
      CanvasElementId('a'),
      CanvasElementId('b'),
      CanvasElementId('locked'),
    ]);
    final marqueePayload =
        marqueeAction.payload as CanvasSelectionActionPayload;
    expect(marqueePayload.previousSelection, isEmpty);
    expect(marqueePayload.nextSelection, marqueeAction.elementIds);
    expect(
      marqueePayload.marqueeRectWorld,
      const Rect.fromLTRB(-20, -20, 45, 12),
    );

    runtime.selection.setSelection([
      CanvasElementId('b'),
      CanvasElementId('a'),
      CanvasElementId('locked'),
    ]);
    runtime.tools.handlePointer(
      _pointer(CanvasPointerLifecyclePhase.down, Offset.zero),
    );
    runtime.tools.handlePointer(
      _pointer(CanvasPointerLifecyclePhase.move, const Offset(3, 4)),
    );
    final preview = runtime.preview as CanvasSelectedMovePreview;
    expect(preview.delta, const Offset(3, 4));
    runtime.tools.handlePointer(
      _pointer(CanvasPointerLifecyclePhase.up, const Offset(3, 4), timestampMs: 21),
    );
    await Future<void>.delayed(Duration.zero);

    expect(resolverCalls, 1);
    final request = moveRequest as CanvasMoveCommitRequest;
    expect(request.proposedDelta, const Offset(3, 4));
    expect(request.timestampMs, 21);
    expect(request.movedElements.map((element) => element.id), [
      CanvasElementId('a'),
      CanvasElementId('b'),
    ]);
    expect(runtime.preview, isA<CanvasNoPreview>());
    expect(_rect(runtime, 'a').transform, CanvasTransform.translation(const Offset(7, 8)));
    expect(_rect(runtime, 'b').transform, CanvasTransform.translation(const Offset(27, 8)));
    expect(actions, hasLength(2));
    final moveAction = actions.last;
    expect(moveAction.type, CanvasActionType.moveSelection);
    expect(moveAction.timestampMs, 22);
    expect(moveAction.elementIds, [
      CanvasElementId('a'),
      CanvasElementId('b'),
    ]);
    final movePayload = moveAction.payload as CanvasTransformActionPayload;
    expect(movePayload.delta, CanvasTransform.translation(const Offset(7, 8)));
    expect(movePayload.operation, CanvasTransformOperation.move);
    expect(movePayload.pivotWorld, isNull);

    expect(
      runtime.commands.removeElement(CanvasElementId('remove-me'), timestampMs: 30),
      isTrue,
    );
    expect(
      runtime.commands.commitTextEdit(
        CanvasInteractionRequestId('unknown'),
        'ignored',
        timestampMs: 31,
      ),
      isFalse,
    );
    await Future<void>.delayed(Duration.zero);
    expect(actions, hasLength(3));
    final deleteAction = actions.last;
    expect(deleteAction.type, CanvasActionType.deleteElements);
    expect(deleteAction.elementIds, [CanvasElementId('remove-me')]);

    final clearResult = runtime.commands.clearContent(
      removeUnusedResources: true,
      timestampMs: 32,
    );
    await Future<void>.delayed(Duration.zero);
    expect(clearResult.didClearContent, isTrue);
    expect(clearResult.removedElementIds, [
      CanvasElementId('a'),
      CanvasElementId('b'),
      CanvasElementId('locked'),
      CanvasElementId('hidden'),
    ]);
    expect(clearResult.removedResourceIds, [CanvasResourceId('unused-resource')]);
    expect(actions, hasLength(4));
    final clearAction = actions.last;
    expect(clearAction.type, CanvasActionType.clearContent);
    expect(clearAction.elementIds, clearResult.removedElementIds);
    final clearPayload = clearAction.payload as CanvasClearActionPayload;
    expect(clearPayload.removedElementIds, clearResult.removedElementIds);
    expect(clearPayload.removedResourceIds, clearResult.removedResourceIds);

    await actionSubscription.cancel();
    actionSubscriptionCanceled = true;
    runtime.dispose();
    disposed = true;
  } finally {
    if (!actionSubscriptionCanceled) {
      await actionSubscription.cancel();
    }
    if (!disposed) {
      runtime.dispose();
    }
  }
}

Future<void> _exercisePublicDrawWorkflow(WidgetTester tester) async {
  final runtime = CanvasRuntime();
  final actions = <CanvasActionCommitted>[];
  final actionSubscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await actionSubscription.cancel();
    runtime.dispose();
  });

  await tester.pumpWidget(_surfaceHost(runtime, interactive: true));

  runtime.tools.setMode(CanvasInteractionMode.draw);
  runtime.tools.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.pencil,
      color: const Color(0xFF112233),
      pencilThickness: 3,
    ),
  );
  final beforePencil = runtime.state.value;
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, Offset.zero),
  );
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(2, 3)),
  );
  final pencilPreview = runtime.preview as CanvasPencilStrokePreview;
  expect(pencilPreview.points, const [Offset.zero, Offset(2, 3)]);
  expect(runtime.state.value.revisions.document, beforePencil.revisions.document);
  expect(
    runtime.state.value.revisions.preview,
    greaterThan(beforePencil.revisions.preview),
  );
  runtime.tools.handlePointer(
    _pointer(
      CanvasPointerLifecyclePhase.up,
      const Offset(4, 5),
      timestampMs: 10,
    ),
  );
  await tester.pump();
  expect(actions, hasLength(1));
  _expectPencilDraw(runtime, actions.single);

  runtime.tools.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.marker,
      color: const Color(0xFF445566),
      markerThickness: 12,
      markerOpacity: 0.4,
    ),
  );
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(6, 7)),
  );
  final markerPreview = runtime.preview as CanvasMarkerStrokePreview;
  expect(markerPreview.points, const [Offset(6, 7)]);
  runtime.tools.handlePointer(
    _pointer(
      CanvasPointerLifecyclePhase.up,
      const Offset(8, 9),
      timestampMs: 11,
    ),
  );
  await tester.pump();
  expect(actions, hasLength(2));
  _expectMarkerDraw(runtime, actions.last);

  runtime.tools.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.line,
      color: const Color(0xFF778899),
      lineThickness: 4,
    ),
  );
  final beforeLine = runtime.state.value;
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(1, 2)),
  );
  runtime.tools.handlePointer(
    _pointer(
      CanvasPointerLifecyclePhase.up,
      const Offset(1, 2),
      timestampMs: 30,
    ),
  );
  final pendingLine = runtime.preview as CanvasPendingLineStartPreview;
  expect(pendingLine.start, const Offset(1, 2));
  expect(pendingLine.timestampMs, 30);
  expect(runtime.state.value.revisions.document, beforeLine.revisions.document);
  expect(actions, hasLength(2));

  await tester.pumpWidget(_surfaceHost(runtime, interactive: false));
  final preservedLine = runtime.preview as CanvasPendingLineStartPreview;
  expect(preservedLine.start, pendingLine.start);
  expect(preservedLine.timestampMs, pendingLine.timestampMs);

  await tester.pumpWidget(_surfaceHost(runtime, interactive: true));
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(3, 4)),
  );
  final linePreview = runtime.preview as CanvasLinePreview;
  expect(linePreview.start, const Offset(1, 2));
  expect(linePreview.end, const Offset(3, 4));
  runtime.tools.handlePointer(
    _pointer(
      CanvasPointerLifecyclePhase.up,
      const Offset(3, 4),
      timestampMs: 31,
    ),
  );
  await tester.pump();
  expect(actions, hasLength(3));
  _expectLineDraw(runtime, actions.last);
}

Widget _surfaceHost(CanvasRuntime runtime, {required bool interactive}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 120,
      height: 80,
      child: CanvasSurface(runtime: runtime, interactive: interactive),
    ),
  );
}

void _expectPencilDraw(
  CanvasRuntime runtime,
  CanvasActionCommitted action,
) {
  expect(action.type, CanvasActionType.drawPencil);
  expect(action.timestampMs, 10);
  final payload = action.payload as CanvasDrawStrokeActionPayload;
  expect(payload.tool, CanvasDrawTool.pencil);
  expect(payload.color, const Color(0xFF112233));
  expect(payload.thickness, 3);
  expect(payload.opacity, 1);
  expect(payload.pointCount, 3);

  final stroke = _element(runtime, action) as CanvasStrokeElement;
  expect(stroke.points, const [Offset.zero, Offset(2, 3), Offset(4, 5)]);
  expect(stroke.color, const Color(0xFF112233));
  expect(stroke.thickness, 3);
  expect(stroke.opacity, 1);
}

void _expectMarkerDraw(
  CanvasRuntime runtime,
  CanvasActionCommitted action,
) {
  expect(action.type, CanvasActionType.drawMarker);
  expect(action.timestampMs, 11);
  final payload = action.payload as CanvasDrawStrokeActionPayload;
  expect(payload.tool, CanvasDrawTool.marker);
  expect(payload.color, const Color(0xFF445566));
  expect(payload.thickness, 12);
  expect(payload.opacity, 0.4);
  expect(payload.pointCount, 2);

  final stroke = _element(runtime, action) as CanvasStrokeElement;
  expect(stroke.points, const [Offset(6, 7), Offset(8, 9)]);
  expect(stroke.color, const Color(0xFF445566));
  expect(stroke.thickness, 12);
  expect(stroke.opacity, 0.4);
}

void _expectLineDraw(CanvasRuntime runtime, CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.drawLine);
  expect(action.timestampMs, 31);
  final payload = action.payload as CanvasDrawLineActionPayload;
  expect(payload.color, const Color(0xFF778899));
  expect(payload.thickness, 4);
  expect(payload.opacity, 1);
  expect(payload.startWorld, const Offset(1, 2));
  expect(payload.endWorld, const Offset(3, 4));

  final line = _element(runtime, action) as CanvasLineElement;
  expect(line.start, const Offset(1, 2));
  expect(line.end, const Offset(3, 4));
  expect(line.color, const Color(0xFF778899));
  expect(line.thickness, 4);
  expect(line.opacity, 1);
}

CanvasElement _element(CanvasRuntime runtime, CanvasActionCommitted action) {
  return runtime
      .readDocument()
      .layers
      .expand((layer) => layer.elements)
      .singleWhere((element) => element.id == action.elementIds.single);
}

void _dragPointer(
  CanvasToolPort tools, {
  required Offset start,
  required Offset end,
  int? timestampMs,
}) {
  tools.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, start));
  tools.handlePointer(_pointer(CanvasPointerLifecyclePhase.move, end));
  tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, end, timestampMs: timestampMs),
  );
}

CanvasPointerSample _pointer(
  CanvasPointerLifecyclePhase phase,
  Offset position, {
  int? timestampMs,
}) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
  );
}

CanvasRectElement _rect(CanvasRuntime runtime, String id) {
  return runtime
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasRectElement>()
      .firstWhere((element) => element.id == CanvasElementId(id));
}

CanvasDocument _selectionMoveCommandDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('unused-resource'),
        source: CanvasResourceSource.appKey('unused'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('interaction-layer'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(10, 10)),
          CanvasRectElement(
            id: CanvasElementId('b'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(20, 0)),
          ),
          CanvasRectElement(
            id: CanvasElementId('locked'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(40, 0)),
            isLocked: true,
          ),
          CanvasRectElement(
            id: CanvasElementId('hidden'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(45, 0)),
            isVisible: false,
          ),
          CanvasRectElement(
            id: CanvasElementId('remove-me'),
            size: const Size(4, 4),
            transform: CanvasTransform.translation(const Offset(80, 0)),
          ),
        ],
      ),
    ],
  );
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

final class _NoopResolver implements CanvasResourceResolver {
  int calls = 0;

  @override
  ui.Image? resolveImage(CanvasImageResource resource) {
    calls += 1;

    return null;
  }
}
''';
