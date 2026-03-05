@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/guardrails_tool_test_support.dart';
import 'support/tool_process_test_support.dart';

void main() {
  group('tool/check_import_boundaries.dart', () {
    test('rejects internal -> commands import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/controller/commands/a/a.dart',
          'class CommandA {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/controller/internal/b.dart',
          "import 'package:iwb_canvas_engine/src/controller/commands/a/a.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller structure',
            detail: 'internal/** must not import commands/**',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects cross-command import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/controller/commands/a/a.dart',
          'class CommandA {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/controller/commands/b/b.dart',
          "import 'package:iwb_canvas_engine/src/controller/commands/a/a.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller structure',
            detail: 'commands/** must not import other commands',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects commands part directives', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/controller/commands/a/a.dart',
          "part 'a.part.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller structure',
            detail: 'commands/** must not use part/part of directives',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects multiline commands part of directives', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/controller/commands/a/a.dart', '''
part
  of 'a_parent.dart';
''');

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller structure',
            detail: 'commands/** must not use part/part of directives',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects internal -> scene_controller import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/controller/internal/b.dart',
          "import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller structure',
            detail:
                'internal/** must not import controller/scene_controller.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects internal -> disallowed external package import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/controller/internal/b.dart',
          "import 'package:external/pkg.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller structure',
            detail: 'internal/** has a disallowed external package import',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects unknown layer under lib/src', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/unknown/z.dart',
          'class Unknown {}\n',
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
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
  });
}
