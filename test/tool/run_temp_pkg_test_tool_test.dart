@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../tool/src/temp_pkg_test/temp_pkg_test_runner.dart';
import 'support/tool_process_test_support.dart';

void main() {
  group('tool/run_temp_pkg_test.dart', () {
    test('parses snippet-file mode and keep-temp flag', () {
      final config = parseTempPkgTestConfig(<String>[
        '--snippet-file=test/tool/scratch_snippet.dart',
        '--keep-temp',
      ]);

      expect(config.keepTemp, isTrue);
      expect(config.input.mode, TempPkgTestInputMode.snippetFile);
      expect(config.input.value, 'test/tool/scratch_snippet.dart');
    });

    test('rejects multiple input sources', () {
      expect(
        () => parseTempPkgTestConfig(<String>[
          '--stdin',
          '--test-file=test/tool/example_test.dart',
        ]),
        throwsA(
          isA<TempPkgTestExit>().having(
            (error) => error.exitCode,
            'exitCode',
            64,
          ),
        ),
      );
    });

    test('wraps snippets with standard imports and main()', () {
      final rendered = renderTempPkgTestFile(
        const TempPkgTestSource(
          mode: TempPkgTestSourceMode.snippet,
          content: '''
test('smoke', () {
  expect(SceneSnapshot(layers: const []), isNotNull);
});
''',
        ),
      );

      expect(
        rendered,
        contains("import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';"),
      );
      expect(rendered, contains('void main() {'));
      expect(rendered, contains("  test('smoke', () {"));
    });

    test('runs snippet input inside a temporary package', () async {
      final sandbox = await createToolSandbox(
        tempPrefix: 'iwb_canvas_engine_run_temp_pkg_test_',
        toolFiles: const <String>[
          'tool/run_temp_pkg_test.dart',
          'tool/src/temp_pkg_test',
        ],
        includeAnalyzer: false,
      );
      try {
        writeSandboxFile(sandbox, 'test_snippet.dart', '''
test('snippet smoke', () {
  expect(SceneSnapshot(layers: const <ContentLayerSnapshot>[]), isNotNull);
});
''');
        _writeFlutterStub(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'run_temp_pkg_test.dart',
          args: const <String>['--snippet-file=test_snippet.dart'],
          environment: _sandboxEnvironment(sandbox),
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('flutter test --no-pub test/temp_pkg_test.dart ok'),
        );

        final log = File(
          '${sandbox.path}/flutter_invocations.log',
        ).readAsStringSync();
        expect(log, contains('pub|get'));
        expect(log, contains('test|--no-pub test/temp_pkg_test.dart|'));
        expect(
          log,
          contains('package:iwb_canvas_engine/iwb_canvas_engine.dart'),
        );
        expect(log, contains("path: '"));
        expect(log, contains('iwb_canvas_engine_run_temp_pkg_test_'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('runs full test file input without wrapper rewrite', () async {
      final sandbox = await createToolSandbox(
        tempPrefix: 'iwb_canvas_engine_run_temp_pkg_test_full_',
        toolFiles: const <String>[
          'tool/run_temp_pkg_test.dart',
          'tool/src/temp_pkg_test',
        ],
        includeAnalyzer: false,
      );
      try {
        writeSandboxFile(sandbox, 'full_test.dart', '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full file', () {
    expect(1, 1);
  });
}
''');
        _writeFlutterStub(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'run_temp_pkg_test.dart',
          args: const <String>['--test-file=full_test.dart'],
          environment: _sandboxEnvironment(sandbox),
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final log = File(
          '${sandbox.path}/flutter_invocations.log',
        ).readAsStringSync();
        expect(
          log,
          contains("import 'package:flutter_test/flutter_test.dart';"),
        );
        expect(
          log,
          isNot(contains("package:iwb_canvas_engine/iwb_canvas_engine.dart")),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

void _writeFlutterStub(Directory root) {
  final binDir = Directory('${root.path}/bin')..createSync(recursive: true);
  final flutter = File('${binDir.path}/flutter');
  flutter.writeAsStringSync(r'''
#!/bin/sh
set -eu
log_file="$IWB_TEMP_PKG_TEST_LOG"
command="$1"
shift
printf '%s|' "$PWD" >> "$log_file"
printf '%s|' "$command" >> "$log_file"
printf '%s|' "$*" >> "$log_file"
printf '\n' >> "$log_file"
if [ "$command" = "test" ]; then
  cat pubspec.yaml >> "$log_file"
  cat test/temp_pkg_test.dart >> "$log_file"
fi
echo "flutter $command $* ok"
exit 0
''');
  Process.runSync('chmod', <String>['+x', flutter.path]);
}

Map<String, String> _sandboxEnvironment(Directory sandbox) {
  final currentPath = Platform.environment['PATH'] ?? '';
  return <String, String>{
    'PATH': '${sandbox.path}/bin${Platform.isWindows ? ';' : ':'}$currentPath',
    'IWB_TEMP_PKG_TEST_LOG': '${sandbox.path}/flutter_invocations.log',
  };
}
