@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    test(
      'scans controller-wide files instead of fixed-file allow-list',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/controller/support/neutral_mutator.dart',
            '''
class NeutralMutator {
  void addThing() {}
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'mutating symbol "addThing" must be routed through '
                  'write*/txn* transaction API',
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

  void addThing() {}
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller API',
            detail:
                'mutating symbol "addThing" must be routed through '
                'write*/txn* transaction API',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('requires controllerEpoch when controller tree exists', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  void writeThing() {}
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'controller API',
            detail:
                'controllerEpoch symbol is required for epoch invalidation '
                'guardrails',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'allows interactive-only setter while scanning interactive entrypoint',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);

          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class SceneControllerInteractive {
  Object? _mode;

  void setMode(Object? mode) {
    _ensurePublicSideEffectAllowed();
    _mode = mode;
  }

  void _ensurePublicSideEffectAllowed({bool allowAfterDispose = false}) {}
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0);
          expect(result.stdout.toString(), contains('OK: guardrails'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects mutating declaration in interactive entrypoint without explicit ownership',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);

          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class SceneControllerInteractive {
  void addThing() {
    _ensurePublicSideEffectAllowed();
  }

  void _ensurePublicSideEffectAllowed({bool allowAfterDispose = false}) {}
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'mutating symbol "addThing" must be routed through '
                  'write*/txn* transaction API',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'allows interactive declaration that routes through canonical write seam',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);

          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class _Commands {
  void writeBackgroundColorSet(Object value) {}
}

class _Core {
  final _Commands commands = _Commands();
}

class SceneControllerInteractive {
  final _Core _core = _Core();

  void setBackgroundColor(Object value) {
    _ensurePublicSideEffectAllowed();
    _core.commands.writeBackgroundColorSet(value);
  }

  void _ensurePublicSideEffectAllowed({bool allowAfterDispose = false}) {}
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0);
          expect(result.stdout.toString(), contains('OK: guardrails'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects interactive declaration that reaches write seam only through helper',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);

          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class _Commands {
  void writeBackgroundColorSet(Object value) {}
}

class _Core {
  final _Commands commands = _Commands();
}

class SceneControllerInteractive {
  final _Core _core = _Core();

  void setBackgroundColor(Object value) {
    _ensurePublicSideEffectAllowed();
    _delegateToWriter(value);
  }

  void _delegateToWriter(Object value) {
    _core.commands.writeBackgroundColorSet(value);
  }

  void _ensurePublicSideEffectAllowed({bool allowAfterDispose = false}) {}
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'mutating symbol "setBackgroundColor" must be routed through '
                  'write*/txn* transaction API',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects unrelated write-prefixed API in interactive declaration',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeCanonicalPublicExportScaffold(sandbox);

          writeSandboxFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class _Sink {
  void writeBackgroundColorSet(Object value) {}
}

class SceneControllerInteractive {
  final _Sink sink = _Sink();

  void setBackgroundColor(Object value) {
    _ensurePublicSideEffectAllowed();
    sink.writeBackgroundColorSet(value);
  }

  void _ensurePublicSideEffectAllowed({bool allowAfterDispose = false}) {}
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'mutating symbol "setBackgroundColor" must be routed through '
                  'write*/txn* transaction API',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}
