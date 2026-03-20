@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tool/check_coverage.dart', () {
    _registerCoverageScenarioTest(
      name: 'rejects lib/src file that is missing from lcov',
      files: <String, String>{
        'lib/src/a.dart': 'int covered() => 1;\n',
        'lib/src/b.dart': 'int uncovered() => 2;\n',
      },
      lcov: _singleFileLcov('lib/src/a.dart'),
      expectedExitCode: isNonZero,
      expectedStderrSubstring: 'lib/src/b.dart',
    );
    _registerCompleteLcovTest();
    _registerExportOnlyShimTest();
    _registerDeclarationOnlyAllowListTest();
    _registerCoverageScenarioTest(
      name: 'rejects missing shim file when logic leaks back into it',
      files: <String, String>{
        'lib/src/contract/a.dart': 'int covered() => 1;\n',
        'lib/src/shim.dart': '''
export 'package:iwb_canvas_engine/src/contract/a.dart';
int leaked() => 1;
''',
      },
      lcov: _singleFileLcov('lib/src/contract/a.dart'),
      expectedExitCode: isNonZero,
      expectedStderrSubstring: 'lib/src/shim.dart',
    );
    _registerFormerRealLogicExclusionTest();
    _registerCommentWrappedExportOnlyShimTest();
  });
}

void _registerCompleteLcovTest() {
  test('passes when every lib/src file is present in lcov', () async {
    final result = await _runCoverageScenario(
      files: <String, String>{
        'lib/src/a.dart': 'int first() => 1;\n',
        'lib/src/b.dart': 'int second() => 2;\n',
      },
      lcov:
          '${_singleFileLcov('lib/src/a.dart')}${_singleFileLcov('lib/src/b.dart')}',
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
}

void _registerExportOnlyShimTest() {
  test('passes when missing file is a pure export-only shim', () async {
    final result = await _runCoverageScenario(
      files: <String, String>{
        'lib/src/contract/a.dart': 'int covered() => 1;\n',
        'lib/src/shim.dart':
            "export 'package:iwb_canvas_engine/src/contract/a.dart';\n",
      },
      lcov: _singleFileLcov('lib/src/contract/a.dart'),
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
}

void _registerDeclarationOnlyAllowListTest() {
  test(
    'passes when missing file is a declaration-only allow-list unit',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/core/tool_defaults.dart': '''
class ToolDefaults {
  static const double penThickness = 3;
}
''',
          'lib/src/contract/a.dart': 'int covered() => 1;\n',
        },
        lcov: _singleFileLcov('lib/src/contract/a.dart'),
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
    },
  );
}

void _registerFormerRealLogicExclusionTest() {
  test(
    'rejects missing scene_value_validation part file with real logic',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/model/scene_value_validation.dart': '''
part 'scene_value_validation_primitives.part.dart';

typedef SceneValidationErrorReporter =
    Never Function({
      required Object? value,
      required String field,
      required String message,
    });
''',
          'lib/src/model/scene_value_validation_primitives.part.dart': '''
part of 'scene_value_validation.dart';

bool validatesSceneValue(Object? value) => value != null;
''',
          'lib/src/contract/a.dart': 'int covered() => 1;\n',
        },
        lcov: _singleFileLcov('lib/src/contract/a.dart'),
      );

      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        contains('lib/src/model/scene_value_validation_primitives.part.dart'),
      );
    },
  );
}

void _registerCommentWrappedExportOnlyShimTest() {
  _registerCoverageScenarioTest(
    name: 'passes when export-only shim includes comment wrapper',
    files: <String, String>{
      'lib/src/contract/a.dart': 'int covered() => 1;\n',
      'lib/src/shim.dart': '''
// comment
export 'package:iwb_canvas_engine/src/contract/a.dart';
''',
    },
    lcov: _singleFileLcov('lib/src/contract/a.dart'),
    expectedExitCode: 0,
  );
}

void _registerCoverageScenarioTest({
  required String name,
  required Map<String, String> files,
  required String lcov,
  required Object expectedExitCode,
  String? expectedStderrSubstring,
}) {
  test(name, () async {
    final result = await _runCoverageScenario(files: files, lcov: lcov);

    expect(result.exitCode, expectedExitCode, reason: result.stderr.toString());
    if (expectedStderrSubstring != null) {
      expect(result.stderr.toString(), contains(expectedStderrSubstring));
    }
  });
}

Future<ProcessResult> _runCoverageScenario({
  required Map<String, String> files,
  required String lcov,
}) async {
  final sandbox = await _createSandbox();
  try {
    for (final entry in files.entries) {
      _writeFile(sandbox, entry.key, entry.value);
    }
    _writeFile(sandbox, 'coverage/lcov.info', lcov);
    return await _runTool(sandbox, 'check_coverage.dart');
  } finally {
    sandbox.deleteSync(recursive: true);
  }
}

String _singleFileLcov(String path) =>
    '''
TN:
SF:$path
DA:1,1
LF:1
LH:1
end_of_record
''';

Future<Directory> _createSandbox() async {
  final sandbox = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_coverage_tool_test_',
  );

  _writeFile(sandbox, 'pubspec.yaml', '''
name: iwb_canvas_engine
environment:
  sdk: ">=3.0.0 <4.0.0"
''');

  final sourceRoot = Directory.current.path;
  _copyFile(
    '$sourceRoot/tool/check_coverage.dart',
    '${sandbox.path}/tool/check_coverage.dart',
  );

  return sandbox;
}

void _copyFile(String from, String to) {
  final source = File(from);
  final target = File(to);
  target.parent.createSync(recursive: true);
  source.copySync(target.path);
}

void _writeFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

Future<ProcessResult> _runTool(Directory sandbox, String toolFileName) {
  return Process.run('dart', <String>[
    'run',
    'tool/$toolFileName',
  ], workingDirectory: sandbox.path);
}
