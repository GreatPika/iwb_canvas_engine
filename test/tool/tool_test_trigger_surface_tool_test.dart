@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/check_tool_test_trigger_surface.dart', () {
    test('passes when CI and VERIFICATION stay aligned', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalCiWorkflow(sandbox);
        _writeCanonicalVerification(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'check_tool_test_trigger_surface.dart',
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('Tool-test trigger surface OK'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('fails when CI is missing the public entrypoint trigger', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCiWorkflow(
          sandbox: sandbox,
          triggerEntries: _canonicalTriggerEntries
              .where((entry) => entry != 'lib/iwb_canvas_engine.dart')
              .toList(growable: false),
        );
        _writeCanonicalVerification(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'check_tool_test_trigger_surface.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            '.github/workflows/ci.yaml is missing required trigger entry '
            '`lib/iwb_canvas_engine.dart`.',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'fails when VERIFICATION.md is missing the public entrypoint trigger',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalCiWorkflow(sandbox);
          _writeVerification(
            sandbox: sandbox,
            triggerEntries: _canonicalTriggerEntries
                .where((entry) => entry != 'lib/iwb_canvas_engine.dart')
                .toList(growable: false),
          );

          final result = await runSandboxTool(
            sandbox,
            'check_tool_test_trigger_surface.dart',
          );

          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains(
              'VERIFICATION.md is missing required trigger entry '
              '`lib/iwb_canvas_engine.dart`.',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('fails when CI and VERIFICATION drift', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalCiWorkflow(sandbox);
        _writeVerification(
          sandbox: sandbox,
          triggerEntries: <String>[
            ..._canonicalTriggerEntries,
            'tool/extra.dart',
          ],
        );

        final result = await runSandboxTool(
          sandbox,
          'check_tool_test_trigger_surface.dart',
        );

        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('Entries present only in VERIFICATION.md: tool/extra.dart'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

const List<String> _canonicalTriggerEntries = <String>[
  'lib/iwb_canvas_engine.dart',
  'tool/**',
  'test/tool/**',
  'test/tool/support/guardrails_tool_test_support.dart',
  'test/tool/support/tool_process_test_support.dart',
  'test/tool/support/public_entrypoint_contract.dart',
  'pubspec.yaml',
  'pubspec.lock',
];

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_tool_test_trigger_surface_',
    toolFiles: const <String>['tool/check_tool_test_trigger_surface.dart'],
    includeAnalyzer: false,
  );
}

void _writeCanonicalCiWorkflow(Directory sandbox) {
  _writeCiWorkflow(sandbox: sandbox, triggerEntries: _canonicalTriggerEntries);
}

void _writeCiWorkflow({
  required Directory sandbox,
  required List<String> triggerEntries,
}) {
  writeSandboxFile(sandbox, '.github/workflows/ci.yaml', '''
name: CI

jobs:
  tool-test-changes:
    steps:
      - name: Detect tool-test-impacting changes
        with:
          filters: |
            tool_tests:
${triggerEntries.map((entry) => "              - '$entry'").join('\n')}
''');
}

void _writeCanonicalVerification(Directory sandbox) {
  _writeVerification(
    sandbox: sandbox,
    triggerEntries: _canonicalTriggerEntries,
  );
}

void _writeVerification({
  required Directory sandbox,
  required List<String> triggerEntries,
}) {
  writeSandboxFile(sandbox, 'VERIFICATION.md', '''
# Verification

- Run tool tests only when the change touches tool-test surface. The trigger
  list in this file must stay identical to `.github/workflows/ci.yaml`:
${triggerEntries.map((entry) => '  - `$entry`').join('\n')}

- Run tool tests with `dart run tool/run_tool_tests.dart`.
''');
}
