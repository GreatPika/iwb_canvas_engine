import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test(
    'public DTOs defensively copy and expose unmodifiable collections',
    () async {
      await expectLater(
        runFlutterConsumerTest(
          packageName: 'iwb_canvas_engine_dto_immutability_consumer',
          testFileName: 'dto_immutability_test.dart',
          testSource: _dtoImmutabilitySource,
        ),
        completes,
      );
    },
  );
}

const _dtoImmutabilitySource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('document and document-family DTO collections are immutable', () {
    final element = CanvasRectElement(
      id: CanvasElementId('element-1'),
      size: const Size(1, 1),
    );
    final resource = CanvasImageResource(
      id: CanvasResourceId('resource-1'),
      source: CanvasResourceSource.appKey('resource-1'),
    );
    final resources = [resource];
    final backgroundElements = [element];
    final layerElements = [element];
    final layer = CanvasLayer(
      id: CanvasLayerId('layer-1'),
      elements: layerElements,
    );
    final layers = [layer];
    final document = CanvasDocument(
      resources: resources,
      backgroundElements: backgroundElements,
      layers: layers,
    );

    resources.clear();
    backgroundElements.clear();
    layerElements.clear();
    layers.clear();

    expect(document.resources, hasLength(1));
    expect(document.backgroundElements, hasLength(1));
    expect(document.layers, hasLength(1));
    expect(layer.elements, hasLength(1));
    expect(() => document.resources.clear(), throwsUnsupportedError);
    expect(() => document.backgroundElements.clear(), throwsUnsupportedError);
    expect(() => document.layers.clear(), throwsUnsupportedError);
    expect(() => layer.elements.clear(), throwsUnsupportedError);

    final penColors = [const Color(0xFF000000)];
    final backgroundColors = [const Color(0xFFFFFFFF)];
    final gridSizes = [10.0];
    final palette = CanvasPalette(
      penColors: penColors,
      backgroundColors: backgroundColors,
      gridSizes: gridSizes,
    );

    penColors.clear();
    backgroundColors.clear();
    gridSizes.clear();

    expect(palette.penColors, hasLength(1));
    expect(palette.backgroundColors, hasLength(1));
    expect(palette.gridSizes, hasLength(1));
    expect(() => palette.penColors.clear(), throwsUnsupportedError);
    expect(() => palette.backgroundColors.clear(), throwsUnsupportedError);
    expect(() => palette.gridSizes.clear(), throwsUnsupportedError);

    final updatePenColors = [const Color(0xFF123456)];
    final updateBackgroundColors = [const Color(0xFF654321)];
    final updateGridSizes = [12.0];
    final update = CanvasPaletteUpdate(
      penColors: updatePenColors,
      backgroundColors: updateBackgroundColors,
      gridSizes: updateGridSizes,
    );
    updatePenColors.clear();
    updateBackgroundColors.clear();
    updateGridSizes.clear();

    expect(update.penColors, hasLength(1));
    expect(update.backgroundColors, hasLength(1));
    expect(update.gridSizes, hasLength(1));
    expect(() => update.penColors.clear(), throwsUnsupportedError);
    expect(() => update.backgroundColors.clear(), throwsUnsupportedError);
    expect(() => update.gridSizes.clear(), throwsUnsupportedError);
  });

  test('metadata is deep frozen', () {
    final nested = <String, Object?>{
      'items': <Object?>[
        <String, Object?>{'name': 'stable'},
      ],
    };
    final metadata = CanvasMetadata.fromMap(nested);
    nested['items'] = const ['mutated'];

    final items = metadata['items'] as List<Object?>;
    final item = items.single as Map<String, Object?>;

    expect(item['name'], 'stable');
    expect(() => items.clear(), throwsUnsupportedError);
    expect(() => item.clear(), throwsUnsupportedError);
  });

  test('event, request, and preview DTO collections are immutable', () {
    final elementId = CanvasElementId('element-1');
    final resourceId = CanvasResourceId('resource-1');
    final elementIds = [elementId];
    final resourceIds = [resourceId];
    final read = CanvasElementRead(
      id: elementId,
      kind: CanvasElementKind.rect,
      revision: 1,
      boundsWorld: const Rect.fromLTWH(0, 0, 1, 1),
      transform: CanvasTransform.identity,
      isLocked: false,
      isTransformable: true,
    );
    final moved = [read];
    final points = [Offset.zero];

    final action = CanvasActionCommitted(
      actionId: CanvasActionId('action-1'),
      type: CanvasActionType.clearContent,
      elementIds: elementIds,
      timestampMs: 1,
      payload: CanvasClearActionPayload(
        removedElementIds: elementIds,
        removedResourceIds: resourceIds,
      ),
    );
    final request = CanvasMoveCommitRequest(
      documentSummary: const CanvasDocumentSummary(
        elementCount: 1,
        layerCount: 1,
        resourceCount: 1,
      ),
      documentRevision: 1,
      selectedElementIdsBefore: const [],
      movedElements: moved,
      proposedDelta: Offset.zero,
      selectionBoundsWorld: const Rect.fromLTWH(0, 0, 1, 1),
    );
    final preview = CanvasPencilStrokePreview(
      points: points,
      color: const Color(0xFF000000),
      thickness: 1,
      opacity: 1,
    );

    elementIds.clear();
    resourceIds.clear();
    moved.clear();
    points.clear();

    expect(action.elementIds, hasLength(1));
    expect((action.payload as CanvasClearActionPayload).removedElementIds, hasLength(1));
    expect((action.payload as CanvasClearActionPayload).removedResourceIds, hasLength(1));
    expect(request.movedElements, hasLength(1));
    expect(preview.points, hasLength(1));
    expect(() => action.elementIds.clear(), throwsUnsupportedError);
    expect(
      () => (action.payload as CanvasClearActionPayload).removedElementIds.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => (action.payload as CanvasClearActionPayload).removedResourceIds.clear(),
      throwsUnsupportedError,
    );
    expect(() => request.movedElements.clear(), throwsUnsupportedError);
    expect(() => preview.points.clear(), throwsUnsupportedError);
  });

  test('delete requests retain entries and reject exposed mutation', () {
    final element = CanvasRectElement(
      id: CanvasElementId('delete-1'),
      size: const Size(1, 1),
    );
    final entries = [
      CanvasCommitElementEntry(
        element: element,
        layerId: CanvasLayerId('layer-1'),
        elementIndex: 0,
      ),
    ];
    final request = CanvasDeleteCommitRequest(
      documentSummary: const CanvasDocumentSummary(
        elementCount: 1,
        layerCount: 1,
        resourceCount: 0,
      ),
      documentRevision: 1,
      selectedElementIdsBefore: const [],
      entries: entries,
    );

    entries.clear();

    expect(request.entries, hasLength(1));
    expect(request.entries.single.element, same(element));
    expect(() => request.entries.clear(), throwsUnsupportedError);
  });
}
''';
