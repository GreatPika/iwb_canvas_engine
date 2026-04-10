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
    _registerDeclarationClusteredGapTest();
    _registerFileScopeFallbackGapTest();
    _registerCandidateTestTargetResolutionTest();
    _registerNoCandidateTestTargetResolutionTest();
    _registerChangedOnlyFilteringTest();
    _registerChangedOnlyFallbackWarningTest();
    _registerDeletedSourceLcovFallbackTest();
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
  test('reports missing files and missed lines in compact json mode', () async {
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
    expect(report['changedOnlyApplied'], false);

    final gaps = (report['gaps'] as List<Object?>).cast<Map<String, Object?>>();
    expect(gaps, hasLength(2));

    final missingEntry = gaps.firstWhere(
      (entry) => entry['p'] == 'lib/src/b.dart',
    );
    expect(missingEntry['k'], 'mf');
    expect(missingEntry['sym'], isNull);
    expect(missingEntry['scope'], 'fs');
    expect(missingEntry['tt'], isEmpty);

    final uncoveredEntry = gaps.firstWhere(
      (entry) => entry['p'] == 'lib/src/a.dart',
    );
    expect(uncoveredEntry['k'], 'ml');
    expect(uncoveredEntry['sym'], 'uncovered');
    final range = uncoveredEntry['rng'] as Map<String, Object?>;
    expect(range['sl'], 3);
    final missedLines = (uncoveredEntry['ml'] as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(missedLines, hasLength(1));
    expect(missedLines.single['line'], 3);
    expect(missedLines.single['source'], 'int uncovered() => 2;');
    expect(uncoveredEntry['mb'], isEmpty);
    expect(uncoveredEntry['sn'], contains('int uncovered() => 2;'));
  });
}

void _registerJsonBranchDiagnosticsTest() {
  test(
    'reports uncovered branches in compact json mode when requested',
    () async {
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
      final report =
          jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      expect(report['branchDataAvailable'], true);
      final gaps = (report['gaps'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(gaps, hasLength(1));
      final entry = gaps.single;
      expect(entry['k'], 'mb');
      expect(entry['sym'], 'pick');
      final branches = (entry['mb'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(branches, hasLength(1));

      final branch = branches.single;
      expect(branch['line'], 2);
      expect(branch['block'], '0');
      expect(branch['branch'], '1');
      expect(branch['taken'], '0');
      expect(branch['source'], '  if (value) {');
    },
  );
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

void _registerDeclarationClusteredGapTest() {
  test('clusters missed lines and branches by enclosing declaration', () async {
    final result = await _runCoverageScenario(
      files: <String, String>{
        'lib/src/render/scene_grid_renderer.dart': '''
int covered() => 1;

int renderGap(bool enabled) {
  if (enabled) {
    return 1;
  }
  return 2;
}
''',
        'test/render/scene_grid_renderer_test.dart': '''
void main() {}
''',
      },
      lcov: _singleFileLcov(
        'lib/src/render/scene_grid_renderer.dart',
        lineHits: <int, int>{1: 1, 3: 0, 4: 0, 5: 0, 7: 0},
        branchHits: const <String>['4,0,0,0'],
      ),
      args: const <String>['--json', '--uncovered-branches'],
    );

    expect(result.exitCode, isNonZero);
    final report = jsonDecode(result.stdout.toString()) as Map<String, Object?>;
    final gaps = (report['gaps'] as List<Object?>).cast<Map<String, Object?>>();
    expect(gaps, hasLength(1));

    final gap = gaps.single;
    expect(gap['k'], 'mx');
    expect(gap['sym'], 'renderGap');
    expect(gap['scope'], 'td');
    expect(gap['tt'], <String>['test/render/scene_grid_renderer_test.dart']);
    expect(gap['sh'], 'scope_render_view');
    final missedLines = (gap['ml'] as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(missedLines.map((line) => line['line']), <int>[3, 4, 5, 7]);
    final branches = (gap['mb'] as List<Object?>).cast<Map<String, Object?>>();
    expect(branches, hasLength(1));
    expect(gap['sn'], contains('int renderGap(bool enabled) {'));
  });
}

void _registerFileScopeFallbackGapTest() {
  test(
    'uses file-scope fallback when executable gap is outside declarations',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/a.dart': '''
final bool sentinel = bool.fromEnvironment('sentinel');
int covered() => 1;
''',
        },
        lcov: _singleFileLcov(
          'lib/src/a.dart',
          lineHits: <int, int>{1: 0, 2: 1},
        ),
        args: const <String>['--json'],
      );

      expect(result.exitCode, isNonZero);
      final report =
          jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      final gaps = (report['gaps'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(gaps, hasLength(1));

      final gap = gaps.single;
      expect(gap['scope'], 'fs');
      expect(gap['sym'], isNull);
      final range = gap['rng'] as Map<String, Object?>;
      expect(range['sl'], 1);
      expect(range['el'], 1);
    },
  );
}

void _registerCandidateTestTargetResolutionTest() {
  test(
    'resolves candidate test paths and verification scopes deterministically',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/interactive/internal/interactive_move_session.dart': '''
int interactiveMoveSession() => 1;
''',
          'lib/src/render/scene_grid_renderer.dart': '''
int sceneGridRenderer() => 1;
''',
          'lib/src/core/covered.dart': 'int covered() => 1;\n',
          'test/interactive/core/interactive_move_session_test.dart':
              'void main() {}\n',
          'test/render/scene_grid_renderer_test.dart': 'void main() {}\n',
        },
        lcov: _singleFileLcov('lib/src/core/covered.dart'),
        args: const <String>['--json'],
      );

      expect(result.exitCode, isNonZero);
      final report =
          jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      final gaps = (report['gaps'] as List<Object?>)
          .cast<Map<String, Object?>>();

      final interactiveGap = gaps.firstWhere(
        (gap) =>
            gap['p'] ==
            'lib/src/interactive/internal/interactive_move_session.dart',
      );
      expect(interactiveGap['tt'], <String>[
        'test/interactive/core/interactive_move_session_test.dart',
      ]);
      expect(interactiveGap['sh'], 'scope_interactive');

      final renderGap = gaps.firstWhere(
        (gap) => gap['p'] == 'lib/src/render/scene_grid_renderer.dart',
      );
      expect(renderGap['tt'], <String>[
        'test/render/scene_grid_renderer_test.dart',
      ]);
      expect(renderGap['sh'], 'scope_render_view');
    },
  );
}

void _registerNoCandidateTestTargetResolutionTest() {
  test(
    'returns no synthetic candidate targets when no matching tests exist',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/core/isolated_feature.dart': 'int isolatedFeature() => 1;\n',
          'lib/src/core/covered.dart': 'int covered() => 1;\n',
        },
        lcov: _singleFileLcov('lib/src/core/covered.dart'),
        args: const <String>['--json'],
      );

      expect(result.exitCode, isNonZero);
      final report =
          jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      final gaps = (report['gaps'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final gap = gaps.single;
      expect(gap['tt'], isEmpty);
      expect(gap['sh'], 'scope_core');
    },
  );
}

void _registerChangedOnlyFilteringTest() {
  test('filters machine gaps to changed source files only', () async {
    final result = await _runCoverageScenario(
      files: <String, String>{
        'lib/src/core/a.dart': 'int first() => 1;\n',
        'lib/src/core/b.dart': 'int second() => 2;\n',
      },
      lcov: _singleFileLcov('lib/src/core/b.dart'),
      args: const <String>['--json', '--changed-only'],
      initializeGit: true,
      mutateAfterGitInit: (Directory sandbox) {
        _writeFile(sandbox, 'lib/src/core/a.dart', 'int first() => 10;\n');
      },
    );

    expect(result.exitCode, isNonZero);
    final report = jsonDecode(result.stdout.toString()) as Map<String, Object?>;
    expect(report['changedOnlyApplied'], true);
    final gaps = (report['gaps'] as List<Object?>).cast<Map<String, Object?>>();
    expect(gaps, hasLength(1));
    expect(gaps.single['p'], 'lib/src/core/a.dart');
  });
}

void _registerChangedOnlyFallbackWarningTest() {
  test(
    'emits deterministic warning when changed-only filtering cannot use git metadata',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/core/a.dart': 'int first() => 1;\n',
          'lib/src/core/covered.dart': 'int covered() => 1;\n',
        },
        lcov: _singleFileLcov('lib/src/core/covered.dart'),
        args: const <String>['--json', '--changed-only'],
      );

      expect(result.exitCode, isNonZero);
      final report =
          jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      expect(report['changedOnlyApplied'], false);
      expect(
        report['warnings'],
        contains(
          'git status metadata is unavailable; changed-only coverage filtering was skipped.',
        ),
      );
    },
  );
}

void _registerDeletedSourceLcovFallbackTest() {
  test(
    'keeps executable json gaps when lcov points to a deleted lib/src file',
    () async {
      final result = await _runCoverageScenario(
        files: <String, String>{
          'lib/src/core/covered.dart': 'int covered() => 1;\n',
        },
        lcov:
            '${_singleFileLcov('lib/src/core/deleted.dart', lineHits: <int, int>{7: 0}, branchHits: const <String>['7,0,1,0'])}'
            '${_singleFileLcov('lib/src/core/covered.dart')}',
        args: const <String>['--json', '--uncovered-branches'],
      );

      expect(result.exitCode, isNonZero);
      final report =
          jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      final gaps = (report['gaps'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final gap = gaps.firstWhere(
        (entry) => entry['p'] == 'lib/src/core/deleted.dart',
      );
      expect(gap['k'], 'mx');
      expect(gap['scope'], 'fs');
      expect(gap['sym'], isNull);
      final missedLines = (gap['ml'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(missedLines.single['line'], 7);
      expect(missedLines.single['source'], isNull);
      final missedBranches = (gap['mb'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(missedBranches.single['line'], 7);
      expect(missedBranches.single['source'], isNull);
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
  bool initializeGit = false,
  void Function(Directory sandbox)? mutateAfterGitInit,
}) async {
  final sandbox = await _createSandbox();
  try {
    for (final entry in files.entries) {
      _writeFile(sandbox, entry.key, entry.value);
    }
    _writeFile(sandbox, 'coverage/lcov.info', lcov);
    if (initializeGit) {
      await _initializeGitRepository(sandbox);
      mutateAfterGitInit?.call(sandbox);
    }
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
dependencies:
  analyzer: ^8.4.0
''');

  final sourceRoot = Directory.current.path;
  _copyFile(
    '$sourceRoot/tool/check_coverage.dart',
    '${sandbox.path}/tool/check_coverage.dart',
  );
  _copyDirectory(
    '$sourceRoot/tool/src/check_coverage',
    '${sandbox.path}/tool/src/check_coverage',
  );
  _copyDirectory(
    '$sourceRoot/tool/src/verification_contract',
    '${sandbox.path}/tool/src/verification_contract',
  );

  return sandbox;
}

void _copyFile(String from, String to) {
  final source = File(from);
  final target = File(to);
  target.parent.createSync(recursive: true);
  source.copySync(target.path);
}

void _copyDirectory(String from, String to) {
  final source = Directory(from);
  final target = Directory(to)..createSync(recursive: true);
  for (final entity in source.listSync(recursive: true, followLinks: false)) {
    final relative = entity.path.substring(source.path.length + 1);
    final targetPath = '${target.path}/$relative';
    if (entity is Directory) {
      Directory(targetPath).createSync(recursive: true);
      continue;
    }
    if (entity is File) {
      _copyFile(entity.path, targetPath);
    }
  }
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

Future<void> _initializeGitRepository(Directory sandbox) async {
  final commands = <List<String>>[
    <String>['init'],
    <String>['config', 'user.email', 'coverage@example.com'],
    <String>['config', 'user.name', 'Coverage Tool Test'],
    <String>['add', '.'],
    <String>['commit', '-m', 'sandbox'],
  ];
  for (final command in commands) {
    final result = await Process.run(
      'git',
      command,
      workingDirectory: sandbox.path,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
  }
}
