import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test(
    'public sealed unions expose readable variants through root barrel',
    () async {
      await expectLater(
        _runFlutterConsumerTest(_readableUnionSource),
        completes,
      );
    },
  );
}

Future<void> _runFlutterConsumerTest(String testSource) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_readable_union_consumer_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/test/readable_union_test.dart',
    ).writeAsString(testSource);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run('flutter', [
      'test',
      'test/readable_union_test.dart',
    ], workingDirectory: packageDir.path);
    expect(test.exitCode, 0, reason: _processOutput(test));
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_readable_union_consumer
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

const _readableUnionSource = '''
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('resource source app-key variant is publicly readable', () {
    final source = CanvasResourceSource.appKey('asset-main');
    final resource = CanvasImageResource(
      id: CanvasResourceId('resource-1'),
      source: source,
    );

    expect(source, isA<CanvasAppKeyResourceSource>());
    switch (resource.source) {
      case CanvasAppKeyResourceSource(:final key):
        expect(key, 'asset-main');
    }
  });

  test('preview state variants are publicly readable', () {
    final previews = <CanvasPreviewState>[
      const CanvasPreviewState.none(),
      const CanvasPreviewState.marquee(
        rect: Rect.fromLTWH(0, 0, 10, 10),
      ),
      const CanvasPreviewState.selectedMove(delta: Offset(1, 2)),
      CanvasPreviewState.pencilStroke(
        points: [Offset.zero],
        color: const Color(0xFF000000),
        thickness: 2,
        opacity: 1,
      ),
      CanvasPreviewState.markerStroke(
        points: [Offset.zero],
        color: const Color(0xFF000000),
        thickness: 4,
        opacity: 0.5,
      ),
      const CanvasPreviewState.pendingLineStart(
        start: Offset.zero,
        timestampMs: 1,
        color: Color(0xFF000000),
        thickness: 2,
      ),
      const CanvasPreviewState.linePreview(
        start: Offset.zero,
        end: Offset(1, 1),
        color: Color(0xFF000000),
        thickness: 2,
      ),
      CanvasPreviewState.eraser(corridor: [Offset.zero], thickness: 8),
    ];

    expect(previews.map((preview) => preview.kind), [
      CanvasPreviewKind.none,
      CanvasPreviewKind.marquee,
      CanvasPreviewKind.selectedMove,
      CanvasPreviewKind.pencilStroke,
      CanvasPreviewKind.markerStroke,
      CanvasPreviewKind.pendingLineStart,
      CanvasPreviewKind.linePreview,
      CanvasPreviewKind.eraser,
    ]);

    for (final preview in previews) {
      switch (preview) {
        case CanvasNoPreview():
          expect(preview.kind, CanvasPreviewKind.none);
        case CanvasMarqueePreview(:final rect):
          expect(rect.width, 10);
        case CanvasSelectedMovePreview(:final delta):
          expect(delta.dx, 1);
        case CanvasPencilStrokePreview(:final points, :final opacity):
          expect(points, hasLength(1));
          expect(opacity, 1);
        case CanvasMarkerStrokePreview(:final points, :final opacity):
          expect(points, hasLength(1));
          expect(opacity, 0.5);
        case CanvasPendingLineStartPreview(:final timestampMs):
          expect(timestampMs, 1);
        case CanvasLinePreview(:final end):
          expect(end, const Offset(1, 1));
        case CanvasEraserPreview(:final corridor, :final thickness):
          expect(corridor, hasLength(1));
          expect(thickness, 8);
      }
    }
  });
}
''';
