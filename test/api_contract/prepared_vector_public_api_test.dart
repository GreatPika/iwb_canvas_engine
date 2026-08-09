import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

const _fixturePath =
    'test/api_contract/fixtures/prepared_vector_public_api_fixture.dart';

void main() {
  test('external root barrel exposes only prepared vector use', () async {
    await expectLater(_expectPermittedUseCompiles(), completes);
  });

  test('external root barrel rejects each prepared vector internal', () async {
    for (final source in _forbiddenConsumerSources) {
      final analyze = await _analyzeConsumerSource(source);

      expect(analyze.exitCode, isNot(0), reason: _processOutput(analyze));
    }
  });
}

Future<void> _expectPermittedUseCompiles() async {
  final fixture = File(_fixturePath).readAsStringSync();
  final analyze = await _analyzeConsumerSource(fixture);

  expect(analyze.exitCode, 0, reason: _processOutput(analyze));
}

Future<ProcessResult> _analyzeConsumerSource(String source) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_prepared_vector_consumer_',
  );

  try {
    await Directory('${packageDir.path}/lib').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_consumerPubspec());
    await File(
      '${packageDir.path}/lib/prepared_vector_consumer.dart',
    ).writeAsString(source);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    return await Process.run('dart', [
      'analyze',
      'lib/prepared_vector_consumer.dart',
    ], workingDirectory: packageDir.path);
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _consumerPubspec() {
  return '''
name: iwb_canvas_engine_prepared_vector_consumer
publish_to: none

environment:
  sdk: ^3.10.4

dependencies:
  flutter:
    sdk: flutter
  iwb_canvas_engine:
    path: $repositoryRoot
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

const _forbiddenConsumerSources = <String>[
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void constructPreparedVector() {
  CanvasPreparedVector();
}
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void inspectPreparedVectorLiveness(CanvasPreparedVector value) {
  value.isDisposed;
}
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void inspectPreparedVectorDebugLiveness(CanvasPreparedVector value) {
  value.debugDisposed;
}
''',
  '''
import 'dart:ui' as ui;

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

ui.Picture extractPreparedVectorPicture(CanvasPreparedVector value) =>
    value.picture;
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

CanvasDocument useCodecLocalDecodeHelper(Map<String, Object?> json) =>
    decodeSchemaV1Document(json);
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

VectorGraphic exposeUpstreamVectorType(VectorGraphic value) => value;
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

Object inspectPreparedVectorDiagnostics(CanvasPreparedVector value) =>
    value.diagnostics;
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

Object inspectVectorElementDiagnostics(CanvasVectorElement value) =>
    value.diagnostics;
''',
  '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

Object inspectPreparedVectorCreationInternals(CanvasPreparedVector value) =>
    liveCanvasPreparedVectorPicture(value);
''',
];
