import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('public equality policy matches the v1 contract', () async {
    await expectLater(
      _runFlutterConsumerTest(_equalityPolicySource),
      completes,
    );
  });
}

Future<void> _runFlutterConsumerTest(String testSource) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_equality_policy_consumer_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/test/equality_policy_test.dart',
    ).writeAsString(testSource);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run('flutter', [
      'test',
      'test/equality_policy_test.dart',
    ], workingDirectory: packageDir.path);
    expect(test.exitCode, 0, reason: _processOutput(test));
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_equality_policy_consumer
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

const _equalityPolicySource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('contract-listed value types compare by public values', () {
    _expectValueEquality(CanvasElementId('element-1'), CanvasElementId('element-1'));
    _expectValueEquality(CanvasLayerId('layer-1'), CanvasLayerId('layer-1'));
    _expectValueEquality(CanvasResourceId('resource-1'), CanvasResourceId('resource-1'));
    _expectValueEquality(CanvasActionId('action-1'), CanvasActionId('action-1'));
    _expectValueEquality(
      CanvasInteractionRequestId('request-1'),
      CanvasInteractionRequestId('request-1'),
    );

    _expectValueEquality(_runtimeRevisions(), _runtimeRevisions());
    _expectValueEquality(_runtimeSummary(), _runtimeSummary());
    _expectValueEquality(
      CanvasRuntimeState(
        revisions: _runtimeRevisions(),
        summary: _runtimeSummary(),
      ),
      CanvasRuntimeState(
        revisions: _runtimeRevisions(),
        summary: _runtimeSummary(),
      ),
    );

    _expectValueEquality(
      CanvasTransform(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6),
      CanvasTransform(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6),
    );
    _expectValueEquality(
      CanvasFieldUpdate<int>.absent(),
      CanvasFieldUpdate<int>.absent(),
    );
    _expectValueEquality(
      CanvasFieldSet<int>(1),
      CanvasFieldSet<int>(1),
    );
    _expectValueEquality(
      CanvasFieldClear<String>(),
      CanvasFieldClear<String>(),
    );
    _expectValueEquality(
      CanvasMetadata.fromMap({
        'a': [
          {'b': true},
        ],
      }),
      CanvasMetadata.fromMap({
        'a': [
          {'b': true},
        ],
      }),
    );
    _expectValueEquality(
      CanvasDocumentSummary(
        elementCount: 1,
        layerCount: 2,
        resourceCount: 3,
      ),
      CanvasDocumentSummary(
        elementCount: 1,
        layerCount: 2,
        resourceCount: 3,
      ),
    );
    _expectValueEquality(
      CanvasCamera(offset: const Offset(1, 2)),
      CanvasCamera(offset: const Offset(1, 2)),
    );
    _expectValueEquality(
      CanvasBackground(grid: CanvasGrid(enabled: true, cellSize: 10)),
      CanvasBackground(grid: CanvasGrid(enabled: true, cellSize: 10)),
    );
    _expectValueEquality(
      CanvasGrid(enabled: true, cellSize: 10),
      CanvasGrid(enabled: true, cellSize: 10),
    );
    _expectValueEquality(
      CanvasSelectionStyle(strokeWidth: 2),
      CanvasSelectionStyle(strokeWidth: 2),
    );
    _expectValueEquality(
      CanvasGridStyle(strokeWidth: 2),
      CanvasGridStyle(strokeWidth: 2),
    );
    _expectValueEquality(
      CanvasPointerPolicy(tapSlop: 2),
      CanvasPointerPolicy(tapSlop: 2),
    );
    _expectValueEquality(
      CanvasPointerSample(
        pointerId: 1,
        position: const Offset(1, 2),
        phase: CanvasPointerLifecyclePhase.down,
        kind: PointerDeviceKind.touch,
      ),
      CanvasPointerSample(
        pointerId: 1,
        position: const Offset(1, 2),
        phase: CanvasPointerLifecyclePhase.down,
        kind: PointerDeviceKind.touch,
      ),
    );
    _expectValueEquality(
      CanvasDrawStyle(tool: CanvasDrawTool.marker),
      CanvasDrawStyle(tool: CanvasDrawTool.marker),
    );
    _expectValueEquality(
      CanvasResourceSource.appKey('asset-main'),
      CanvasResourceSource.appKey('asset-main'),
    );
    _expectValueEquality(
      CanvasElementRead(
        id: CanvasElementId('element-1'),
        kind: CanvasElementKind.rect,
        revision: 1,
        boundsWorld: const Rect.fromLTWH(0, 0, 1, 1),
        transform: CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0),
        isLocked: false,
        isTransformable: true,
      ),
      CanvasElementRead(
        id: CanvasElementId('element-1'),
        kind: CanvasElementKind.rect,
        revision: 1,
        boundsWorld: const Rect.fromLTWH(0, 0, 1, 1),
        transform: CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0),
        isLocked: false,
        isTransformable: true,
      ),
    );
    _expectValueEquality(
      CanvasMoveCommit(delta: const Offset(1, 2)),
      CanvasMoveCommit(delta: const Offset(1, 2)),
    );
    _expectValueEquality(
      CanvasMoveCancel(reason: 'blocked'),
      CanvasMoveCancel(reason: 'blocked'),
    );
    _expectValueEquality(
      CanvasDiagnosticPolicy.disabled(),
      CanvasDiagnosticPolicy.disabled(),
    );
    _expectValueEquality(
      CanvasDiagnosticPolicy.summary(),
      CanvasDiagnosticPolicy.summary(),
    );
    _expectValueEquality(
      CanvasDiagnosticPolicy.verbose(maxPreviewLength: 20, maxListEntries: 3),
      CanvasDiagnosticPolicy.verbose(maxPreviewLength: 20, maxListEntries: 3),
    );
  });

  test('contract-listed identity types keep identity equality', () {
    expect(CanvasDocument(), isNot(CanvasDocument()));
    expect(
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
      isNot(
        CanvasImageResource(
          id: CanvasResourceId('resource-1'),
          source: CanvasResourceSource.appKey('resource-1'),
        ),
      ),
    );
    expect(
      CanvasDataException(
        code: CanvasDataErrorCode.invalidJson,
        message: 'invalid',
        path: r'\$',
      ),
      isNot(
        CanvasDataException(
          code: CanvasDataErrorCode.invalidJson,
          message: 'invalid',
          path: r'\$',
        ),
      ),
    );
  });
}

void _expectValueEquality(Object left, Object right) {
  expect(identical(left, right), isFalse);
  expect(left, right);
  expect(left.hashCode, right.hashCode);
}

CanvasRuntimeRevisions _runtimeRevisions() {
  return CanvasRuntimeRevisions(
    document: 1,
    selection: 2,
    preview: 3,
    viewCamera: 4,
    resourceVisual: 5,
    interaction: 6,
    epoch: 7,
  );
}

CanvasRuntimeSummary _runtimeSummary() {
  return CanvasRuntimeSummary(
    elementCount: 1,
    layerCount: 2,
    resourceCount: 3,
    selectedCount: 4,
  );
}
''';
