import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

const _fixturePath =
    'test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart';

void main() {
  test('app adapter fixture imports only the root public barrel', () {
    expect(_expectFixtureImportsOnlyRootBarrel, returnsNormally);
  });

  test('app adapter fixture compiles from an external package', () async {
    await expectLater(_expectFixtureCompilesFromExternalPackage(), completes);
  });
}

void _expectFixtureImportsOnlyRootBarrel() {
  final source = File(_fixturePath).readAsStringSync();
  final importLines = source
      .split('\n')
      .where((line) => line.trimLeft().startsWith('import '))
      .toList();

  expect(importLines, [
    'import \'package:iwb_canvas_engine/iwb_canvas_engine.dart\';',
  ]);
  expect(source, isNot(contains('/src/')));
  expect(source, isNot(contains('SceneController')));
  expect(source, isNot(contains('NodeSpec')));
  expect(source, isNot(contains('NodePatch')));
}

Future<void> _expectFixtureCompilesFromExternalPackage() async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_app_adapter_consumer_',
  );

  try {
    await Directory('${packageDir.path}/lib').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/lib/app_adapter_fixture.dart',
    ).writeAsString(File(_fixturePath).readAsStringSync());

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    final analyze = await Process.run('dart', [
      'analyze',
      'lib/app_adapter_fixture.dart',
    ], workingDirectory: packageDir.path);
    expect(analyze.exitCode, 0, reason: _processOutput(analyze));
  } finally {
    await packageDir.delete(recursive: true);
  }
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_app_adapter_consumer
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
