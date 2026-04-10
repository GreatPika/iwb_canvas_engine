@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/run_verification_preset.dart', () {
    test('resolve returns the required preset machine plan', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalToolTestFile(sandbox);
        _writeChangedPathsFile(sandbox, 'tool/run_verification_preset.dart\n');

        final result = await runSandboxTool(
          sandbox,
          'run_verification_preset.dart',
          args: const <String>[
            'resolve',
            '--format=json',
            '--preset=required_code_change',
            '--changed-paths-file=.codex/changed_paths.txt',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final payload =
            jsonDecode(result.stdout.toString()) as Map<String, Object?>;
        expect(payload.keys, <String>['mode', 'selectors', 'steps']);
        expect(payload['mode'], 'preset');
        expect(payload['selectors'], <Object?>['required_code_change']);
        final steps = List<Map<String, Object?>>.from(
          (payload['steps'] as List<Object?>?) ?? const <Object?>[],
        );
        expect(steps.first['id'], 'format_check');
        expect(steps.last['id'], 'tool_tests');
        expect(steps.last['kind'], 'tool_tests');
        expect(steps.last['reason'], 'preset:required_code_change:tool_tests');
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'resolve deduplicates and orders explicit scopes canonically',
      () async {
        final sandbox = await _createSandbox();
        try {
          final result = await runSandboxTool(
            sandbox,
            'run_verification_preset.dart',
            args: const <String>[
              'resolve',
              '--format=json',
              '--scope=interactive',
              '--scope=render_view',
              '--scope=render_view',
            ],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          final payload =
              jsonDecode(result.stdout.toString()) as Map<String, Object?>;
          expect(payload['mode'], 'scope');
          expect(payload['selectors'], <Object?>['render_view', 'interactive']);
          expect(payload['steps'], <Object?>[
            <String, Object?>{
              'id': 'scope_render_view',
              'kind': 'shell',
              'cmd': 'flutter test --no-pub test/render test/view',
              'cwd': '.',
              'reason': 'scope:render_view',
            },
            <String, Object?>{
              'id': 'scope_interactive',
              'kind': 'shell',
              'cmd': 'flutter test --no-pub test/interactive',
              'cwd': '.',
              'reason': 'scope:interactive',
            },
          ]);
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('resolve returns example scope with example cwd', () async {
      final sandbox = await _createSandbox();
      try {
        final result = await runSandboxTool(
          sandbox,
          'run_verification_preset.dart',
          args: const <String>['resolve', '--format=json', '--scope=example'],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final payload =
            jsonDecode(result.stdout.toString()) as Map<String, Object?>;
        final step = List<Map<String, Object?>>.from(
          (payload['steps'] as List<Object?>?) ?? const <Object?>[],
        ).single;
        expect(step['id'], 'scope_example');
        expect(step['cwd'], 'example');
        expect(step['cmd'], 'flutter test --no-pub test');
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'resolve returns tool tests only when changed paths match trigger surface',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeChangedPathsFile(sandbox, 'tool/src/tool_test_runner.dart\n');
          final matched = await runSandboxTool(
            sandbox,
            'run_verification_preset.dart',
            args: const <String>[
              'resolve',
              '--format=json',
              '--tool-tests',
              '--changed-paths-file=.codex/changed_paths.txt',
            ],
          );
          _writeChangedPathsFile(sandbox, 'README.md\n');
          final unmatched = await runSandboxTool(
            sandbox,
            'run_verification_preset.dart',
            args: const <String>[
              'resolve',
              '--format=json',
              '--tool-tests',
              '--changed-paths-file=.codex/changed_paths.txt',
            ],
          );

          expect(matched.exitCode, 0, reason: matched.stderr.toString());
          expect(unmatched.exitCode, 0, reason: unmatched.stderr.toString());
          final matchedPayload =
              jsonDecode(matched.stdout.toString()) as Map<String, Object?>;
          expect(
            ((matchedPayload['steps'] as List<Object?>?) ?? const <Object?>[])
                .length,
            1,
          );
          expect(
            (jsonDecode(unmatched.stdout.toString())
                as Map<String, Object?>)['steps'],
            <Object?>[],
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'resolve preserves explicit tool test file order after normalization',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalToolTestFile(sandbox, 'test/tool/a_tool_test.dart');
          _writeCanonicalToolTestFile(sandbox, 'test/tool/b_tool_test.dart');

          final result = await runSandboxTool(
            sandbox,
            'run_verification_preset.dart',
            args: const <String>[
              'resolve',
              '--format=json',
              r'--tool-test-file=test\tool\b_tool_test.dart',
              '--tool-test-file=./test/tool/a_tool_test.dart',
            ],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          final payload =
              jsonDecode(result.stdout.toString()) as Map<String, Object?>;
          expect(payload['selectors'], <Object?>[
            'test/tool/b_tool_test.dart',
            'test/tool/a_tool_test.dart',
          ]);
          final step = List<Map<String, Object?>>.from(
            (payload['steps'] as List<Object?>?) ?? const <Object?>[],
          ).single;
          expect(
            step['cmd'],
            'dart run tool/run_tool_tests.dart test/tool/b_tool_test.dart '
            'test/tool/a_tool_test.dart',
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('resolve fails when selector modes are mixed', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalToolTestFile(sandbox);
        final result = await runSandboxTool(
          sandbox,
          'run_verification_preset.dart',
          args: const <String>[
            'resolve',
            '--format=json',
            '--scope=core',
            '--tool-test-file=test/tool/run_verification_preset_tool_test.dart',
          ],
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('Selector modes cannot be mixed.'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'resolve reads changed paths from file together with explicit flags',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalToolTestFile(sandbox);
          _writeChangedPathsFile(sandbox, 'README.md\n');

          final result = await runSandboxTool(
            sandbox,
            'run_verification_preset.dart',
            args: const <String>[
              'resolve',
              '--format=json',
              '--tool-tests',
              '--changed-paths-file=.codex/changed_paths.txt',
              '--changed-path=tool/src/tool_test_runner.dart',
            ],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          final payload =
              jsonDecode(result.stdout.toString()) as Map<String, Object?>;
          expect(payload['mode'], 'tool_tests');
          expect(payload['selectors'], <Object?>[
            'README.md',
            'tool/src/tool_test_runner.dart',
          ]);
          expect((payload['steps'] as List<Object?>).length, 1);
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('resolve fails when required changed paths are missing', () async {
      final sandbox = await _createSandbox();
      try {
        final result = await runSandboxTool(
          sandbox,
          'run_verification_preset.dart',
          args: const <String>[
            'resolve',
            '--format=json',
            '--preset=required_code_change',
          ],
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'requires --changed-paths-file or at least one --changed-path',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('resolve fails when changed paths file is missing', () async {
      final sandbox = await _createSandbox();
      try {
        final result = await runSandboxTool(
          sandbox,
          'run_verification_preset.dart',
          args: const <String>[
            'resolve',
            '--format=json',
            '--preset=required_code_change',
            '--changed-paths-file=.codex/missing.txt',
          ],
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('Changed paths file not found: .codex/missing.txt'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'run emits compact success output and hides child output for passing steps',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFakeExecutables(sandbox);
          _writeCanonicalToolTestFile(sandbox);
          _writeChangedPathsFile(
            sandbox,
            'test/tool/run_verification_preset_tool_test.dart\n',
          );

          final result = await runSandboxTool(
            sandbox,
            'run_verification_preset.dart',
            args: const <String>[
              'run',
              '--tool-tests',
              '--changed-paths-file=.codex/changed_paths.txt',
            ],
            environment: _sandboxEnvironment(sandbox),
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(result.stdout.toString(), contains('PASS tool_tests'));
          expect(
            result.stdout.toString(),
            isNot(contains('fake child stdout')),
          );
          expect(result.stderr.toString(), isEmpty);
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'run surfaces child diagnostics and exits non-zero on failure',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFailingShell(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'run_verification_preset.dart',
            args: const <String>['run', '--scope=core'],
            environment: _sandboxEnvironment(sandbox),
          );

          expect(result.exitCode, isNonZero);
          expect(result.stdout.toString(), contains('FAIL scope_core'));
          expect(result.stdout.toString(), contains('failing stdout'));
          expect(result.stderr.toString(), contains('failing stderr'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}

void _writeChangedPathsFile(Directory sandbox, String content) {
  writeSandboxFile(sandbox, '.codex/changed_paths.txt', content);
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_run_verification_preset_',
    toolFiles: const <String>[
      'tool/run_verification_preset.dart',
      'tool/run_tool_tests.dart',
      'tool/src/tool_test_runner.dart',
      'tool/src/verification_contract',
    ],
    includeAnalyzer: false,
  );
}

void _writeCanonicalToolTestFile(
  Directory sandbox, [
  String path = 'test/tool/run_verification_preset_tool_test.dart',
]) {
  writeSandboxFile(sandbox, path, '''
@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ok', () {
    expect(1, 1);
  });
}
''');
}

void _writeFakeExecutables(Directory sandbox) {
  final binDir = Directory('${sandbox.path}/bin')..createSync(recursive: true);
  final flutter = File('${binDir.path}/flutter');
  flutter.writeAsStringSync('''
#!/bin/sh
if [ "\$1" = "test" ]; then
  echo "fake child stdout"
fi
exit 0
''');
  Process.runSync('chmod', <String>['+x', flutter.path]);
}

void _writeFailingShell(Directory sandbox) {
  final binDir = Directory('${sandbox.path}/bin')..createSync(recursive: true);
  final flutter = File('${binDir.path}/flutter');
  flutter.writeAsStringSync('''
#!/bin/sh
echo "failing stdout"
echo "failing stderr" 1>&2
exit 9
''');
  Process.runSync('chmod', <String>['+x', flutter.path]);
}

Map<String, String> _sandboxEnvironment(Directory sandbox) {
  final currentPath = Platform.environment['PATH'] ?? '';
  return <String, String>{
    'PATH': '${sandbox.path}/bin${Platform.isWindows ? ';' : ':'}$currentPath',
  };
}
