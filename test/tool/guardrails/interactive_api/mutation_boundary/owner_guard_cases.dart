part of '../../guardrails_interactive_api_tool_test.dart';

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
          sceneControllerFixture(
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
        sceneControllerFixture(
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
        sceneControllerFixture(
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
          sceneControllerFixture(
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
          sceneControllerFixture(
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
          sceneControllerFixture(
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
          sceneControllerFixture(
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
          sceneControllerFixture(
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
          sceneControllerFixture(
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
          sceneControllerFixture(
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
          sceneControllerFixture(
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
        sceneControllerFixture(
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
          sceneControllerFixture(
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
        sceneControllerFixture(
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
        sceneControllerFixture(
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
          sceneControllerFixture(
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
        sceneControllerFixture(
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
