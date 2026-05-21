import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

Future<void> runFlutterConsumerTest({
  required String packageName,
  required String testFileName,
  required String testSource,
}) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_${packageName}_',
  );

  try {
    await Directory('${packageDir.path}/test').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource(packageName));
    await File(
      '${packageDir.path}/test/$testFileName',
    ).writeAsString(testSource);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final test = await Process.run('flutter', [
      'test',
      'test/$testFileName',
    ], workingDirectory: packageDir.path);
    expect(test.exitCode, 0, reason: _processOutput(test));
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource(String packageName) {
  return '''
name: $packageName
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
