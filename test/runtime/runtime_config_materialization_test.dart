import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test(
    'runtime materializes validated config values in package context',
    () async {
      final result = await Process.run('flutter', [
        'test',
        'test/runtime/fixtures/runtime_config_materialization_fixture.dart',
      ], workingDirectory: repositoryRoot);

      expect(result.exitCode, 0, reason: _processOutput(result));
    },
  );
}

String _processOutput(ProcessResult result) {
  return '''
stdout:
${result.stdout}

stderr:
${result.stderr}
''';
}
