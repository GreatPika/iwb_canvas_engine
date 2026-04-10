@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/tool_test_runner.dart';
import 'support/tool_process_test_support.dart';

void main() {
  group('tool/run_tool_tests.dart', () {
    test(
      'discovers tool test files in sorted order and skips support files',
      () async {
        final sandbox = await Directory.systemTemp.createTemp(
          'iwb_canvas_engine_tool_test_runner_',
        );
        try {
          _writeFile(sandbox, 'test/tool/z_last_tool_test.dart');
          _writeFile(sandbox, 'test/tool/a_first_tool_test.dart');
          _writeFile(sandbox, 'test/tool/support/helper_test.dart');
          _writeFile(sandbox, 'test/tool/misc.dart');

          final files = await discoverToolTestFiles(
            root: '${sandbox.path}/test/tool',
          );

          expect(files, <String>[
            '${sandbox.path}/test/tool/a_first_tool_test.dart'.replaceAll(
              r'\',
              '/',
            ),
            '${sandbox.path}/test/tool/z_last_tool_test.dart'.replaceAll(
              r'\',
              '/',
            ),
          ]);
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('parses jobs and explicit test files', () {
      final config = parseToolTestRunnerConfig(<String>[
        '--jobs=2',
        'test/tool/a_test.dart',
        r'test\tool\b_test.dart',
      ], processorCount: 8);

      expect(config.jobs, 2);
      expect(config.explicitTestFiles, <String>[
        'test/tool/a_test.dart',
        'test/tool/b_test.dart',
      ]);
    });

    test('fails on unsupported options', () {
      expect(
        () => parseToolTestRunnerConfig(const <String>[
          '--bogus',
        ], processorCount: 8),
        throwsA(
          isA<RunnerExit>().having((error) => error.exitCode, 'exitCode', 64),
        ),
      );
    });

    test(
      'runs tool tests with bounded concurrency and sorted results',
      () async {
        var inFlight = 0;
        var maxInFlight = 0;

        final results = await runToolTests(
          testFiles: const <String>[
            'test/tool/c_test.dart',
            'test/tool/a_test.dart',
            'test/tool/b_test.dart',
          ],
          jobs: 2,
          runSingleTest: (testFile) async {
            inFlight++;
            if (inFlight > maxInFlight) {
              maxInFlight = inFlight;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
            inFlight--;
            return ToolTestResult(
              testFile: testFile,
              exitCode: 0,
              duration: const Duration(milliseconds: 10),
              stdout: '',
              stderr: '',
            );
          },
        );

        expect(maxInFlight, lessThanOrEqualTo(2));
        expect(results.map((result) => result.testFile).toList(), <String>[
          'test/tool/a_test.dart',
          'test/tool/b_test.dart',
          'test/tool/c_test.dart',
        ]);
      },
    );

    test('hides child output for passing tool test processes', () async {
      final sandbox = await createToolSandbox(
        tempPrefix: 'iwb_canvas_engine_run_tool_tests_',
        toolFiles: const <String>[
          'tool/run_tool_tests.dart',
          'tool/src/tool_test_runner.dart',
        ],
        includeAnalyzer: false,
      );
      try {
        _writeToolTest(sandbox, 'test/tool/passing_tool_test.dart');
        _writeFlutterStub(sandbox, '''
#!/bin/sh
echo "passing child stdout"
echo "passing child stderr" 1>&2
exit 0
''');

        final result = await runSandboxTool(
          sandbox,
          'run_tool_tests.dart',
          args: const <String>['test/tool/passing_tool_test.dart'],
          environment: _sandboxEnvironment(sandbox),
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('PASS test/tool/passing_tool_test.dart'),
        );
        expect(
          result.stdout.toString(),
          isNot(contains('passing child stdout')),
        );
        expect(result.stderr.toString(), isEmpty);
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('prints child output for failing tool test processes', () async {
      final sandbox = await createToolSandbox(
        tempPrefix: 'iwb_canvas_engine_run_tool_tests_fail_',
        toolFiles: const <String>[
          'tool/run_tool_tests.dart',
          'tool/src/tool_test_runner.dart',
        ],
        includeAnalyzer: false,
      );
      try {
        _writeToolTest(sandbox, 'test/tool/failing_tool_test.dart');
        _writeFlutterStub(sandbox, '''
#!/bin/sh
echo "failing child stdout"
echo "failing child stderr" 1>&2
exit 7
''');

        final result = await runSandboxTool(
          sandbox,
          'run_tool_tests.dart',
          args: const <String>['test/tool/failing_tool_test.dart'],
          environment: _sandboxEnvironment(sandbox),
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stdout.toString(),
          contains('FAIL test/tool/failing_tool_test.dart'),
        );
        expect(result.stdout.toString(), contains('failing child stdout'));
        expect(result.stderr.toString(), contains('failing child stderr'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

void _writeFile(Directory root, String relativePath) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('// stub\n');
}

void _writeToolTest(Directory root, String relativePath) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('''
@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stub', () {
    expect(1, 1);
  });
}
''');
}

void _writeFlutterStub(Directory root, String content) {
  final binDir = Directory('${root.path}/bin')..createSync(recursive: true);
  final flutter = File('${binDir.path}/flutter');
  flutter.writeAsStringSync(content);
  Process.runSync('chmod', <String>['+x', flutter.path]);
}

Map<String, String> _sandboxEnvironment(Directory sandbox) {
  final currentPath = Platform.environment['PATH'] ?? '';
  return <String, String>{
    'PATH': '${sandbox.path}/bin${Platform.isWindows ? ';' : ':'}$currentPath',
  };
}
