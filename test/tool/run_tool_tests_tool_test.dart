@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/tool_test_runner.dart';

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
  });
}

void _writeFile(Directory root, String relativePath) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('// stub\n');
}
