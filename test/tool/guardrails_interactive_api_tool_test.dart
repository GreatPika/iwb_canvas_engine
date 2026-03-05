@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/guardrails_tool_test_support.dart';
import 'support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
    test(
      'accepts guarded public interactive entrypoints in SceneControllerInteractive',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class SceneControllerInteractive {
  int get value => 1;

  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
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
      'accepts guarded multiline interactive entrypoint signatures',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class SceneControllerInteractive {
  void handlePointer(
    int value,
  ) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  set mode(
    int value,
  ) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
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
      'rejects public interactive method without resolver purity guard',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class SceneControllerInteractive {
  void handlePointer() {
    print('missing guard');
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'interactive API',
              detail:
                  'public SceneControllerInteractive entrypoints must guard '
                  'resolver purity with _ensurePublicSideEffectAllowed',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects dispose without allowAfterDispose true in purity guard',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class SceneControllerInteractive {
  void dispose() {
    _ensurePublicSideEffectAllowed('dispose');
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'interactive API',
              detail:
                  'dispose() must guard resolver purity with '
                  'allowAfterDispose: true',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}
