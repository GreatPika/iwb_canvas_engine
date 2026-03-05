import 'package:flutter_test/flutter_test.dart';

import '../utils/guardrails_tool_test_support.dart';
import '../utils/public_entrypoint_contract.dart';
import '../utils/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    // INV:INV-ENG-TXN-ATOMIC-COMMIT
    // INV:INV-G-PUBLIC-ENTRYPOINTS
    // INV:INV-ENG-SAFE-TXN-API
    // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
    test('does not require API_GUIDE.md', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects reintroduced deleted public layer without imports', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/public/value.dart',
          'class PublicValue {}\n',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          allOf(
            contains('layer layout violation:'),
            contains('uses deleted top-level layer "public"'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects unknown top-level lib/src layer without imports', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/unknown/value.dart',
          'class UnknownValue {}\n',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          allOf(
            contains('layer layout violation:'),
            contains('uses unapproved top-level layer "unknown"'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'allows top-level lib/src file without treating it as a layer',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/version.dart',
            'const version = 1;\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('allows approved contract top-level layer without imports', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/contract/value.dart',
          'class ContractValue {}\n',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows export-only root lib entrypoint files', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeCanonicalPublicExportScaffold(sandbox);

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'allows export-only root lib entrypoint files with inline block comments',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            canonicalPublicEntrypoint(withInlineComments: true),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('allows multiline export directives in root lib entrypoint', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeCanonicalPublicExportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/iwb_canvas_engine.dart',
          canonicalPublicEntrypoint().replaceFirst(
            "export 'src/contract/node_patch.dart';",
            "export\n  'src/contract/node_patch.dart';",
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects executable logic in root lib entrypoint files', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
library;

void bootstrap() {}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'public entrypoint',
            detail:
                'root lib/*.dart files must contain only '
                'library/docs/comments/export directives',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects executable logic after inline block comment in root entrypoint',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
library;

/* safe comment */ void bootstrap() {}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'public entrypoint',
              detail:
                  'root lib/*.dart files must contain only '
                  'library/docs/comments/export directives',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects stale non-contract export scan policy entry', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeCanonicalPublicExportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/iwb_canvas_engine.dart',
          canonicalPublicEntrypoint().replaceFirst(
            '$canonicalViewPublicExportDirective\n',
            '',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          allOf(
            diagnostic(
              category: 'public entrypoint',
              detail:
                  'exported API policy entry '
                  '/lib/src/view/scene_view_interactive.dart is stale',
            ),
            contains('view widgets expose framework UI types'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects executable logic after export and inline block comment',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            canonicalPublicEntrypoint(withTrailingLogicAfterFirstExport: true),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'public entrypoint',
              detail:
                  'root lib/*.dart files must contain only '
                  'library/docs/comments/export directives',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects advanced.dart entrypoint', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/advanced.dart',
          '// forbidden entrypoint\n',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'public entrypoint',
            detail: 'advanced.dart is forbidden',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}
