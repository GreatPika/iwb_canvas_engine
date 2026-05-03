@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/guardrail_fixture_writer.dart';
import '../support/guardrails_sandbox_support.dart';
import '../support/public_entrypoint_contract.dart';
import '../support/tool_diagnostic_matchers.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    _registerLayoutScaffoldTests();
    _registerDeletedLayerViolationTests();
    _registerUnknownLayerViolationTests();
    _registerNonDartLayerAcceptanceTests();
    _registerLayerLeafViolationTests();
    _registerContractLayerAcceptanceTests();
    _registerCanonicalRootEntrypointTests();
    _registerMultilineRootEntrypointTests();
    _registerExecutableRootEntrypointViolationTests();
    _registerInlineCommentRootEntrypointViolationTests();
    _registerStalePolicyEntryTests();
    _registerTrailingLogicEntrypointTests();
    _registerAdditionalRootEntrypointTests();
  });
}

void _registerLayoutScaffoldTests() {
  // INV:INV-G-PUBLIC-ENTRYPOINTS
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

  test('canonical test scaffold mirrors the real public barrel exports', () {
    final source = File('lib/iwb_canvas_engine.dart').readAsStringSync();
    final directives = extractNormalizedExportDirectives(source);
    final ownerFiles = extractExportOwnerFiles(source);

    expect(canonicalPublicExportDirectives, directives);
    expect(canonicalPublicExportFiles, ownerFiles);
    expect(
      canonicalPublicExportFiles,
      contains('lib/src/contract/validated.dart'),
    );
    expect(
      canonicalViewPublicExportDirective,
      contains("'src/view/scene_view_interactive.dart'"),
    );
  });
}

void _registerDeletedLayerViolationTests() {
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
}

void _registerUnknownLayerViolationTests() {
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
}

void _registerNonDartLayerAcceptanceTests() {
  test('ignores non-Dart top-level lib/src files', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeSandboxFile(sandbox, 'lib/src/README.md', '# Internal notes\n');

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });
}

void _registerLayerLeafViolationTests() {
  test('rejects unapproved top-level lib/src leaf file', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeSandboxFile(sandbox, 'lib/src/version.dart', 'const version = 1;\n');

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        allOf(
          contains('layer layout violation:'),
          contains('uses unapproved top-level lib/src leaf "version.dart"'),
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });
}

void _registerContractLayerAcceptanceTests() {
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
}

void _registerCanonicalRootEntrypointTests() {
  test('accepts canonical single root public entrypoint', () async {
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
    'accepts canonical root public entrypoint with inline block comments',
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
}

void _registerMultilineRootEntrypointTests() {
  test('allows multiline export directives in root lib entrypoint', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeCanonicalPublicExportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/iwb_canvas_engine.dart',
        canonicalPublicEntrypoint().replaceFirst(
          canonicalFirstPublicExportDirective,
          canonicalFirstPublicExportDirective.replaceFirst(
            'export ',
            'export\n  ',
          ),
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });
}

void _registerExecutableRootEntrypointViolationTests() {
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
}

void _registerInlineCommentRootEntrypointViolationTests() {
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
}

void _registerStalePolicyEntryTests() {
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
          contains('Remove or update this targeted skip'),
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });
}

void _registerTrailingLogicEntrypointTests() {
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
}

void _registerAdditionalRootEntrypointTests() {
  test('rejects additional export-only root entrypoint', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeCanonicalPublicExportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/testing.dart',
        "export 'src/contract/snapshot.dart';\n",
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'public entrypoint',
          detail:
              'root lib/*.dart files must not introduce additional '
              'entrypoints',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });
}
