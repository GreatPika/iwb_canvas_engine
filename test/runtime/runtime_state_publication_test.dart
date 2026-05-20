import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('CanvasRuntime publishes initial public state', () async {
    expect(await _runFlutterConsumerTest(_runtimeStateSource), isTrue);
  });
}

Future<bool> _runFlutterConsumerTest(String testSource) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_runtime_state_consumer_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/test/runtime_state_test.dart',
    ).writeAsString(testSource);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run('flutter', [
      'test',
      'test/runtime_state_test.dart',
    ], workingDirectory: packageDir.path);
    expect(test.exitCode, 0, reason: _processOutput(test));

    return true;
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_runtime_state_consumer
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

const _runtimeStateSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('state.value is readable immediately after construction', () {
    final document = CanvasDocument(
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('resource-1'),
          source: CanvasResourceSource.appKey('resource-1'),
        ),
      ],
      backgroundElements: [
        CanvasRectElement(
          id: CanvasElementId('background-1'),
          size: const Size(1, 1),
        ),
      ],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-1'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('element-1'),
              size: const Size(2, 2),
            ),
          ],
        ),
      ],
    );
    final runtime = CanvasRuntime(initialDocument: document);

    expect(runtime.readDocument(), same(document));
    expect(runtime.state.value, isA<CanvasRuntimeState>());
    expect(runtime.state.value.revisions, _zeroRevisions());
    expect(
      runtime.state.value.summary,
      const CanvasRuntimeSummary(
        elementCount: 2,
        layerCount: 1,
        resourceCount: 1,
        selectedCount: 0,
      ),
    );
  });

  test('snapshot DTOs compare by public values', () {
    expect(_zeroRevisions(), _zeroRevisions());
    expect(
      const CanvasRuntimeSummary(
        elementCount: 1,
        layerCount: 2,
        resourceCount: 3,
        selectedCount: 4,
      ),
      const CanvasRuntimeSummary(
        elementCount: 1,
        layerCount: 2,
        resourceCount: 3,
        selectedCount: 4,
      ),
    );
    expect(
      CanvasRuntimeState(
        revisions: _zeroRevisions(),
        summary: const CanvasRuntimeSummary(
          elementCount: 1,
          layerCount: 2,
          resourceCount: 3,
          selectedCount: 4,
        ),
      ),
      CanvasRuntimeState(
        revisions: _zeroRevisions(),
        summary: const CanvasRuntimeSummary(
          elementCount: 1,
          layerCount: 2,
          resourceCount: 3,
          selectedCount: 4,
        ),
      ),
    );
  });
}

CanvasRuntimeRevisions _zeroRevisions() {
  return const CanvasRuntimeRevisions(
    document: 0,
    selection: 0,
    preview: 0,
    viewCamera: 0,
    resourceVisual: 0,
    interaction: 0,
    epoch: 0,
  );
}
''';
