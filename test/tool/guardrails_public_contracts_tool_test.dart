@Tags(['tool'])
library;

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
    test('passes for write/txn APIs and controllerEpoch usage', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects mutable core exports from iwb_canvas_engine.dart', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeCanonicalPublicExportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/iwb_canvas_engine.dart',
          "${canonicalPublicEntrypoint()}export 'src/core/scene.dart';\n",
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'public export',
            detail:
                'lib/iwb_canvas_engine.dart must not export mutable core model',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects conditional import/export branch in exported contract API to disallowed layers',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(sandbox, 'lib/src/contract/node_patch.dart', '''
export 'package:iwb_canvas_engine/src/contract/node_spec.dart'
    if (dart.library.io) 'package:iwb_canvas_engine/src/view/scene_view_interactive.dart';

class NodePatch {}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'public export',
              detail:
                  'must not import/export controller/**, render/**, view/**, or serialization/**',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects conditional export of mutable core from iwb_canvas_engine.dart',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            canonicalPublicEntrypoint().replaceFirst(
              "export 'src/contract/node_patch.dart';",
              "export 'src/contract/node_patch.dart' if (dart.library.io) 'src/core/scene.dart';",
            ),
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'public export',
              detail:
                  'lib/iwb_canvas_engine.dart must not export mutable core model',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-contract export without mutable-type leak scan policy',
      () async {
        // INV:INV-G-PUBLIC-ENTRYPOINTS
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            "${canonicalPublicEntrypoint()}export 'src/view/foo.dart';\n",
          );
          writeSandboxFile(sandbox, 'lib/src/view/foo.dart', '''
class SceneView {}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'public entrypoint',
              detail:
                  'must declare a mutable-type leak scan policy in '
                  'tool/check_guardrails.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects scene/writeFindNode/writeMark*/id-bookkeeping in exported txn API',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(sandbox, 'lib/src/contract/scene_write_txn.dart', '''
abstract interface class SceneWriteTxn {
  Object get scene;
  Object? writeFindNode(String id);
  void writeMarkVisualChanged();
  String writeNewNodeId();
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            anyOf(
              diagnostic(
                category: 'public contract',
                detail:
                    'exported SceneWriteTxn must not expose raw scene access',
              ),
              diagnostic(
                category: 'public contract',
                detail: 'exported SceneWriteTxn must not expose writeFindNode',
              ),
              diagnostic(
                category: 'public contract',
                detail:
                    'exported SceneWriteTxn must not expose writeMark* '
                    'escape hatches',
              ),
              diagnostic(
                category: 'public contract',
                detail:
                    'exported SceneWriteTxn must not expose node-id '
                    'bookkeeping methods',
              ),
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'skips mutable-type leak scan for explicitly classified exported view API',
      () async {
        // INV:INV-ENG-NO-EXTERNAL-MUTATION
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/view/scene_view_interactive.dart',
            '''
abstract class SceneView {
  Scene get scene;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects mutable core type in exported public API signature',
      () async {
        // INV:INV-ENG-NO-EXTERNAL-MUTATION
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
abstract class Foo {
  Scene get scene;
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'public contract',
              detail: 'exported API must not expose mutable core types',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects multiline mutable core type in exported public API signature',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);
          writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
abstract class Foo {
  Scene
  get scene;
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'public contract',
              detail: 'exported API must not expose mutable core types',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects mutating symbol outside write/txn prefixes', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  int controllerEpoch = 0;

  void replaceScene() {}
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller API',
            detail:
                'mutating symbol "replaceScene" must be routed through '
                'write*/txn* transaction API',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects exported contract import from controller layer', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeCanonicalPublicExportScaffold(sandbox);
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/controller/types.dart',
          'class ControllerType {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/contract/snapshot.dart',
          "import 'package:iwb_canvas_engine/src/controller/types.dart';\n",
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'public export',
            detail:
                'exported contract/** and the model facade must not '
                'import/export controller/**, render/**, view/**, or '
                'serialization/**',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}
