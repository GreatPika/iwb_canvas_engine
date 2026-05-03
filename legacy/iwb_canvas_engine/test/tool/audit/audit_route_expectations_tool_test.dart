@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/tool_process_test_support.dart';

void main() {
  group('tool/audit_route_expectations.dart', () {
    test(
      'reports mixed pass and fail route expectations from a config file',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'audit_route_expectations.dart',
            args: const <String>['--config=tool/audit/route_expectations.json'],
          );

          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('Summary: total=2, passed=1, failed=1, errors=0'),
          );
          expect(
            result.stdout.toString(),
            contains('PASS: validated write reaches validator'),
          );
          expect(
            result.stdout.toString(),
            contains('FAIL: unsafe write reaches validator'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('writes a JSON report artifact', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFixture(sandbox);
        writeSandboxFile(
          sandbox,
          'tool/audit/route_expectations_clean.json',
          '''
{
  "checks": [
    {
      "description": "validated write reaches validator",
      "file": "lib/src/flow.dart",
      "symbol": "write",
      "target": "validateInput",
      "expectation": "contains",
      "direction": "outgoing",
      "depth": 2
    }
  ]
}
''',
        );

        final result = await runSandboxTool(
          sandbox,
          'audit_route_expectations.dart',
          args: const <String>[
            '--config=tool/audit/route_expectations_clean.json',
            '--json-out=artifacts/routes.json',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final reportFile = File('${sandbox.path}/artifacts/routes.json');
        expect(reportFile.existsSync(), isTrue);
        expect(reportFile.readAsStringSync(), contains('"status": "PASS"'));
        expect(reportFile.readAsStringSync(), contains('"symbol": "write"'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_audit_route_expectations_tool_test_',
    toolFiles: const <String>[
      'tool/audit_route_expectations.dart',
      'tool/src/lsp',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/flow.dart', '''
void validateInput() {}

void materialize() {}

void write() {
  validateInput();
  materialize();
}

void unsafeWrite() {
  materialize();
}
''');
  writeSandboxFile(sandbox, 'tool/audit/route_expectations.json', '''
{
  "checks": [
    {
      "description": "validated write reaches validator",
      "file": "lib/src/flow.dart",
      "symbol": "write",
      "target": "validateInput",
      "expectation": "contains",
      "direction": "outgoing",
      "depth": 2
    },
    {
      "description": "unsafe write reaches validator",
      "file": "lib/src/flow.dart",
      "symbol": "unsafeWrite",
      "target": "validateInput",
      "expectation": "contains",
      "direction": "outgoing",
      "depth": 2
    }
  ]
}
''');
}
