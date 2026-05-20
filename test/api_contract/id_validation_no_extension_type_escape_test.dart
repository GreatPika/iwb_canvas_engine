import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('public id constructors reject unchecked values', () async {
    expect(await _runFlutterConsumerTest(_idValidationTestSource), isTrue);
  });

  test('public ids are classes, not extension types', () {
    final source = File('lib/src/api/canvas_ids.dart').readAsStringSync();

    expect(source, isNot(contains('extension type CanvasElementId')));
    expect(source, isNot(contains('extension type CanvasLayerId')));
    expect(source, isNot(contains('extension type CanvasResourceId')));
    expect(source, isNot(contains('extension type CanvasActionId')));
    expect(source, isNot(contains('extension type CanvasInteractionRequestId')));
  });
}

Future<bool> _runFlutterConsumerTest(String testSource) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_id_validation_consumer_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File('${packageDir.path}/pubspec.yaml').writeAsString(
      _pubspecSource(),
    );
    await File('${packageDir.path}/test/id_validation_test.dart').writeAsString(
      testSource,
    );

    final pubGet = await Process.run(
      'flutter',
      ['pub', 'get'],
      workingDirectory: packageDir.path,
    );
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run(
      'flutter',
      ['test', 'test/id_validation_test.dart'],
      workingDirectory: packageDir.path,
    );
    expect(test.exitCode, 0, reason: _processOutput(test));

    return true;
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_id_validation_consumer
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

const _idValidationTestSource = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('ids validate at public construction', () {
    expect(() => CanvasElementId('element-1'), returnsNormally);
    expect(() => CanvasLayerId('layer-1'), returnsNormally);
    expect(() => CanvasResourceId('resource-1'), returnsNormally);
    expect(() => CanvasActionId('action-1'), returnsNormally);
    expect(() => CanvasInteractionRequestId('request-1'), returnsNormally);

    expect(() => CanvasElementId(''), throwsA(isA<CanvasDataException>()));
    expect(() => CanvasLayerId('   '), throwsA(isA<CanvasDataException>()));
    expect(
      () => CanvasResourceId('r' * 1025),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasActionId('bad\\nid'),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      () => CanvasInteractionRequestId('i' * 257),
      throwsA(isA<CanvasDataException>()),
    );
  });
}
''';
