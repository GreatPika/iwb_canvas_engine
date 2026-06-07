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
import 'dart:convert';
import 'dart:ui' hide Image;
import 'dart:ui' as ui show Image;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  testWidgets('schema v1 document reaches runtime state and selection', (tester) async {
    final runtime = CanvasRuntime();
    runtime.edits.loadDocumentFromJson(jsonEncode(_smallSchemaV1Document()));
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
    expect(
      initialState.revisions,
      _runtimeRevisions(document: 1, selection: 1, viewCamera: 1, epoch: 1),
    );
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
    expect(selectedState.revisions.selection, 2);
    expect(selectedState.revisions.document, 1);
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
    expect(editedState.revisions.document, 2);
    expect(editedState.revisions.selection, 2);
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

    final loadSnapshots = <CanvasRuntimeState>[];
    runtime.state.addListener(() {
      loadSnapshots.add(runtime.state.value);
    });

    runtime.edits.loadDocumentFromJson(jsonEncode(_secondSchemaV1Document()));

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
    expect(loadedState.revisions.document, 3);
    expect(loadedState.revisions.selection, 3);
    expect(loadedState.revisions.viewCamera, 2);
    expect(loadedState.revisions.epoch, 2);
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

    runtime.edits.loadDocumentFromJson(
      jsonEncode(_geometryRichSchemaV1Document()),
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
    expect(geometryState.revisions.document, 4);
    expect(geometryState.revisions.selection, 4);

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
    expect(geometryEditedState.revisions.document, 5);
    final geometryEditedDocument = runtime.readDocument();
    final movedTop = geometryEditedDocument.layers.single.elements.last as CanvasRectElement;
    expect(movedTop.transform.translation, const Offset(24, 18));
    expect(movedTop.size, const Size(44, 24));

    runtime.edits.loadDocumentFromJson(
      jsonEncode(_replacementGeometryRichSchemaV1Document()),
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
    expect(replacementState.revisions.document, 6);
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

  testWidgets('public consumer erases and commits context text requests', (tester) async {
    await _exercisePublicEraserAndContextRequestWorkflow(tester);
  });

  testWidgets('public consumer can replace the official text editing overlay', (tester) async {
    await _exercisePublicCustomTextEditingOverlay(tester);
  });

  testWidgets('public consumer uses CanvasSurface pointer and resource bridge', (tester) async {
    await _exercisePublicCanvasSurfacePointerAndResourceBridge(tester);
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
    config: CanvasRuntimeConfig(
      clearSelectionOnDrawModeEnter: true,
      moveCommitResolver: (request) {
        resolverCalls += 1;
        moveRequest = request;

        return const CanvasMoveCommit(delta: Offset(7, 8));
      },
    ),
  );
  runtime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_selectionMoveCommandDocument()),
  );
  final actions = <CanvasActionCommitted>[];
  final contextRequests = <CanvasContextActionRequested>[];
  final actionSubscription = runtime.actions.listen(actions.add);
  final requestSubscription = runtime.contextActionRequests.listen(
    contextRequests.add,
  );
  var actionSubscriptionCanceled = false;
  var requestSubscriptionCanceled = false;
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

    runtime.tools.handleDoubleTap(position: Offset.zero);
    await Future<void>.delayed(Duration.zero);
    expect(contextRequests, hasLength(1));
    expect(contextRequests.single.trigger, CanvasContextActionTrigger.doubleTap);
    expect(
      contextRequests.single.target,
      isA<CanvasContentElementContextActionTarget>(),
    );
    expect(actions, isEmpty);

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
    if (!requestSubscriptionCanceled) {
      await requestSubscription.cancel();
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

Future<void> _exercisePublicEraserAndContextRequestWorkflow(
  WidgetTester tester,
) async {
  final runtime = CanvasRuntime();
  runtime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_eraserContextRequestDocument()),
  );
  final actions = <CanvasActionCommitted>[];
  final requests = <CanvasContextActionRequested>[];
  final stateEvents = <CanvasRuntimeState>[];
  final deliveryEvents = <String>[];
  final actionSubscription = runtime.actions.listen((action) {
    actions.add(action);
    deliveryEvents.add('action:${action.type.name}');
  });
  final requestSubscription = runtime.contextActionRequests.listen(requests.add);
  runtime.state.addListener(() {
    stateEvents.add(runtime.state.value);
    deliveryEvents.add('state');
  });
  addTearDown(() async {
    await actionSubscription.cancel();
    await requestSubscription.cancel();
    runtime.dispose();
  });

  await tester.pumpWidget(_surfaceHost(runtime, interactive: true));

  _previewAndCommitPublicEraser(runtime, actions, deliveryEvents);
  await tester.pump();
  _expectPublicEraseCommit(runtime, actions, deliveryEvents);

  _clearPublicEventBuffers(actions, requests, stateEvents, deliveryEvents);
  runtime.tools.handleDoubleTap(position: const Offset(90, 0), timestampMs: 50);
  await tester.pump();
  final textRequest = _expectPublicContentRequest(
    runtime,
    actions,
    requests,
    stateEvents,
  );

  _clearPublicEventBuffers(actions, requests, stateEvents, deliveryEvents);
  expect(
    runtime.commands.commitTextEdit(
      textRequest.requestId,
      'updated',
      timestampMs: 51,
    ),
    isTrue,
  );
  await tester.pump();
  _expectPublicTextEditCommit(
    runtime,
    actions,
    stateEvents,
    deliveryEvents,
    textRequest.requestId,
  );

  _clearPublicEventBuffers(actions, requests, stateEvents, deliveryEvents);
  expect(
    runtime.commands.commitTextEdit(textRequest.requestId, 'retry'),
    isFalse,
  );
  final beforeUnknown = runtime.state.value;
  expect(
    runtime.commands.commitTextEdit(
      CanvasInteractionRequestId('unknown'),
      'ignored',
    ),
    isFalse,
  );
  await tester.pump();
  expect(actions, isEmpty);
  expect(stateEvents, isEmpty);
  expect(runtime.state.value, same(beforeUnknown));

  _clearPublicEventBuffers(actions, requests, stateEvents, deliveryEvents);
  runtime.tools.handleDoubleTap(position: const Offset(200, 200), timestampMs: 52);
  await tester.pump();
  _expectPublicEmptyRequest(actions, requests, stateEvents);
}

Future<void> _exercisePublicCustomTextEditingOverlay(
  WidgetTester tester,
) async {
  final runtime = CanvasRuntime();
  runtime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_eraserContextRequestDocument(
      cameraOffset: const Offset(5, 3),
    )),
  );
  final requests = <CanvasContextActionRequested>[];
  final requestSubscription = runtime.contextActionRequests.listen(requests.add);
  addTearDown(() async {
    await requestSubscription.cancel();
    runtime.dispose();
  });

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 160,
        height: 120,
        child: Stack(
          children: [
            CanvasSurface(runtime: runtime, interactive: false),
            _CustomTextEditingOverlay(runtime: runtime),
          ],
        ),
      ),
    ),
  );

  runtime.tools.handleDoubleTap(position: const Offset(85, -3), timestampMs: 70);
  await tester.pump();
  final session = runtime.textEditing.startFromContextAction(requests.single);
  expect(session, isNotNull);
  await tester.pump();

  expect(
    find.byKey(const ValueKey<String>('custom.text.edit.host')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('custom.text.edit.field')),
    findsOneWidget,
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('custom.text.edit.field')),
    'custom',
  );
  await tester.pump();
  final editor = tester.widget<EditableText>(
    find.byKey(const ValueKey<String>('custom.text.edit.field')),
  );
  expect(editor.style.fontSize, session!.style.fontSize);
  expect(editor.textAlign, session.style.textAlign);
  editor.onEditingComplete?.call();
  await tester.pump();

  expect(
    (_elementOrNull(runtime, CanvasElementId('text-edit')) as CanvasTextElement)
        .text,
    'custom',
  );
  expect(runtime.textEditing.activeSession.value, isNull);
}

Future<void> _exercisePublicCanvasSurfacePointerAndResourceBridge(
  WidgetTester tester,
) async {
  final resourceFreeRuntime = CanvasRuntime();
  resourceFreeRuntime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_surfaceShapeDocument()),
  );
  final resourceFreeResolver = _NoopResolver();
  addTearDown(resourceFreeRuntime.dispose);
  await tester.pumpWidget(
    _surfaceHost(
      resourceFreeRuntime,
      interactive: false,
      resourceResolver: resourceFreeResolver,
    ),
  );
  expect(_paintHosts(), findsOneWidget);
  expect(resourceFreeResolver.calls, 0);

  final runtime = CanvasRuntime();
  runtime.edits.loadDocumentFromJson(
    encodeCanvasDocumentToJson(_surfaceImageDocument()),
  );
  final actions = <CanvasActionCommitted>[];
  final actionSubscription = runtime.actions.listen(actions.add);
  addTearDown(() async {
    await actionSubscription.cancel();
    runtime.dispose();
  });

  final resolver = _NoopResolver();
  await tester.pumpWidget(
    _surfaceHost(runtime, interactive: true, resourceResolver: resolver),
  );
  await tester.pump();
  expect(_paintHosts(), findsOneWidget);
  expect(find.byType(CustomPaint), findsOneWidget);
  expect(resolver.calls, greaterThan(0));
  expect(tester.takeException(), isNull);

  final resolverCallsBeforeReplacement = resolver.calls;
  final replacementResolver = _NoopResolver();
  await tester.pumpWidget(
    _surfaceHost(
      runtime,
      interactive: true,
      resourceResolver: replacementResolver,
    ),
  );
  await tester.pump();
  expect(resolver.calls, resolverCallsBeforeReplacement);
  expect(replacementResolver.calls, greaterThan(0));
  expect(tester.takeException(), isNull);

  runtime.tools
    ..setMode(CanvasInteractionMode.draw)
    ..setDrawStyle(
      CanvasDrawStyle(
        tool: CanvasDrawTool.pencil,
        color: const Color(0xFF135724),
        pencilThickness: 5,
      ),
    );
  await _drawFlutterStroke(tester, const Offset(8, 9), const Offset(18, 19));
  await tester.pump();
  expect(actions, hasLength(1));
  final pencilAction = actions.single;
  expect(pencilAction.type, CanvasActionType.drawPencil);
  final stroke = _element(runtime, pencilAction) as CanvasStrokeElement;
  expect(stroke.points, const [Offset(8, 9), Offset(18, 19)]);
  expect(stroke.color, const Color(0xFF135724));
  expect(stroke.thickness, 5);

  final beforeFalse = _PublicRuntimeProbe(runtime, actions);
  await tester.pumpWidget(
    _surfaceHost(
      runtime,
      interactive: false,
      resourceResolver: replacementResolver,
    ),
  );
  await _tapPaintHost(tester, const Offset(28, 29));
  await tester.pump();
  beforeFalse.expectNoEffects(runtime, actions);

  runtime.tools.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.line,
      color: const Color(0xFF246813),
      lineThickness: 4,
    ),
  );
  await tester.pumpWidget(
    _surfaceHost(
      runtime,
      interactive: true,
      resourceResolver: replacementResolver,
    ),
  );
  await _tapPaintHost(tester, const Offset(31, 32), timestampMs: 70);
  final pendingLine = runtime.preview as CanvasPendingLineStartPreview;
  expect(pendingLine.start, const Offset(31, 32));
  expect(pendingLine.timestampMs, 71);
  final beforePendingFalse = _PublicRuntimeProbe(runtime, actions);
  await tester.pumpWidget(
    _surfaceHost(
      runtime,
      interactive: false,
      resourceResolver: replacementResolver,
    ),
  );
  await tester.pump();
  final preservedLine = runtime.preview as CanvasPendingLineStartPreview;
  expect(preservedLine.start, pendingLine.start);
  expect(preservedLine.timestampMs, pendingLine.timestampMs);
  beforePendingFalse.expectNoEffects(runtime, actions);
}

void _previewAndCommitPublicEraser(
  CanvasRuntime runtime,
  List<CanvasActionCommitted> actions,
  List<String> deliveryEvents,
) {
  runtime.tools
    ..setMode(CanvasInteractionMode.draw)
    ..setDrawStyle(
      CanvasDrawStyle(tool: CanvasDrawTool.eraser, eraserThickness: 6),
    );
  final before = runtime.state.value;
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(2, 2)),
  );
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(18, 2)),
  );
  final preview = runtime.preview as CanvasEraserPreview;
  expect(preview.corridor, const [Offset(2, 2), Offset(18, 2)]);
  expect(() => preview.corridor.add(Offset.zero), throwsUnsupportedError);
  expect(preview.thickness, 6);
  expect(runtime.state.value.revisions.document, before.revisions.document);
  expect(actions, isEmpty);
  deliveryEvents.clear();

  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(18, 2), timestampMs: 40),
  );
}

void _expectPublicEraseCommit(
  CanvasRuntime runtime,
  List<CanvasActionCommitted> actions,
  List<String> deliveryEvents,
) {
  expect(deliveryEvents, ['state', 'action:erase']);
  expect(runtime.preview, isA<CanvasNoPreview>());
  expect(_elementOrNull(runtime, CanvasElementId('erase-me')), isNull);
  expect(actions, hasLength(1));
  final action = actions.single;
  expect(action.type, CanvasActionType.erase);
  expect(action.timestampMs, 40);
  expect(action.elementIds, [CanvasElementId('erase-me')]);
  final payload = action.payload as CanvasEraseActionPayload;
  expect(payload.eraserThickness, 6);
  expect(payload.erasedElementIds, action.elementIds);
  expect(payload.corridorPointCount, 2);
  expect(
    (_elementOrNull(runtime, CanvasElementId('locked-content')) as CanvasRectElement)
        .isDeletable,
    isFalse,
  );
}

CanvasContextActionRequested _expectPublicContentRequest(
  CanvasRuntime runtime,
  List<CanvasActionCommitted> actions,
  List<CanvasContextActionRequested> requests,
  List<CanvasRuntimeState> stateEvents,
) {
  expect(actions, isEmpty);
  expect(stateEvents, isEmpty);
  expect(requests, hasLength(1));
  final request = requests.single;
  expect(request.trigger, CanvasContextActionTrigger.doubleTap);
  expect(request.timestampMs, 50);
  expect(request.viewPosition, const Offset(90, 0));
  expect(request.worldPosition, const Offset(90, 0));
  expect(request.controllerEpoch, runtime.state.value.revisions.epoch);
  expect(request.documentRevision, runtime.state.value.revisions.document);
  final target = request.target as CanvasContentElementContextActionTarget;
  expect(target.elementSnapshot.id, CanvasElementId('text-edit'));
  expect(target.elementSnapshot, isA<CanvasTextElement>());
  expect(target.boundsWorld.isEmpty, isFalse);
  expect(target.boundsWorld.left.isFinite, isTrue);
  expect(target.boundsWorld.top.isFinite, isTrue);
  expect(target.boundsWorld.right.isFinite, isTrue);
  expect(target.boundsWorld.bottom.isFinite, isTrue);

  return request;
}

void _expectPublicTextEditCommit(
  CanvasRuntime runtime,
  List<CanvasActionCommitted> actions,
  List<CanvasRuntimeState> stateEvents,
  List<String> deliveryEvents,
  CanvasInteractionRequestId requestId,
) {
  expect(deliveryEvents, ['state', 'action:editText']);
  expect(stateEvents, hasLength(1));
  expect(actions, hasLength(1));
  expect((_elementOrNull(runtime, CanvasElementId('text-edit')) as CanvasTextElement).text, 'updated');
  final action = actions.single;
  expect(action.type, CanvasActionType.editText);
  expect(action.timestampMs, 51);
  expect(action.elementIds, [CanvasElementId('text-edit')]);
  final payload = action.payload as CanvasTextEditActionPayload;
  expect(payload.requestId, requestId);
  expect(payload.previousTextLength, 5);
  expect(payload.nextTextLength, 7);
  final observedActionSurface = '$action $payload';
  expect(observedActionSurface, isNot(contains('hello')));
  expect(observedActionSurface, isNot(contains('updated')));
}

void _expectPublicEmptyRequest(
  List<CanvasActionCommitted> actions,
  List<CanvasContextActionRequested> requests,
  List<CanvasRuntimeState> stateEvents,
) {
  expect(actions, isEmpty);
  expect(stateEvents, isEmpty);
  expect(requests, hasLength(1));
  final request = requests.single;
  expect(request.timestampMs, 52);
  expect(request.viewPosition, const Offset(200, 200));
  expect(request.worldPosition, const Offset(200, 200));
  expect(request.target, isA<CanvasEmptyCanvasContextActionTarget>());
}

void _clearPublicEventBuffers(
  List<CanvasActionCommitted> actions,
  List<CanvasContextActionRequested> requests,
  List<CanvasRuntimeState> stateEvents,
  List<String> deliveryEvents,
) {
  actions.clear();
  requests.clear();
  stateEvents.clear();
  deliveryEvents.clear();
}

Widget _surfaceHost(
  CanvasRuntime runtime, {
  required bool interactive,
  CanvasResourceResolver? resourceResolver,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 120,
      height: 80,
      child: CanvasSurface(
        runtime: runtime,
        resourceResolver: resourceResolver,
        interactive: interactive,
      ),
    ),
  );
}

Finder _paintHosts() {
  return find.byKey(const ValueKey<String>('iwb_canvas_surface.paint_host'));
}

Future<void> _drawFlutterStroke(
  WidgetTester tester,
  Offset start,
  Offset end,
) async {
  final gesture = await _downOnPaintHost(tester, start, timestampMs: 60);
  await gesture.moveTo(
    tester.getTopLeft(_paintHosts()) + end,
    timeStamp: const Duration(milliseconds: 61),
  );
  await gesture.up(timeStamp: const Duration(milliseconds: 62));
  await tester.pump();
}

Future<void> _tapPaintHost(
  WidgetTester tester,
  Offset localPosition, {
  int timestampMs = 1,
}) async {
  final gesture = await _downOnPaintHost(
    tester,
    localPosition,
    timestampMs: timestampMs,
  );
  await gesture.up(timeStamp: Duration(milliseconds: timestampMs + 1));
  await tester.pump();
}

Future<TestGesture> _downOnPaintHost(
  WidgetTester tester,
  Offset localPosition, {
  int timestampMs = 1,
}) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
  await gesture.down(
    tester.getTopLeft(_paintHosts()) + localPosition,
    timeStamp: Duration(milliseconds: timestampMs),
  );

  return gesture;
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

CanvasElement? _elementOrNull(CanvasRuntime runtime, CanvasElementId id) {
  for (final layer in runtime.readDocument().layers) {
    for (final element in layer.elements) {
      if (element.id == id) {
        return element;
      }
    }
  }

  return null;
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

CanvasDocument _surfaceShapeDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('surface-shape-layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('surface-shape'),
            size: const Size(20, 18),
            fillColor: const Color(0xFF336699),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _surfaceImageDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('surface-image-resource'),
        source: CanvasResourceSource.appKey('surface-smoke-image'),
        mimeType: 'image/png',
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('surface-image-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('surface-image'),
            resourceId: CanvasResourceId('surface-image-resource'),
            size: const Size(24, 16),
            naturalSize: const Size(24, 16),
          ),
          CanvasRectElement(
            id: CanvasElementId('surface-selectable'),
            transform: CanvasTransform.translation(const Offset(40, 0)),
            size: const Size(16, 16),
            fillColor: const Color(0xFF669933),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _eraserContextRequestDocument({Offset cameraOffset = Offset.zero}) {
  return CanvasDocument(
    camera: CanvasCamera(offset: cameraOffset),
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('background-only'),
        size: const Size(40, 40),
        transform: CanvasTransform.translation(const Offset(180, 180)),
        isSelectable: false,
        isLocked: true,
        isDeletable: false,
        isTransformable: false,
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('eraser-context-layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('erase-me'),
            size: const Size(20, 20),
          ),
          CanvasRectElement(
            id: CanvasElementId('locked-content'),
            size: const Size(20, 20),
            transform: CanvasTransform.translation(const Offset(30, 0)),
            isDeletable: false,
          ),
          CanvasTextElement(
            id: CanvasElementId('text-edit'),
            text: 'hello',
            color: const Color(0xFF111827),
            textDirection: TextDirection.ltr,
            transform: CanvasTransform.translation(const Offset(90, 0)),
          ),
        ],
      ),
    ],
  );
}

CanvasRuntimeRevisions _runtimeRevisions({
  required int document,
  required int selection,
  int viewCamera = 0,
  int epoch = 0,
}) {
  return CanvasRuntimeRevisions(
    document: document,
    selection: selection,
    preview: 0,
    viewCamera: viewCamera,
    resourceVisual: 0,
    interaction: 0,
    epoch: epoch,
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

final class _PublicRuntimeProbe {
  _PublicRuntimeProbe(CanvasRuntime runtime, List<CanvasActionCommitted> actions)
    : document = runtime.readDocument(),
      preview = runtime.preview,
      mode = runtime.tools.mode,
      drawStyle = runtime.tools.drawStyle,
      selection = Set<CanvasElementId>.of(runtime.selection.selectedElementIds),
      resources = _resourceFacts(runtime.resources.resources),
      actionCount = actions.length;

  final CanvasDocument document;
  final CanvasPreviewState preview;
  final CanvasInteractionMode mode;
  final CanvasDrawStyle drawStyle;
  final Set<CanvasElementId> selection;
  final List<_ResourceFact> resources;
  final int actionCount;

  void expectNoEffects(
    CanvasRuntime runtime,
    List<CanvasActionCommitted> actions,
  ) {
    expect(runtime.readDocument(), same(document));
    expect(runtime.preview, same(preview));
    expect(runtime.tools.mode, mode);
    expect(runtime.tools.drawStyle, drawStyle);
    expect(runtime.selection.selectedElementIds, selection);
    expect(_resourceFacts(runtime.resources.resources), resources);
    expect(actions, hasLength(actionCount));
  }
}

final class _CustomTextEditingOverlay extends StatelessWidget {
  const _CustomTextEditingOverlay({required this.runtime});

  final CanvasRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CanvasRuntimeState>(
      valueListenable: runtime.state,
      builder: (context, session, _) {
        return ValueListenableBuilder<CanvasTextEditSession?>(
          valueListenable: runtime.textEditing.activeSession,
          builder: (context, session, _) {
            if (session == null) {
              return const SizedBox.shrink();
            }

            return _CustomSessionEditor(
              session: session,
              cameraOffset: runtime.camera.offset,
            );
          },
        );
      },
    );
  }
}

final class _CustomSessionEditor extends StatefulWidget {
  const _CustomSessionEditor({
    required this.session,
    required this.cameraOffset,
  });

  final CanvasTextEditSession session;
  final Offset cameraOffset;

  @override
  State<_CustomSessionEditor> createState() => _CustomSessionEditorState();
}

final class _CustomSessionEditorState extends State<_CustomSessionEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.session.liveText)
      ..addListener(_handleTextChanged);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = widget.session.geometry;
    final bounds = geometry.editBoundsLocal;
    if (bounds == null) {
      return const SizedBox.shrink();
    }
    final style = widget.session.style;
    final surfaceTransform = geometry.transform
        .withTranslation(geometry.transform.translation - widget.cameraOffset)
        .toCanvasTransform();

    return Positioned.fill(
      child: Transform(
        transform: Matrix4.fromFloat64List(surfaceTransform),
        alignment: Alignment.topLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: bounds.left,
              top: bounds.top,
              child: SizedBox(
                key: const ValueKey<String>('custom.text.edit.host'),
                width: bounds.width,
                height: bounds.height,
                child: EditableText(
                  key: const ValueKey<String>('custom.text.edit.field'),
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(
                    color: style.color,
                    fontSize: style.fontSize,
                    fontFamily: style.fontFamily,
                    fontWeight: style.isBold
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontStyle: style.isItalic
                        ? FontStyle.italic
                        : FontStyle.normal,
                    decoration: style.isUnderline
                        ? TextDecoration.underline
                        : null,
                    height: style.lineHeight,
                  ),
                  cursorColor: const Color(0xFF1565C0),
                  backgroundCursorColor: const Color(0x00000000),
                  textAlign: style.textAlign,
                  textDirection: style.textDirection,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.done,
                  maxLines: null,
                  onEditingComplete: () =>
                      widget.session.commit(timestampMs: 71),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTextChanged() {
    widget.session.updateText(_controller.text);
  }
}

List<_ResourceFact> _resourceFacts(List<CanvasResource> resources) {
  return [
    for (final resource in resources)
      (
        id: resource.id,
        source: resource.source,
        contentHash: resource.contentHash,
        byteLength: resource.byteLength,
      ),
  ];
}

typedef _ResourceFact = ({
  CanvasResourceId id,
  CanvasResourceSource source,
  String? contentHash,
  int? byteLength,
});
''';
