import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'public_entrypoint_contract.dart';
import 'tool_process_test_support.dart';

Matcher diagnostic({required String category, required String detail}) {
  return allOf(contains('$category violation:'), contains(detail));
}

Future<Directory> createGuardrailsSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_guardrails_tool_test_',
    toolFiles: const <String>[
      'tool/check_guardrails.dart',
      'tool/src/layer_guardrails.dart',
    ],
  );
}

Future<Directory> createImportBoundariesSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_import_boundaries_tool_test_',
    toolFiles: const <String>[
      'tool/check_import_boundaries.dart',
      'tool/src/layer_guardrails.dart',
    ],
  );
}

void writeCanonicalPublicExportScaffold(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/iwb_canvas_engine.dart',
    canonicalPublicEntrypoint(),
  );
  for (final filePath in canonicalPublicExportFiles) {
    writeSandboxFile(sandbox, filePath, '// stub\n');
  }
}

void writeMinimalControllerStore(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  int controllerEpoch = 0;

  void writeMutations() {}

  void txnCommit() {
    writeMutations();
  }
}
''');
}
