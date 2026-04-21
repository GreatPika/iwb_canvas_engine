@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/import_boundaries_sandbox_support.dart';
import '../support/tool_diagnostic_matchers.dart';
import '../support/tool_process_test_support.dart';

void _writeContractBridgeSurfaces(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/node_boundary_schema.dart',
    'class NodeBoundarySchema {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/snapshot_fast_path.dart',
    'class SnapshotFastPath {}\n',
  );
}

void main() {
  group('tool/check_import_boundaries.dart', () {
    // INV:INV-ENG-COMMANDS-NO-PART
    // INV:INV-ENG-COMMANDS-NO-SCENE-CONTROLLER
    // INV:INV-ENG-COMMANDS-NO-CROSS-IMPORTS
    // INV:INV-ENG-INTERNAL-NO-SCENE-CONTROLLER
    // INV:INV-ENG-INTERNAL-NO-COMMANDS-IMPORTS
    // INV:INV-ENG-SHARED-CONTROLLER-HELPERS
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

    test('rejects internal -> scene_store_controller import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/controller/internal/b.dart',
          "import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';\n",
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
                'internal/** must not import controller/scene_store_controller.dart',
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

    test('rejects internal -> lib barrel bypass to commands', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/controller/commands/a/a.dart',
          'class CommandA {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/controller_api.dart',
          "export 'src/controller/commands/a/a.dart';\n",
        );
        writeSandboxFile(
          sandbox,
          'lib/src/controller/internal/b.dart',
          "import '../../../controller_api.dart';\n",
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

    test('rejects internal -> package re-export bypass to commands', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/controller/commands/a/a.dart',
          'class CommandA {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/controller_api.dart',
          "export 'src/controller/commands/a/a.dart';\n",
        );
        writeSandboxFile(
          sandbox,
          'lib/src/controller/internal/b.dart',
          "import 'package:iwb_canvas_engine/controller_api.dart';\n",
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

    test(
      'rejects internal -> non-bridge contract/internal target as cross-layer internal boundary violation',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/unlisted_internal.dart',
            'class UnlistedInternal {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/controller/internal/b.dart',
            "import 'package:iwb_canvas_engine/src/contract/internal/unlisted_internal.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('cross-layer internal boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains('controller/** must not import contract/internal/**'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects internal -> contract bridge target as bridge boundary violation',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          _writeContractBridgeSurfaces(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/internal/b.dart',
            "import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('bridge boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains(
              'controller/** must not import contract/internal/snapshot_fast_path.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects commands -> non-bridge contract/internal target as cross-layer internal boundary violation',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/unlisted_internal.dart',
            'class UnlistedInternal {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/controller/commands/a/a.dart',
            "import 'package:iwb_canvas_engine/src/contract/internal/unlisted_internal.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('cross-layer internal boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains('controller/** must not import contract/internal/**'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects commands -> contract bridge target as bridge boundary violation',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          _writeContractBridgeSurfaces(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/commands/a/a.dart',
            "import 'package:iwb_canvas_engine/src/contract/internal/node_boundary_schema.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('bridge boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains(
              'controller/** must not import contract/internal/node_boundary_schema.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}
