import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_registry.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('public API compiles from an empty consumer package', () async {
    final registryNames = readPublicApiRegistry();
    final packageDir = await Directory.systemTemp.createTemp(
      'iwb_canvas_engine_public_api_consumer_',
    );

    try {
      await Directory('${packageDir.path}/lib').create();
      await File('${packageDir.path}/pubspec.yaml').writeAsString(
        _pubspecSource(),
      );
      await File(
        '${packageDir.path}/lib/public_api_consumer.dart',
      ).writeAsString(_consumerSource(registryNames));

      final pubGet = await Process.run(
        'flutter',
        ['pub', 'get'],
        workingDirectory: packageDir.path,
      );
      expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

      final analyze = await Process.run(
        'dart',
        ['analyze', 'lib/public_api_consumer.dart'],
        workingDirectory: packageDir.path,
      );
      expect(analyze.exitCode, 0, reason: _processOutput(analyze));
    } finally {
      await packageDir.delete(recursive: true);
    }
  });
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_public_api_consumer
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

String _consumerSource(Set<String> registryNames) {
  final publicUses = (registryNames.toList()..sort())
      .map((name) => '  _use($name);')
      .join('\n');

  return '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void acceptPublicSurface() {
$publicUses
}

void _use(Object? value) {}
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
