import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test(
    'CanvasFieldUpdate static semantics reject null set and bad clear',
    () async {
      final result = await _analyzeConsumer(_invalidFieldUpdateSource);
      final output = _processOutput(result);

      expect(result.exitCode, isNot(0), reason: output);
      expect(output, contains('ARGUMENT_TYPE_NOT_ASSIGNABLE'));
      expect(output, contains('INVALID_ASSIGNMENT'));
    },
  );

  test(
    'CanvasFieldUpdate static semantics accept valid absent set and clear',
    () async {
      final result = await _analyzeConsumer(_validFieldUpdateSource);

      expect(result.exitCode, 0, reason: _processOutput(result));
    },
  );
}

Future<ProcessResult> _analyzeConsumer(String source) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_field_update_static_consumer_',
  );

  try {
    await Directory('${packageDir.path}/lib').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/lib/field_update_static.dart',
    ).writeAsString(source);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final analyze = await Process.run('dart', [
      'analyze',
      '--format=machine',
      'lib/field_update_static.dart',
    ], workingDirectory: packageDir.path);

    return analyze;
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_field_update_static_consumer
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

const _invalidFieldUpdateSource = '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

final CanvasFieldUpdate<String> nullSet = CanvasFieldSet(null);
final CanvasFieldUpdate<String> clearNonNullable = CanvasFieldClear<String>();
''';

const _validFieldUpdateSource = '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

final CanvasFieldUpdate<String> absent = CanvasFieldUpdate.absent();
final CanvasFieldUpdate<String> set = CanvasFieldSet('value');
final CanvasFieldUpdate<String?> clear = CanvasFieldClear<String>();
''';
