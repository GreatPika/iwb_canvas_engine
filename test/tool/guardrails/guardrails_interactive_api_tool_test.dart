@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    _registerInteractiveAcceptanceTests();
    _registerInteractiveGuardViolationTests();
    _registerInteractiveDisposeGuardTests();
    _registerCapabilityGuardViolationTests();
    // INV:INV-ENG-INTERACTIVE-MUTATION-BOUNDARY
    _registerInteractiveArchitectureGuardrailTests();
    _registerCommittedReadSideHermeticityTests();
  });
}

String _sceneControllerFixture({
  required String methods,
  String extraImports = '',
  String extraMembers = '',
}) {
  return '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';
$extraImports

class SceneController {
  final Object _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );
$extraMembers

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

$methods

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
}
''';
}

void _registerInteractiveAcceptanceTests() {
  // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
  test(
    'accepts guarded public interactive entrypoints in SceneController',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            extraMembers: '\n  int get value => 1;\n',
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('accepts guarded multiline interactive entrypoint signatures', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(
    int value,
  ) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(
    int value,
  ) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('accepts canonical shared capability-owner scaffold', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('writes canonical shared capability-owner guard fixtures', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);

      final interactionOwner = File(
        '${sandbox.path}/lib/src/interactive/scene_controller_interaction.dart',
      ).readAsStringSync();
      final selectionOwner = File(
        '${sandbox.path}/lib/src/interactive/scene_controller_selection.dart',
      ).readAsStringSync();
      final sceneOwner = File(
        '${sandbox.path}/lib/src/interactive/scene_controller_scene.dart',
      ).readAsStringSync();

      expect(interactionOwner, contains('void handlePointer(Object input)'));
      expect(
        interactionOwner,
        contains(
          "_access.runtime.ensurePublicSideEffectAllowed('handlePointer');",
        ),
      );
      expect(interactionOwner, contains('void handleDoubleTap()'));
      expect(interactionOwner, contains('set mode(int value)'));

      expect(selectionOwner, contains('void setSelection(Object nodeIds)'));
      expect(
        selectionOwner,
        contains("_runtime.ensurePublicSideEffectAllowed('setSelection');"),
      );
      expect(selectionOwner, contains('void toggleSelection(Object nodeId)'));
      expect(selectionOwner, contains('void clearSelection()'));
      expect(selectionOwner, contains('void selectAll()'));
      expect(selectionOwner, contains('void rotateSelection()'));

      expect(sceneOwner, contains('void write(Object fn)'));
      expect(sceneOwner, contains("ensurePublicSideEffectAllowed('write');"));
      expect(sceneOwner, contains('void clearScene()'));
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });
}

void _registerInteractiveGuardViolationTests() {
  test(
    'rejects public interactive method without resolver purity guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    print('missing guard');
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'public SceneController entrypoints must guard '
                'resolver purity with _ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}

void _registerCapabilityGuardViolationTests() {
  test(
    'rejects public interaction method without resolver purity guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller_interaction.dart',
          '''
class SceneControllerInteractionOwner {
  void handlePointer() {
    print('missing guard');
  }
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
                'public SceneControllerInteractionOwner entrypoints must guard '
                'resolver purity with '
                '_access.runtime.ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects public scene mutation without resolver purity guard', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller_scene.dart',
        '''
class SceneControllerSceneOwner {
  void write(Object fn) {
    print('missing guard');
  }
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
              'public SceneControllerSceneOwner entrypoints must guard '
              'resolver purity with ensurePublicSideEffectAllowed',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects selection mutation owner without active gesture guard', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_selection_mutations.dart',
        interactiveSelectionMutationsFixture(
          setSelectionBody: "print('missing guard');",
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneControllerSelectionMutations.setSelection must guard '
              'active-gesture exclusivity with '
              'ensureExternalMutationAllowed',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects selection mutation owner with late active gesture guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_selection_mutations.dart',
          interactiveSelectionMutationsFixture(
            setSelectionBody: '''
mutations.setSelection(nodeIds);
ensureExternalMutationAllowed('setSelection');
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSelectionMutations.setSelection must guard '
                'active-gesture exclusivity with '
                'ensureExternalMutationAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'accepts harmless local prelude before selection mutation owner guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_selection_mutations.dart',
          interactiveSelectionMutationsFixture(
            setSelectionBody: '''
final shouldWrite = nodeIds != null;
if (!shouldWrite) {
  return;
}
ensureExternalMutationAllowed('setSelection');
mutations.setSelection(nodeIds);
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene mutation owner write without active gesture guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          interactiveSceneMutationsFixture(
            writeBody: "print('missing guard');",
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneMutations.write must guard '
                'active-gesture exclusivity with '
                'ensureExternalMutationAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene mutation owner write with late active gesture guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          interactiveSceneMutationsFixture(
            writeBody: '''
mutations.write(fn);
ensureExternalMutationAllowed('write');
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneMutations.write must guard '
                'active-gesture exclusivity with '
                'ensureExternalMutationAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'accepts canonical scene mutation owner camera offset preflight',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          interactiveSceneMutationsFixture(),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene mutation owner camera offset with late interrupt',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          interactiveSceneMutationsFixture(
            setCameraOffsetBody: '''
mutations.validateCameraOffset(value);
if (!mutations.shouldApplyCameraOffset(value)) {
  return;
}
mutations.setCameraOffset(value);
interruptForExternalMutation();
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneMutations.setCameraOffset must guard '
                'active-gesture exclusivity with '
                'interruptForExternalMutation',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene mutation owner camera offset without early return short circuit',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          interactiveSceneMutationsFixture(
            setCameraOffsetBody: '''
mutations.validateCameraOffset(value);
if (!mutations.shouldApplyCameraOffset(value)) {
  final noop = 1;
}
interruptForExternalMutation();
mutations.setCameraOffset(value);
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneMutations.setCameraOffset must guard '
                'active-gesture exclusivity with '
                'interruptForExternalMutation',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene mutation owner camera offset with extra step after interrupt',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          interactiveSceneMutationsFixture(
            setCameraOffsetBody: '''
mutations.validateCameraOffset(value);
if (!mutations.shouldApplyCameraOffset(value)) {
  return;
}
interruptForExternalMutation();
final debugMarker = value;
mutations.setCameraOffset(debugMarker);
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneMutations.setCameraOffset must guard '
                'active-gesture exclusivity with '
                'interruptForExternalMutation',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('accepts direct replaceScene interrupt forwarding', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
        interactiveSceneMutationsFixture(),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects replaceScene forwarding through wrong direct callback',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          interactiveSceneMutationsFixture(
            replaceSceneBody: '''
mutations.replaceScene(
  snapshot,
  interruptBeforeApply: () {},
);
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneMutations.replaceScene must guard '
                'active-gesture exclusivity with '
                'interruptForExternalMutation',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects replaceScene forwarding through local alias', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
        interactiveSceneMutationsFixture(
          replaceSceneBody: '''
final beforeApply = interruptForExternalMutation;
mutations.replaceScene(
  snapshot,
  interruptBeforeApply: beforeApply,
);
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneControllerSceneMutations.replaceScene must guard '
              'active-gesture exclusivity with '
              'interruptForExternalMutation',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects replaceScene forwarding through reassigned alias', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
        interactiveSceneMutationsFixture(
          replaceSceneBody: '''
var beforeApply = interruptForExternalMutation;
beforeApply = () {};
mutations.replaceScene(
  snapshot,
  interruptBeforeApply: beforeApply,
);
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneControllerSceneMutations.replaceScene must guard '
              'active-gesture exclusivity with '
              'interruptForExternalMutation',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects replaceScene forwarding with trailing effectful boundary call',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          interactiveSceneMutationsFixture(
            replaceSceneBody: '''
mutations.replaceScene(
  snapshot,
  interruptBeforeApply: interruptForExternalMutation,
);
mutations.clearScene();
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneMutations.replaceScene must guard '
                'active-gesture exclusivity with '
                'interruptForExternalMutation',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects mutation-owner helper bypass for scene.write', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
        '''
class SceneControllerSceneMutations {
  void write(Object fn) {
    _guardExternal('write');
  }

  void setBackgroundColor(Object value) {
    ensureExternalMutationAllowed('setBackgroundColor');
  }

  void setGridEnabled(bool value) {
    ensureExternalMutationAllowed('setGridEnabled');
  }

  void setGridCellSize(double value) {
    ensureExternalMutationAllowed('setGridCellSize');
  }

  void addNode(Object node) {
    ensureExternalMutationAllowed('addNode');
  }

  void ensureLayer(Object layerId) {
    ensureExternalMutationAllowed('ensureLayer');
  }

  void patchNode(Object patch) {
    ensureExternalMutationAllowed('patchNode');
  }

  void removeNode(Object nodeId) {
    ensureExternalMutationAllowed('removeNode');
  }

  void clearScene() {
    ensureExternalMutationAllowed('clearScene');
  }

  void _guardExternal(String operation) {
    ensureExternalMutationAllowed(operation);
  }

  final void Function(String operation) ensureExternalMutationAllowed =
      (String operation) {};
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
              'SceneControllerSceneMutations.write must guard '
              'active-gesture exclusivity with '
              'ensureExternalMutationAllowed',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });
}

void _registerCommittedReadSideHermeticityTests() {
  test('accepts snapshot-only interactive committed read callbacks', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects interactive committed read callback leaking runtime scene node through typedef alias',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          '''
import '../../core/scene_node.dart';
import '../../core/scene_spatial_index.dart';

typedef LeakedNode = SceneNode;

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
  });

  final Object onPublicStateChanged;
  final Object onSceneStateChanged;
  final Object onOverlayStateChanged;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final LeakedNode? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object emitAction;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveMoveSessionCallbacks.'
                'resolveSpatialCandidateSnapshot" must not expose live '
                'runtime scene-graph types (SceneNode)',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive eraser callback leaking runtime scene node subtype',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
        writeSandboxFile(sandbox, 'lib/src/core/vector_nodes.dart', '''
import 'scene_node.dart';

class StrokeNode extends SceneNode {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_draw_eraser_targets.dart',
          '''
import '../../core/vector_nodes.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawEraserTargetsCallbacks {
  const InteractiveDrawEraserTargetsCallbacks({
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.onSpatialQuery,
  });

  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final StrokeNode? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object onSpatialQuery;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveDrawEraserTargetsCallbacks.'
                'resolveSpatialCandidateSnapshot" must not expose live '
                'runtime scene-graph types (StrokeNode)',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive callback field outside sealed committed read surface',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
    required this.resolveSnapshotNodeById,
  });

  final Object onPublicStateChanged;
  final Object onSceneStateChanged;
  final Object onOverlayStateChanged;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object emitAction;
  final Object resolveSnapshotNodeById;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveMoveSessionCallbacks.resolveSnapshotNodeById" '
                'must not extend the sealed callback surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive callback queryHitTestCandidates signature drift',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
  });

  final Object onPublicStateChanged;
  final Object onSceneStateChanged;
  final Object onOverlayStateChanged;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Object bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object emitAction;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveMoveSessionCallbacks.queryHitTestCandidates" '
                'must keep the exact sealed signature',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive callback resolveSpatialCandidateSnapshot extra parameters',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart',
          '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawCoordinatorCallbacks {
  const InteractiveDrawCoordinatorCallbacks({
    required this.onOverlayStateChanged,
    required this.emitAction,
    required this.commitDrawStroke,
    required this.commitDrawLineFromWorldSegment,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.commitEraseNodes,
  });

  final Object onOverlayStateChanged;
  final Object emitAction;
  final Object commitDrawStroke;
  final Object commitDrawLineFromWorldSegment;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(
    SceneHitTestSpatialCandidate candidate, {
    Object? snapshotOverride,
  })
  resolveSpatialCandidateSnapshot;
  final Object commitEraseNodes;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveDrawCoordinatorCallbacks.'
                'resolveSpatialCandidateSnapshot" must keep the exact sealed '
                'signature',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects missing interactive committed read callback owner class',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
          '''
class InteractiveDrawEraserEngine {}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback owner '
                '"InteractiveDrawEraserEngineCallbacks" is required in '
                'internal/interactive_draw_eraser_engine.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects missing interactive committed read callback file', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      final missingFile = File(
        '${sandbox.path}/lib/src/interactive/internal/'
        'interactive_draw_eraser_targets.dart',
      );
      missingFile.deleteSync();
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'committed read callback file '
              'internal/interactive_draw_eraser_targets.dart is required '
              'for "InteractiveDrawEraserTargetsCallbacks"',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects when all interactive committed read callback files are missing',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        for (final relativePath in const <String>[
          'lib/src/interactive/internal/interactive_runtime_callbacks.dart',
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          'lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart',
          'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
          'lib/src/interactive/internal/interactive_draw_eraser_targets.dart',
        ]) {
          final file = File('${sandbox.path}/$relativePath');
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback files are required for the '
                'interactive committed read surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive callback constructor parameter outside sealed surface',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          '''
import '../../contract/snapshot.dart';
import '../../core/scene_node.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
    required SceneNode leakedNode,
  });

  final Object onPublicStateChanged;
  final Object onSceneStateChanged;
  final Object onOverlayStateChanged;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object emitAction;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback constructor for '
                '"InteractiveMoveSessionCallbacks" must not expose live '
                'runtime scene-graph types (SceneNode)',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}

void _registerInteractiveDisposeGuardTests() {
  test(
    'rejects dispose without allowAfterDispose true in purity guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void dispose() {
    _ensurePublicSideEffectAllowed('dispose');
  }
''',
          ),
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
}

void _registerInteractiveArchitectureGuardrailTests() {
  // INV:INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY
  test('accepts final interactive boundary shape', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'accepts facade-to-view runtime bridge with render-state-only view surface',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects facade that skips canonical createSceneControllerGraph assembly',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';

class SceneController {
  SceneController() : _graph = Object();

  final dynamic _graph;

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
                'SceneController must remain a thin facade over '
                'the assembled controller graph',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects facade that routes graph assembly through local createSceneControllerGraph shadow',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';

class SceneController {
  final dynamic _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

Object createSceneControllerGraph(Object request) => Object();

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
                'SceneController must remain a thin facade over '
                'the assembled controller graph',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects facade that builds graph with local SceneControllerGraphRequest shadow',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';

class SceneController {
  final dynamic _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

class SceneControllerGraphRequest {}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
                'SceneController must remain a thin facade over '
                'the assembled controller graph',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects facade that routes graph assembly through imported shadow owners',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_graph_shadow.dart',
          '''
class SceneControllerGraphRequest {}

Object createSceneControllerGraph(Object request) => Object();
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';
import 'internal/scene_controller_graph_shadow.dart' as shadow;

class SceneController {
  final dynamic _graph = shadow.createSceneControllerGraph(
    shadow.SceneControllerGraphRequest(),
  );

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
                'SceneController must remain a thin facade over '
                'the assembled controller graph',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects graph assembly that declares local owner shadows', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_graph.dart',
        '''
import 'scene_controller_internal_access.dart';
import 'scene_controller_scene_view_runtime.dart';

class SceneControllerInteractionOwner {}

class SceneControllerSelectionOwner {
  SceneControllerSelectionOwner(Object runtime);
}

class SceneControllerSceneOwner {
  SceneControllerSceneOwner(Object ensurePublicSideEffectAllowed);
}

class SceneControllerGraphRequest {}

class SceneControllerSceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });
}

class _InteractionRuntime {
  void ensurePublicSideEffectAllowed(String operation) {}
}

class _Graph {
  _Graph({
    required this.sceneViewRuntime,
    required this.internalAccessRegistration,
  });

  final SceneControllerSceneViewRuntime sceneViewRuntime;
  final SceneControllerInternalAccessRegistration internalAccessRegistration;
}

Object createSceneControllerGraph(Object request) {
  final graph = _assembleSceneControllerGraph(request);
  registerSceneControllerInternalAccess(Object(), graph.internalAccessRegistration);
  return graph;
}

_Graph _assembleSceneControllerGraph(Object request) {
  final interactionRuntime = _InteractionRuntime();
  final interaction = SceneControllerInteractionOwner();
  final selection = SceneControllerSelectionOwner(interactionRuntime);
  final scene = SceneControllerSceneOwner(
    interactionRuntime.ensurePublicSideEffectAllowed,
  );
  interaction.toString();
  selection.toString();
  scene.toString();
  return _Graph(
    sceneViewRuntime: SceneControllerSceneViewRuntime(
      ensurePublicSideEffectAllowed:
          interactionRuntime.ensurePublicSideEffectAllowed,
    ),
    internalAccessRegistration: SceneControllerInternalAccessRegistration(),
  );
}

Object sceneControllerGraphActions(Object graph) => Object();

Object sceneControllerGraphEditTextRequests(Object graph) => Object();
''',
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneController graph must assemble view runtime and '
              'internal access outside the facade',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects facade when SceneController becomes SceneViewRenderState',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';

class SceneController implements SceneViewRenderState {
  SceneController() {
    _graph = createSceneControllerGraph(SceneControllerGraphRequest());
  }

  late final dynamic _graph;

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
                'SceneController must remain a thin facade over '
                'the assembled controller graph',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime host that stops owning replacement pointer-session creation',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_runtime_host.dart',
          '''
class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  Object build() {
    final renderState = _activeRuntime.renderState;
    return SceneViewRenderSurface(renderState: renderState);
  }
}

class StatefulWidget {}

class SceneViewRuntime {
  Object get renderState => Object();

  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    return SceneViewPointerSession();
  }
}

class SceneViewPointerSession {}

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({required SceneViewPointerSession pointerSession});
}

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required Object renderState,
  });
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
                'SceneViewRuntimeHost must remain the active-runtime and '
                'pointer-host owner for the view boundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime host that depends on concrete SceneController',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_runtime_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import '../interactive/scene_controller.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;
  final SceneController controller;

  SceneViewRuntimeHost({
    required this.runtime,
    required this.controller,
  });
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
  }

  Object build() {
    final renderState = widget.controller;
    return SceneViewRenderSurface(renderState: renderState);
  }

  SceneViewPointerSession _createReplacementPointerSession(
    SceneViewRuntime runtime,
  ) {
    return runtime.createPointerSession(
      isMounted: () => true,
      hasLiveRawPointers: () => false,
    );
  }
}

class StatefulWidget {}

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  });

  void replacePointerSession(SceneViewPointerSession session) {}
}

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required Object renderState,
  });
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
                'SceneViewRuntimeHost must remain the active-runtime and '
                'pointer-host owner for the view boundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime host that keeps replacement swap on stale runtime',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_runtime_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    final nextPointerSession = _createReplacementPointerSession(_activeRuntime);
    _pointerHost.replacePointerSession(nextPointerSession);
  }

  Object build() {
    final renderState = _activeRuntime.renderState;
    return SceneViewRenderSurface(renderState: renderState);
  }

  SceneViewPointerSession _createReplacementPointerSession(
    SceneViewRuntime runtime,
  ) {
    return runtime.createPointerSession(
      isMounted: () => true,
      hasLiveRawPointers: () => false,
    );
  }
}

class StatefulWidget {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneViewRuntimeHost must remain the active-runtime and '
                'pointer-host owner for the view boundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime host that creates replacement session before runtime equality short circuit',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_runtime_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
  }

  Object build() {
    final renderState = _activeRuntime.renderState;
    return SceneViewRenderSurface(renderState: renderState);
  }

  SceneViewPointerSession _createReplacementPointerSession(
    SceneViewRuntime runtime,
  ) {
    return runtime.createPointerSession(
      isMounted: () => true,
      hasLiveRawPointers: () => false,
    );
  }
}

class StatefulWidget {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneViewRuntimeHost must remain the active-runtime and '
                'pointer-host owner for the view boundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime host that prefetched replacement session before equality short circuit under another local name',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_runtime_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    final prefetched = _createReplacementPointerSession(widget.runtime);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
    prefetched.dispose();
  }

  Object build() {
    final renderState = _activeRuntime.renderState;
    return SceneViewRenderSurface(renderState: renderState);
  }

  SceneViewPointerSession _createReplacementPointerSession(
    SceneViewRuntime runtime,
  ) {
    return runtime.createPointerSession(
      isMounted: () => true,
      hasLiveRawPointers: () => false,
    );
  }
}

class StatefulWidget {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneViewRuntimeHost must remain the active-runtime and '
                'pointer-host owner for the view boundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime host that renders SceneViewRenderSurface from non-active runtime render state',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_runtime_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;
  late SceneViewRuntime _staleRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _staleRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
  }

  Object build() {
    final renderState = _staleRuntime.renderState;
    return SceneViewRenderSurface(renderState: renderState);
  }

  SceneViewPointerSession _createReplacementPointerSession(
    SceneViewRuntime runtime,
  ) {
    return runtime.createPointerSession(
      isMounted: () => true,
      hasLiveRawPointers: () => false,
    );
  }
}

class StatefulWidget {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneViewRuntimeHost must remain the active-runtime and '
                'pointer-host owner for the view boundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime host that switches active runtime before pointer-session swap',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_runtime_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _activeRuntime = widget.runtime;
    _pointerHost.replacePointerSession(nextPointerSession);
  }

  Object build() {
    final renderState = _activeRuntime.renderState;
    return SceneViewRenderSurface(renderState: renderState);
  }

  SceneViewPointerSession _createReplacementPointerSession(
    SceneViewRuntime runtime,
  ) {
    return runtime.createPointerSession(
      isMounted: () => true,
      hasLiveRawPointers: () => false,
    );
  }
}

class StatefulWidget {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneViewRuntimeHost must remain the active-runtime and '
                'pointer-host owner for the view boundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime host that declares local pointer host shadow',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_runtime_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
  }

  Object build() {
    final renderState = _activeRuntime.renderState;
    return SceneViewRenderSurface(renderState: renderState);
  }

  SceneViewPointerSession _createReplacementPointerSession(
    SceneViewRuntime runtime,
  ) {
    return runtime.createPointerSession(
      isMounted: () => true,
      hasLiveRawPointers: () => false,
    );
  }
}

class StatefulWidget {}

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  });

  void replacePointerSession(SceneViewPointerSession session) {}
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
                'SceneViewRuntimeHost must remain the active-runtime and '
                'pointer-host owner for the view boundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects pointer host that installs next session before releasing current',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive_pointer_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_pointer_router.dart';

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  }) : _runtime = _SceneViewInteractivePointerRuntime(
         pointerSession: pointerSession,
       );

  final _SceneViewInteractivePointerRuntime _runtime;

  int get debugLiveRawPointerCount => _runtime.debugLiveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _runtime.debugPendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession pointerSession) {
    _runtime.replacePointerSession(pointerSession);
  }

  void dispose() {
    _runtime.dispose();
  }
}

class _SceneViewInteractivePointerRuntime {
  _SceneViewInteractivePointerRuntime({
    required SceneViewPointerSession pointerSession,
  }) : _pointerSession = pointerSession;

  final SceneViewPointerRouter _pointerRouter = SceneViewPointerRouter();
  SceneViewPointerSession _pointerSession;

  int get debugLiveRawPointerCount => 0;
  int? get debugPendingTapFlushTimestampMs =>
      _pointerSession.pendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession next) {
    final current = _pointerSession;
    _pointerSession = next;
    current.detach();
    current.dispose();
    _pointerRouter.reset();
  }

  void dispose() {
    _pointerSession.detach();
    _pointerSession.dispose();
  }
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
                'SceneViewInteractivePointerHost must remain a raw '
                'routing/lifecycle shell over pointer sessions',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects pointer host that installs a non-next session after releasing current',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive_pointer_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_pointer_router.dart';

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  }) : _runtime = _SceneViewInteractivePointerRuntime(
         pointerSession: pointerSession,
       );

  final _SceneViewInteractivePointerRuntime _runtime;

  int get debugLiveRawPointerCount => _runtime.debugLiveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _runtime.debugPendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession pointerSession) {
    _runtime.replacePointerSession(pointerSession);
  }

  void dispose() {
    _runtime.dispose();
  }
}

class _SceneViewInteractivePointerRuntime {
  _SceneViewInteractivePointerRuntime({
    required SceneViewPointerSession pointerSession,
  }) : _pointerSession = pointerSession;

  final SceneViewPointerRouter _pointerRouter = SceneViewPointerRouter();
  final SceneViewPointerSession _sentinel = _DisposedSceneViewPointerSession();
  SceneViewPointerSession _pointerSession;

  int get debugLiveRawPointerCount => 0;
  int? get debugPendingTapFlushTimestampMs =>
      _pointerSession.pendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession next) {
    final current = _pointerSession;
    current.detach();
    current.dispose();
    _pointerRouter.reset();
    _pointerSession = _sentinel;
  }

  void dispose() {
    _pointerSession.detach();
    _pointerSession.dispose();
  }
}

class _DisposedSceneViewPointerSession implements SceneViewPointerSession {
  @override
  int? get pendingTapFlushTimestampMs => null;

  @override
  void detach() {}

  @override
  void dispose() {}

  @override
  void handleInvalidTerminalSample({
    required Object input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {}

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {}

  @override
  void handleRoutedSample(Object sample, {required bool shouldTrackSignals}) {}
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
                'SceneViewInteractivePointerHost must remain a raw '
                'routing/lifecycle shell over pointer sessions',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects pointer host that overwrites next session after canonical install',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive_pointer_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_pointer_router.dart';

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  }) : _runtime = _SceneViewInteractivePointerRuntime(
         pointerSession: pointerSession,
       );

  final _SceneViewInteractivePointerRuntime _runtime;

  int get debugLiveRawPointerCount => _runtime.debugLiveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _runtime.debugPendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession pointerSession) {
    _runtime.replacePointerSession(pointerSession);
  }

  void dispose() {
    _runtime.dispose();
  }
}

class _SceneViewInteractivePointerRuntime {
  _SceneViewInteractivePointerRuntime({
    required SceneViewPointerSession pointerSession,
  }) : _pointerSession = pointerSession;

  final SceneViewPointerRouter _pointerRouter = SceneViewPointerRouter();
  final SceneViewPointerSession _sentinel = _DisposedSceneViewPointerSession();
  SceneViewPointerSession _pointerSession;

  int get debugLiveRawPointerCount => 0;
  int? get debugPendingTapFlushTimestampMs =>
      _pointerSession.pendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession next) {
    final current = _pointerSession;
    current.detach();
    current.dispose();
    _pointerRouter.reset();
    _pointerSession = next;
    _pointerSession = _sentinel;
  }

  void dispose() {
    _pointerSession.detach();
    _pointerSession.dispose();
  }
}

class _DisposedSceneViewPointerSession implements SceneViewPointerSession {
  @override
  int? get pendingTapFlushTimestampMs => null;

  @override
  void detach() {}

  @override
  void dispose() {}

  @override
  void handleInvalidTerminalSample({
    required Object input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {}

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {}

  @override
  void handleRoutedSample(Object sample, {required bool shouldTrackSignals}) {}
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
                'SceneViewInteractivePointerHost must remain a raw '
                'routing/lifecycle shell over pointer sessions',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'accepts runtime host render-state bridge routed through owner-local getter',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_runtime_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  SceneViewRenderState get _renderStateForBuild => _activeRuntime.renderState;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
  }

  Object build() {
    return SceneViewRenderSurface(renderState: _renderStateForBuild);
  }

  SceneViewPointerSession _createReplacementPointerSession(
    SceneViewRuntime runtime,
  ) {
    return runtime.createPointerSession(
      isMounted: () => true,
      hasLiveRawPointers: () => false,
    );
  }
}

class StatefulWidget {}
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
    'rejects SceneViewInteractive bridge routed through local runtime host shadow',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive.dart',
          '''
import '../interactive/scene_controller.dart';
import 'scene_view_runtime_host.dart';

class SceneViewInteractive {
  SceneViewInteractive({required this.controller});

  final SceneController controller;

  Object build(Object context) {
    return SceneViewRuntimeHost(
      runtime: sceneControllerViewRuntimeOf(controller),
    );
  }
}

class SceneViewRuntimeHost {
  SceneViewRuntimeHost({required Object runtime});
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
                'SceneViewInteractive must remain a thin public shell over '
                'SceneViewRuntimeHost',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'accepts SceneViewInteractive bridge routed through owner-local getter',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive.dart',
          '''
import '../contract/scene_view_runtime.dart';
import '../interactive/scene_controller.dart';
import 'scene_view_runtime_host.dart';

class SceneViewInteractive {
  SceneViewInteractive({required this.controller});

  final SceneController controller;

  SceneViewRuntime get _runtime => sceneControllerViewRuntimeOf(controller);

  Object build(Object context) {
    return SceneViewRuntimeHost(runtime: _runtime);
  }
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
    'rejects render surface that takes concrete SceneController owner',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_render_surface.dart',
          '''
import '../contract/scene_view_runtime.dart';
import '../interactive/scene_controller.dart';

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required SceneController renderState,
  }) : _renderState = renderState;

  final SceneController _renderState;

  State<SceneViewRenderSurface> createState() => SceneViewRenderSurfaceState();
}

class SceneViewRenderSurfaceState extends State<SceneViewRenderSurface> {
  void initState() {
    widget._renderState.addListener(_handleControllerChanged);
  }

  void didUpdateWidget(SceneViewRenderSurface oldWidget) {
    oldWidget._renderState.removeListener(_handleControllerChanged);
    widget._renderState.addListener(_handleControllerChanged);
  }

  void dispose() {
    widget._renderState.removeListener(_handleControllerChanged);
  }

  Object build(Object context) => Object();

  void _handleControllerChanged() {}
}

class State<T> {
  T get widget => throw UnimplementedError();
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
                'SceneViewRenderSurface must remain a render-state-only view '
                'surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects render surface that shadows the SceneViewRenderState contract locally',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_render_surface.dart',
          '''
import '../contract/scene_view_runtime.dart';

class SceneViewRenderState {
  void addListener(Object listener) {}

  void removeListener(Object listener) {}
}

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required SceneViewRenderState renderState,
  }) : _renderState = renderState;

  final SceneViewRenderState _renderState;

  State<SceneViewRenderSurface> createState() => SceneViewRenderSurfaceState();
}

class SceneViewRenderSurfaceState extends State<SceneViewRenderSurface> {
  void initState() {
    widget._renderState.addListener(_handleControllerChanged);
  }

  void didUpdateWidget(SceneViewRenderSurface oldWidget) {
    oldWidget._renderState.removeListener(_handleControllerChanged);
    widget._renderState.addListener(_handleControllerChanged);
  }

  void dispose() {
    widget._renderState.removeListener(_handleControllerChanged);
  }

  Object build(Object context) => Object();

  void _handleControllerChanged() {}
}

class State<T> {
  T get widget => throw UnimplementedError();
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
                'SceneViewRenderSurface must remain a render-state-only view '
                'surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects render surface that subscribes listeners outside widget renderState',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_render_surface.dart',
          '''
import '../contract/scene_view_runtime.dart';

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required SceneViewRenderState renderState,
  }) : _renderState = renderState;

  final SceneViewRenderState _renderState;
  final SceneViewRenderState _otherRenderState = SceneControllerSceneViewRenderState();
}

class SceneViewRenderSurfaceState extends State<SceneViewRenderSurface> {
  void initState() {
    super.initState();
    widget._otherRenderState.addListener(_handleControllerChanged);
  }

  void didUpdateWidget(SceneViewRenderSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget._otherRenderState.removeListener(_handleControllerChanged);
    widget._otherRenderState.addListener(_handleControllerChanged);
  }

  void dispose() {
    widget._otherRenderState.removeListener(_handleControllerChanged);
  }

  Object build(Object context) => Object();

  void _handleControllerChanged() {}
}

class SceneControllerSceneViewRenderState implements SceneViewRenderState {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
}

class State<T> {
  T get widget => throw UnimplementedError();
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
                'SceneViewRenderSurface must remain a render-state-only '
                'view surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene view runtime that shadows SceneControllerPointerSession locally',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
          '''
import '../../contract/scene_view_runtime.dart';
import 'scene_controller_pointer_session.dart';
import 'pointer_session_token.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });

  @override
  final renderState = SceneControllerSceneViewRenderState();
  final _interactionRuntime = SceneControllerInteractionRuntime();

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    return SceneControllerPointerSession(
      token: _interactionRuntime.createPointerSessionToken(),
      detachPointerSession: _interactionRuntime.detachPointerSession,
      releasePointerSessionToken: _interactionRuntime.releasePointerSessionToken,
      handlePointerFromSession: _interactionRuntime.handlePointerFromSession,
      handleDoubleTapFromSession:
          _interactionRuntime.handleDoubleTapFromSession,
    );
  }
}

class SceneControllerPointerSession implements SceneViewPointerSession {
  SceneControllerPointerSession({
    required Object token,
    required Object detachPointerSession,
    required Object releasePointerSessionToken,
    required Object handlePointerFromSession,
    required Object handleDoubleTapFromSession,
  });
}

class SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(Object token) {}

  void releasePointerSessionToken(Object token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}
}

class SceneControllerSceneViewRenderState implements SceneViewRenderState {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
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
                'SceneControllerSceneViewRuntime must own the render-state '
                'adapter and pointer-session factory',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene view runtime that mints pointer-session tokens outside interaction runtime',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
          '''
import '../../contract/scene_view_runtime.dart';
import 'scene_controller_pointer_session.dart';
import 'pointer_session_token.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });

  @override
  final renderState = SceneControllerSceneViewRenderState();
  final _interactionRuntime = SceneControllerInteractionRuntime();

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    return SceneControllerPointerSession(
      token: PointerSessionToken(),
      detachPointerSession: _interactionRuntime.detachPointerSession,
      releasePointerSessionToken: _interactionRuntime.releasePointerSessionToken,
      handlePointerFromSession: _interactionRuntime.handlePointerFromSession,
      handleDoubleTapFromSession:
          _interactionRuntime.handleDoubleTapFromSession,
    );
  }
}

class SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(Object token) {}

  void releasePointerSessionToken(Object token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}
}

class SceneControllerSceneViewRenderState implements SceneViewRenderState {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
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
                'SceneControllerSceneViewRuntime must own the render-state '
                'adapter and pointer-session factory',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene view runtime that routes pointer-session callbacks through local wrappers',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
          '''
import '../../contract/scene_view_runtime.dart';
import 'scene_controller_pointer_session.dart';
import 'pointer_session_token.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });

  @override
  final renderState = SceneControllerSceneViewRenderState();
  final _interactionRuntime = SceneControllerInteractionRuntime();

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    return SceneControllerPointerSession(
      token: _interactionRuntime.createPointerSessionToken(),
      detachPointerSession: detachPointerSession,
      releasePointerSessionToken: releasePointerSessionToken,
      handlePointerFromSession: handlePointerFromSession,
      handleDoubleTapFromSession: handleDoubleTapFromSession,
    );
  }

  void detachPointerSession(Object token) {}

  void releasePointerSessionToken(Object token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}
}

class SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(Object token) {}

  void releasePointerSessionToken(Object token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}
}

class SceneControllerSceneViewRenderState implements SceneViewRenderState {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
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
                'SceneControllerSceneViewRuntime must own the render-state '
                'adapter and pointer-session factory',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects pointer session that routes through public interaction facade',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_pointer_session.dart',
          '''
class SceneControllerInteraction {}
class PointerInputTracker {}
class PointerSessionToken {}

class SceneControllerPointerSession {
  final _ownerListenable = _OwnerListenable();
  final _PendingTapFlushScheduler scheduler = _PendingTapFlushScheduler();
  final SceneControllerInteraction _readInteraction = SceneControllerInteraction();

  void createTracker() {
    PointerInputTracker();
  }

  void attach() {
    _ownerListenable.addListener(Object());
    _readInteraction.runtimeType;
  }
}

class _PendingTapFlushScheduler {}

class _OwnerListenable {
  void addListener(Object listener) {}
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
                'pointer session must stay owned by SceneControllerPointerSession',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive runtime that keeps pre-split pointer boundary names',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_runtime.dart',
          '''
import '../contract/canvas_pointer_input.dart';
import 'pointer_session_token.dart';
import 'interactive_draw_coordinator.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_gesture_router.dart';
import 'interactive_double_tap_router.dart';

class InteractiveRuntime {
  void handlePointer(CanvasPointerInput input) {}

  void handleDoubleTap({required Object position, int? timestampMs}) {}
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
                'InteractiveRuntime must keep event timeline and draw-local geometry outside the boundary runtime',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects retained scene access seam', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_scene_access.dart',
        'class SceneControllerSceneAccessAdapter {}\n',
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneControllerSceneAccessAdapter is a deleted residual seam '
              'and must not exist',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects interaction snapshot leak', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller_interaction.dart',
        '''
import '../contract/snapshot.dart';

abstract interface class SceneControllerInteraction {
  SceneSnapshot get snapshot;
}

class SceneControllerInteractionOwner implements SceneControllerInteraction {
  final _access = _Access();

  @override
  SceneSnapshot get snapshot => _access.snapshot;
}

class _Access {
  SceneSnapshot get snapshot => throw UnimplementedError();
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
              'SceneControllerInteraction must not expose committed '
              'render-state through snapshot',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects facade that directly imports draw-local owner', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          extraImports: "import 'internal/interactive_draw_coordinator.dart';",
          extraMembers:
              '\n  final InteractiveDrawCoordinator _drawCoordinator =\n'
              '      InteractiveDrawCoordinator();\n',
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneController must remain a thin facade over '
              'the assembled controller graph',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects scene mutation owner store controller write bypass outside mutation boundary',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          '''
class SceneControllerSceneMutations {
  final mutations = Object();

  void write(Object fn) {
    ensureExternalMutationAllowed('write');
    storeController.write(fn);
  }

  void setBackgroundColor(Object value) {
    ensureExternalMutationAllowed('setBackgroundColor');
    mutations.toString();
  }

  void setGridEnabled(bool value) {
    ensureExternalMutationAllowed('setGridEnabled');
    mutations.toString();
  }

  void setGridCellSize(double value) {
    ensureExternalMutationAllowed('setGridCellSize');
    mutations.toString();
  }

  void addNode(Object node) {
    ensureExternalMutationAllowed('addNode');
    mutations.toString();
  }

  void ensureLayer(Object layerId) {
    ensureExternalMutationAllowed('ensureLayer');
    mutations.toString();
  }

  void patchNode(Object patch) {
    ensureExternalMutationAllowed('patchNode');
    mutations.toString();
  }

  void removeNode(Object nodeId) {
    ensureExternalMutationAllowed('removeNode');
    mutations.toString();
  }

  void clearScene() {
    ensureExternalMutationAllowed('clearScene');
    mutations.toString();
  }

  void setCameraOffset(Object value) {
    mutations.validateCameraOffset(value);
    if (!mutations.shouldApplyCameraOffset(value)) {
      return;
    }
    interruptForExternalMutation();
    mutations.setCameraOffset(value);
  }

  void replaceScene(Object snapshot) {
    mutations.replaceScene(
      snapshot,
      interruptBeforeApply: interruptForExternalMutation,
    );
  }

  void notifySceneChanged() {
    mutations.toString();
  }

  final void Function(String operation) ensureExternalMutationAllowed =
      (String operation) {};

  final void Function() interruptForExternalMutation = () {};

  final storeController = _StoreController();
}

class _StoreController {
  void write(Object fn) {}
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
                'SceneControllerSceneMutations must delegate committed scene '
                'writes through SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects scene mutation owner generic core write bypass', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
        '''
class SceneControllerSceneMutations {
  final mutations = Object();

  void write(Object fn) {
    ensureExternalMutationAllowed('write');
    storeController.write<int>(fn);
  }

  void setBackgroundColor(Object value) {
    ensureExternalMutationAllowed('setBackgroundColor');
    mutations.toString();
  }

  void setGridEnabled(bool value) {
    ensureExternalMutationAllowed('setGridEnabled');
    mutations.toString();
  }

  void setGridCellSize(double value) {
    ensureExternalMutationAllowed('setGridCellSize');
    mutations.toString();
  }

  void addNode(Object node) {
    ensureExternalMutationAllowed('addNode');
    mutations.toString();
  }

  void ensureLayer(Object layerId) {
    ensureExternalMutationAllowed('ensureLayer');
    mutations.toString();
  }

  void patchNode(Object patch) {
    ensureExternalMutationAllowed('patchNode');
    mutations.toString();
  }

  void removeNode(Object nodeId) {
    ensureExternalMutationAllowed('removeNode');
    mutations.toString();
  }

  void clearScene() {
    ensureExternalMutationAllowed('clearScene');
    mutations.toString();
  }

  void setCameraOffset(Object value) {
    mutations.validateCameraOffset(value);
    if (!mutations.shouldApplyCameraOffset(value)) {
      return;
    }
    interruptForExternalMutation();
    mutations.setCameraOffset(value);
  }

  void replaceScene(Object snapshot) {
    mutations.replaceScene(
      snapshot,
      interruptBeforeApply: interruptForExternalMutation,
    );
  }

  void notifySceneChanged() {
    mutations.toString();
  }

  void ensureExternalMutationAllowed(String operation) {}

  void interruptForExternalMutation() {}

  final storeController = _Core();
}

class _Core {
  void write<T>(Object fn) {}
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
              'SceneControllerSceneMutations must delegate committed scene '
              'writes through SceneControllerMutationBoundary',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects selection mutation owner store controller write bypass outside mutation boundary',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_selection_mutations.dart',
          '''
class SceneControllerSelectionMutations {
  final mutations = Object();

  void setSelection(Object nodeIds) {
    ensureExternalMutationAllowed('setSelection');
    storeController.commands.writeSelectionReplace(nodeIds);
  }

  void toggleSelection(Object nodeId) {
    ensureExternalMutationAllowed('toggleSelection');
    mutations.toString();
  }

  void clearSelection() {
    ensureExternalMutationAllowed('clearSelection');
    mutations.toString();
  }

  void selectAll() {
    ensureExternalMutationAllowed('selectAll');
    mutations.toString();
  }

  void rotateSelection() {
    ensureExternalMutationAllowed('rotateSelection');
    mutations.toString();
  }

  void flipSelectionVertical() {
    ensureExternalMutationAllowed('flipSelectionVertical');
    mutations.toString();
  }

  void flipSelectionHorizontal() {
    ensureExternalMutationAllowed('flipSelectionHorizontal');
    mutations.toString();
  }

  void deleteSelection() {
    ensureExternalMutationAllowed('deleteSelection');
    mutations.toString();
  }

  void ensureExternalMutationAllowed(String operation) {}

  final storeController = _StoreController();
}

class _StoreController {
  final commands = _Commands();
}

class _Commands {
  void writeSelectionReplace(Object nodeIds) {}
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
                'SceneControllerSelectionMutations must delegate committed '
                'selection writes through SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects selection actions core write bypass outside mutation boundary',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_selection_actions.dart',
          '''
class InteractiveSelectionActions {
  void rotateSelection() {
    core.write('rotateSelection');
  }

  final core = _Core();
}

class _Core {
  void write(Object operation) {}
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
                'InteractiveSelectionActions must remain a thin routing shell '
                'over SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime selection callbacks that bypass mutation boundary',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
          '''
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

class SceneControllerInteractionRuntime {
  void ensurePublicSideEffectAllowed(String operation) {}

  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}

  void wireRuntime(Object request, Object mutationBoundary) {
    request.storeController.commands.writeSelectionReplace;
    request.storeController.draw.writeDrawStroke;
  }
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
                'SceneControllerInteractionRuntime must route committed '
                'selection/draw callbacks through '
                'SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime assembly without canonical mutation boundary routing',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
          '''
import 'dart:ui';

import '../contract/canvas_pointer_input.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import 'interactive_selection_actions.dart';
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

class SceneControllerInteractionRuntimeRequest {
  SceneControllerInteractionRuntimeRequest({
    required this.mutationAccess,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;
}

class SceneControllerInteractionRuntime {
  SceneControllerInteractionRuntime._({
    required this.mutationBoundary,
    required this.selectionActions,
    required this.runtime,
  });

  final SceneControllerMutationBoundary mutationBoundary;
  final InteractiveSelectionActions selectionActions;
  final InteractiveRuntime runtime;

  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}

  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {}

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {}

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {}
}

class InteractiveRuntime {
  InteractiveRuntime({required Object callbacks});
}

SceneControllerInteractionRuntime createSceneControllerInteractionRuntime({
  required SceneControllerInteractionRuntimeRequest request,
}) {
  final mutationBoundary = _createMutationBoundary(request);
  final selectionActions = _createSelectionActions(mutationBoundary);
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    mutationBoundary: mutationBoundary,
  );
  return SceneControllerInteractionRuntime._(
    mutationBoundary: mutationBoundary,
    selectionActions: selectionActions,
    runtime: interactiveRuntime,
  );
}

SceneControllerMutationBoundary _createMutationBoundary(
  SceneControllerInteractionRuntimeRequest request,
) {
  return SceneControllerMutationBoundary(
    mutationAccess: request.mutationAccess,
  );
}

InteractiveSelectionActions _createSelectionActions(
  SceneControllerMutationBoundary mutationBoundary,
) {
  return InteractiveSelectionActions(mutations: mutationBoundary);
}

InteractiveRuntime _createInteractiveRuntime(
  SceneControllerInteractionRuntimeRequest request, {
  required SceneControllerMutationBoundary mutationBoundary,
}) {
  return InteractiveRuntime(
    callbacks: Object(),
  );
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
                'SceneControllerInteractionRuntime must route committed '
                'selection/draw callbacks through '
                'SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects mutation boundary concrete SceneStoreController seam', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_mutation_boundary.dart',
        '''
import '../../controller/scene_store_controller.dart';

class SceneControllerMutationBoundary {
  SceneControllerMutationBoundary(this.storeController);

  final SceneStoreController storeController;

  void clearScene() {
    storeController.commands.writeClearSceneExactResult();
  }
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
              'SceneControllerMutationBoundary must remain the canonical '
              'scene/selection write owner',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects mutation boundary generic store controller write bypass',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_mutation_boundary.dart',
          '''
class SceneControllerMutationBoundary {
  final storeController = _Core();

  void clearScene() {
    storeController.write<void>((writer) {});
  }

  void setSelection(Object nodeIds) {
    storeController.commands.writeSelectionReplace(nodeIds);
  }

  void clearSelection() {
    storeController.commands.writeSelectionClear();
  }

  void deleteSelection() {
    storeController.commands.writeDeleteSelection();
  }

  void transformSelection(Object delta) {
    storeController.commands.writeSelectionTransform(delta);
  }

  Object prepareSceneReplacement(Object snapshot) {
    return storeController.prepareSceneReplacement(snapshot);
  }

  void replaceScene(Object snapshot) {
    final replacement = storeController.prepareSceneReplacement(snapshot);
    storeController.writePreparedSceneReplacement(replacement);
  }

  Object commitMoveSelection(Object proposedDelta) => proposedDelta;

  Object commitDrawStroke(Object payload) {
    return storeController.draw.writeDrawStroke(payload);
  }

  Object commitDrawLineFromWorldSegment(Object payload) {
    return storeController.draw.writeDrawLineFromWorldSegment(payload);
  }

  int commitEraseNodes(Object ids) {
    return storeController.draw.writeEraseNodes(ids);
  }
}

class _Core {
  final commands = _Commands();
  final draw = _Draw();

  void write<T>(Object fn) {}

  Object prepareSceneReplacement(Object snapshot) => snapshot;

  void writePreparedSceneReplacement(Object replacement) {}
}

class _Commands {
  void writeSelectionReplace(Object nodeIds) {}

  void writeSelectionClear() {}

  void writeDeleteSelection() {}

  void writeSelectionTransform(Object delta) {}
}

class _Draw {
  Object writeDrawStroke(Object payload) => payload;

  Object writeDrawLineFromWorldSegment(Object payload) => payload;

  int writeEraseNodes(Object ids) => 0;
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
                'SceneControllerMutationBoundary must remain the canonical '
                'scene/selection write owner',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects mutation boundary clearScene store controller write bypass with return value',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_mutation_boundary.dart',
          '''
class SceneControllerMutationBoundary {
  final storeController = _Core();

  bool clearScene() {
    return storeController.write<bool>((writer) => true);
  }

  void setSelection(Object nodeIds) {
    storeController.commands.writeSelectionReplace(nodeIds);
  }

  void clearSelection() {
    storeController.commands.writeSelectionClear();
  }

  void deleteSelection() {
    storeController.commands.writeDeleteSelection();
  }

  void transformSelection(Object delta) {
    storeController.commands.writeSelectionTransform(delta);
  }

  Object prepareSceneReplacement(Object snapshot) {
    return storeController.prepareSceneReplacement(snapshot);
  }

  void replaceScene(Object snapshot) {
    final replacement = storeController.prepareSceneReplacement(snapshot);
    storeController.writePreparedSceneReplacement(replacement);
  }

  Object commitMoveSelection(Object proposedDelta) => proposedDelta;

  Object commitDrawStroke(Object payload) {
    return storeController.draw.writeDrawStroke(payload);
  }

  Object commitDrawLineFromWorldSegment(Object payload) {
    return storeController.draw.writeDrawLineFromWorldSegment(payload);
  }

  int commitEraseNodes(Object ids) {
    return storeController.draw.writeEraseNodes(ids);
  }
}

class _Core {
  final commands = _Commands();
  final draw = _Draw();

  T write<T>(Object fn) => true as T;

  Object prepareSceneReplacement(Object snapshot) => snapshot;

  void writePreparedSceneReplacement(Object replacement) {}
}

class _Commands {
  void writeSelectionReplace(Object nodeIds) {}

  void writeSelectionClear() {}

  void writeDeleteSelection() {}

  void writeSelectionTransform(Object delta) {}
}

class _Draw {
  Object writeDrawStroke(Object payload) => payload;

  Object writeDrawLineFromWorldSegment(Object payload) => payload;

  int writeEraseNodes(Object ids) => 0;
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
                'SceneControllerMutationBoundary must remain the canonical '
                'scene/selection write owner',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects runtime that re-owns event timeline state', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/interactive_runtime.dart',
        '''
import 'dart:async';

import 'interactive_draw_coordinator.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_gesture_router.dart';
import 'interactive_double_tap_router.dart';

class InteractiveRuntime {
  InteractiveRuntime({required this.events});

  final InteractiveEventDispatcher events;
  final _actions = StreamController<Object>.broadcast();
  int _timestampCursorMs = 0;

  void handlePointer(Object input) {}

  void handleDoubleTap({required Object position, int? timestampMs}) {
    events.resolveTimestampMs(timestampMs);
  }
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
              'InteractiveRuntime must keep event timeline and draw-local '
              'geometry outside the boundary runtime',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects draw coordinator that re-owns eraser geometry', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/interactive_draw_coordinator.dart',
        '''
import 'interactive_draw_eraser_engine.dart';
import 'interactive_draw_line_engine.dart';
import 'interactive_draw_stroke_engine.dart';
import 'interactive_draw_terminal_router.dart';

class InteractiveDrawCoordinator {
  bool _eraserHitsLine() => false;

  void handlePointer(Object sample) {}
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
              'InteractiveDrawCoordinator must remain a draw-family '
              'orchestrator and not re-own eraser geometry',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects eraser engine that re-owns exact-hit geometry', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
        '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawEraserEngineCallbacks {
  const InteractiveDrawEraserEngineCallbacks({
    required this.onOverlayStateChanged,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.commitEraseNodes,
  });

  final Object onOverlayStateChanged;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object commitEraseNodes;
}

class InteractiveDrawEraserEngine {
  bool _eraserHitsLine() => false;
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
              'InteractiveDrawEraserEngine must delegate exact-hit geometry '
              'to eraser-local owners',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects internal access seam that drops canonical accessor surface',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_internal_access.dart',
          '''
class SceneControllerInternalAccessRegistration {}

void registerSceneControllerInternalAccess(
  Object controller,
  Object registration,
) {}

void unregisterSceneControllerInternalAccess(Object controller) {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'internal interactive test/debug access must remain outside '
                'SceneController',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects missing required split-owner file', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      File(
        '${sandbox.path}/lib/src/interactive/internal/'
        'interactive_event_dispatcher.dart',
      ).deleteSync();

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'missing required split owner InteractiveEventDispatcher at '
              '/lib/src/interactive/internal/interactive_event_dispatcher.dart',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects SceneViewRuntime contract getter drift', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(sandbox, 'lib/src/contract/scene_view_runtime.dart', '''
abstract interface class SceneViewRuntime {
  SceneViewRenderState get renderState;

  SceneViewPointerSession get createPointerSession;
}

abstract interface class SceneViewRenderState {
  void addListener(Object listener);

  void removeListener(Object listener);
}

abstract interface class SceneViewPointerSession {
  int get detach;

  void dispose();
}
''');

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneViewRuntime must remain the single internal '
              'runtime/session contract for view core',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects runtime session callbacks without token validation', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
        '''
import 'dart:ui';

import '../contract/canvas_pointer_input.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import 'interactive_selection_actions.dart';
import 'interactive_runtime.dart';
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

final class SceneControllerInteractionRuntime {
  SceneControllerInteractionRuntime._({
    required this.mutationBoundary,
    required this.selectionActions,
    required this.runtime,
  });

  final SceneControllerMutationBoundary mutationBoundary;
  final InteractiveSelectionActions selectionActions;
  final InteractiveRuntime runtime;

  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

final class SceneControllerInteractionRuntimeRequest {
  const SceneControllerInteractionRuntimeRequest({
    required this.mutationAccess,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;
}

SceneControllerInteractionRuntime createSceneControllerInteractionRuntime({
  required SceneControllerInteractionRuntimeRequest request,
}) {
  final mutationBoundary = _createMutationBoundary(request);
  final selectionActions = _createSelectionActions(mutationBoundary);
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    mutationBoundary: mutationBoundary,
  );
  return SceneControllerInteractionRuntime._(
    mutationBoundary: mutationBoundary,
    selectionActions: selectionActions,
    runtime: interactiveRuntime,
  );
}

extension SceneControllerInteractionRuntimeMutationApi
    on SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {}

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
  }
}

SceneControllerMutationBoundary _createMutationBoundary(
  SceneControllerInteractionRuntimeRequest request,
) {
  return SceneControllerMutationBoundary(
    mutationAccess: request.mutationAccess,
  );
}

InteractiveSelectionActions _createSelectionActions(
  SceneControllerMutationBoundary mutationBoundary,
) {
  return InteractiveSelectionActions(mutations: mutationBoundary);
}

InteractiveRuntime _createInteractiveRuntime(
  SceneControllerInteractionRuntimeRequest request, {
  required SceneControllerMutationBoundary mutationBoundary,
}) {
  return InteractiveRuntime(
    callbacks: InteractiveRuntimeCallbacks(
      writeSelectionReplace: mutationBoundary.setSelection,
      writeSelectionClear: mutationBoundary.clearSelection,
      commitMoveSelection: mutationBoundary.commitMoveSelection,
      commitDrawStroke: mutationBoundary.commitDrawStroke,
      commitDrawLineFromWorldSegment:
          mutationBoundary.commitDrawLineFromWorldSegment,
      commitEraseNodes: mutationBoundary.commitEraseNodes,
    ),
  );
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
              'SceneControllerInteractionRuntime must route committed '
              'selection/draw callbacks through SceneControllerMutationBoundary',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects runtime session callbacks when an unguarded callback appears before a later guarded one',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
          '''
import 'dart:ui';

import '../contract/canvas_pointer_input.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import 'interactive_selection_actions.dart';
import 'interactive_runtime.dart';
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

final class SceneControllerInteractionRuntime {
  SceneControllerInteractionRuntime._({
    required this.mutationBoundary,
    required this.selectionActions,
    required this.runtime,
  });

  final SceneControllerMutationBoundary mutationBoundary;
  final InteractiveSelectionActions selectionActions;
  final InteractiveRuntime runtime;

  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}

  void _ensureKnownPointerSessionToken(PointerSessionToken token) {}
}

final class SceneControllerInteractionRuntimeRequest {
  const SceneControllerInteractionRuntimeRequest({
    required this.mutationAccess,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;
}

SceneControllerInteractionRuntime createSceneControllerInteractionRuntime({
  required SceneControllerInteractionRuntimeRequest request,
}) {
  final mutationBoundary = _createMutationBoundary(request);
  final selectionActions = _createSelectionActions(mutationBoundary);
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    mutationBoundary: mutationBoundary,
  );
  return SceneControllerInteractionRuntime._(
    mutationBoundary: mutationBoundary,
    selectionActions: selectionActions,
    runtime: interactiveRuntime,
  );
}

extension SceneControllerInteractionRuntimeMutationApi
    on SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {}

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {
    runtime.handlePointerFromSession(input, token: token);
    _ensureKnownPointerSessionToken(token);
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
    _ensureKnownPointerSessionToken(token);
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
  }
}

SceneControllerMutationBoundary _createMutationBoundary(
  SceneControllerInteractionRuntimeRequest request,
) {
  return SceneControllerMutationBoundary(
    mutationAccess: request.mutationAccess,
  );
}

InteractiveSelectionActions _createSelectionActions(
  SceneControllerMutationBoundary mutationBoundary,
) {
  return InteractiveSelectionActions(mutations: mutationBoundary);
}

InteractiveRuntime _createInteractiveRuntime(
  SceneControllerInteractionRuntimeRequest request, {
  required SceneControllerMutationBoundary mutationBoundary,
}) {
  return InteractiveRuntime(
    callbacks: InteractiveRuntimeCallbacks(
      writeSelectionReplace: mutationBoundary.setSelection,
      writeSelectionClear: mutationBoundary.clearSelection,
      commitMoveSelection: mutationBoundary.commitMoveSelection,
      commitDrawStroke: mutationBoundary.commitDrawStroke,
      commitDrawLineFromWorldSegment:
          mutationBoundary.commitDrawLineFromWorldSegment,
      commitEraseNodes: mutationBoundary.commitEraseNodes,
    ),
  );
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
                'SceneControllerInteractionRuntime must route committed '
                'selection/draw callbacks through SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime session callbacks when an unguarded callback appears after a guarded one',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
          '''
import 'dart:ui';

import '../contract/canvas_pointer_input.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import 'interactive_selection_actions.dart';
import 'interactive_runtime.dart';
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

final class SceneControllerInteractionRuntime {
  SceneControllerInteractionRuntime._({
    required this.mutationBoundary,
    required this.selectionActions,
    required this.runtime,
  });

  final SceneControllerMutationBoundary mutationBoundary;
  final InteractiveSelectionActions selectionActions;
  final InteractiveRuntime runtime;

  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}

  void _ensureKnownPointerSessionToken(PointerSessionToken token) {}
}

final class SceneControllerInteractionRuntimeRequest {
  const SceneControllerInteractionRuntimeRequest({
    required this.mutationAccess,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;
}

SceneControllerInteractionRuntime createSceneControllerInteractionRuntime({
  required SceneControllerInteractionRuntimeRequest request,
}) {
  final mutationBoundary = _createMutationBoundary(request);
  final selectionActions = _createSelectionActions(mutationBoundary);
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    mutationBoundary: mutationBoundary,
  );
  return SceneControllerInteractionRuntime._(
    mutationBoundary: mutationBoundary,
    selectionActions: selectionActions,
    runtime: interactiveRuntime,
  );
}

extension SceneControllerInteractionRuntimeMutationApi
    on SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {}

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
    runtime.handlePointerFromSession(input, token: token);
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
  }
}

SceneControllerMutationBoundary _createMutationBoundary(
  SceneControllerInteractionRuntimeRequest request,
) {
  return SceneControllerMutationBoundary(
    mutationAccess: request.mutationAccess,
  );
}

InteractiveSelectionActions _createSelectionActions(
  SceneControllerMutationBoundary mutationBoundary,
) {
  return InteractiveSelectionActions(mutations: mutationBoundary);
}

InteractiveRuntime _createInteractiveRuntime(
  SceneControllerInteractionRuntimeRequest request, {
  required SceneControllerMutationBoundary mutationBoundary,
}) {
  return InteractiveRuntime(
    callbacks: InteractiveRuntimeCallbacks(
      writeSelectionReplace: mutationBoundary.setSelection,
      writeSelectionClear: mutationBoundary.clearSelection,
      commitMoveSelection: mutationBoundary.commitMoveSelection,
      commitDrawStroke: mutationBoundary.commitDrawStroke,
      commitDrawLineFromWorldSegment:
          mutationBoundary.commitDrawLineFromWorldSegment,
      commitEraseNodes: mutationBoundary.commitEraseNodes,
    ),
  );
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
                'SceneControllerInteractionRuntime must route committed '
                'selection/draw callbacks through SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime session callbacks routed through runtime alias without token validation',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
          '''
import 'dart:ui';

import '../contract/canvas_pointer_input.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import 'interactive_selection_actions.dart';
import 'interactive_runtime.dart';
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

final class SceneControllerInteractionRuntime {
  SceneControllerInteractionRuntime._({
    required this.mutationBoundary,
    required this.selectionActions,
    required this.runtime,
  });

  final SceneControllerMutationBoundary mutationBoundary;
  final InteractiveSelectionActions selectionActions;
  final InteractiveRuntime runtime;

  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}

  void _ensureKnownPointerSessionToken(PointerSessionToken token) {}
}

final class SceneControllerInteractionRuntimeRequest {
  const SceneControllerInteractionRuntimeRequest({
    required this.mutationAccess,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;
}

SceneControllerInteractionRuntime createSceneControllerInteractionRuntime({
  required SceneControllerInteractionRuntimeRequest request,
}) {
  final mutationBoundary = _createMutationBoundary(request);
  final selectionActions = _createSelectionActions(mutationBoundary);
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    mutationBoundary: mutationBoundary,
  );
  return SceneControllerInteractionRuntime._(
    mutationBoundary: mutationBoundary,
    selectionActions: selectionActions,
    runtime: interactiveRuntime,
  );
}

extension SceneControllerInteractionRuntimeMutationApi
    on SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {}

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {
    final rt = runtime;
    rt.handlePointerFromSession(input, token: token);
    _ensureKnownPointerSessionToken(token);
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    final rt = runtime;
    rt.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
    _ensureKnownPointerSessionToken(token);
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
  }
}

SceneControllerMutationBoundary _createMutationBoundary(
  SceneControllerInteractionRuntimeRequest request,
) {
  return SceneControllerMutationBoundary(
    mutationAccess: request.mutationAccess,
  );
}

InteractiveSelectionActions _createSelectionActions(
  SceneControllerMutationBoundary mutationBoundary,
) {
  return InteractiveSelectionActions(mutations: mutationBoundary);
}

InteractiveRuntime _createInteractiveRuntime(
  SceneControllerInteractionRuntimeRequest request, {
  required SceneControllerMutationBoundary mutationBoundary,
}) {
  return InteractiveRuntime(
    callbacks: InteractiveRuntimeCallbacks(
      writeSelectionReplace: mutationBoundary.setSelection,
      writeSelectionClear: mutationBoundary.clearSelection,
      commitMoveSelection: mutationBoundary.commitMoveSelection,
      commitDrawStroke: mutationBoundary.commitDrawStroke,
      commitDrawLineFromWorldSegment:
          mutationBoundary.commitDrawLineFromWorldSegment,
      commitEraseNodes: mutationBoundary.commitEraseNodes,
    ),
  );
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
                'SceneControllerInteractionRuntime must route committed '
                'selection/draw callbacks through SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects pointer session that skips owned resource release', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/scene_controller_pointer_session.dart',
        '''
import 'dart:ui';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/pointer_input.dart';
import '../../contract/scene_view_runtime.dart';
import '../../core/pointer_input_tracker.dart';
import 'pointer_session_token.dart';

final class SceneControllerPointerSession implements SceneViewPointerSession {
  SceneControllerPointerSession({
    required Listenable ownerListenable,
    required PointerSessionToken token,
    required void Function(PointerSessionToken token) detachPointerSession,
    required void Function(PointerSessionToken token)
    releasePointerSessionToken,
  }) : _ownerListenable = ownerListenable,
       _token = token,
       _detachPointerSession = detachPointerSession,
       _releasePointerSessionToken = releasePointerSessionToken,
       _pointerTracker = PointerInputTracker(settings: const PointerInputSettings()),
       _ownerListener = _handleOwnerChanged {
    _ownerListenable.addListener(_ownerListener);
  }

  final Listenable _ownerListenable;
  final PointerSessionToken _token;
  final void Function(PointerSessionToken token) _detachPointerSession;
  final void Function(PointerSessionToken token) _releasePointerSessionToken;
  final _PendingTapFlushScheduler _pendingTapFlushScheduler =
      _PendingTapFlushScheduler();
  final PointerInputTracker _pointerTracker;
  late final VoidCallback _ownerListener;

  @override
  int? get pendingTapFlushTimestampMs => null;

  @override
  void detach() {
    _detachPointerSession(_token);
  }

  @override
  void dispose() {
    detach();
    _pendingTapFlushScheduler.dispose();
  }

  @override
  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  }) {}

  @override
  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {}

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {}

  void _handleOwnerChanged() {}
}

class _PendingTapFlushScheduler {
  void dispose() {}
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
              'pointer session must stay owned by SceneControllerPointerSession',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects mutation boundary replaceScene without beforeApply hook',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_mutation_boundary.dart',
          '''
class SceneControllerMutationBoundary {
  const SceneControllerMutationBoundary({required this.mutationAccess});

  final _MutationAccess mutationAccess;

  void clearScene() {
    mutationAccess.clearSceneExactResult();
  }

  void setSelection(Object nodeIds) {
    mutationAccess.replaceSelection(nodeIds);
  }

  void clearSelection() {
    mutationAccess.clearSelection();
  }

  void deleteSelection() {
    mutationAccess.deleteSelection();
  }

  void replaceScene(Object snapshot, {required Object interruptBeforeApply}) {
    mutationAccess.replaceScene(snapshot);
  }

  Object commitMoveSelection(Object proposedDelta) => proposedDelta;

  Object commitDrawStroke(Object payload) {
    return mutationAccess.commitDrawStroke(payload);
  }

  Object commitDrawLineFromWorldSegment(Object payload) {
    return mutationAccess.commitDrawLineFromWorldSegment(payload);
  }

  int commitEraseNodes(Object ids) {
    return mutationAccess.commitEraseNodes(ids);
  }

  void notifySceneChanged() {
    mutationAccess.requestRepaint();
  }
}

class _MutationAccess {
  void clearSceneExactResult() {}
  void replaceSelection(Object nodeIds) {}
  void clearSelection() {}
  void deleteSelection() {}
  void replaceScene(Object snapshot) {}
  Object commitDrawStroke(Object payload) => payload;
  Object commitDrawLineFromWorldSegment(Object payload) => payload;
  int commitEraseNodes(Object ids) => 0;
  void requestRepaint() {}
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
                'SceneControllerMutationBoundary must remain the canonical '
                'scene/selection write owner',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects facade that re-owns runtime event state', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          extraImports: "import 'dart:async';",
          extraMembers: '''
  final StreamController<Object> _actions = StreamController<Object>.broadcast();
  final dynamic _runtime = Object();
  int _timestampCursorMs = 0;
''',
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(input);
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap();
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneController must remain a thin facade over '
              'the assembled controller graph',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects interactive runtime that drops split public/session entrypoints',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_runtime.dart',
          '''
import 'interactive_draw_coordinator.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_gesture_router.dart';
import 'interactive_double_tap_router.dart';

class InteractiveRuntime {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'InteractiveRuntime must keep event timeline and draw-local '
                'geometry outside the boundary runtime',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects SceneViewInteractive wrapper Listener shell', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(sandbox, 'lib/src/view/scene_view_interactive.dart', '''
import 'package:flutter/widgets.dart';

import '../interactive/scene_controller.dart';
import 'scene_view_runtime_host.dart';

class SceneViewInteractive extends StatelessWidget {
  const SceneViewInteractive({required this.controller, super.key});

  final SceneController controller;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {},
      child: SceneViewRuntimeHost(
        runtime: sceneControllerViewRuntimeOf(controller),
      ),
    );
  }
}
''');

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneViewInteractive must remain a thin public shell over '
              'SceneViewRuntimeHost',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects render surface with extra named constructor entrypoint',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_render_surface.dart',
          '''
import '../contract/scene_view_render_state.dart';

class SceneViewRenderSurface {
  SceneViewRenderSurface({required SceneViewRenderState renderState})
    : _renderState = renderState;

  SceneViewRenderSurface.interactive({required SceneViewRenderState renderState})
    : _renderState = renderState;

  final SceneViewRenderState _renderState;

  SceneViewRenderSurfaceState createState() => SceneViewRenderSurfaceState();
}

class SceneViewRenderSurfaceState extends State<SceneViewRenderSurface> {
  void initState() {
    widget._renderState.addListener(_handleControllerChanged);
  }

  void didUpdateWidget(SceneViewRenderSurface oldWidget) {
    oldWidget._renderState.removeListener(_handleControllerChanged);
    widget._renderState.addListener(_handleControllerChanged);
  }

  void dispose() {
    widget._renderState.removeListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {}
}

class State<T> {
  T get widget => throw UnimplementedError();
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
                'SceneViewRenderSurface must remain a render-state-only '
                'view surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects PointerSessionToken with exposed payload field', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/pointer_session_token.dart',
        '''
class PointerSessionToken {
  const PointerSessionToken(this.id);

  final int id;
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
              'PointerSessionToken must remain an opaque internal nominal token',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects PointerSessionToken with exposed payload field under another name',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/pointer_session_token.dart',
          '''
final class PointerSessionToken {
  const PointerSessionToken(this.rawValue);

  final int rawValue;
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
                'PointerSessionToken must remain an opaque internal nominal token',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects event dispatcher that re-owns eraser geometry helper', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/interactive_event_dispatcher.dart',
        '''
import 'dart:async';

class InteractiveEventDispatcher {
  final StreamController<Object> _actions = StreamController<Object>.broadcast();
  final StreamController<Object> _editTextRequests =
      StreamController<Object>.broadcast();

  int resolveTimestampMs(int? value) => value ?? 0;

  void emitAction(Object type, List<Object> nodeIds, int timestampMs) {}

  void emitEditTextRequested(Object request) {}

  bool _eraserHitsLine() => false;
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
              'InteractiveEventDispatcher must remain the event timeline owner',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects projected eraser contract that drops thresholdSquared',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_draw_eraser_projection.dart',
          '''
import 'dart:ui';

typedef InteractiveDrawProjectedEraser = ({
  List<Offset> points,
  double threshold,
});
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'InteractiveDrawProjectedEraser must remain the shared '
                'projection contract',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}
