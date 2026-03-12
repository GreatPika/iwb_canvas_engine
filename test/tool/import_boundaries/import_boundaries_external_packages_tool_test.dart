@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_import_boundaries.dart', () {
    test(
      'rejects core -> external package through lib barrel re-export',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/widgets_api.dart',
            "export 'package:flutter/widgets.dart';\n",
          );
          writeSandboxFile(
            sandbox,
            'lib/src/core/value.dart',
            "import 'package:iwb_canvas_engine/widgets_api.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains(
              'external package violation: core/** must not import '
              'package:flutter/widgets.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}
