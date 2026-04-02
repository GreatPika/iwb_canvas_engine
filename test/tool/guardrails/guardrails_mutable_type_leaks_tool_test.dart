@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    _registerMutableLeakSurfaceTests();
    _registerMutableCoreLeakTests();
    _registerMultilineMutableCoreLeakTests();
    _registerMutableRuntimeLeakTests();
    _registerInteractiveMutableLeakTests();
  });
}

void _registerMutableLeakSurfaceTests() {
  test(
    'ignores non-exported view declarations while scanning exported surface',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeCanonicalPublicExportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive.dart',
          '''
Scene debugLeakedScene() => throw UnimplementedError();

class SceneViewInteractive {
  SceneController get controller => throw UnimplementedError();
}

typedef SceneView = SceneViewInteractive;
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}

void _registerMutableCoreLeakTests() {
  test('rejects mutable core type in exported public API signature', () async {
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
  });
}

void _registerMultilineMutableCoreLeakTests() {
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
}

void _registerMutableRuntimeLeakTests() {
  test('rejects mutable runtime type in exported contract signature', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeCanonicalPublicExportScaffold(sandbox);
      writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
abstract class Foo {
  SceneController get controller;
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
  });
}

void _registerInteractiveMutableLeakTests() {
  test('rejects mutable core type in exported interactive surface', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeCanonicalPublicExportScaffold(sandbox);
      writeSandboxFile(sandbox, 'lib/src/interactive/scene_controller.dart', '''
class SceneController {
  Scene get snapshot => throw UnimplementedError();

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

typedef SceneController = SceneController;
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
  });
}
