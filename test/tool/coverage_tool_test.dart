@Tags(['tool'])
library;

import 'dart:convert';
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
    _registerInteractiveDeclarationOnlyAllowListTest();
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
    _registerMultilineExportOnlyShimTest();
    _registerJsonCoverageDiagnosticsTest();
    _registerJsonBranchDiagnosticsTest();
    _registerJsonNoBranchDataWarningTest();
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

  test(
    'passes when missing file is the scene view render-state declaration unit',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/contract/scene_render_state.dart': '''
abstract interface class SceneRenderState {}
''',
          'lib/src/contract/scene_view_render_state.dart': '''
import 'scene_render_state.dart';

abstract interface class SceneViewRenderState implements SceneRenderState {}
''',
          'lib/src/contract/a.dart': 'int covered() => 1;\n',
        },
        lcov: _singleFileLcov('lib/src/contract/a.dart'),
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
    },
  );

  test(
    'passes when missing file is the scene view runtime declaration unit',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/contract/canvas_pointer_input.dart': '''
class CanvasPointerInput {}
''',
          'lib/src/contract/pointer_input.dart': '''
class PointerSample {}
''',
          'lib/src/contract/scene_view_runtime.dart': '''
import '../contract/canvas_pointer_input.dart';
import '../contract/pointer_input.dart';

abstract interface class SceneViewRuntime {
  Object createPointerSession({
    required Object isMounted,
    required Object hasLiveRawPointers,
  });
}

abstract interface class SceneViewPointerSession {
  void handleRoutedSample(PointerSample sample);
  void handleInvalidTerminalSample(CanvasPointerInput input);
}
''',
          'lib/src/contract/a.dart': 'int covered() => 1;\n',
        },
        lcov:
            '${_singleFileLcov('lib/src/contract/canvas_pointer_input.dart')}${_singleFileLcov('lib/src/contract/pointer_input.dart')}${_singleFileLcov('lib/src/contract/a.dart')}',
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
    },
  );
}

void _registerFormerRealLogicExclusionTest() {
  test(
    'rejects missing explicit scene value validation module with real logic',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/model/scene_value_validation.dart': '''
typedef SceneValidationErrorReporter =
    Never Function({
      required Object? value,
      required String field,
      required String message,
    });

void sceneValidateNode(Object? value) =>
    scene_value_validation_node.sceneValidateNode(value);
''',
          'lib/src/model/scene_value_validation_node.dart': '''
void sceneValidateNode(Object? value) {
  if (value == null) throw ArgumentError.notNull('value');
}
''',
          'lib/src/model/scene_value_validation_support.dart': '''
typedef SceneValidationErrorReporter =
    Never Function({
      required Object? value,
      required String field,
      required String message,
    });
''',
          'lib/src/contract/a.dart': 'int covered() => 1;\n',
        },
        lcov:
            '${_singleFileLcov('lib/src/model/scene_value_validation.dart')}${_singleFileLcov('lib/src/contract/a.dart')}',
      );

      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        contains('lib/src/model/scene_value_validation_node.dart'),
      );
    },
  );

  test(
    'rejects missing scene value validation facade from lcov when only explicit modules are covered',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/model/scene_value_validation.dart': '''
typedef SceneValidationErrorReporter =
    Never Function({
      required Object? value,
      required String field,
      required String message,
    });

void sceneValidateNode(Object? value) =>
    scene_value_validation_node.sceneValidateNode(value);
''',
          'lib/src/model/scene_value_validation_node.dart': '''
void sceneValidateNode(Object? value) {}
''',
          'lib/src/contract/a.dart': 'int covered() => 1;\n',
        },
        lcov:
            '${_singleFileLcov('lib/src/model/scene_value_validation_node.dart')}${_singleFileLcov('lib/src/contract/a.dart')}',
      );

      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        contains('lib/src/model/scene_value_validation.dart'),
      );
    },
  );

  test(
    'reports missed lines when explicit scene value validation facade is in lcov',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/model/scene_value_validation.dart': '''
typedef SceneValidationErrorReporter =
    Never Function({
      required Object? value,
      required String field,
      required String message,
    });

void sceneValidateNode(Object? value) =>
    scene_value_validation_node.sceneValidateNode(value);
''',
          'lib/src/model/scene_value_validation_node.dart': '''
void sceneValidateNode(Object? value) {}
''',
          'lib/src/contract/a.dart': 'int covered() => 1;\n',
        },
        lcov:
            '${_singleFileLcov('lib/src/model/scene_value_validation.dart', lineHits: <int, int>{1: 1, 8: 0})}${_singleFileLcov('lib/src/model/scene_value_validation_node.dart')}${_singleFileLcov('lib/src/contract/a.dart')}',
      );

      expect(result.exitCode, isNonZero);
      expect(
        result.stdout.toString(),
        contains('lib/src/model/scene_value_validation.dart:8'),
      );
    },
  );
}

void _registerInteractiveDeclarationOnlyAllowListTest() {
  test(
    'passes when missing interactive draw-style typedef unit is allow-listed',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/interactive/internal/interactive_draw_style.dart': '''
typedef InteractiveDrawStyle = ({
  double lineThickness,
});
''',
          'lib/src/contract/a.dart': 'int covered() => 1;\n',
        },
        lcov: _singleFileLcov('lib/src/contract/a.dart'),
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
    },
  );

  test(
    'passes when missing interactive eraser projection typedef unit is allow-listed',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/interactive/internal/interactive_draw_eraser_projection.dart':
              '''
typedef InteractiveDrawProjectedEraser = ({
  double threshold,
});
''',
          'lib/src/contract/a.dart': 'int covered() => 1;\n',
        },
        lcov: _singleFileLcov('lib/src/contract/a.dart'),
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
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

void _registerMultilineExportOnlyShimTest() {
  _registerCoverageScenarioTest(
    name: 'passes when export-only shim spans multiple lines',
    files: <String, String>{
      'lib/src/contract/a.dart': 'int covered() => 1;\n',
      'lib/src/shim.dart': '''
export 'package:iwb_canvas_engine/src/contract/a.dart'
    show
        covered;
''',
    },
    lcov: _singleFileLcov('lib/src/contract/a.dart'),
    expectedExitCode: 0,
  );
}

void _registerJsonCoverageDiagnosticsTest() {
  test('reports missing files and missed lines in json mode', () async {
    final result = await _runCoverageScenario(
      files: <String, String>{
        'lib/src/a.dart': '''
int covered() => 1;

int uncovered() => 2;
''',
        'lib/src/b.dart': 'int missing() => 3;\n',
      },
      lcov: _singleFileLcov('lib/src/a.dart', lineHits: <int, int>{1: 1, 3: 0}),
      args: const <String>['--json'],
    );

    expect(result.exitCode, isNonZero);
    final report = jsonDecode(result.stdout.toString()) as Map<String, Object?>;
    expect(report['branchDataAvailable'], false);

    final summary = report['summary'] as Map<String, Object?>;
    expect(summary['missingFileCount'], 1);
    expect(summary['missedLineCount'], 1);

    final files = (report['files'] as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(files, hasLength(2));

    final missingEntry = files.firstWhere(
      (entry) => entry['path'] == 'lib/src/b.dart',
    );
    expect(missingEntry['missingFromLcov'], true);
    expect(
      missingEntry['description'],
      'File is under lib/src/** but has no LCOV record.',
    );

    final uncoveredEntry = files.firstWhere(
      (entry) => entry['path'] == 'lib/src/a.dart',
    );
    expect(uncoveredEntry['missingFromLcov'], false);
    final missedLines = (uncoveredEntry['missedLines'] as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(missedLines, hasLength(1));
    expect(missedLines.single['line'], 3);
    expect(missedLines.single['source'], 'int uncovered() => 2;');
    expect(
      missedLines.single['description'],
      'Instrumented line was not executed.',
    );
  });
}

void _registerJsonBranchDiagnosticsTest() {
  test('reports uncovered branches in json mode when requested', () async {
    final result = await _runCoverageScenario(
      files: <String, String>{
        'lib/src/a.dart': '''
int pick(bool value) {
  if (value) {
    return 1;
  }
  return 2;
}
''',
      },
      lcov: _singleFileLcov(
        'lib/src/a.dart',
        branchHits: const <String>['2,0,0,1', '2,0,1,0'],
      ),
      args: const <String>['--json', '--uncovered-branches'],
    );

    expect(result.exitCode, isNonZero);
    final report = jsonDecode(result.stdout.toString()) as Map<String, Object?>;
    expect(report['branchDataAvailable'], true);

    final summary = report['summary'] as Map<String, Object?>;
    expect(summary['uncoveredBranchCount'], 1);

    final files = (report['files'] as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(files, hasLength(1));
    final entry = files.single;
    final branches = (entry['uncoveredBranches'] as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(branches, hasLength(1));

    final branch = branches.single;
    expect(branch['line'], 2);
    expect(branch['block'], '0');
    expect(branch['branch'], '1');
    expect(branch['taken'], '0');
    expect(branch['source'], '  if (value) {');
    expect(branch['description'], 'Instrumented branch was not taken.');
  });
}

void _registerJsonNoBranchDataWarningTest() {
  test(
    'emits a warning when branch diagnostics are requested without BRDA data',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{'lib/src/a.dart': 'int covered() => 1;\n'},
        lcov: _singleFileLcov('lib/src/a.dart'),
        args: const <String>['--json', '--uncovered-branches'],
      );

      expect(result.exitCode, 0);
      final report =
          jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      expect(report['branchDataAvailable'], false);
      expect(report['warnings'], <String>[
        'coverage/lcov.info does not contain BRDA entries; uncovered branch diagnostics are unavailable.',
      ]);
    },
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
  List<String> args = const <String>[],
}) async {
  final sandbox = await _createSandbox();
  try {
    for (final entry in files.entries) {
      _writeFile(sandbox, entry.key, entry.value);
    }
    _writeFile(sandbox, 'coverage/lcov.info', lcov);
    return await _runTool(sandbox, 'check_coverage.dart', args: args);
  } finally {
    sandbox.deleteSync(recursive: true);
  }
}

String _singleFileLcov(
  String path, {
  Map<int, int>? lineHits,
  List<String> branchHits = const <String>[],
}) {
  final normalizedLineHits = lineHits ?? <int, int>{1: 1};
  final sortedLines = normalizedLineHits.keys.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('TN:')
    ..writeln('SF:$path');
  var hitLineCount = 0;
  for (final line in sortedLines) {
    final hits = normalizedLineHits[line]!;
    if (hits > 0) {
      hitLineCount++;
    }
    buffer.writeln('DA:$line,$hits');
  }
  for (final branch in branchHits) {
    buffer.writeln('BRDA:$branch');
  }
  buffer
    ..writeln('LF:${sortedLines.length}')
    ..writeln('LH:$hitLineCount')
    ..writeln('end_of_record');
  return buffer.toString();
}

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

Future<ProcessResult> _runTool(
  Directory sandbox,
  String toolFileName, {
  List<String> args = const <String>[],
}) {
  return Process.run('dart', <String>[
    'run',
    'tool/$toolFileName',
    ...args,
  ], workingDirectory: sandbox.path);
}
