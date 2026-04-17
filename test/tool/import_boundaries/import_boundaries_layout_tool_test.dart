@Tags(['tool'])
library;

import 'package:test/test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_import_boundaries.dart', () {
    // INV:INV-G-LAYER-BOUNDARIES
    test('rejects core -> unknown target layer import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/unknown/value.dart',
          'class UnknownValue {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          "import 'package:iwb_canvas_engine/src/unknown/value.dart';\n",
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

    test('rejects core -> reintroduced deleted public layer import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        final deletedLayerSegments = ['src', 'public', 'value.dart'];
        final deletedLayerPathSuffix = deletedLayerSegments.join('/');
        final deletedLayerFilePath = 'lib/$deletedLayerPathSuffix';
        final deletedLayerImportTarget =
            'package:iwb_canvas_engine/$deletedLayerPathSuffix';

        writeSandboxFile(
          sandbox,
          deletedLayerFilePath,
          'class DeletedLayerValue {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          "import '$deletedLayerImportTarget';\n",
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
            contains('uses deleted top-level layer "public"'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects reintroduced deleted public layer without imports', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/public/value.dart',
          'class DeletedLayerValue {}\n',
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
            contains('uses deleted top-level layer "public"'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects unknown top-level lib/src layer without imports', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/unknown/value.dart',
          'class UnknownValue {}\n',
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

    test('ignores non-Dart top-level lib/src files', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/README.md', '# Internal notes\n');
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          'class CoreValue {}\n',
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    const higherLayerCases = <({String filePath, String label})>[
      (filePath: 'lib/src/model/value.dart', label: 'model'),
      (filePath: 'lib/src/controller/value.dart', label: 'controller'),
      (filePath: 'lib/src/interactive/value.dart', label: 'interactive'),
      (filePath: 'lib/src/render/value.dart', label: 'render'),
      (filePath: 'lib/src/serialization/value.dart', label: 'serialization'),
      (filePath: 'lib/src/view/value.dart', label: 'view'),
    ];

    for (final layerCase in higherLayerCases) {
      test(
        'rejects ${layerCase.label} -> unknown target layer import',
        () async {
          final sandbox = await createImportBoundariesSandbox();
          try {
            writeSandboxFile(
              sandbox,
              'lib/src/unknown/value.dart',
              'class UnknownValue {}\n',
            );
            writeSandboxFile(
              sandbox,
              layerCase.filePath,
              "import 'package:iwb_canvas_engine/src/unknown/value.dart';\n",
            );

            final result = await runSandboxTool(
              sandbox,
              'check_import_boundaries.dart',
            );
            expect(
              result.exitCode,
              isNonZero,
              reason: '${layerCase.label} unexpectedly imported unknown layer',
            );
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
        },
      );
    }

    test('rejects unapproved top-level lib/src leaf file', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/version.dart',
          'const version = 1;\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          'class CoreValue {}\n',
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
            contains('uses unapproved top-level lib/src leaf "version.dart"'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows approved contract top-level layer without imports', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/contract/value.dart',
          'class ContractValue {}\n',
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}
