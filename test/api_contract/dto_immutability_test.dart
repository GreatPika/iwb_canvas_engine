import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test(
    'public DTOs defensively copy and expose unmodifiable collections',
    () async {
      await expectLater(
        _runFlutterConsumerTest(_dtoImmutabilitySource),
        completes,
      );
    },
  );
}

Future<void> _runFlutterConsumerTest(String testSource) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_dto_immutability_consumer_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/test/dto_immutability_test.dart',
    ).writeAsString(testSource);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run('flutter', [
      'test',
      'test/dto_immutability_test.dart',
    ], workingDirectory: packageDir.path);
    expect(test.exitCode, 0, reason: _processOutput(test));
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_dto_immutability_consumer
publish_to: none

environment:
  sdk: ^3.10.4

dependencies:
  flutter:
    sdk: flutter
  iwb_canvas_engine:
    path: $repositoryRoot

dev_dependencies:
  flutter_test:
    sdk: flutter
''';
}

String _processOutput(ProcessResult result) {
  return '''
stdout:
${result.stdout}

stderr:
${result.stderr}
''';
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
      movedElements: moved,
      proposedDelta: Offset.zero,
      selectionBoundsWorld: const Rect.fromLTWH(0, 0, 1, 1),
      timestampMs: 1,
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
}
''';
