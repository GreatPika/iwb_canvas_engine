import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('CanvasFieldUpdate variants expose stable value semantics', () async {
    expect(await _runFlutterConsumerTest(_canvasFieldUpdateSource), isTrue);
  });
}

Future<bool> _runFlutterConsumerTest(String testSource) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_field_update_consumer_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/test/canvas_field_update_test.dart',
    ).writeAsString(testSource);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run('flutter', [
      'test',
      'test/canvas_field_update_test.dart',
    ], workingDirectory: packageDir.path);
    expect(test.exitCode, 0, reason: _processOutput(test));

    return true;
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_field_update_consumer
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

const _canvasFieldUpdateSource = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('CanvasFieldUpdate variants expose stable value semantics', () {
    const absent = CanvasFieldUpdate<String>.absent();
    const alsoAbsent = CanvasFieldAbsent<String>();
    const set = CanvasFieldSet('value');
    const sameSet = CanvasFieldSet('value');
    const clear = CanvasFieldClear<String>();
    const sameClear = CanvasFieldClear<String>();

    expect(absent, alsoAbsent);
    expect(absent.hashCode, alsoAbsent.hashCode);
    expect(set.value, 'value');
    expect(set, sameSet);
    expect(set.hashCode, sameSet.hashCode);
    expect(clear, sameClear);
    expect(clear.hashCode, sameClear.hashCode);
    expect(absent, isA<CanvasFieldUpdate<String>>());
    expect(set, isA<CanvasFieldUpdate<String>>());
    expect(clear, isA<CanvasFieldUpdate<String?>>());
  });
}
''';
